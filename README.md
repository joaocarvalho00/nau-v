# Nau-V

A **RV32I** RISC-V processor core written in SystemVerilog, available in two microarchitectural variants:

| Variant | Description | CPI |
|---------|-------------|-----|
| **Single-cycle** (`core.sv`) | Every instruction completes in exactly one clock cycle | 1.0 |
| **5-stage pipeline** (`core_pipeline.sv`) | Classic IF/ID/EX/MEM/WB pipeline with full hazard handling | ≥1.0 (stalls on load-use, flush on branch) |

Both variants implement the full base integer instruction set (RV32I, 47 instructions) and share identical port interfaces so testbenches, software, and synthesis scripts work unchanged for either design.

## Test Status

<!-- DASHBOARD_START -->
| Suite | Status | Details | Last run |
|-------|--------|---------|----------|
| Unit tests (Verilator) | $\color{green}{\textsf{PASS}}$ | 168/168 checks · 5/5 testbenches | 2026-03-14 12:29 UTC |
| riscv-tests RV32UI | $\color{green}{\textsf{PASS}}$ | 40/40 passed · 2 skipped | 2026-03-14 12:29 UTC |
<!-- DASHBOARD_END -->

*Updated automatically by the [pre-commit hook](.githooks/pre-commit) on every commit. Run `bash .githooks/pre-commit` to refresh manually.*

---

## Table of Contents

1. [Repository Layout](#repository-layout)
2. [Architecture](#architecture)
   - [Single-cycle](#single-cycle-coreSV)
   - [5-stage Pipeline](#5-stage-pipeline-core_pipelinesv)
   - [Memory Map](#memory-map)
3. [RTL Modules](#rtl-modules)
4. [Testbenches](#testbenches)
5. [Compliance Testing](#compliance-testing)
6. [Software](#software)
7. [Dhrystone Benchmark](#dhrystone-benchmark)
8. [Synthesis](#synthesis)
9. [Tools & Dependencies](#tools--dependencies)
10. [Useful Commands](#useful-commands)

---

## Repository Layout

```
NauV/
├── src/
│   ├── if/         # Instruction Fetch stage
│   │   └── if_stage.sv
│   ├── id/         # Instruction Decode & Register Read stage
│   │   ├── decoder.sv
│   │   ├── regfile.sv
│   │   └── id_stage.sv
│   ├── ex/         # Execute stage
│   │   ├── alu.sv
│   │   └── ex_stage.sv
│   ├── mem/        # Memory Access stage
│   │   └── mem_stage.sv
│   ├── wb/         # Write Back stage
│   │   └── wb_stage.sv
│   └── core/       # Top-level integration + memories
│       ├── imem.sv
│       ├── dmem.sv
│       ├── core.sv             # Single-cycle top-level
│       ├── core_pipeline.sv    # 5-stage pipeline top-level
│       └── hazard_unit.sv      # Stall + flush controller (pipeline only)
├── tb/             # SystemVerilog testbenches
│   ├── tb_alu.sv
│   ├── tb_regfile.sv
│   ├── tb_decoder.sv
│   ├── tb_if_stage.sv
│   ├── tb_core.sv
│   └── tb_prog.sv  # Generic program runner (works for both designs)
├── sim/
│   ├── Makefile                # Verilator build: PIPELINE=0 (default) or PIPELINE=1
│   ├── run_dhrystone.sh        # Dhrystone sweep: PIPELINE=0/1
│   └── riscv-tests/            # RISC-V compliance test runner + NauV environment
├── software/
│   ├── startup/    # Shared bare-metal runtime (startup.S, link.ld, bin2hex.py)
│   ├── hello/      # Example C program
│   └── dhrystone/  # Dhrystone 2.1 benchmark port
├── synth/
│   ├── Makefile    # Synthesis targets: synth, timing, sweep, sweep_both, clean
│   ├── scripts/
│   │   ├── synth.tcl         # Yosys Tcl script (PIPELINE=0/1 env var)
│   │   ├── sta.tcl           # OpenSTA timing + power script
│   │   ├── mem_blackbox.v    # Black-box stubs for imem and dmem
│   │   ├── parse_reports.py  # Parse sweep reports → summary.csv
│   │   └── plot_results.py   # Comparison plots → docs/figures/
│   └── lib/                  # NanGate45 liberty file (gitignored, download separately)
├── scripts/
│   ├── update_dashboard.py  # README dashboard updater (used by pre-commit hook)
│   └── plot_dhrystone.py    # Dhrystone results plotter (single-cycle + pipeline)
└── docs/
    └── figures/    # Synthesis KPI and benchmark plots (tracked)
```

---

## Architecture

### Single-cycle (`core.sv`)

Every instruction completes in one clock cycle. All combinational paths connect directly from IF to WB within the same cycle. There are no pipeline registers. CPI = 1.0 for all instructions.

```
         ┌──────────────────────────────────────────────────────┐
  clk ──►│                                                      │
  rst ──►│  IF          ID           EX         MEM        WB  │
         │  ──────      ──────       ──────      ──────     ──  │
         │  if_stage    id_stage     ex_stage    mem_stage  wb  │
         │   │ PC        │ decode     │ ALU        │ dmem    │  │
         │   ▼           │ regfile    │ branch     │ ld/st   ▼  │
         │  imem         └────────────────────────────────► rd  │
         │                     ◄── WB writeback ──────────────  │
         └──────────────────────────────────────────────────────┘
```

### 5-stage Pipeline (`core_pipeline.sv`)

A classic five-stage in-order pipeline with full hazard handling. Module name and port interface are identical to `core.sv` — the Makefile selects which file to compile via `PIPELINE=0/1`.

```
  IF        ID        EX        MEM       WB
  ──────    ──────    ──────    ──────    ──────
  if_stage  id_stage  ex_stage  mem_stage wb_stage
    │  ───────►  ───────►  ───────►  ───────►
    │       IF/ID     ID/EX    EX/MEM   MEM/WB
    │       reg       reg      reg      reg
    │
    ◄─── flush (2 cycles on branch/jump) ────────
              ◄── EX/MEM forward ──────
              ◄──── MEM/WB forward ────────────
```

**Hazard handling:**

| Hazard | Cause | Resolution | Cost |
|--------|-------|------------|------|
| Load-use | Load in EX, dependent in ID | Stall IF+ID for 1 cycle, insert bubble into EX | +1 cycle |
| Control (branch/jump) | Branch/JALR resolves in EX | Flush IF+ID (2 bubbles) | +2 cycles |
| EX→EX data | Result in EX/MEM needed by EX | Forward `alu_result` → operand mux | 0 cycles |
| MEM→EX data | Result in MEM/WB needed by EX | Forward `rd_data` → operand mux | 0 cycles |
| WB→ID data | Writer in WB, reader in ID same cycle | Bypass `wb_rd_data` into ID/EX register | 0 cycles |

The WB→ID bypass is necessary because the register file's asynchronous read output doesn't settle in time for the `always_ff` ID/EX capture when WB writes in the same cycle.

Forwarding is suppressed for load results that are still in the MEM stage (a load-use stall handles those instead).

### Memory Map

| Region | Address Range | Size | Physical |
|--------|--------------|------|----------|
| Instruction memory | `0x0000_0000` – `0x0000_3FFF` | 16 KB | `imem` (read via PC) |
| Data memory | `0x0000_0000` – `0x0000_3FFF` | 16 KB | `dmem` (read/write via load/store) |
| Stack (top) | `0x0000_4000` | — | `dmem`, grows downward |

Both designs are **Harvard architecture**: instruction and data spaces share the same virtual address range but use separate physical memories.

---

## RTL Modules

All modules are written in SystemVerilog. Combinational logic uses `always_comb`; sequential logic uses `always_ff @(posedge clk)` with synchronous active-high reset. Signal names use `snake_case` prefixed by stage of origin (e.g. `id_rs1_addr`, `ex_alu_result`).

### IF — `if_stage`

**File:** `src/if/if_stage.sv`

Holds the Program Counter register. `pc_en` (active high) gates PC advance — used by the pipeline's hazard unit for stalls; the single-cycle core ties it high. `if_pc_plus4` is a combinational output used by JAL/JALR to save the return address.

| Port | Direction | Description |
|------|-----------|-------------|
| `clk`, `rst` | in | Clock and synchronous active-high reset |
| `pc_en` | in | `1` = advance PC; `0` = hold (stall) |
| `pc_sel` | in | `0` = PC+4, `1` = jump/branch target |
| `if_pc_target` | in | Target address from EX stage |
| `if_pc` | out | Current PC (registered) |
| `if_pc_plus4` | out | PC+4 (combinational) |

On reset, PC is set to `0x0000_0000`.

---

### ID — `decoder`

**File:** `src/id/decoder.sv`

Fully combinational decoder for all nine RV32I opcode groups. Given a 32-bit instruction word it produces register addresses, a sign-extended immediate, an ALU operation code, and a complete set of control signals for downstream stages.

| Opcode | Instructions |
|--------|-------------|
| R-type (`0110011`) | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| I-type ALU (`0010011`) | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| Load (`0000011`) | LB, LH, LW, LBU, LHU |
| Store (`0100011`) | SB, SH, SW |
| Branch (`1100011`) | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| JAL (`1101111`) | JAL |
| JALR (`1100111`) | JALR |
| LUI (`0110111`) | LUI |
| AUIPC (`0010111`) | AUIPC |

---

### ID — `regfile`

**File:** `src/id/regfile.sv`

32 × 32-bit general-purpose register file. `x0` is hardwired to zero. Reads are asynchronous; writes are synchronous on the rising clock edge.

---

### ID — `id_stage`

**File:** `src/id/id_stage.sv`

Wrapper that instantiates `decoder` and `regfile`. Exposes the register file's debug read port for testbenches.

---

### EX — `alu`

**File:** `src/ex/alu.sv`

Purely combinational. Implements all eleven RV32I ALU operations (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS_B) plus zero/neg/overflow status flags.

---

### EX — `ex_stage`

**File:** `src/ex/ex_stage.sv`

Selects ALU operands, instantiates `alu`, evaluates branch conditions, and computes the next-PC target. For branches, the ALU is forced to SUB so the zero/neg/overflow flags reflect `rs1 − rs2`. `ex_pc_sel` is asserted for any jump or taken branch.

---

### MEM — `mem_stage`

**File:** `src/mem/mem_stage.sv`

Purely combinational. Computes byte-enable signals and data alignment for stores (SB/SH/SW), and performs sign/zero extension for loads (LB/LBU/LH/LHU/LW).

---

### WB — `wb_stage`

**File:** `src/wb/wb_stage.sv`

Purely combinational. Selects write-back data from three sources: PC+4 (JAL/JALR), memory read data (loads), or ALU result (everything else).

---

### Core — `imem`

**File:** `src/core/imem.sv`

Asynchronous-read, 4096 × 32-bit instruction memory (16 KB). Initialised to NOP. Includes a clocked write port for testbench program loading.

---

### Core — `dmem`

**File:** `src/core/dmem.sv`

Synchronous-write, asynchronous-read, 4096 × 32-bit data memory (16 KB) with 4-bit byte-enable masking.

---

### Core — `core` / `core_pipeline` (top-level)

**Files:** `src/core/core.sv` and `src/core/core_pipeline.sv`

Both modules are named `core` with identical port interfaces. The Makefile variable `PIPELINE=0/1` selects which file compiles — no `ifdef` directives appear in the RTL.

`core_pipeline.sv` adds:
- Four `always_ff` pipeline register blocks (IF/ID, ID/EX, EX/MEM, MEM/WB)
- `hazard_unit` instantiation for stall and flush control
- Combinational forwarding muxes for EX/MEM→EX and MEM/WB→EX paths
- WB→ID bypass in the ID/EX register block

`hazard_unit.sv` detects load-use hazards (stall) and branch/jump resolution (flush), filtering `rs1`/`rs2` use by opcode to avoid spurious stalls.

---

## Testbenches

All testbenches are written in pure SystemVerilog and compiled with Verilator. Each is self-checking, prints `PASS`/`FAIL` per test case, and dumps a `.vcd` waveform.

| Testbench | What it tests | Checks |
|-----------|--------------|--------|
| `tb_alu.sv` | All 11 ALU operations, status flags | 33 |
| `tb_regfile.sv` | Reset, x0 protection, simultaneous reads, debug port | 13 |
| `tb_decoder.sv` | All instruction formats and control signals | 96 |
| `tb_if_stage.sv` | PC reset, sequential increment, branch redirect, stall | 13 |
| `tb_core.sv` | Full integration (single-cycle only): ALU, loads/stores, branches, jumps | 13 |
| `tb_prog.sv` | Generic program runner — loads a compiled hex at runtime, monitors tohost | — |

`tb_core` is specific to single-cycle timing assumptions and is excluded from the pipeline test suite (compliance testing via `tb_prog` covers correctness instead).

`tb_prog` works with both designs: tohost=1 → PASS, other non-zero → FAIL (encoding: `(TESTNUM<<1)|1`).

---

## Compliance Testing

Nau-V is verified against the official [riscv-tests](https://github.com/riscv-software-src/riscv-tests) RV32UI suite — 40 tests covering every RV32I instruction. Both the single-cycle and pipelined designs pass all 40 tests.

### Test coverage

| Category | Tests | Status |
|----------|-------|--------|
| Arithmetic & logic | `add` `addi` `sub` `and` `andi` `or` `ori` `xor` `xori` | PASS |
| Shifts | `sll` `slli` `srl` `srli` `sra` `srai` | PASS |
| Comparisons | `slt` `slti` `sltu` `sltiu` | PASS |
| Upper-immediate | `lui` `auipc` | PASS |
| Branches | `beq` `bne` `blt` `bltu` `bge` `bgeu` | PASS |
| Jumps | `jal` `jalr` | PASS |
| Loads | `lb` `lbu` `lh` `lhu` `lw` | PASS |
| Stores | `sb` `sh` `sw` | PASS |
| Misc | `simple` `ld_st` `st_ld` | PASS |
| Skipped | `fence_i` `ma_data` | Zifencei / trap handling — out of scope |

### Setup

```bash
# Clone the test suite once (gitignored at repo root)
git clone https://github.com/riscv-software-src/riscv-tests

# Single-cycle
./sim/riscv-tests/run_riscv_tests.sh

# Pipeline
./sim/riscv-tests/run_riscv_tests.sh --pipeline
```

---

## Software

### Bare-Metal Infrastructure

**Location:** `software/startup/`

| File | Purpose |
|------|---------|
| `startup.S` | Entry at `_start` (PC=0): sets `sp=0x4000`, zeroes `.bss`, calls `main` |
| `link.ld` | `.text` at `0x0` (→ imem); `.data`/`.bss`/stack in data space (→ dmem) |
| `bin2hex.py` | Converts raw binary to Verilog `$readmemh` hex format |

Compilation: `-march=rv32i -mabi=ilp32 -nostdlib -ffreestanding`.

Because the core is Harvard, initialised globals (`.data`) must be loaded via a separate `data.hex` file — they cannot be copied from imem at startup.

### Hello World

**Location:** `software/hello/`

Eight arithmetic/logic tests; writes `tohost=1` on success or an error code identifying the failing test.

---

## Dhrystone Benchmark

Dhrystone 2.1 is the classic synthetic integer benchmark. The metric is **DMIPS/MHz**:

```
DMIPS/MHz = (iterations × 1,000,000) / (cycles × 1757)
```

### Results

| Iterations | SC Cycles | SC DMIPS/MHz | PL Cycles | PL DMIPS/MHz |
|------------|-----------|-------------|-----------|-------------|
| 100  | 61,960  | 0.92 | 94,313  | 0.60 |
| 500  | 267,160 | 1.07 | 407,513 | 0.70 |
| 1,000 | 523,660 | 1.09 | 799,013 | 0.71 |
| 2,000 | 1,036,660 | 1.10 | 1,582,013 | 0.72 |
| 5,000 | 2,580,660 | **1.10** | 3,936,013 | **0.72** |

*SC = Single-cycle · PL = Pipeline*

The single-cycle design scores **1.10 DMIPS/MHz** at steady state (~516 cycles/iteration). The pipeline scores **0.72 DMIPS/MHz** (~787 cycles/iteration). The lower pipeline score reflects stall overhead: Dhrystone is a stall-heavy workload with frequent load-use sequences and many short branch-taken paths, each incurring the 2-cycle flush penalty.

For context: ARM Cortex-M0 ~0.9 DMIPS/MHz; Cortex-M3 ~1.25 DMIPS/MHz.

### Figures

| DMIPS/MHz vs iterations | Cycles per run vs iterations |
|:-:|:-:|
| ![DMIPS/MHz](docs/figures/dhrystone_dmips.png) | ![Cycles/run](docs/figures/dhrystone_cpr.png) |

### Implementation Notes

String constants normally go to `.rodata` (imem) and cannot be read by load instructions on a Harvard core. The benchmark stores all Dhrystone strings in `.data` (→ dmem), loaded via `dhrystone.data.hex`.

tohost address is **0x3000** — above the `.bss` region (0x0628–0x2E60), so the startup BSS-zero loop doesn't trigger a false signal.

---

## Synthesis

The `synth/` directory contains a complete logic synthesis flow targeting **NanGate 45 nm** open-source standard-cell library. Both designs can be synthesised — `PIPELINE=0` (default) or `PIPELINE=1`.

`imem`/`dmem` are black-boxed (SRAM macros in silicon). All metrics reflect **datapath logic only**.

### Results at 100 MHz

| Metric | Single-cycle | Pipeline | Delta |
|--------|-------------|----------|-------|
| **Area** | 13,852 µm² | 17,099 µm² | +23% |
| **Area (GTE)** | 17,358 | 21,427 | +23% |
| **WNS** | +4.822 ns | +4.870 ns | — |
| **Fmax (estimated)** | ~193 MHz | ~195 MHz | — |
| **Power** | 1.34 mW | 1.89 mW | +41% |

The pipeline area overhead (+23%) comes from the four pipeline register banks, the hazard unit, and the forwarding mux logic. Both designs achieve the same Fmax because the critical path runs through the same combinational logic (decode + ALU + branch evaluation) — the pipeline only adds registers at stage boundaries.

### Frequency Sweep (50–250 MHz)

Both designs close timing up to **150 MHz** and fail at 200 MHz.

| Freq | SC WNS | SC Power | PL WNS | PL Power |
|------|--------|----------|--------|----------|
| 50 MHz  | +14.822 ns | 0.83 mW | +14.870 ns | 1.14 mW |
| 100 MHz | +4.822 ns  | 1.34 mW | +4.870 ns  | 1.89 mW |
| 150 MHz | +1.489 ns  | 1.86 mW | +1.536 ns  | 2.65 mW |
| 200 MHz | −0.178 ns  | 2.37 mW | −0.130 ns  | 3.40 mW |
| 250 MHz | −1.178 ns  | 2.88 mW | −1.130 ns  | 4.16 mW |

*SC = Single-cycle · PL = Pipeline*

**Fmax (sweep): 150 MHz** for both designs.

![Slack vs Frequency](docs/figures/slack_vs_freq.png)

![Power vs Frequency](docs/figures/power_vs_freq.png)

![Area vs Frequency](docs/figures/area_vs_freq.png)

> Area stays flat across the sweep because Yosys+ABC is a one-shot mapper. Area/speed
> tradeoffs become visible in a full place-and-route flow (e.g. OpenROAD).

### Running synthesis

```bash
# Download NanGate45 liberty file (once)
mkdir -p synth/lib
curl -L "https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib" \
     -o synth/lib/NangateOpenCellLibrary_typical.lib

cd synth

# Baseline synthesis + STA (single-cycle)
make all

# Baseline synthesis + STA (pipeline)
make all PIPELINE=1

# Frequency sweep — single design
make sweep           # single-cycle
make sweep PIPELINE=1  # pipeline

# Frequency sweep — both designs + comparison plots
make sweep_both
```

---

## Tools & Dependencies

| Tool | Version | Purpose |
|------|---------|---------|
| [Verilator](https://www.veripool.org/verilator/) | ≥ 5.0 | RTL simulation |
| [GTKWave](https://gtkwave.sourceforge.net/) | any | Waveform viewing |
| `gcc-riscv64-unknown-elf` | any | Bare-metal C/assembly compiler |
| `binutils-riscv64-unknown-elf` | any | `objcopy`, `objdump`, linker |
| [Yosys](https://github.com/YosysHQ/yosys) | ≥ 0.35 | Logic synthesis |
| [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA) | any | Static timing analysis + power |
| Python | ≥ 3.10 | `bin2hex.py`, synthesis report scripts |
| Make | any | Build system |

Install RISC-V toolchain on Ubuntu/Debian:

```bash
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf picolibc-riscv64-unknown-elf
```

---

## Useful Commands

### Run unit tests

```bash
cd sim

# Single-cycle (default)
make run

# Pipeline
make run PIPELINE=1
```

### Run a compiled program

```bash
cd sim

# Single-cycle
make prog TEXT=../software/hello/hello.text.hex

# Pipeline
make prog TEXT=../software/hello/hello.text.hex PIPELINE=1
```

### Open waveform in GTKWave

```bash
cd sim
make wave MOD=tb_core           # single-cycle only
make wave MOD=tb_alu            # shared
```

### RISC-V compliance tests

```bash
# Clone once (gitignored)
git clone https://github.com/riscv-software-src/riscv-tests

# Single-cycle
./sim/riscv-tests/run_riscv_tests.sh

# Pipeline
./sim/riscv-tests/run_riscv_tests.sh --pipeline

# Verbose output on failure
./sim/riscv-tests/run_riscv_tests.sh --pipeline --verbose
```

### Dhrystone benchmark

```bash
# Full sweep → reports/dhrystone.csv
bash sim/run_dhrystone.sh

# Pipeline sweep → reports/dhrystone_pipeline.csv
PIPELINE=1 bash sim/run_dhrystone.sh

# Regenerate comparison plots
python3 scripts/plot_dhrystone.py
```

### Synthesis

```bash
cd synth

# Single-cycle baseline
make all

# Pipeline baseline
make all PIPELINE=1

# Frequency sweep, single design
make sweep             # single-cycle
make sweep PIPELINE=1  # pipeline

# Both designs with comparison plots
make sweep_both

# Clean all generated files
make clean
```

### Pre-commit hook

```bash
# Activate once per clone
git config core.hooksPath .githooks

# Run manually
bash .githooks/pre-commit

# Bypass for WIP commits
git commit --no-verify -m "wip: ..."
```

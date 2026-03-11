# Claude-V - An AI generated RISC-V core

- [Claude-V - An AI generated RISC-V core](#claude-v---an-ai-generated-risc-v-core)
  - [Summary](#summary)
  - [Architecture](#architecture)
  - [Organization](#organization)
  - [Coding Conventions](#coding-conventions)
  - [Tools \& Dependencies](#tools--dependencies)
  - [Testing](#testing)
    - [Phase 1 — SystemVerilog Testbenches](#phase-1--systemverilog-testbenches)
    - [Phase 2 — RISC-V Compliance Tests](#phase-2--risc-v-compliance-tests)
    - [Phase 3 — Dhrystone Benchmark](#phase-3--dhrystone-benchmark)

## Summary

Claude-V is my attempt at creating a simple RISC-V core to test out the capabilities of Claude Code.
This file will contain instructions on how I want the code to be organized, generated and tested.

## Architecture

Claude-V is a RV32I compliant RISC-V core supporting all opcodes in the I (integer) extension.

The initial implementation is **single-cycle**: every instruction completes within one clock cycle, with no pipeline registers between stages. However, the RTL must be written with a future **5-stage pipeline** refactor in mind. The five classic RISC-V pipeline stages are:

1. **IF** - Instruction Fetch
2. **ID** - Instruction Decode & Register Read
3. **EX** - Execute (ALU)
4. **MEM** - Memory Access
5. **WB** - Write Back

Even in the single-cycle implementation, the logic should be clearly partitioned into these five functional blocks using separate modules or clearly delineated `always_comb` blocks. This will make the transition to a pipelined design significantly easier by just inserting pipeline registers between the existing stage modules.

## Organization

The repository is organized as follows:

```
ClaudeV/
├── src/          # RTL source files (SystemVerilog)
│   ├── if/       # Instruction Fetch stage logic
│   ├── id/       # Instruction Decode stage logic
│   ├── ex/       # Execute stage logic (ALU, branch resolution)
│   ├── mem/      # Memory Access stage logic
│   ├── wb/       # Write Back stage logic
│   └── core/     # Top-level core integration
├── tb/           # SystemVerilog testbenches
├── sim/          # Simulation scripts, waveform configs, and Verilator build files
├── software/     # C/Assembly programs to run on the core (compliance tests, benchmarks)
│   ├── riscv-tests/   # RISC-V compliance test suite (riscv-tests)
│   └── dhrystone/     # Dhrystone benchmark
└── docs/         # Documentation, diagrams, and design notes
```

## Coding Conventions

All RTL is written in **SystemVerilog**. The following conventions must be followed to keep the codebase clean and to ease the future pipeline refactor:

- **One module per file.** File name must match module name (e.g., `alu.sv` contains `module alu`).
- **Stage separation.** Each pipeline stage must be implemented as its own module, even in the single-cycle version. The top-level core module instantiates and connects all stage modules.
- **Combinational vs sequential separation.** Use `always_comb` for combinational logic and `always_ff @(posedge clk)` for sequential logic. Never mix them in the same block.
- **Signal naming.** Use lowercase `snake_case` for all signal names. Prefix signals with their stage of origin where ambiguous (e.g., `id_rs1_addr`, `ex_alu_result`).
- **Parameters over `define`.** Use `parameter` and `localparam` for constants. Avoid `` `define `` macros except for global include guards.
- **No latches.** All `always_comb` blocks must have fully specified outputs to avoid unintended latches.
- **Reset.** Use synchronous active-high reset (`rst`) throughout, unless there is a strong reason to do otherwise.

## Tools & Dependencies

| Tool | Version | Purpose |
|------|---------|---------|
| [Verilator](https://www.veripool.org/verilator/) | ≥ 5.0 | RTL simulation |
| [GTKWave](https://gtkwave.sourceforge.net/) | any | Waveform viewing |
| RISC-V GNU Toolchain | any | Compiling software / compliance tests |
| [riscv-tests](https://github.com/riscv-software-src/riscv-tests) | latest | RISC-V ISA compliance test suite |
| Dhrystone | 2.1 | Benchmark |
| Python | ≥ 3.10 | Simulation helper scripts |
| Make | any | Build system |

## Testing

Testing is done in two phases:

### Phase 1 — SystemVerilog Testbenches

Hand-written SystemVerilog testbenches located in `tb/` are used for unit and integration testing of individual modules (ALU, decoder, register file, etc.) and the full core. Testbenches are compiled and run with Verilator.

Each testbench should:
- Test all relevant instruction types and edge cases.
- Self-check results using `assert` statements and print a clear `PASS` / `FAIL` summary.
- Dump waveforms in `.vcd` format for debugging with GTKWave.

### Phase 2 — RISC-V Compliance Tests

The [riscv-tests](https://github.com/riscv-software-src/riscv-tests) suite is used to validate full ISA compliance. Test binaries are compiled with the RISC-V GNU Toolchain and loaded into the simulated core. A pass/fail result is determined by checking the value written to a designated result register or memory address as defined by the test suite.

### Phase 3 — Dhrystone Benchmark

Once the core passes compliance tests, the [Dhrystone 2.1](https://github.com/riscv-software-src/riscv-tests/tree/master/benchmarks) benchmark will be used to measure performance in DMIPS/MHz. This serves as the primary performance metric for comparing the single-cycle and future pipelined implementations.

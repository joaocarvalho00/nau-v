#!/usr/bin/env bash
# run_riscv_tests.sh — Compile and run all RV32UI riscv-tests on the NauV core.
#
# Usage:
#   ./sim/riscv-tests/run_riscv_tests.sh [--verbose]
#
# Environment variables:
#   RISCV_TESTS_DIR   Path to cloned riscv-tests repo
#                     (default: <repo-root>/riscv-tests)
#
# Exit code: 0 = all tests passed, 1 = one or more failed.

set -euo pipefail

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RISCV_TESTS_DIR="${RISCV_TESTS_DIR:-$REPO_ROOT/riscv-tests}"
ENV_DIR="$REPO_ROOT/sim/riscv-tests/env/nauv"
SIM_DIR="$REPO_ROOT/sim"
BIN2HEX="$REPO_ROOT/software/startup/bin2hex.py"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Tests skipped because they require features outside base RV32I:
#   fence_i  — uses FENCE.I (Zifencei extension, not in base RV32I)
#   ma_data  — tests misaligned-access trap handling (no exception unit)
# ---------------------------------------------------------------------------
SKIP_TESTS="fence_i ma_data"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
if [ ! -d "$RISCV_TESTS_DIR" ]; then
    echo -e "${RED}ERROR:${NC} riscv-tests repo not found at: $RISCV_TESTS_DIR"
    echo ""
    echo "Clone it with:"
    echo "  git clone https://github.com/riscv-software-src/riscv-tests $RISCV_TESTS_DIR"
    exit 1
fi

MACROS_DIR="$RISCV_TESTS_DIR/isa/macros/scalar"
TESTS_DIR="$RISCV_TESTS_DIR/isa/rv32ui"

if [ ! -d "$MACROS_DIR" ]; then
    echo -e "${RED}ERROR:${NC} test_macros.h not found at $MACROS_DIR"
    echo "The riscv-tests repo may be incomplete. Re-clone and try again."
    exit 1
fi

if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
    echo -e "${RED}ERROR:${NC} riscv64-unknown-elf-gcc not in PATH"
    exit 1
fi

# ---------------------------------------------------------------------------
# Compile tb_prog once (reused for all tests)
# ---------------------------------------------------------------------------
echo "=== Compiling tb_prog ==="
make -C "$SIM_DIR" tb_prog --no-print-directory
VTBPROG="$SIM_DIR/build/tb_prog/Vtb_prog"

# ---------------------------------------------------------------------------
# Run each RV32UI test
# ---------------------------------------------------------------------------
echo ""
echo "=== Running RV32UI riscv-tests ==="
echo ""

PASS=0
FAIL=0
SKIP=0
ERRORS=()

for test_src in "$TESTS_DIR"/*.S; do
    name=$(basename "$test_src" .S)

    # Skip tests that require out-of-scope features
    if echo "$SKIP_TESTS" | grep -qw "$name"; then
        printf "  %-20s  ${YELLOW}SKIPPED${NC}\n" "$name"
        SKIP=$((SKIP + 1))
        continue
    fi

    elf="$WORK_DIR/$name.elf"
    text_bin="$WORK_DIR/$name.text.bin"
    text_hex="$WORK_DIR/$name.text.hex"
    data_bin="$WORK_DIR/$name.data.bin"
    data_hex="$WORK_DIR/$name.data.hex"

    # 1. Compile the test
    compile_log="$WORK_DIR/$name.compile.log"
    if ! riscv64-unknown-elf-gcc \
            -march=rv32i -mabi=ilp32 \
            -nostdlib -static \
            -T "$ENV_DIR/link.ld" \
            -I "$MACROS_DIR" \
            -I "$ENV_DIR" \
            "$test_src" -o "$elf" \
            >"$compile_log" 2>&1; then
        printf "  %-20s  ${RED}COMPILE ERROR${NC}\n" "$name"
        [[ $VERBOSE -eq 1 ]] && cat "$compile_log"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name (compile error)")
        continue
    fi

    # 2. Extract .text sections → imem hex
    riscv64-unknown-elf-objcopy -O binary \
        --only-section=.text.init \
        --only-section=.text \
        --only-section=.rodata \
        "$elf" "$text_bin"
    python3 "$BIN2HEX" "$text_bin" "$text_hex" >/dev/null

    # 3. Extract .data section → dmem hex (if non-empty)
    #    The linker script places .data at 0x2000; tests use pre-initialised
    #    byte tables (e.g. tdat in lb.S: 0xff 0x00 0xf0 0x0f) that must be
    #    present in dmem for the load tests to see the expected values.
    data_arg=""
    riscv64-unknown-elf-objcopy -O binary \
        --only-section=.data \
        "$elf" "$data_bin" 2>/dev/null || true
    if [ -s "$data_bin" ]; then
        python3 "$BIN2HEX" "$data_bin" "$data_hex" --base-addr 0x2000 >/dev/null
        data_arg="+DATA_HEX=$data_hex"
    fi

    # 4. Run on the NauV core
    run_log="$WORK_DIR/$name.run.log"
    if "$VTBPROG" \
            "+TEXT_HEX=$text_hex" \
            $data_arg \
            "+TOHOST_ADDR=1000" \
            "+TIMEOUT=200000" \
            >"$run_log" 2>&1; then
        printf "  %-20s  ${GREEN}PASS${NC}\n" "$name"
        PASS=$((PASS + 1))
    else
        # Decode the tohost failure value: tohost = (TESTNUM<<1)|1
        tohost=$(grep -oP 'tohost=0x\K[0-9a-f]+' "$run_log" | head -1 || echo "?")
        if [[ "$tohost" =~ ^[0-9a-f]+$ ]]; then
            testnum=$(( (16#$tohost - 1) / 2 ))
            printf "  %-20s  ${RED}FAIL${NC}  (sub-test #%d, tohost=0x%s)\n" \
                   "$name" "$testnum" "$tohost"
        else
            printf "  %-20s  ${RED}FAIL${NC}\n" "$name"
        fi
        [[ $VERBOSE -eq 1 ]] && cat "$run_log"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name")
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "────────────────────────────────────────"
printf "  Passed  : ${GREEN}%d${NC}\n"   "$PASS"
printf "  Failed  : ${RED}%d${NC}\n"     "$FAIL"
printf "  Skipped : ${YELLOW}%d${NC}\n"  "$SKIP"
echo "────────────────────────────────────────"

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    for e in "${ERRORS[@]}"; do
        echo "  - $e"
    done
    echo ""
    echo "Tip: rerun with --verbose to see the simulator output for each failure."
    exit 1
fi

echo ""
echo -e "${GREEN}All applicable RV32UI tests passed.${NC}"
exit 0

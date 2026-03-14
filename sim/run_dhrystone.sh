#!/usr/bin/env bash
# run_dhrystone.sh — Build and run Dhrystone at multiple iteration counts.
#
# For each run:
#   1. Rebuild software/dhrystone with the given NUMBER_OF_RUNS.
#   2. Execute Vtb_prog and capture the cycle count.
#   3. Compute DMIPS/MHz = runs / (cycles × 1757).
#   4. Append a CSV row to reports/dhrystone.csv.
#
# Usage:
#   ./sim/run_dhrystone.sh [--runs "N1 N2 ..."]  (default: 100 500 1000 2000 5000)
#
# Output: reports/dhrystone.csv

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_DIR="$REPO_ROOT/sim"
SW_DIR="$REPO_ROOT/software/dhrystone"

# Pipeline/branch-predictor selection
PIPELINE="${PIPELINE:-0}"
BRANCH_PREDICT="${BRANCH_PREDICT:-0}"
if [[ "$BRANCH_PREDICT" == "1" ]]; then
    VTBPROG="$SIM_DIR/build/pipeline_bp/tb_prog/Vtb_prog"
    OUT_CSV="$REPO_ROOT/reports/dhrystone_pipeline_bp.csv"
    LABEL="Pipeline+BP"
elif [[ "$PIPELINE" == "1" ]]; then
    VTBPROG="$SIM_DIR/build/pipeline/tb_prog/Vtb_prog"
    OUT_CSV="$REPO_ROOT/reports/dhrystone_pipeline.csv"
    LABEL="Pipeline"
else
    VTBPROG="$SIM_DIR/build/single_cycle/tb_prog/Vtb_prog"
    OUT_CSV="$REPO_ROOT/reports/dhrystone.csv"
    LABEL="Single-cycle"
fi

# Dhrystone reference constant (1 DMIPS = 1757 Dhrystones/second)
DHRYSTONES_PER_DMIPS=1757

# Iteration counts to sweep
RUNS="${1:-100 500 1000 2000 5000}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}=== NauV Dhrystone Benchmark ($LABEL) ===${NC}"

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
if [ ! -x "$VTBPROG" ]; then
    echo -e "${RED}ERROR:${NC} Vtb_prog not found at $VTBPROG"
    if [[ "$BRANCH_PREDICT" == "1" ]]; then
        echo "  Build it first: cd sim && make tb_prog PIPELINE=1 BRANCH_PREDICT=1"
    elif [[ "$PIPELINE" == "1" ]]; then
        echo "  Build it first: cd sim && make tb_prog PIPELINE=1"
    else
        echo "  Build it first: cd sim && make tb_prog"
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# Output CSV
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$OUT_CSV")"
if [[ "$BRANCH_PREDICT" == "1" ]]; then
    echo "runs,cycles,cycles_per_run,dmips_mhz,bp_accuracy" > "$OUT_CSV"
else
    echo "runs,cycles,cycles_per_run,dmips_mhz" > "$OUT_CSV"
fi

# ---------------------------------------------------------------------------
# Sweep
# ---------------------------------------------------------------------------
echo ""
if [[ "$BRANCH_PREDICT" == "1" ]]; then
    printf "  %-8s  %-12s  %-14s  %-12s  %-12s\n" "Runs" "Cycles" "Cycles/Run" "DMIPS/MHz" "BP Accuracy"
    printf "  %-8s  %-12s  %-14s  %-12s  %-12s\n" "--------" "------------" "--------------" "------------" "------------"
else
    printf "  %-8s  %-12s  %-14s  %-12s\n" "Runs" "Cycles" "Cycles/Run" "DMIPS/MHz"
    printf "  %-8s  %-12s  %-14s  %-12s\n" "--------" "------------" "--------------" "------------"
fi

for N in $RUNS; do
    # Rebuild dhrystone with this iteration count (-B forces recompile so
    # the NUMBER_OF_RUNS define is picked up even when sources are unchanged)
    make -C "$SW_DIR" -B build NUMBER_OF_RUNS="$N" --no-print-directory \
        > /dev/null 2>&1

    # Set a generous timeout (single-cycle core: ~620 cycles/iter, ×10 safety)
    TIMEOUT=$(( N * 620 * 10 ))
    [ "$TIMEOUT" -lt 1000000 ] && TIMEOUT=1000000

    # Run simulation
    run_log="$(mktemp)"
    trap 'rm -f "$run_log"' EXIT

    if ! "$VTBPROG" \
            "+TEXT_HEX=$SW_DIR/dhrystone.text.hex" \
            "+DATA_HEX=$SW_DIR/dhrystone.data.hex" \
            "+TOHOST_ADDR=3000" \
            "+TIMEOUT=$TIMEOUT" \
            > "$run_log" 2>&1; then
        echo -e "  ${RED}FAIL${NC}  N=$N (see above)"
        cat "$run_log"
        continue
    fi

    # Parse cycle count from: "  [PASS]  tohost=0x00000001  (12345 cycles)"
    cycles=$(grep -oP '\(\K\d+(?= cycles\))' "$run_log" | head -1)
    if [ -z "$cycles" ]; then
        echo -e "  ${YELLOW}WARN${NC}  N=$N  could not parse cycle count"
        cat "$run_log"
        continue
    fi

    # Compute DMIPS/MHz = runs / (cycles × 1757)  [floating point via awk]
    cycles_per_run=$(awk "BEGIN {printf \"%.1f\", $cycles / $N}")
    dmips_mhz=$(awk "BEGIN {printf \"%.4f\", ($N * 1e6) / ($cycles * $DHRYSTONES_PER_DMIPS)}")

    if [[ "$BRANCH_PREDICT" == "1" ]]; then
        # Parse BP accuracy from: "  [BP STATS]  total=N  mispred=M  accuracy=PP.PP%"
        bp_accuracy=$(grep -oP '\[BP STATS\].*accuracy=\K[\d.]+' "$run_log" | head -1)
        bp_accuracy="${bp_accuracy:-N/A}"
        printf "  %-8d  %-12d  %-14s  %-12s  %s%%\n" \
               "$N" "$cycles" "$cycles_per_run" "$dmips_mhz" "$bp_accuracy"
        echo "$N,$cycles,$cycles_per_run,$dmips_mhz,$bp_accuracy" >> "$OUT_CSV"
    else
        printf "  %-8d  %-12d  %-14s  %-12s\n" "$N" "$cycles" "$cycles_per_run" "$dmips_mhz"
        echo "$N,$cycles,$cycles_per_run,$dmips_mhz" >> "$OUT_CSV"
    fi

    rm -f "$run_log"
    trap - EXIT
done

echo ""
echo -e "${GREEN}Results written to:${NC} $OUT_CSV"
echo ""

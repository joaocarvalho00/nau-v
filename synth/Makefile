LIB     := lib/NangateOpenCellLibrary_typical.lib
NETLIST := netlist/core_synth.v
FREQS   := 50 100 150 200 250

.PHONY: all synth timing sweep clean

# ---------------------------------------------------------------------------
# Phase 1 — baseline synthesis + STA at 100 MHz
# ---------------------------------------------------------------------------
all: synth timing

synth: $(NETLIST)

$(NETLIST): scripts/synth.ys scripts/mem_blackbox.v $(LIB)
	@mkdir -p reports netlist
	@test -f $(LIB) || \
	  (echo ""; \
	   echo "ERROR: $(LIB) not found."; \
	   echo "Download it with:"; \
	   echo "  mkdir -p lib && curl -L 'https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib' -o $(LIB)"; \
	   echo ""; exit 1)
	yosys -l reports/yosys.log scripts/synth.ys
	@echo ""
	@echo "=== Area Report ==="
	@cat reports/area.rpt

timing: $(NETLIST)
	@mkdir -p reports
	sta scripts/sta.tcl

# ---------------------------------------------------------------------------
# Phase 2 — frequency sweep
# ---------------------------------------------------------------------------
sweep: $(LIB)
	@mkdir -p reports netlist
	@for freq in $(FREQS); do \
	    period_ps=$$(( 1000000 / $$freq )); \
	    period_ns=$$(echo "scale=4; 1000 / $$freq" | bc); \
	    echo ""; \
	    echo "======================================================"; \
	    echo "  Synthesising at $$freq MHz  (period = $$period_ns ns)"; \
	    echo "======================================================"; \
	    mkdir -p reports/$${freq}MHz netlist/$${freq}MHz; \
	    PERIOD_PS=$$period_ps \
	    OUTDIR=reports/$${freq}MHz \
	    NETLIST=netlist/$${freq}MHz/core_synth.v \
	        yosys -l reports/$${freq}MHz/yosys.log -c scripts/synth.tcl; \
	    PERIOD_NS=$$period_ns \
	    OUTDIR=reports/$${freq}MHz \
	    NETLIST=netlist/$${freq}MHz/core_synth.v \
	        sta scripts/sta.tcl; \
	done
	@echo ""
	@echo "=== Parsing reports ==="
	python3 scripts/parse_reports.py
	@echo ""
	@echo "=== Plotting ==="
	python3 scripts/plot_results.py

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
clean:
	rm -rf reports/ netlist/

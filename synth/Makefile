LIB      := lib/NangateOpenCellLibrary_typical.lib
FREQS    := 50 100 150 200 250

# PIPELINE=0 (default) → single-cycle; PIPELINE=1 → pipeline
PIPELINE ?= 0

ifeq ($(PIPELINE),1)
  DESIGN   := pipeline
else
  DESIGN   := single_cycle
endif

NETLIST  := netlist/$(DESIGN)/core_synth.v

.PHONY: all synth timing sweep sweep_both clean

# ---------------------------------------------------------------------------
# Phase 1 — baseline synthesis + STA at 100 MHz
# ---------------------------------------------------------------------------
all: synth timing

synth: $(NETLIST)

$(NETLIST): scripts/synth.tcl scripts/mem_blackbox.v $(LIB)
	@mkdir -p reports/$(DESIGN) netlist/$(DESIGN)
	@test -f $(LIB) || \
	  (echo ""; \
	   echo "ERROR: $(LIB) not found."; \
	   echo "Download it with:"; \
	   echo "  mkdir -p lib && curl -L 'https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib' -o $(LIB)"; \
	   echo ""; exit 1)
	PIPELINE=$(PIPELINE) \
	OUTDIR=reports/$(DESIGN) \
	NETLIST=$(NETLIST) \
	    yosys -l reports/$(DESIGN)/yosys.log -c scripts/synth.tcl
	@echo ""
	@echo "=== Area Report ==="
	@cat reports/$(DESIGN)/area.rpt

timing: $(NETLIST)
	@mkdir -p reports/$(DESIGN)
	PERIOD_NS=10.0 \
	OUTDIR=reports/$(DESIGN) \
	NETLIST=$(NETLIST) \
	    sta scripts/sta.tcl

# ---------------------------------------------------------------------------
# Phase 2 — frequency sweep for one design (PIPELINE=0 or 1)
# ---------------------------------------------------------------------------
sweep: $(LIB)
	@mkdir -p reports netlist
	@for freq in $(FREQS); do \
	    period_ps=$$(( 1000000 / $$freq )); \
	    period_ns=$$(echo "scale=4; 1000 / $$freq" | bc); \
	    echo ""; \
	    echo "======================================================"; \
	    echo "  Synthesising $(DESIGN) at $$freq MHz  (period = $$period_ns ns)"; \
	    echo "======================================================"; \
	    mkdir -p reports/$(DESIGN)/$${freq}MHz netlist/$(DESIGN)/$${freq}MHz; \
	    PIPELINE=$(PIPELINE) \
	    PERIOD_PS=$$period_ps \
	    OUTDIR=reports/$(DESIGN)/$${freq}MHz \
	    NETLIST=netlist/$(DESIGN)/$${freq}MHz/core_synth.v \
	        yosys -l reports/$(DESIGN)/$${freq}MHz/yosys.log -c scripts/synth.tcl; \
	    PERIOD_NS=$$period_ns \
	    OUTDIR=reports/$(DESIGN)/$${freq}MHz \
	    NETLIST=netlist/$(DESIGN)/$${freq}MHz/core_synth.v \
	        sta scripts/sta.tcl; \
	done
	@echo ""
	@echo "=== Parsing reports ==="
	python3 scripts/parse_reports.py
	@echo ""
	@echo "=== Plotting ==="
	python3 scripts/plot_results.py

# ---------------------------------------------------------------------------
# Phase 2b — sweep both designs, then generate comparison plots
# ---------------------------------------------------------------------------
sweep_both: $(LIB)
	$(MAKE) sweep PIPELINE=0
	$(MAKE) sweep PIPELINE=1
	@echo ""
	@echo "=== Parsing all reports ==="
	python3 scripts/parse_reports.py --both
	@echo ""
	@echo "=== Plotting comparison ==="
	python3 scripts/plot_results.py --both

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
clean:
	rm -rf reports/ netlist/

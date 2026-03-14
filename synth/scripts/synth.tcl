# synth.tcl — Yosys synthesis script for NauV (RV32I core)
# Parameterised via environment variables:
#   PERIOD_PS      : ABC timing target in picoseconds (default: 10000 = 100 MHz)
#   OUTDIR         : directory for area report output  (default: reports)
#   NETLIST        : output path for gate-level netlist (default: netlist/core_synth.v)
#   PIPELINE       : 0 = single-cycle core.sv (default), 1 = core_pipeline.sv
#   BRANCH_PREDICT : 0 = no predictor (default), 1 = core_pipeline_bp.sv (requires PIPELINE=1)
#
# Usage: PERIOD_PS=5000 OUTDIR=reports/200MHz NETLIST=netlist/200MHz/core_synth.v \
#            yosys -c scripts/synth.tcl

set period_ps      [expr {[info exists ::env(PERIOD_PS)]      ? int($::env(PERIOD_PS))      : 10000}]
set outdir         [expr {[info exists ::env(OUTDIR)]         ? $::env(OUTDIR)               : "reports"}]
set netlist        [expr {[info exists ::env(NETLIST)]        ? $::env(NETLIST)              : "netlist/core_synth.v"}]
set pipeline       [expr {[info exists ::env(PIPELINE)]       ? int($::env(PIPELINE))        : 0}]
set branch_predict [expr {[info exists ::env(BRANCH_PREDICT)] ? int($::env(BRANCH_PREDICT)) : 0}]

# In yosys -c mode, commands are invoked via the `yosys` proc.

# Define SYNTHESIS so `ifndef SYNTHESIS blocks (simulation assertions etc.) are excluded.
yosys "verilog_defaults -add -DSYNTHESIS"

# 1. Black-box stubs for imem and dmem
yosys read_verilog scripts/mem_blackbox.v

# 2. RTL source files (SystemVerilog)
yosys "read_verilog -sv -I../src/if ../src/if/if_stage.sv"
yosys "read_verilog -sv -I../src/id ../src/id/decoder.sv"
yosys "read_verilog -sv -I../src/id ../src/id/regfile.sv"
yosys "read_verilog -sv -I../src/id ../src/id/id_stage.sv"
yosys "read_verilog -sv -I../src/ex ../src/ex/alu.sv"
yosys "read_verilog -sv -I../src/ex ../src/ex/ex_stage.sv"
yosys "read_verilog -sv -I../src/mem ../src/mem/mem_stage.sv"
yosys "read_verilog -sv -I../src/wb ../src/wb/wb_stage.sv"
if {$pipeline || $branch_predict} {
    yosys "read_verilog -sv -I../src/core ../src/core/hazard_unit.sv"
}
if {$branch_predict} {
    yosys "read_verilog -sv -I../src/core ../src/core/branch_predictor.sv"
    yosys "read_verilog -sv -I../src/core ../src/core/core_pipeline_bp.sv"
} elseif {$pipeline} {
    yosys "read_verilog -sv -I../src/core ../src/core/core_pipeline.sv"
} else {
    yosys "read_verilog -sv -I../src/core ../src/core/core.sv"
}

# 3. Synthesise
yosys "synth -top core -flatten"

# 4. Technology mapping
yosys "dfflibmap -liberty lib/NangateOpenCellLibrary_typical.lib"
yosys "abc -liberty lib/NangateOpenCellLibrary_typical.lib -D $period_ps"

# 5. Clean up dangling wires
yosys clean

# 6. Area report and gate-level netlist
yosys "tee -o $outdir/area.rpt stat -liberty lib/NangateOpenCellLibrary_typical.lib"
yosys "write_verilog -noattr $netlist"

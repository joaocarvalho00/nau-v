# sta.tcl — OpenSTA timing and power analysis for NauV
# Parameterised via environment variables:
#   PERIOD_NS : clock period in nanoseconds   (default: 10.0 = 100 MHz)
#   OUTDIR    : directory for report output   (default: reports)
#   NETLIST   : path to synthesised netlist   (default: netlist/core_synth.v)
#
# Run from: synth/
# Usage: sta scripts/sta.tcl

set period_ns [expr {[info exists ::env(PERIOD_NS)] ? $::env(PERIOD_NS) : 10.0}]
set outdir    [expr {[info exists ::env(OUTDIR)]    ? $::env(OUTDIR)    : "reports"}]
set netlist   [expr {[info exists ::env(NETLIST)]   ? $::env(NETLIST)   : "netlist/core_synth.v"}]

set freq_mhz [expr {1000.0 / $period_ns}]
puts "\n========== STA: [format %.0f $freq_mhz] MHz (period = $period_ns ns) =========="

# ---------------------------------------------------------------------------
# 1. Read library and netlist
# ---------------------------------------------------------------------------
read_liberty lib/NangateOpenCellLibrary_typical.lib
read_verilog  $netlist
link_design   core

# ---------------------------------------------------------------------------
# 2. Timing constraints (inlined — period driven by env var)
# ---------------------------------------------------------------------------
create_clock -name clk -period $period_ns [get_ports clk]
set_input_delay  2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]

# ---------------------------------------------------------------------------
# 3. Timing report — critical (longest) path
# ---------------------------------------------------------------------------
report_checks \
    -path_delay max \
    -format full_clock_expanded \
    -fields {slew cap input_pin} \
    -digits 3 \
    > $outdir/timing.rpt

report_wns >> $outdir/timing.rpt
report_tns >> $outdir/timing.rpt

# Append machine-readable summary for parse_reports.py
set wns       [sta::worst_slack -max]
set crit_ns   [expr {$period_ns - $wns}]
set fmax_mhz_est [expr {1000.0 / $crit_ns}]

set fp [open $outdir/timing.rpt a]
puts $fp ""
puts $fp "## SUMMARY"
puts $fp "PERIOD_NS $period_ns"
puts $fp "WNS_NS $wns"
puts $fp "CRIT_PATH_NS $crit_ns"
puts $fp "FMAX_MHZ $fmax_mhz_est"
close $fp

puts "  WNS      : [format %.3f $wns] ns"
puts "  Fmax est : [format %.1f $fmax_mhz_est] MHz  (critical path = [format %.3f $crit_ns] ns)"

# ---------------------------------------------------------------------------
# 4. Power report
# ---------------------------------------------------------------------------
puts "\n========== POWER REPORT =========="
report_power > $outdir/power.rpt

set fp2 [open $outdir/power.rpt r]
puts [read $fp2]
close $fp2

puts "\nReports written to $outdir/"
exit

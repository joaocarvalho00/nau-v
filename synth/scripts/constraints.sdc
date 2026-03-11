# constraints.sdc — Timing constraints for NauV synthesis and STA
# Target: 100 MHz (10.0 ns clock period)
# Used by: OpenSTA (sta.tcl)

# ---------------------------------------------------------------------------
# Clock
# ---------------------------------------------------------------------------
create_clock -name clk -period 10.0 [get_ports clk]

# ---------------------------------------------------------------------------
# Input / output delays
# Model 2 ns of external combinational delay on all data I/O.
# The clock port itself is excluded from input delay.
# ---------------------------------------------------------------------------
set_input_delay  2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]

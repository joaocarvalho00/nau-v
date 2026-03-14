// sta_blackbox.v — Stub module definitions for OpenSTA.
// OpenSTA treats any module that has no liberty model as a black box.
// These stubs let link_design resolve references to imem and dmem.
// Parameters are omitted (not supported by OpenSTA's Verilog parser).

module imem (
    input  clk,
    input  [31:0] addr,
    output [31:0] rdata,
    input  init_we,
    input  [31:0] init_addr,
    input  [31:0] init_data
);
endmodule

module dmem (
    input  clk,
    input  [31:0] addr,
    input  [31:0] wdata,
    input  [3:0]  byte_en,
    input  we,
    output [31:0] rdata
);
endmodule

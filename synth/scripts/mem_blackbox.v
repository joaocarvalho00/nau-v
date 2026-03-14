// mem_blackbox.v — Black-box stubs for imem and dmem.
// Used during synthesis so Yosys treats the memories as opaque SRAM macros
// rather than synthesising them as flip-flop arrays.
// Port definitions must exactly match the behavioural models in src/core/.

(* blackbox *)
module imem #(parameter MEM_DEPTH = 4096) (
    input  wire        clk,
    input  wire [31:0] addr,
    output wire [31:0] rdata,
    input  wire        init_we,
    input  wire [31:0] init_addr,
    input  wire [31:0] init_data
);
endmodule

(* blackbox *)
module dmem #(parameter MEM_DEPTH = 4096) (
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  byte_en,
    input  wire        we,
    output wire [31:0] rdata
);
endmodule


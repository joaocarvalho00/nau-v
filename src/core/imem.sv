// Instruction Memory
// Read-only at runtime; word-addressed (addr[31:2]).
// Asynchronous read.
// Initialised to NOP (32'h0000_0013 = ADDI x0,x0,0).
// A clocked init port allows the testbench to load programs before reset
// is de-asserted.

module imem #(
    parameter int MEM_DEPTH = 4096  // number of 32-bit words
)(
    input  logic        clk,
    // Runtime read port
    input  logic [31:0] addr,
    output logic [31:0] rdata,
    // Testbench init port (clocked write)
    input  logic        init_we,
    input  logic [31:0] init_addr,
    input  logic [31:0] init_data
);

    // -----------------------------------------------------------------------
    // Storage — initialised to NOP
    // -----------------------------------------------------------------------
    logic [31:0] mem [0:MEM_DEPTH-1];

    initial begin
        integer i;
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013;  // NOP: ADDI x0,x0,0
    end

    // -----------------------------------------------------------------------
    // Address truncation to array index width
    // -----------------------------------------------------------------------
    localparam int ADDR_BITS = $clog2(MEM_DEPTH);

    // -----------------------------------------------------------------------
    // Init write port — synchronous, word-addressed
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (init_we)
            mem[ADDR_BITS'(init_addr[31:2])] <= init_data;
    end

    // -----------------------------------------------------------------------
    // Asynchronous read — word-addressed
    // -----------------------------------------------------------------------
    always_comb begin
        rdata = mem[ADDR_BITS'(addr[31:2])];
    end

endmodule

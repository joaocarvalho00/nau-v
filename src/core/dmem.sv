// Data Memory
// Byte-addressable with byte-enable signals; word-aligned accesses.
// Synchronous write (byte-enable granularity).
// Asynchronous read.
// Initialised to zero.

module dmem #(
    parameter int MEM_DEPTH = 4096  // number of 32-bit words
)(
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  byte_en,
    input  logic        we,
    output logic [31:0] rdata
);

    // -----------------------------------------------------------------------
    // Storage
    // -----------------------------------------------------------------------
    logic [31:0] mem [0:MEM_DEPTH-1];

    initial begin
        integer i;
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
    end

    // -----------------------------------------------------------------------
    // Address truncation to array index width
    // -----------------------------------------------------------------------
    // $clog2(MEM_DEPTH) = 12 for the default depth of 4096.
    // Using a local parameter avoids WIDTHTRUNC warnings.
    localparam int ADDR_BITS = $clog2(MEM_DEPTH);

    // -----------------------------------------------------------------------
    // Synchronous byte-enable write
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (we) begin
            if (byte_en[0]) mem[ADDR_BITS'(addr[31:2])][7:0]   <= wdata[7:0];
            if (byte_en[1]) mem[ADDR_BITS'(addr[31:2])][15:8]  <= wdata[15:8];
            if (byte_en[2]) mem[ADDR_BITS'(addr[31:2])][23:16] <= wdata[23:16];
            if (byte_en[3]) mem[ADDR_BITS'(addr[31:2])][31:24] <= wdata[31:24];
        end
    end

    // -----------------------------------------------------------------------
    // Asynchronous read — word-addressed
    // -----------------------------------------------------------------------
    always_comb begin
        rdata = mem[ADDR_BITS'(addr[31:2])];
    end

endmodule

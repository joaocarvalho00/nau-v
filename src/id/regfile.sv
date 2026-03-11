// ID Stage — Register File
// 32 general-purpose 32-bit registers.  x0 is hardwired to zero.
// Read ports are asynchronous (always_comb).
// The single write port is synchronous (always_ff) and occurs on the
// rising clock edge.  Synchronous active-high reset clears all registers.
// A debug read port (dbg_addr / dbg_data) allows the testbench to inspect
// any register without disturbing normal operation.

module regfile (
    input  logic        clk,
    input  logic        rst,

    // Asynchronous read ports (ID stage)
    input  logic [4:0]  id_rs1_addr,
    input  logic [4:0]  id_rs2_addr,
    output logic [31:0] id_rs1_data,
    output logic [31:0] id_rs2_data,

    // Synchronous write port (WB stage)
    input  logic [4:0]  wb_rd_addr,
    input  logic [31:0] wb_rd_data,
    input  logic        wb_rd_we,

    // Debug read port
    input  logic [4:0]  dbg_addr,
    output logic [31:0] dbg_data
);

    // -----------------------------------------------------------------------
    // Storage
    // -----------------------------------------------------------------------
    logic [31:0] regs [0:31];

    // -----------------------------------------------------------------------
    // Synchronous write + reset
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            integer i;
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'h0000_0000;
        end else begin
            if (wb_rd_we && (wb_rd_addr != 5'h0))
                regs[wb_rd_addr] <= wb_rd_data;
        end
    end

    // -----------------------------------------------------------------------
    // Asynchronous read — rs1
    // -----------------------------------------------------------------------
    always_comb begin
        if (id_rs1_addr == 5'h0)
            id_rs1_data = 32'h0000_0000;
        else
            id_rs1_data = regs[id_rs1_addr];
    end

    // -----------------------------------------------------------------------
    // Asynchronous read — rs2
    // -----------------------------------------------------------------------
    always_comb begin
        if (id_rs2_addr == 5'h0)
            id_rs2_data = 32'h0000_0000;
        else
            id_rs2_data = regs[id_rs2_addr];
    end

    // -----------------------------------------------------------------------
    // Debug read port
    // -----------------------------------------------------------------------
    always_comb begin
        if (dbg_addr == 5'h0)
            dbg_data = 32'h0000_0000;
        else
            dbg_data = regs[dbg_addr];
    end

endmodule

// IF Stage — Instruction Fetch
// Holds the program counter register and computes PC+4.
// On each rising clock edge the PC advances to either PC+4 (pc_sel=0)
// or the branch/jump target supplied by the EX stage (pc_sel=1).
// Synchronous active-high reset sets PC to 32'h0.

module if_stage (
    input  logic        clk,
    input  logic        rst,
    input  logic        pc_sel,        // 0 = PC+4, 1 = branch/jump target
    input  logic [31:0] if_pc_target,  // target address from EX stage
    output logic [31:0] if_pc,         // current PC (registered)
    output logic [31:0] if_pc_plus4    // PC+4 (combinational)
);

    // -----------------------------------------------------------------------
    // PC+4 — purely combinational
    // -----------------------------------------------------------------------
    always_comb begin
        if_pc_plus4 = if_pc + 32'd4;
    end

    // -----------------------------------------------------------------------
    // PC register — synchronous, active-high reset
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            if_pc <= 32'h0000_0000;
        end else begin
            if_pc <= pc_sel ? if_pc_target : if_pc_plus4;
        end
    end

endmodule

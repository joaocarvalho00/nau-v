// WB Stage — Write Back
// Selects the value to write back to the register file:
//   wb_pc_to_reg = 1                  → wb_pc_plus4   (JAL / JALR)
//   wb_pc_to_reg = 0, wb_mem_to_reg=1 → wb_mem_rdata  (loads)
//   wb_pc_to_reg = 0, wb_mem_to_reg=0 → wb_alu_result (ALU / LUI / AUIPC)
//
// wb_rd_we passes through wb_reg_we unchanged; it gates the register-file
// write port in id_stage.

module wb_stage (
    input  logic [31:0] wb_alu_result,
    input  logic [31:0] wb_mem_rdata,
    input  logic [31:0] wb_pc_plus4,
    input  logic        wb_mem_to_reg,
    input  logic        wb_pc_to_reg,
    input  logic        wb_reg_we,
    input  logic [4:0]  wb_rd_addr_in,

    output logic [31:0] wb_rd_data,
    output logic [4:0]  wb_rd_addr,
    output logic        wb_rd_we
);

    // -----------------------------------------------------------------------
    // Write-data mux
    // -----------------------------------------------------------------------
    always_comb begin
        if (wb_pc_to_reg)
            wb_rd_data = wb_pc_plus4;
        else if (wb_mem_to_reg)
            wb_rd_data = wb_mem_rdata;
        else
            wb_rd_data = wb_alu_result;
    end

    // -----------------------------------------------------------------------
    // Pass-through: destination register address and write enable
    // -----------------------------------------------------------------------
    always_comb begin
        wb_rd_addr = wb_rd_addr_in;
        wb_rd_we   = wb_reg_we;
    end

endmodule

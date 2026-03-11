// ID Stage — top-level wrapper
// Instantiates the decoder and the register file, then wires them together.
// All signals are passed through; no additional logic lives here.

module id_stage (
    input  logic        clk,
    input  logic        rst,

    // Instruction and PC from IF stage
    input  logic [31:0] id_instr,
    input  logic [31:0] id_pc,      // passed through to ex_stage via core

    // Write-back feed-through (from WB stage)
    input  logic [4:0]  wb_rd_addr,
    input  logic [31:0] wb_rd_data,
    input  logic        wb_rd_we,

    // Register data to EX stage
    output logic [31:0] id_rs1_data,
    output logic [31:0] id_rs2_data,

    // Decoder outputs to EX / MEM / WB stages
    output logic [31:0] id_imm,
    output logic [4:0]  id_rd_addr,
    output logic [3:0]  id_alu_op,
    output logic        id_alu_src,
    output logic        id_mem_we,
    output logic [2:0]  id_mem_funct3,
    output logic        id_mem_re,
    output logic        id_reg_we,
    output logic        id_mem_to_reg,
    output logic        id_branch,
    output logic        id_jump,
    output logic        id_jalr,
    output logic        id_pc_to_reg,
    output logic        id_auipc,

    // Debug register read port
    input  logic [4:0]  dbg_addr,
    output logic [31:0] dbg_data
);

    // -----------------------------------------------------------------------
    // Internal wires from decoder to register file address ports
    // -----------------------------------------------------------------------
    logic [4:0] dec_rs1_addr;
    logic [4:0] dec_rs2_addr;

    // -----------------------------------------------------------------------
    // Decoder instantiation
    // -----------------------------------------------------------------------
    decoder u_decoder (
        .id_instr     (id_instr),
        .id_rs1_addr  (dec_rs1_addr),
        .id_rs2_addr  (dec_rs2_addr),
        .id_rd_addr   (id_rd_addr),
        .id_imm       (id_imm),
        .id_alu_op    (id_alu_op),
        .id_alu_src   (id_alu_src),
        .id_mem_we    (id_mem_we),
        .id_mem_funct3(id_mem_funct3),
        .id_mem_re    (id_mem_re),
        .id_reg_we    (id_reg_we),
        .id_mem_to_reg(id_mem_to_reg),
        .id_branch    (id_branch),
        .id_jump      (id_jump),
        .id_jalr      (id_jalr),
        .id_pc_to_reg (id_pc_to_reg),
        .id_auipc     (id_auipc)
    );

    // -----------------------------------------------------------------------
    // Register file instantiation
    // -----------------------------------------------------------------------
    regfile u_regfile (
        .clk         (clk),
        .rst         (rst),
        .id_rs1_addr (dec_rs1_addr),
        .id_rs2_addr (dec_rs2_addr),
        .id_rs1_data (id_rs1_data),
        .id_rs2_data (id_rs2_data),
        .wb_rd_addr  (wb_rd_addr),
        .wb_rd_data  (wb_rd_data),
        .wb_rd_we    (wb_rd_we),
        .dbg_addr    (dbg_addr),
        .dbg_data    (dbg_data)
    );

endmodule

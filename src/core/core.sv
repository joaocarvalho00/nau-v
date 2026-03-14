// Claude-V — Single-Cycle RV32I Core
// Top-level integration module.  Instantiates all five pipeline-stage modules
// (IF, ID, EX, MEM, WB) plus instruction and data memories, then wires
// every signal together.
//
// Signal naming follows the stage-prefix convention defined in CLAUDE.md.

module core (
    input  logic        clk,
    input  logic        rst,

    // Instruction-memory init port (for testbench program loading)
    input  logic        imem_init_we,
    input  logic [31:0] imem_init_addr,
    input  logic [31:0] imem_init_data,

    // Debug outputs
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_instr,
    input  logic [4:0]  dbg_rf_addr,
    output logic [31:0] dbg_rf_data,
    // Memory bus observation (for tohost monitoring in tb_prog)
    output logic [31:0] dbg_mem_addr,
    output logic [31:0] dbg_mem_wdata,
    output logic        dbg_mem_we
);

    // =========================================================================
    // IF stage signals
    // =========================================================================
    logic [31:0] if_pc;
    logic [31:0] if_pc_plus4;

    // =========================================================================
    // ID stage signals (decoder + regfile outputs)
    // =========================================================================
    logic [31:0] id_instr;
    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;
    logic [31:0] id_imm;
    logic [4:0]  id_rd_addr;
    logic [3:0]  id_alu_op;
    logic        id_alu_src;
    logic        id_mem_we;
    logic [2:0]  id_mem_funct3;
    logic        id_mem_re;
    logic        id_reg_we;
    logic        id_mem_to_reg;
    logic        id_branch;
    logic        id_jump;
    logic        id_jalr;
    logic        id_pc_to_reg;
    logic        id_auipc;

    // =========================================================================
    // EX stage signals
    // =========================================================================
    logic [31:0] ex_alu_result;
    logic        ex_pc_sel;
    logic [31:0] ex_pc_target;

    // =========================================================================
    // MEM stage signals
    // =========================================================================
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_byte_en;
    logic        mem_we_out;
    logic [31:0] mem_rdata_raw;
    logic [31:0] mem_rdata;

    // =========================================================================
    // WB stage signals
    // =========================================================================
    logic [31:0] wb_rd_data;
    logic [4:0]  wb_rd_addr;
    logic        wb_rd_we;

    // =========================================================================
    // IF Stage
    // =========================================================================
    if_stage u_if_stage (
        .clk           (clk),
        .rst           (rst),
        .pc_en         (1'b1),        // single-cycle always advances
        .pc_sel        (ex_pc_sel),
        .if_pc_target  (ex_pc_target),
        .if_pc         (if_pc),
        .if_pc_plus4   (if_pc_plus4)
    );

    // =========================================================================
    // Instruction Memory
    // =========================================================================
    imem u_imem (
        .clk       (clk),
        .addr      (if_pc),
        .rdata     (id_instr),
        .init_we   (imem_init_we),
        .init_addr (imem_init_addr),
        .init_data (imem_init_data)
    );

    // =========================================================================
    // ID Stage
    // =========================================================================
    id_stage u_id_stage (
        .clk          (clk),
        .rst          (rst),
        .id_instr     (id_instr),
        .id_pc        (if_pc),
        .wb_rd_addr   (wb_rd_addr),
        .wb_rd_data   (wb_rd_data),
        .wb_rd_we     (wb_rd_we),
        .id_rs1_data  (id_rs1_data),
        .id_rs2_data  (id_rs2_data),
        .id_imm       (id_imm),
        .id_rd_addr   (id_rd_addr),
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
        .id_auipc     (id_auipc),
        .dbg_addr     (dbg_rf_addr),
        .dbg_data     (dbg_rf_data)
    );

    // =========================================================================
    // EX Stage
    // =========================================================================
    ex_stage u_ex_stage (
        .ex_pc         (if_pc),
        .ex_rs1_data   (id_rs1_data),
        .ex_rs2_data   (id_rs2_data),
        .ex_imm        (id_imm),
        .ex_alu_op     (id_alu_op),
        .ex_alu_src    (id_alu_src),
        .ex_branch     (id_branch),
        .ex_jump       (id_jump),
        .ex_jalr       (id_jalr),
        .ex_auipc      (id_auipc),
        .ex_funct3     (id_mem_funct3),
        .ex_alu_result (ex_alu_result),
        .ex_pc_sel     (ex_pc_sel),
        .ex_pc_target  (ex_pc_target)
    );

    // =========================================================================
    // MEM Stage (combinational part)
    // =========================================================================
    mem_stage u_mem_stage (
        .mem_alu_result (ex_alu_result),
        .mem_rs2_data   (id_rs2_data),
        .mem_we         (id_mem_we),
        .mem_re         (id_mem_re),
        .mem_funct3     (id_mem_funct3),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        .mem_byte_en    (mem_byte_en),
        .mem_we_out     (mem_we_out),
        .mem_rdata_raw  (mem_rdata_raw),
        .mem_rdata      (mem_rdata)
    );

    // =========================================================================
    // Data Memory
    // =========================================================================
    dmem u_dmem (
        .clk      (clk),
        .addr     (mem_addr),
        .wdata    (mem_wdata),
        .byte_en  (mem_byte_en),
        .we       (mem_we_out),
        .rdata    (mem_rdata_raw)
    );

    // =========================================================================
    // WB Stage
    // =========================================================================
    wb_stage u_wb_stage (
        .wb_alu_result  (ex_alu_result),
        .wb_mem_rdata   (mem_rdata),
        .wb_pc_plus4    (if_pc_plus4),
        .wb_mem_to_reg  (id_mem_to_reg),
        .wb_pc_to_reg   (id_pc_to_reg),
        .wb_reg_we      (id_reg_we),
        .wb_rd_addr_in  (id_rd_addr),
        .wb_rd_data     (wb_rd_data),
        .wb_rd_addr     (wb_rd_addr),
        .wb_rd_we       (wb_rd_we)
    );

    // =========================================================================
    // Debug outputs
    // =========================================================================
    always_comb begin
        dbg_pc        = if_pc;
        dbg_instr     = id_instr;
        dbg_mem_addr  = mem_addr;
        dbg_mem_wdata = mem_wdata;
        dbg_mem_we    = mem_we_out;
    end

endmodule

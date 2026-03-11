// EX Stage — Execute
// Selects ALU operands, instantiates the ALU, resolves branch conditions,
// and computes the next-PC target for branches and jumps.
//
// Operand-A selection:
//   AUIPC : ex_pc  (so that PC + imm is computed)
//   others: ex_rs1_data
//
// Operand-B selection (ex_alu_src):
//   0 : ex_rs2_data
//   1 : ex_imm
//
// Branch instructions override ex_alu_op with ALU_SUB internally so that
// the zero / neg / overflow flags are meaningful for condition evaluation.
//
// Jump target:
//   JALR  : (rs1 + imm) & ~32'd1
//   JAL / branch : pc + imm

module ex_stage (
    input  logic [31:0] ex_pc,
    input  logic [31:0] ex_rs1_data,
    input  logic [31:0] ex_rs2_data,
    input  logic [31:0] ex_imm,
    input  logic [3:0]  ex_alu_op,
    input  logic        ex_alu_src,    // 0 = rs2, 1 = imm
    input  logic        ex_branch,
    input  logic        ex_jump,
    input  logic        ex_jalr,
    input  logic        ex_auipc,
    input  logic [2:0]  ex_funct3,     // branch type (from id_mem_funct3)

    output logic [31:0] ex_alu_result,
    output logic        ex_pc_sel,     // 1 = redirect PC to ex_pc_target
    output logic [31:0] ex_pc_target   // branch/jump destination
);

    // -----------------------------------------------------------------------
    // ALU operation localparams (must match alu.sv)
    // -----------------------------------------------------------------------
    localparam logic [3:0] ALU_SUB = 4'd1;

    // -----------------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------------
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [3:0]  alu_op_eff;       // effective op sent to ALU
    logic        alu_zero;
    logic        alu_neg;
    logic        alu_overflow;
    logic        branch_taken;

    // -----------------------------------------------------------------------
    // Operand-A mux: AUIPC uses PC, all others use rs1
    // -----------------------------------------------------------------------
    always_comb begin
        alu_operand_a = ex_auipc ? ex_pc : ex_rs1_data;
    end

    // -----------------------------------------------------------------------
    // Operand-B mux: ALU source select
    // -----------------------------------------------------------------------
    always_comb begin
        alu_operand_b = ex_alu_src ? ex_imm : ex_rs2_data;
    end

    // -----------------------------------------------------------------------
    // ALU op override for branches: always subtract to generate flags
    // -----------------------------------------------------------------------
    always_comb begin
        alu_op_eff = ex_branch ? ALU_SUB : ex_alu_op;
    end

    // -----------------------------------------------------------------------
    // ALU instantiation
    // -----------------------------------------------------------------------
    alu u_alu (
        .ex_operand_a   (alu_operand_a),
        .ex_operand_b   (alu_operand_b),
        .ex_alu_op      (alu_op_eff),
        .ex_alu_result  (ex_alu_result),
        .ex_alu_zero    (alu_zero),
        .ex_alu_neg     (alu_neg),
        .ex_alu_overflow(alu_overflow)
    );

    // -----------------------------------------------------------------------
    // Branch condition evaluation
    // BEQ  3'b000 : zero
    // BNE  3'b001 : !zero
    // BLT  3'b100 : signed less-than  (neg XOR overflow)
    // BGE  3'b101 : signed >=         !(neg XOR overflow)
    // BLTU 3'b110 : unsigned <        rs1 < rs2 (compare operands directly)
    // BGEU 3'b111 : unsigned >=       rs1 >= rs2
    // -----------------------------------------------------------------------
    always_comb begin
        case (ex_funct3)
            3'b000:  branch_taken = alu_zero;
            3'b001:  branch_taken = ~alu_zero;
            3'b100:  branch_taken = alu_neg ^ alu_overflow;
            3'b101:  branch_taken = ~(alu_neg ^ alu_overflow);
            3'b110:  branch_taken = (ex_rs1_data < ex_rs2_data);
            3'b111:  branch_taken = (ex_rs1_data >= ex_rs2_data);
            default: branch_taken = 1'b0;
        endcase
    end

    // -----------------------------------------------------------------------
    // PC-select: redirect when jump or taken branch
    // -----------------------------------------------------------------------
    always_comb begin
        ex_pc_sel = ex_jump | (ex_branch & branch_taken);
    end

    // -----------------------------------------------------------------------
    // Target address
    //   JALR  : (rs1 + imm) & ~1  (LSB cleared per spec)
    //   others: pc + imm
    // -----------------------------------------------------------------------
    always_comb begin
        if (ex_jalr)
            ex_pc_target = (ex_rs1_data + ex_imm) & ~32'd1;
        else
            ex_pc_target = ex_pc + ex_imm;
    end

endmodule

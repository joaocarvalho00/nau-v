// ID Stage — Instruction Decoder
// Decodes all RV32I instructions into register addresses, a sign-extended
// immediate, and a set of control signals consumed by downstream stages.
// The default (unknown opcode) case zeroes every output to prevent latches
// and to produce a safe no-op behaviour.

module decoder (
    input  logic [31:0] id_instr,

    // Register address fields
    output logic [4:0]  id_rs1_addr,
    output logic [4:0]  id_rs2_addr,
    output logic [4:0]  id_rd_addr,

    // Sign-extended immediate
    output logic [31:0] id_imm,

    // ALU control
    output logic [3:0]  id_alu_op,
    output logic        id_alu_src,    // 0 = rs2,  1 = imm

    // Memory control
    output logic        id_mem_we,     // data memory write enable
    output logic [2:0]  id_mem_funct3, // load/store width
    output logic        id_mem_re,     // data memory read enable

    // Write-back control
    output logic        id_reg_we,     // register file write enable
    output logic        id_mem_to_reg, // WB mux: 0 = ALU result, 1 = mem data

    // Branch / jump control
    output logic        id_branch,
    output logic        id_jump,
    output logic        id_jalr,
    output logic        id_pc_to_reg,  // write PC+4 to rd (JAL / JALR)
    output logic        id_auipc       // AUIPC: operand_a is PC
);

    // -----------------------------------------------------------------------
    // ALU operation encoding (matches alu.sv localparams)
    // -----------------------------------------------------------------------
    localparam logic [3:0] ALU_ADD    = 4'd0;
    localparam logic [3:0] ALU_SUB    = 4'd1;
    localparam logic [3:0] ALU_SLL    = 4'd2;
    localparam logic [3:0] ALU_SLT    = 4'd3;
    localparam logic [3:0] ALU_SLTU   = 4'd4;
    localparam logic [3:0] ALU_XOR    = 4'd5;
    localparam logic [3:0] ALU_SRL    = 4'd6;
    localparam logic [3:0] ALU_SRA    = 4'd7;
    localparam logic [3:0] ALU_OR     = 4'd8;
    localparam logic [3:0] ALU_AND    = 4'd9;
    localparam logic [3:0] ALU_PASS_B = 4'd10;

    // -----------------------------------------------------------------------
    // Instruction field extraction (purely wires — no logic cost)
    // -----------------------------------------------------------------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = id_instr[6:0];
        funct3 = id_instr[14:12];
        funct7 = id_instr[31:25];
    end

    // -----------------------------------------------------------------------
    // Main decode
    // -----------------------------------------------------------------------
    always_comb begin
        // Default — safe no-op; fully specified to prevent latches
        id_rs1_addr   = id_instr[19:15];
        id_rs2_addr   = id_instr[24:20];
        id_rd_addr    = id_instr[11:7];
        id_imm        = 32'h0;
        id_alu_op     = ALU_ADD;
        id_alu_src    = 1'b0;
        id_mem_we     = 1'b0;
        id_mem_funct3 = funct3;
        id_mem_re     = 1'b0;
        id_reg_we     = 1'b0;
        id_mem_to_reg = 1'b0;
        id_branch     = 1'b0;
        id_jump       = 1'b0;
        id_jalr       = 1'b0;
        id_pc_to_reg  = 1'b0;
        id_auipc      = 1'b0;

        case (opcode)

            // ----------------------------------------------------------
            // R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            // ----------------------------------------------------------
            7'b0110011: begin
                id_alu_src = 1'b0;
                id_reg_we  = 1'b1;
                id_imm     = 32'h0;
                case ({funct7, funct3})
                    10'b0000000_000: id_alu_op = ALU_ADD;
                    10'b0100000_000: id_alu_op = ALU_SUB;
                    10'b0000000_001: id_alu_op = ALU_SLL;
                    10'b0000000_010: id_alu_op = ALU_SLT;
                    10'b0000000_011: id_alu_op = ALU_SLTU;
                    10'b0000000_100: id_alu_op = ALU_XOR;
                    10'b0000000_101: id_alu_op = ALU_SRL;
                    10'b0100000_101: id_alu_op = ALU_SRA;
                    10'b0000000_110: id_alu_op = ALU_OR;
                    10'b0000000_111: id_alu_op = ALU_AND;
                    default:         id_alu_op = ALU_ADD;
                endcase
            end

            // ----------------------------------------------------------
            // I-type ALU: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI,
            //             SRLI, SRAI
            // ----------------------------------------------------------
            7'b0010011: begin
                id_alu_src = 1'b1;
                id_reg_we  = 1'b1;
                // I-type immediate
                id_imm     = {{20{id_instr[31]}}, id_instr[31:20]};
                case (funct3)
                    3'b000: id_alu_op = ALU_ADD;   // ADDI
                    3'b010: id_alu_op = ALU_SLT;   // SLTI
                    3'b011: id_alu_op = ALU_SLTU;  // SLTIU
                    3'b100: id_alu_op = ALU_XOR;   // XORI
                    3'b110: id_alu_op = ALU_OR;    // ORI
                    3'b111: id_alu_op = ALU_AND;   // ANDI
                    3'b001: id_alu_op = ALU_SLL;   // SLLI
                    3'b101: begin
                        // SRLI vs SRAI distinguished by funct7[5]
                        if (funct7[5])
                            id_alu_op = ALU_SRA;
                        else
                            id_alu_op = ALU_SRL;
                    end
                    default: id_alu_op = ALU_ADD;
                endcase
            end

            // ----------------------------------------------------------
            // Loads: LB, LH, LW, LBU, LHU
            // ----------------------------------------------------------
            7'b0000011: begin
                id_alu_src    = 1'b1;
                id_alu_op     = ALU_ADD;
                id_mem_re     = 1'b1;
                id_mem_to_reg = 1'b1;
                id_reg_we     = 1'b1;
                // I-type immediate
                id_imm        = {{20{id_instr[31]}}, id_instr[31:20]};
            end

            // ----------------------------------------------------------
            // Stores: SB, SH, SW
            // ----------------------------------------------------------
            7'b0100011: begin
                id_alu_src = 1'b1;
                id_alu_op  = ALU_ADD;
                id_mem_we  = 1'b1;
                // S-type immediate
                id_imm     = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
            end

            // ----------------------------------------------------------
            // Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // ----------------------------------------------------------
            7'b1100011: begin
                id_branch  = 1'b1;
                id_alu_src = 1'b0;
                id_alu_op  = ALU_SUB; // Flags computed from rs1-rs2
                // B-type immediate
                id_imm     = {{19{id_instr[31]}}, id_instr[31], id_instr[7],
                              id_instr[30:25], id_instr[11:8], 1'b0};
            end

            // ----------------------------------------------------------
            // JAL
            // ----------------------------------------------------------
            7'b1101111: begin
                id_jump      = 1'b1;
                id_pc_to_reg = 1'b1;
                id_reg_we    = 1'b1;
                id_alu_op    = ALU_ADD;
                // J-type immediate
                id_imm       = {{11{id_instr[31]}}, id_instr[31], id_instr[19:12],
                                id_instr[20], id_instr[30:21], 1'b0};
            end

            // ----------------------------------------------------------
            // JALR
            // ----------------------------------------------------------
            7'b1100111: begin
                id_jump      = 1'b1;
                id_jalr      = 1'b1;
                id_pc_to_reg = 1'b1;
                id_reg_we    = 1'b1;
                id_alu_src   = 1'b1;
                id_alu_op    = ALU_ADD;
                // I-type immediate
                id_imm       = {{20{id_instr[31]}}, id_instr[31:20]};
            end

            // ----------------------------------------------------------
            // LUI
            // ----------------------------------------------------------
            7'b0110111: begin
                id_alu_op  = ALU_PASS_B;
                id_alu_src = 1'b1;
                id_reg_we  = 1'b1;
                // U-type immediate
                id_imm     = {id_instr[31:12], 12'b0};
                // rs1 is don't-care for LUI but must not cause X
                id_rs1_addr = 5'h0;
            end

            // ----------------------------------------------------------
            // AUIPC
            // ----------------------------------------------------------
            7'b0010111: begin
                id_auipc   = 1'b1;
                id_alu_op  = ALU_ADD;
                id_alu_src = 1'b1;
                id_reg_we  = 1'b1;
                // U-type immediate
                id_imm     = {id_instr[31:12], 12'b0};
            end

            // ----------------------------------------------------------
            // Default — unknown opcode: all outputs already zeroed above
            // ----------------------------------------------------------
            default: begin
                id_rs1_addr   = 5'h0;
                id_rs2_addr   = 5'h0;
                id_rd_addr    = 5'h0;
                id_imm        = 32'h0;
                id_alu_op     = ALU_ADD;
                id_alu_src    = 1'b0;
                id_mem_we     = 1'b0;
                id_mem_funct3 = 3'b0;
                id_mem_re     = 1'b0;
                id_reg_we     = 1'b0;
                id_mem_to_reg = 1'b0;
                id_branch     = 1'b0;
                id_jump       = 1'b0;
                id_jalr       = 1'b0;
                id_pc_to_reg  = 1'b0;
                id_auipc      = 1'b0;
            end

        endcase
    end

endmodule

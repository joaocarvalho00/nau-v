// Hazard Unit — detects data and control hazards in the 5-stage pipeline.
//
// Load-use hazard (data):
//   When the instruction in EX is a LOAD and the instruction in ID reads the
//   same register, one stall cycle is inserted: PC and IF/ID hold, ID/EX
//   gets a bubble.  After the stall, MEM/WB forwarding delivers the loaded
//   value to EX the following cycle.
//
// Control hazard (branch / jump):
//   Branch and jump targets are resolved at the end of the EX stage.  Two
//   instructions have been speculatively fetched on the wrong path (the ones
//   that were in IF and ID when EX resolves the redirect).  Both IF/ID and
//   ID/EX are flushed (replaced with NOPs).
//
// Register-use filter:
//   Only instructions that architecturally read rs1 or rs2 are checked for
//   load-use hazards.  LUI, AUIPC, and JAL do not read rs1/rs2; checking
//   their immediate-field bits against the load destination would cause
//   spurious stalls.

module hazard_unit (
    // Instruction word currently in the ID stage (from IF/ID register)
    input  logic [31:0] if_id_instr,

    // ID/EX register — destination and type of instruction now in EX
    input  logic [4:0]  id_ex_rd_addr,
    input  logic        id_ex_mem_re,     // EX instruction is a LOAD

    // Branch/jump resolved by EX stage (combinational)
    input  logic        ex_pc_sel,        // 1 = redirect PC

    // Control outputs
    output logic        stall,            // hold PC + IF/ID; bubble ID/EX
    output logic        flush_if_id,      // clear IF/ID register
    output logic        flush_id_ex       // clear ID/EX register
);

    // -----------------------------------------------------------------------
    // Decode which registers the instruction in ID actually reads
    // -----------------------------------------------------------------------
    logic [6:0] opcode;
    logic        rs1_used;
    logic        rs2_used;

    always_comb begin
        opcode = if_id_instr[6:0];

        // Instructions that do NOT read rs1: LUI, AUIPC, JAL
        // (LUI bits[19:15] are part of the U-immediate, not a register specifier;
        //  AUIPC and JAL similarly use those bits as immediate fields.)
        case (opcode)
            7'b0110111,   // LUI
            7'b0010111,   // AUIPC
            7'b1101111:   // JAL
                rs1_used = 1'b0;
            default:
                rs1_used = 1'b1;
        endcase

        // Only R-type, store, and branch instructions read rs2
        case (opcode)
            7'b0110011,   // R-type  (ADD, SUB, …)
            7'b0100011,   // S-type  (SB, SH, SW)
            7'b1100011:   // B-type  (BEQ, BNE, …)
                rs2_used = 1'b1;
            default:
                rs2_used = 1'b0;
        endcase
    end

    // -----------------------------------------------------------------------
    // Load-use hazard detection
    // -----------------------------------------------------------------------
    logic luse_rs1, luse_rs2;

    always_comb begin
        luse_rs1 = id_ex_mem_re
                   && (id_ex_rd_addr != 5'b0)
                   && rs1_used
                   && (id_ex_rd_addr == if_id_instr[19:15]);

        luse_rs2 = id_ex_mem_re
                   && (id_ex_rd_addr != 5'b0)
                   && rs2_used
                   && (id_ex_rd_addr == if_id_instr[24:20]);

        stall = luse_rs1 | luse_rs2;
    end

    // -----------------------------------------------------------------------
    // Control hazard: flush two speculatively-fetched instructions when
    // a branch is taken or a jump resolves in EX.
    // -----------------------------------------------------------------------
    always_comb begin
        flush_if_id = ex_pc_sel;
        flush_id_ex = ex_pc_sel;
    end

endmodule

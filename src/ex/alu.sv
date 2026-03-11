// EX Stage — Arithmetic/Logic Unit
// Implements all 11 RV32I ALU operations.
// Flags: zero (result==0), neg (result[31]), overflow (signed add/sub).

module alu (
    input  logic [31:0] ex_operand_a,
    input  logic [31:0] ex_operand_b,
    input  logic [3:0]  ex_alu_op,
    output logic [31:0] ex_alu_result,
    output logic        ex_alu_zero,
    output logic        ex_alu_neg,
    output logic        ex_alu_overflow
);

    // -----------------------------------------------------------------------
    // ALU operation encodings
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
    // Combinational ALU core
    // -----------------------------------------------------------------------
    logic [32:0] add_sub_result; // 33 bits to capture carry/borrow

    always_comb begin
        // Default assignment prevents latches
        ex_alu_result  = 32'h0;
        add_sub_result = 33'h0;

        case (ex_alu_op)
            ALU_ADD: begin
                add_sub_result = {1'b0, ex_operand_a} + {1'b0, ex_operand_b};
                ex_alu_result  = add_sub_result[31:0];
            end
            ALU_SUB: begin
                add_sub_result = {1'b0, ex_operand_a} - {1'b0, ex_operand_b};
                ex_alu_result  = add_sub_result[31:0];
            end
            ALU_SLL:    ex_alu_result = ex_operand_a << ex_operand_b[4:0];
            ALU_SLT:    ex_alu_result = ($signed(ex_operand_a) < $signed(ex_operand_b))
                                         ? 32'd1 : 32'd0;
            ALU_SLTU:   ex_alu_result = (ex_operand_a < ex_operand_b)
                                         ? 32'd1 : 32'd0;
            ALU_XOR:    ex_alu_result = ex_operand_a ^ ex_operand_b;
            ALU_SRL:    ex_alu_result = ex_operand_a >> ex_operand_b[4:0];
            ALU_SRA:    ex_alu_result = $signed(ex_operand_a) >>> ex_operand_b[4:0];
            ALU_OR:     ex_alu_result = ex_operand_a | ex_operand_b;
            ALU_AND:    ex_alu_result = ex_operand_a & ex_operand_b;
            ALU_PASS_B: ex_alu_result = ex_operand_b;
            default:    ex_alu_result = 32'h0;
        endcase
    end

    // -----------------------------------------------------------------------
    // Status flags (combinational, derived from the result)
    // -----------------------------------------------------------------------
    always_comb begin
        ex_alu_zero     = (ex_alu_result == 32'h0);
        ex_alu_neg      = ex_alu_result[31];
        // Signed overflow for ADD/SUB:
        //   ADD: overflow when both operands have the same sign and the
        //        result has a different sign.
        //   SUB: overflow when operands have different signs and the
        //        result sign differs from operand_a.
        case (ex_alu_op)
            ALU_ADD: ex_alu_overflow =
                (~ex_operand_a[31] & ~ex_operand_b[31] &  ex_alu_result[31]) |
                ( ex_operand_a[31] &  ex_operand_b[31] & ~ex_alu_result[31]);
            ALU_SUB: ex_alu_overflow =
                (~ex_operand_a[31] &  ex_operand_b[31] &  ex_alu_result[31]) |
                ( ex_operand_a[31] & ~ex_operand_b[31] & ~ex_alu_result[31]);
            default: ex_alu_overflow = 1'b0;
        endcase
    end

endmodule

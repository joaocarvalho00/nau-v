// Testbench: tb_alu
// Tests all 11 ALU operations, status flags, and edge cases.

module tb_alu;

    // -----------------------------------------------------------------------
    // DUT ports
    // -----------------------------------------------------------------------
    logic [31:0] ex_operand_a;
    logic [31:0] ex_operand_b;
    logic [3:0]  ex_alu_op;
    logic [31:0] ex_alu_result;
    logic        ex_alu_zero;
    logic        ex_alu_neg;
    logic        ex_alu_overflow;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    alu u_alu (
        .ex_operand_a   (ex_operand_a),
        .ex_operand_b   (ex_operand_b),
        .ex_alu_op      (ex_alu_op),
        .ex_alu_result  (ex_alu_result),
        .ex_alu_zero    (ex_alu_zero),
        .ex_alu_neg     (ex_alu_neg),
        .ex_alu_overflow(ex_alu_overflow)
    );

    // -----------------------------------------------------------------------
    // ALU op codes (mirror alu.sv localparams)
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
    // Test counters
    // -----------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -----------------------------------------------------------------------
    // Check helper
    // -----------------------------------------------------------------------
    task automatic check_result(
        input string       test_name,
        input logic [31:0] got,
        input logic [31:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %-30s  got=0x%08h", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-30s  got=0x%08h  expected=0x%08h",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    task automatic check_flag(
        input string test_name,
        input logic  got,
        input logic  expected
    );
        if (got === expected) begin
            $display("  PASS  %-30s  got=%0b", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-30s  got=%0b  expected=%0b",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
    end

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("=== tb_alu ===");

        // --- ADD ---
        $display("-- ADD --");
        ex_alu_op = ALU_ADD;
        ex_operand_a = 32'd10;  ex_operand_b = 32'd20;
        #1; check_result("ADD 10+20",       ex_alu_result, 32'd30);

        ex_operand_a = 32'd0;   ex_operand_b = 32'd0;
        #1; check_result("ADD 0+0",         ex_alu_result, 32'd0);
             check_flag("ADD zero flag",    ex_alu_zero,   1'b1);

        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'd1;
        #1; check_result("ADD wrap",        ex_alu_result, 32'd0);
             check_flag("ADD wrap zero",    ex_alu_zero,   1'b1);

        // Signed overflow: MAX_INT + 1
        ex_operand_a = 32'h7FFF_FFFF; ex_operand_b = 32'd1;
        #1; check_result("ADD signed ovf",  ex_alu_result, 32'h8000_0000);
             check_flag("ADD overflow",     ex_alu_overflow, 1'b1);
             check_flag("ADD neg flag",     ex_alu_neg,    1'b1);

        // --- SUB ---
        $display("-- SUB --");
        ex_alu_op = ALU_SUB;
        ex_operand_a = 32'd30;  ex_operand_b = 32'd20;
        #1; check_result("SUB 30-20",       ex_alu_result, 32'd10);

        ex_operand_a = 32'd5;   ex_operand_b = 32'd5;
        #1; check_result("SUB 5-5",         ex_alu_result, 32'd0);
             check_flag("SUB zero flag",    ex_alu_zero,   1'b1);

        ex_operand_a = 32'd0;   ex_operand_b = 32'd1;
        #1; check_result("SUB 0-1",         ex_alu_result, 32'hFFFF_FFFF);
             check_flag("SUB neg flag",     ex_alu_neg,    1'b1);

        // Signed overflow: MIN_INT - 1
        ex_operand_a = 32'h8000_0000; ex_operand_b = 32'd1;
        #1; check_flag("SUB overflow",      ex_alu_overflow, 1'b1);

        // --- SLL ---
        $display("-- SLL --");
        ex_alu_op = ALU_SLL;
        ex_operand_a = 32'h0000_0001; ex_operand_b = 32'd4;
        #1; check_result("SLL 1<<4",        ex_alu_result, 32'h0000_0010);

        ex_operand_a = 32'h0000_0001; ex_operand_b = 32'd31;
        #1; check_result("SLL 1<<31",       ex_alu_result, 32'h8000_0000);

        // --- SLT (signed) ---
        $display("-- SLT --");
        ex_alu_op = ALU_SLT;
        ex_operand_a = 32'd5;   ex_operand_b = 32'd10;
        #1; check_result("SLT 5<10",        ex_alu_result, 32'd1);

        ex_operand_a = 32'd10;  ex_operand_b = 32'd5;
        #1; check_result("SLT 10<5",        ex_alu_result, 32'd0);

        // Negative < positive
        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'd1;
        #1; check_result("SLT -1<1",        ex_alu_result, 32'd1);

        // --- SLTU (unsigned) ---
        $display("-- SLTU --");
        ex_alu_op = ALU_SLTU;
        ex_operand_a = 32'd5;   ex_operand_b = 32'd10;
        #1; check_result("SLTU 5<10",       ex_alu_result, 32'd1);

        // 0xFFFF_FFFF > 1 unsigned
        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'd1;
        #1; check_result("SLTU max>1",      ex_alu_result, 32'd0);

        // --- XOR ---
        $display("-- XOR --");
        ex_alu_op = ALU_XOR;
        ex_operand_a = 32'hAAAA_AAAA; ex_operand_b = 32'h5555_5555;
        #1; check_result("XOR alternating", ex_alu_result, 32'hFFFF_FFFF);

        ex_operand_a = 32'hDEAD_BEEF; ex_operand_b = 32'hDEAD_BEEF;
        #1; check_result("XOR self",        ex_alu_result, 32'd0);

        // --- SRL ---
        $display("-- SRL --");
        ex_alu_op = ALU_SRL;
        ex_operand_a = 32'h8000_0000; ex_operand_b = 32'd1;
        #1; check_result("SRL msb>>1",      ex_alu_result, 32'h4000_0000);

        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'd4;
        #1; check_result("SRL fff>>4",      ex_alu_result, 32'h0FFF_FFFF);

        // --- SRA ---
        $display("-- SRA --");
        ex_alu_op = ALU_SRA;
        ex_operand_a = 32'h8000_0000; ex_operand_b = 32'd1;
        #1; check_result("SRA msb>>1",      ex_alu_result, 32'hC000_0000);

        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'd4;
        #1; check_result("SRA -1>>4",       ex_alu_result, 32'hFFFF_FFFF);

        ex_operand_a = 32'h7FFF_FFFF; ex_operand_b = 32'd1;
        #1; check_result("SRA pos>>1",      ex_alu_result, 32'h3FFF_FFFF);

        // --- OR ---
        $display("-- OR --");
        ex_alu_op = ALU_OR;
        ex_operand_a = 32'hAAAA_AAAA; ex_operand_b = 32'h5555_5555;
        #1; check_result("OR alternating",  ex_alu_result, 32'hFFFF_FFFF);

        ex_operand_a = 32'h0000_0000; ex_operand_b = 32'h0000_0000;
        #1; check_result("OR zeros",        ex_alu_result, 32'h0000_0000);

        // --- AND ---
        $display("-- AND --");
        ex_alu_op = ALU_AND;
        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'hAAAA_AAAA;
        #1; check_result("AND mask",        ex_alu_result, 32'hAAAA_AAAA);

        ex_operand_a = 32'hFFFF_FFFF; ex_operand_b = 32'h0000_0000;
        #1; check_result("AND zero",        ex_alu_result, 32'h0000_0000);

        // --- PASS_B ---
        $display("-- PASS_B --");
        ex_alu_op = ALU_PASS_B;
        ex_operand_a = 32'hDEAD_BEEF; ex_operand_b = 32'h1234_5000;
        #1; check_result("PASS_B",          ex_alu_result, 32'h1234_5000);

        // -----------------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------------
        $display("");
        if (fail_count == 0)
            $display("ALL TESTS PASSED (%0d tests)", pass_count);
        else
            $display("TESTS FAILED: %0d / %0d", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule

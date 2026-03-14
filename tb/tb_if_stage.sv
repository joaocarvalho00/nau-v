// Testbench: tb_if_stage
// Tests reset behaviour, sequential PC increment (PC+4 each cycle),
// and branch/jump target redirection.

module tb_if_stage;

    // -----------------------------------------------------------------------
    // Clock generation
    // -----------------------------------------------------------------------
    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT ports
    // -----------------------------------------------------------------------
    logic        rst;
    logic        pc_sel;
    logic [31:0] if_pc_target;
    logic [31:0] if_pc;
    logic [31:0] if_pc_plus4;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    if_stage u_if_stage (
        .clk          (clk),
        .rst          (rst),
        .pc_en        (1'b1),         // always enabled for unit test
        .pc_sel       (pc_sel),
        .if_pc_target (if_pc_target),
        .if_pc        (if_pc),
        .if_pc_plus4  (if_pc_plus4)
    );

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
            $display("  PASS  %-40s  got=0x%08h", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-40s  got=0x%08h  expected=0x%08h",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_if_stage.vcd");
        $dumpvars(0, tb_if_stage);
    end

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        pass_count   = 0;
        fail_count   = 0;
        rst          = 1'b1;
        pc_sel       = 1'b0;
        if_pc_target = 32'h0;

        $display("=== tb_if_stage ===");

        // -----------------------------------------------------------------------
        // Reset — PC must be zero immediately after first rising edge
        // -----------------------------------------------------------------------
        $display("-- Reset --");
        @(posedge clk); #1;
        check_result("PC after reset",       if_pc,       32'h0000_0000);
        check_result("PC+4 after reset",     if_pc_plus4, 32'h0000_0004);

        // -----------------------------------------------------------------------
        // Sequential increment: PC should advance by 4 each cycle
        // -----------------------------------------------------------------------
        $display("-- Sequential increment --");
        rst = 1'b0;
        @(posedge clk); #1;
        check_result("PC after clk 1 (0x04)", if_pc,       32'h0000_0004);
        check_result("PC+4 comb     (0x08)",  if_pc_plus4, 32'h0000_0008);

        @(posedge clk); #1;
        check_result("PC after clk 2 (0x08)", if_pc,       32'h0000_0008);

        @(posedge clk); #1;
        check_result("PC after clk 3 (0x0c)", if_pc,       32'h0000_000c);

        // -----------------------------------------------------------------------
        // Branch taken — redirect to 0x80
        // -----------------------------------------------------------------------
        $display("-- Branch taken: redirect to 0x80 --");
        pc_sel       = 1'b1;
        if_pc_target = 32'h0000_0080;
        @(posedge clk); #1;
        check_result("PC after redirect (0x80)", if_pc,       32'h0000_0080);
        check_result("PC+4 after redirect (0x84)", if_pc_plus4, 32'h0000_0084);

        // -----------------------------------------------------------------------
        // Resume sequential from 0x80
        // -----------------------------------------------------------------------
        $display("-- Resume sequential from 0x80 --");
        pc_sel = 1'b0;
        @(posedge clk); #1;
        check_result("PC seq from 0x80 (0x84)", if_pc, 32'h0000_0084);
        @(posedge clk); #1;
        check_result("PC seq (0x88)", if_pc, 32'h0000_0088);

        // -----------------------------------------------------------------------
        // Second redirect
        // -----------------------------------------------------------------------
        $display("-- Second redirect to 0x100 --");
        pc_sel       = 1'b1;
        if_pc_target = 32'h0000_0100;
        @(posedge clk); #1;
        check_result("PC after redirect (0x100)", if_pc, 32'h0000_0100);

        // -----------------------------------------------------------------------
        // Reset while running
        // -----------------------------------------------------------------------
        $display("-- Reset while running --");
        rst = 1'b1;
        @(posedge clk); #1;
        check_result("PC after mid-run reset", if_pc, 32'h0000_0000);
        rst = 1'b0; pc_sel = 1'b0;
        @(posedge clk); #1;
        check_result("PC resumes at 0x04", if_pc, 32'h0000_0004);

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

// Testbench: tb_regfile
// Tests the register file: reset, synchronous writes, asynchronous reads,
// x0 hardwired-zero, and debug read port.

module tb_regfile;

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
    logic [4:0]  id_rs1_addr;
    logic [4:0]  id_rs2_addr;
    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;
    logic [4:0]  wb_rd_addr;
    logic [31:0] wb_rd_data;
    logic        wb_rd_we;
    logic [4:0]  dbg_addr;
    logic [31:0] dbg_data;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    regfile u_regfile (
        .clk        (clk),
        .rst        (rst),
        .id_rs1_addr(id_rs1_addr),
        .id_rs2_addr(id_rs2_addr),
        .id_rs1_data(id_rs1_data),
        .id_rs2_data(id_rs2_data),
        .wb_rd_addr (wb_rd_addr),
        .wb_rd_data (wb_rd_data),
        .wb_rd_we   (wb_rd_we),
        .dbg_addr   (dbg_addr),
        .dbg_data   (dbg_data)
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
            $display("  PASS  %-35s  got=0x%08h", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-35s  got=0x%08h  expected=0x%08h",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);
    end

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        pass_count  = 0;
        fail_count  = 0;

        // Default port values
        rst         = 1'b1;
        id_rs1_addr = 5'h0;
        id_rs2_addr = 5'h0;
        wb_rd_addr  = 5'h0;
        wb_rd_data  = 32'h0;
        wb_rd_we    = 1'b0;
        dbg_addr    = 5'h0;

        $display("=== tb_regfile ===");

        // -----------------------------------------------------------------------
        // Reset
        // -----------------------------------------------------------------------
        @(posedge clk); #1;
        rst = 1'b0;

        // After reset all regs should be 0
        $display("-- Post-reset reads --");
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd31;
        #1;
        check_result("reset x1==0",  id_rs1_data, 32'h0);
        check_result("reset x31==0", id_rs2_data, 32'h0);

        // -----------------------------------------------------------------------
        // Write x1 = 0xDEAD_BEEF, read back
        // -----------------------------------------------------------------------
        $display("-- Write x1=0xDEAD_BEEF, read back --");
        wb_rd_addr = 5'd1; wb_rd_data = 32'hDEAD_BEEF; wb_rd_we = 1'b1;
        @(posedge clk); #1;
        wb_rd_we = 1'b0;
        id_rs1_addr = 5'd1;
        #1;
        check_result("x1 readback", id_rs1_data, 32'hDEAD_BEEF);

        // -----------------------------------------------------------------------
        // Write x2 = 0x1234_5678
        // -----------------------------------------------------------------------
        $display("-- Write x2=0x1234_5678 --");
        wb_rd_addr = 5'd2; wb_rd_data = 32'h1234_5678; wb_rd_we = 1'b1;
        @(posedge clk); #1;
        wb_rd_we = 1'b0;
        id_rs1_addr = 5'd1; id_rs2_addr = 5'd2;
        #1;
        check_result("x1 still 0xDEAD_BEEF", id_rs1_data, 32'hDEAD_BEEF);
        check_result("x2 == 0x1234_5678",    id_rs2_data, 32'h1234_5678);

        // -----------------------------------------------------------------------
        // x0 is always zero, even with write
        // -----------------------------------------------------------------------
        $display("-- x0 hardwired zero --");
        wb_rd_addr = 5'd0; wb_rd_data = 32'hFFFF_FFFF; wb_rd_we = 1'b1;
        @(posedge clk); #1;
        wb_rd_we = 1'b0;
        id_rs1_addr = 5'd0;
        #1;
        check_result("x0 after write attempt", id_rs1_data, 32'h0);

        // -----------------------------------------------------------------------
        // Debug port
        // -----------------------------------------------------------------------
        $display("-- Debug port --");
        dbg_addr = 5'd1;
        #1;
        check_result("dbg x1", dbg_data, 32'hDEAD_BEEF);
        dbg_addr = 5'd2;
        #1;
        check_result("dbg x2", dbg_data, 32'h1234_5678);
        dbg_addr = 5'd0;
        #1;
        check_result("dbg x0", dbg_data, 32'h0);

        // -----------------------------------------------------------------------
        // Write multiple registers and verify independence
        // -----------------------------------------------------------------------
        $display("-- Multi-register writes --");
        begin
            integer i;
            for (i = 1; i <= 31; i = i + 1) begin
                wb_rd_addr = i[4:0];
                wb_rd_data = 32'(i * 32'hAABBCC01);
                wb_rd_we   = 1'b1;
                @(posedge clk); #1;
                wb_rd_we = 1'b0;
            end
        end
        // Spot-check a few
        id_rs1_addr = 5'd5;  id_rs2_addr = 5'd10;
        #1;
        check_result("x5  spot check", id_rs1_data, 32'(5  * 32'hAABBCC01));
        check_result("x10 spot check", id_rs2_data, 32'(10 * 32'hAABBCC01));

        // -----------------------------------------------------------------------
        // Synchronous reset clears all
        // -----------------------------------------------------------------------
        $display("-- Synchronous reset --");
        rst = 1'b1;
        @(posedge clk); #1;
        rst = 1'b0;
        id_rs1_addr = 5'd5; id_rs2_addr = 5'd10;
        #1;
        check_result("post-rst x5==0",  id_rs1_data, 32'h0);
        check_result("post-rst x10==0", id_rs2_data, 32'h0);

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

// tb_branch_predictor.sv — Unit testbench for the branch_predictor module.
//
// Tests:
//  1. Reset state — all entries invalid, no prediction
//  2. Miss on cold BTB
//  3. Counter ramps: weakly-taken after 1 update, strongly-taken after 2
//  4. Predict taken (counter >= 2)
//  5. Predict not-taken (counter < 2) after two not-taken updates
//  6. Tag mismatch — same index, different tag -> no prediction
//  7. Multiple entries — two different branches coexist
//  8. Counter saturation at 11 (taken) and 00 (not-taken)
//  9. Target update — correct target stored after branch taken
// 10. Opcode filter is NOT in the predictor module (just verifies raw prediction)

`timescale 1ns/1ps

module tb_branch_predictor;

    // Clock and reset
    /* verilator lint_off PROCASSINIT */
    logic        clk = 0;
    /* verilator lint_on PROCASSINIT */
    logic        rst = 1;
    always #5 clk = ~clk;

    // DUT ports
    logic        bp_pred_taken;
    logic [31:0] bp_pred_target;
    logic [31:0] bp_fetch_pc = 32'h0;

    logic        bp_update_en     = 0;
    logic [31:0] bp_update_pc     = 32'h0;
    logic        bp_update_taken  = 0;
    logic [31:0] bp_update_target = 32'h0;

    branch_predictor #(.ENTRIES(64)) dut (
        .clk              (clk),
        .rst              (rst),
        .bp_fetch_pc      (bp_fetch_pc),
        .bp_pred_taken    (bp_pred_taken),
        .bp_pred_target   (bp_pred_target),
        .bp_update_en     (bp_update_en),
        .bp_update_pc     (bp_update_pc),
        .bp_update_taken  (bp_update_taken),
        .bp_update_target (bp_update_target)
    );

    // -------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(string name, logic got, logic exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_count++;
        end else begin
            $display("  FAIL  %s  got=%0b exp=%0b", name, got, exp);
            fail_count++;
        end
    endtask

    task automatic check32(string name, logic [31:0] got, logic [31:0] exp);
        if (got === exp) begin
            $display("  PASS  %s", name);
            pass_count++;
        end else begin
            $display("  FAIL  %s  got=0x%08x exp=0x%08x", name, got, exp);
            fail_count++;
        end
    endtask

    // Clock a single update
    task automatic update(logic [31:0] pc, logic taken, logic [31:0] tgt);
        @(negedge clk);
        bp_update_en     = 1;
        bp_update_pc     = pc;
        bp_update_taken  = taken;
        bp_update_target = tgt;
        @(posedge clk); #1;
        bp_update_en = 0;
    endtask

    // -------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------
    initial begin
        $dumpfile("tb_branch_predictor.vcd");
        $dumpvars(0, tb_branch_predictor);
        $display("=== tb_branch_predictor ===");

        // Reset for 3 cycles
        rst = 1;
        repeat (3) @(posedge clk); #1;
        rst = 0;

        // ------------------------------------------------------------------
        // Test 1: cold miss — no prediction after reset
        // ------------------------------------------------------------------
        $display("--- Test 1: cold miss ---");
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cold miss: pred_taken = 0", bp_pred_taken, 1'b0);

        // ------------------------------------------------------------------
        // Test 2: one taken update -> counter goes to 01 (weakly not-taken)
        //         Still should NOT predict taken (cnt[1]=0)
        // ------------------------------------------------------------------
        $display("--- Test 2: one taken update (cnt=01, no prediction) ---");
        update(32'h0000_0100, 1'b1, 32'h0000_0200);
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cnt=01: pred_taken = 0", bp_pred_taken, 1'b0);

        // ------------------------------------------------------------------
        // Test 3: second taken update -> counter goes to 10 (weakly taken)
        //         Now should predict taken
        // ------------------------------------------------------------------
        $display("--- Test 3: second taken update (cnt=10, predict taken) ---");
        update(32'h0000_0100, 1'b1, 32'h0000_0200);
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cnt=10: pred_taken = 1",   bp_pred_taken,  1'b1);
        check32("cnt=10: pred_target",    bp_pred_target, 32'h0000_0200);

        // ------------------------------------------------------------------
        // Test 4: third taken update -> counter saturates at 11 (strongly taken)
        // ------------------------------------------------------------------
        $display("--- Test 4: counter saturation at 11 ---");
        update(32'h0000_0100, 1'b1, 32'h0000_0200);
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cnt=11: pred_taken = 1", bp_pred_taken, 1'b1);

        // ------------------------------------------------------------------
        // Test 5: two not-taken updates from 11 -> 10 -> 01 (weakly not-taken)
        //         Should stop predicting taken
        // ------------------------------------------------------------------
        $display("--- Test 5: two not-taken updates (cnt 11->10->01) ---");
        update(32'h0000_0100, 1'b0, 32'h0000_0104);   // 11->10
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cnt=10 after 1 NT: pred_taken = 1", bp_pred_taken, 1'b1);  // still taken
        update(32'h0000_0100, 1'b0, 32'h0000_0104);   // 10->01
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cnt=01 after 2 NT: pred_taken = 0", bp_pred_taken, 1'b0);

        // ------------------------------------------------------------------
        // Test 6: counter saturation at 00
        // ------------------------------------------------------------------
        $display("--- Test 6: counter saturation at 00 ---");
        update(32'h0000_0100, 1'b0, 32'h0000_0104);   // 01->00
        update(32'h0000_0100, 1'b0, 32'h0000_0104);   // 00->00 (saturate)
        bp_fetch_pc = 32'h0000_0100;
        #1;
        check("cnt=00 saturated: pred_taken = 0", bp_pred_taken, 1'b0);

        // ------------------------------------------------------------------
        // Test 7: tag mismatch — same BTB index (PC[7:2]), different tag
        // ------------------------------------------------------------------
        $display("--- Test 7: tag mismatch ---");
        // PC 0x0000_0100 -> index = bits[7:2] = 0x04
        // PC 0x0001_0100 -> same index (bits[7:2]=0x04), different tag
        // First populate with 0x100
        update(32'h0000_0100, 1'b1, 32'h0000_0200);
        update(32'h0000_0100, 1'b1, 32'h0000_0200);  // get to cnt=10 (taken)
        bp_fetch_pc = 32'h0001_0100;   // different tag, same index
        #1;
        check("tag mismatch: pred_taken = 0", bp_pred_taken, 1'b0);

        // ------------------------------------------------------------------
        // Test 8: two independent branches coexist (different indices)
        // Branch A: PC=0x0000_0020 → index=bits[7:2]=8
        // Branch B: PC=0x0000_0030 → index=bits[7:2]=12
        // ------------------------------------------------------------------
        $display("--- Test 8: two branches coexist ---");
        update(32'h0000_0020, 1'b1, 32'h0000_0400);
        update(32'h0000_0020, 1'b1, 32'h0000_0400);
        update(32'h0000_0030, 1'b1, 32'h0000_0500);
        update(32'h0000_0030, 1'b1, 32'h0000_0500);

        bp_fetch_pc = 32'h0000_0020;
        #1;
        check("branch A: pred_taken", bp_pred_taken, 1'b1);
        check32("branch A: target",   bp_pred_target, 32'h0000_0400);

        bp_fetch_pc = 32'h0000_0030;
        #1;
        check("branch B: pred_taken", bp_pred_taken, 1'b1);
        check32("branch B: target",   bp_pred_target, 32'h0000_0500);

        // ------------------------------------------------------------------
        // Test 9: target update — JALR-like changing target
        // ------------------------------------------------------------------
        $display("--- Test 9: target update ---");
        // Branch at 0x400, first seen going to 0x800, now goes to 0x900
        update(32'h0000_0400, 1'b1, 32'h0000_0800);
        update(32'h0000_0400, 1'b1, 32'h0000_0800);  // get to taken
        bp_fetch_pc = 32'h0000_0400;
        #1;
        check32("target before update", bp_pred_target, 32'h0000_0800);
        // Now update with new target
        update(32'h0000_0400, 1'b1, 32'h0000_0900);
        bp_fetch_pc = 32'h0000_0400;
        #1;
        check32("target after update",  bp_pred_target, 32'h0000_0900);

        // ------------------------------------------------------------------
        // Done
        // ------------------------------------------------------------------
        $display("");
        $display("=== RESULTS: %0d/%0d checks passed ===", pass_count, pass_count+fail_count);
        if (fail_count == 0)
            $display("ALL PASS");
        else
            $display("FAILURES: %0d", fail_count);
        $finish;
    end

endmodule

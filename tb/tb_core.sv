// Testbench: tb_core
// Integration test for the full single-cycle Claude-V core.
// Programs are loaded via the imem_init_we port, then the core is run
// for a fixed number of cycles and register values are checked via the
// debug read port.

module tb_core;

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
    logic        imem_init_we;
    logic [31:0] imem_init_addr;
    logic [31:0] imem_init_data;
    logic [31:0] dbg_pc;
    logic [31:0] dbg_instr;
    logic [4:0]  dbg_rf_addr;
    logic [31:0] dbg_rf_data;
    logic [31:0] dbg_mem_addr;
    logic [31:0] dbg_mem_wdata;
    logic        dbg_mem_we;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    core u_core (
        .clk            (clk),
        .rst            (rst),
        .imem_init_we   (imem_init_we),
        .imem_init_addr (imem_init_addr),
        .imem_init_data (imem_init_data),
        .dbg_pc         (dbg_pc),
        .dbg_instr      (dbg_instr),
        .dbg_rf_addr    (dbg_rf_addr),
        .dbg_rf_data    (dbg_rf_data),
        .dbg_mem_addr   (dbg_mem_addr),
        .dbg_mem_wdata  (dbg_mem_wdata),
        .dbg_mem_we     (dbg_mem_we)
    );

    // -----------------------------------------------------------------------
    // Test counters
    // -----------------------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // -----------------------------------------------------------------------
    // Helper: load one word into instruction memory
    // -----------------------------------------------------------------------
    task automatic load_word(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        imem_init_we   = 1'b1;
        imem_init_addr = addr;
        imem_init_data = data;
        @(posedge clk);
        imem_init_we   = 1'b0;
    endtask

    // -----------------------------------------------------------------------
    // Helper: run N clock cycles
    // -----------------------------------------------------------------------
    task automatic run_cycles(input int n);
        integer i;
        for (i = 0; i < n; i = i + 1)
            @(posedge clk);
        #1;  // settle combinational outputs
    endtask

    // -----------------------------------------------------------------------
    // Helper: check a register value
    // -----------------------------------------------------------------------
    task automatic check_reg(
        input logic [4:0]  reg_addr,
        input logic [31:0] expected,
        input string       test_name
    );
        dbg_rf_addr = reg_addr;
        #1;
        if (dbg_rf_data === expected) begin
            $display("  PASS  %-40s  x%0d=0x%08h", test_name, reg_addr, dbg_rf_data);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-40s  x%0d got=0x%08h  expected=0x%08h",
                     test_name, reg_addr, dbg_rf_data, expected);
            fail_count = fail_count + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Helper: assert reset and flush imem to NOPs, then release
    // -----------------------------------------------------------------------
    task automatic reset_core();
        rst = 1'b1;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
        #1;
    endtask

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_core.vcd");
        $dumpvars(0, tb_core);
    end

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        pass_count      = 0;
        fail_count      = 0;
        rst             = 1'b1;
        imem_init_we    = 1'b0;
        imem_init_addr  = 32'h0;
        imem_init_data  = 32'h0;
        dbg_rf_addr     = 5'h0;

        $display("=== tb_core ===");

        // ===================================================================
        // Test 1: Basic ALU — ADDI + ADD
        //   0x00: ADDI x1, x0, 10   -> x1 = 10
        //   0x04: ADDI x2, x0, 20   -> x2 = 20
        //   0x08: ADD  x3, x1, x2   -> x3 = 30
        //   0x0c: NOP
        //   0x10: NOP (keep executing NOPs)
        // ===================================================================
        $display("-- Test 1: ADDI + ADD (expect x3=30) --");

        // Load instructions while reset is held
        imem_init_we = 1'b0;
        // ADDI x1, x0, 10  -> 0x00a00093
        load_word(32'h00, 32'h00a00093);
        // ADDI x2, x0, 20  -> 0x01400113
        load_word(32'h04, 32'h01400113);
        // ADD  x3, x1, x2  -> 0x002081b3
        load_word(32'h08, 32'h002081b3);
        // NOP
        load_word(32'h0c, 32'h00000013);

        reset_core();
        run_cycles(6);
        check_reg(5'd3, 32'd30, "ADDI+ADD x3==30");

        // ===================================================================
        // Test 2: LUI
        //   0x00: LUI x1, 0x12345   -> x1 = 0x12345000
        //   0x04: NOP
        // ===================================================================
        $display("-- Test 2: LUI (expect x1=0x12345000) --");

        load_word(32'h00, 32'h123450b7);  // LUI x1, 0x12345
        load_word(32'h04, 32'h00000013);  // NOP

        reset_core();
        run_cycles(4);
        check_reg(5'd1, 32'h1234_5000, "LUI x1==0x12345000");

        // ===================================================================
        // Test 3: Store + Load (SW/LW)
        //   0x00: ADDI x1, x0, 42   -> x1 = 42
        //   0x04: SW   x1, 0(x0)    -> mem[0] = 42
        //   0x08: LW   x2, 0(x0)    -> x2 = 42
        //   0x0c: NOP
        // ===================================================================
        $display("-- Test 3: SW then LW (expect x2=42) --");

        // ADDI x1, x0, 42  -> 0x02a00093
        load_word(32'h00, 32'h02a00093);
        // SW x1, 0(x0)     -> 0x00102023
        load_word(32'h04, 32'h00102023);
        // LW x2, 0(x0)     -> 0x00002103
        load_word(32'h08, 32'h00002103);
        // NOP
        load_word(32'h0c, 32'h00000013);

        reset_core();
        run_cycles(6);
        check_reg(5'd2, 32'd42, "SW+LW x2==42");

        // ===================================================================
        // Test 4: Branch taken (BEQ)
        //   0x00: ADDI x1, x0, 5
        //   0x04: ADDI x2, x0, 5
        //   0x08: BEQ  x1, x2, +8    -> branch to 0x10
        //   0x0c: ADDI x3, x0, 99    -> should be SKIPPED
        //   0x10: ADDI x3, x0, 42    -> should execute
        //   0x14: NOP
        // BEQ x1,x2,+8:
        //   offset=8: bit12=0,bits10:5=000000,bits4:1=0100,bit11=0
        //   = 0_000000_00010_00001_000_0100_0_1100011 = 32'h00208463
        // ===================================================================
        $display("-- Test 4: Branch taken BEQ (expect x3=42) --");

        load_word(32'h00, 32'h00500093);  // ADDI x1,x0,5
        load_word(32'h04, 32'h00500113);  // ADDI x2,x0,5
        load_word(32'h08, 32'h00208463);  // BEQ x1,x2,+8
        load_word(32'h0c, 32'h06300193);  // ADDI x3,x0,99  (skipped)
        load_word(32'h10, 32'h02a00193);  // ADDI x3,x0,42
        load_word(32'h14, 32'h00000013);  // NOP

        reset_core();
        run_cycles(8);
        check_reg(5'd3, 32'd42, "BEQ taken x3==42");

        // ===================================================================
        // Test 5: Branch not taken (BEQ with unequal operands)
        //   0x00: ADDI x1, x0, 3
        //   0x04: ADDI x2, x0, 7
        //   0x08: BEQ  x1, x2, +8   -> NOT taken (3 != 7)
        //   0x0c: ADDI x3, x0, 99   -> executes
        //   0x10: NOP
        // ===================================================================
        $display("-- Test 5: Branch not taken BEQ (expect x3=99) --");

        load_word(32'h00, 32'h00300093);  // ADDI x1,x0,3
        load_word(32'h04, 32'h00700113);  // ADDI x2,x0,7
        load_word(32'h08, 32'h00208463);  // BEQ x1,x2,+8 (not taken)
        load_word(32'h0c, 32'h06300193);  // ADDI x3,x0,99
        load_word(32'h10, 32'h00000013);  // NOP

        reset_core();
        run_cycles(8);
        check_reg(5'd3, 32'd99, "BEQ not taken x3==99");

        // ===================================================================
        // Test 6: JAL
        //   0x00: JAL x1, +8        -> PC = 0x08, x1 = 0x04
        //   0x04: ADDI x2,x0,77     -> skipped
        //   0x08: ADDI x3,x0,55     -> executes
        //   0x0c: NOP
        // JAL x1, +8:
        //   imm=8: bit20=0,bits10:1=0000000100,bit11=0,bits19:12=00000000
        //   rd=x1=00001
        //   = 0_00000000_0_0000000100_00001_1101111 = 32'h008000ef
        // ===================================================================
        $display("-- Test 6: JAL (expect x1=4, x3=55) --");

        load_word(32'h00, 32'h008000ef);  // JAL x1, +8
        load_word(32'h04, 32'h04d00113);  // ADDI x2,x0,77 (skipped)
        load_word(32'h08, 32'h03700193);  // ADDI x3,x0,55
        load_word(32'h0c, 32'h00000013);  // NOP

        reset_core();
        run_cycles(6);
        check_reg(5'd1, 32'h0000_0004, "JAL x1==PC+4==4");
        check_reg(5'd3, 32'd55,        "JAL x3==55");

        // ===================================================================
        // Test 7: AUIPC
        //   0x00: NOP
        //   0x04: AUIPC x1, 1     -> x1 = 0x04 + 0x1000 = 0x1004
        //   0x08: NOP
        // AUIPC x1, 1: imm=0x1000, rd=x1, opcode=0010111
        // = 00000000000000000001_00001_0010111 = 32'h00001097
        // ===================================================================
        $display("-- Test 7: AUIPC (expect x1=0x1004) --");

        load_word(32'h00, 32'h00000013);  // NOP
        load_word(32'h04, 32'h00001097);  // AUIPC x1, 1  (imm=0x1000)
        load_word(32'h08, 32'h00000013);  // NOP

        reset_core();
        run_cycles(5);
        check_reg(5'd1, 32'h0000_1004, "AUIPC x1==0x1004");

        // ===================================================================
        // Test 8: BLT (signed branch less-than)
        //   0x00: ADDI x1, x0, -1   -> x1 = -1 (0xFFFFFFFF)
        //   0x04: ADDI x2, x0,  1   -> x2 = 1
        //   0x08: BLT  x1, x2, +8   -> taken (-1 < 1)
        //   0x0c: ADDI x3, x0, 11   -> skipped
        //   0x10: ADDI x3, x0, 22   -> executes
        //   0x14: NOP
        // ADDI x1,x0,-1: imm=0xFFF, rs1=0, rd=1, funct3=000, op=0010011
        //   = 111111111111_00000_000_00001_0010011 = 32'hfff00093
        // BLT x1,x2,+8: funct3=100, rs1=x1, rs2=x2, imm=8
        //   imm=8: bit12=0,bits10:5=000000,bits4:1=0100,bit11=0
        //   = 0_000000_00010_00001_100_0100_0_1100011 = 32'h00204463
        // ===================================================================
        $display("-- Test 8: BLT taken (expect x3=22) --");

        load_word(32'h00, 32'hfff00093);  // ADDI x1,x0,-1
        load_word(32'h04, 32'h00100113);  // ADDI x2,x0,1
        load_word(32'h08, 32'h00204463);  // BLT x1,x2,+8
        load_word(32'h0c, 32'h00b00193);  // ADDI x3,x0,11 (skipped)
        load_word(32'h10, 32'h01600193);  // ADDI x3,x0,22
        load_word(32'h14, 32'h00000013);  // NOP

        reset_core();
        run_cycles(8);
        check_reg(5'd3, 32'd22, "BLT taken x3==22");

        // ===================================================================
        // Test 9: SB + LBU (byte store and zero-extending byte load)
        //   0x00: ADDI x1, x0, 0xAB  -> x1 = 0xAB
        //   0x04: SB   x1, 0(x0)     -> mem[0] byte 0 = 0xAB
        //   0x08: LBU  x2, 0(x0)     -> x2 = 0x000000AB
        //   0x0c: LB   x3, 0(x0)     -> x3 = 0xFFFFFFAB (sign-extended)
        //   0x10: NOP
        // ADDI x1,x0,0xAB: imm=0x0AB, rs1=0, rd=1 -> 32'h0ab00093
        // SB x1,0(x0): imm=0, rs2=x1=1, rs1=x0=0, funct3=000, op=0100011
        //   = 0000000_00001_00000_000_00000_0100011 = 32'h00100023
        // LBU x2,0(x0): imm=0, rs1=0, funct3=100, rd=2, op=0000011
        //   = 000000000000_00000_100_00010_0000011 = 32'h00004103
        // LB x3,0(x0): imm=0, rs1=0, funct3=000, rd=3, op=0000011
        //   = 000000000000_00000_000_00011_0000011 = 32'h00000183
        // ===================================================================
        $display("-- Test 9: SB + LBU/LB (byte ops) --");

        load_word(32'h00, 32'h0ab00093);  // ADDI x1,x0,0xAB
        load_word(32'h04, 32'h00100023);  // SB x1,0(x0)
        load_word(32'h08, 32'h00004103);  // LBU x2,0(x0)
        load_word(32'h0c, 32'h00000183);  // LB  x3,0(x0)
        load_word(32'h10, 32'h00000013);  // NOP

        reset_core();
        run_cycles(8);
        check_reg(5'd2, 32'h0000_00AB, "LBU x2==0xAB zero-extended");
        check_reg(5'd3, 32'hFFFF_FFAB, "LB  x3==0xAB sign-extended");

        // ===================================================================
        // Test 10: JALR
        //   0x00: ADDI x5, x0, 8    -> x5 = 8
        //   0x04: JALR x1, x5, 0    -> PC = 8, x1 = 0x08
        //   0x08: ADDI x3, x0, 77   -> executes (jump target)
        //   0x0c: NOP
        // JALR x1, x5, 0: imm=0, rs1=x5=5, funct3=000, rd=x1=1, op=1100111
        //   = 000000000000_00101_000_00001_1100111 = 32'h000280e7
        // ===================================================================
        $display("-- Test 10: JALR (expect x1=8, x3=77) --");

        load_word(32'h00, 32'h00800293);  // ADDI x5,x0,8
        load_word(32'h04, 32'h000280e7);  // JALR x1,x5,0
        load_word(32'h08, 32'h04d00193);  // ADDI x3,x0,77
        load_word(32'h0c, 32'h00000013);  // NOP

        reset_core();
        run_cycles(6);
        check_reg(5'd1, 32'h0000_0008, "JALR x1==PC+4==8");
        check_reg(5'd3, 32'd77,        "JALR x3==77");

        // ===================================================================
        // Summary
        // ===================================================================
        $display("");
        if (fail_count == 0)
            $display("ALL TESTS PASSED (%0d tests)", pass_count);
        else
            $display("TESTS FAILED: %0d / %0d", fail_count, pass_count + fail_count);

        $finish;
    end

endmodule

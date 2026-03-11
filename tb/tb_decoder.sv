// Testbench: tb_decoder
// Drives hardcoded 32-bit instruction encodings and checks all decoder
// output signals against expected values.

module tb_decoder;

    // -----------------------------------------------------------------------
    // DUT ports
    // -----------------------------------------------------------------------
    logic [31:0] id_instr;

    logic [4:0]  id_rs1_addr;
    logic [4:0]  id_rs2_addr;
    logic [4:0]  id_rd_addr;
    logic [31:0] id_imm;
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

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    decoder u_decoder (
        .id_instr     (id_instr),
        .id_rs1_addr  (id_rs1_addr),
        .id_rs2_addr  (id_rs2_addr),
        .id_rd_addr   (id_rd_addr),
        .id_imm       (id_imm),
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
        .id_auipc     (id_auipc)
    );

    // -----------------------------------------------------------------------
    // ALU op codes
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
    // Check helpers
    // -----------------------------------------------------------------------
    task automatic check32(
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

    task automatic check1(
        input string test_name,
        input logic  got,
        input logic  expected
    );
        if (got === expected) begin
            $display("  PASS  %-40s  got=%0b", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-40s  got=%0b  expected=%0b",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    task automatic check4(
        input string      test_name,
        input logic [3:0] got,
        input logic [3:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %-40s  got=0x%01h", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-40s  got=0x%01h  expected=0x%01h",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    task automatic check5(
        input string      test_name,
        input logic [4:0] got,
        input logic [4:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %-40s  got=%0d", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL  %-40s  got=%0d  expected=%0d",
                     test_name, got, expected);
            fail_count = fail_count + 1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("tb_decoder.vcd");
        $dumpvars(0, tb_decoder);
    end

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        pass_count = 0;
        fail_count = 0;
        $display("=== tb_decoder ===");

        // ===================================================================
        // ADD x3, x1, x2
        // funct7=0000000 rs2=x2=00010 rs1=x1=00001 funct3=000 rd=x3=00011 op=0110011
        // 0000000_00010_00001_000_00011_0110011 = 0x002081b3
        // ===================================================================
        $display("-- ADD x3,x1,x2  (32'h002081b3) --");
        id_instr = 32'h002081b3;
        #1;
        check5("ADD rs1_addr", id_rs1_addr, 5'd1);
        check5("ADD rs2_addr", id_rs2_addr, 5'd2);
        check5("ADD rd_addr",  id_rd_addr,  5'd3);
        check4("ADD alu_op",   id_alu_op,   ALU_ADD);
        check1("ADD alu_src",  id_alu_src,  1'b0);
        check1("ADD reg_we",   id_reg_we,   1'b1);
        check1("ADD mem_we",   id_mem_we,   1'b0);
        check1("ADD mem_re",   id_mem_re,   1'b0);
        check1("ADD branch",   id_branch,   1'b0);
        check1("ADD jump",     id_jump,     1'b0);

        // ===================================================================
        // SUB x5, x3, x4 — funct7=0100000
        // 0100000_00100_00011_000_00101_0110011 = 32'h404181b3
        // ===================================================================
        $display("-- SUB x5,x3,x4  (32'h404181b3) --");
        id_instr = 32'h404181b3;
        #1;
        check4("SUB alu_op",  id_alu_op,  ALU_SUB);
        check1("SUB alu_src", id_alu_src, 1'b0);
        check1("SUB reg_we",  id_reg_we,  1'b1);

        // ===================================================================
        // ADDI x1, x2, 5
        // imm=000000000101 rs1=00010 funct3=000 rd=00001 op=0010011
        // 000000000101_00010_000_00001_0010011 = 32'h00510093
        // ===================================================================
        $display("-- ADDI x1,x2,5  (32'h00510093) --");
        id_instr = 32'h00510093;
        #1;
        check5("ADDI rs1_addr", id_rs1_addr, 5'd2);
        check5("ADDI rd_addr",  id_rd_addr,  5'd1);
        check4("ADDI alu_op",   id_alu_op,   ALU_ADD);
        check1("ADDI alu_src",  id_alu_src,  1'b1);
        check32("ADDI imm",     id_imm,      32'd5);
        check1("ADDI reg_we",   id_reg_we,   1'b1);
        check1("ADDI mem_we",   id_mem_we,   1'b0);

        // ===================================================================
        // SLTI x4, x1, -1
        // imm=111111111111 rs1=00001 funct3=010 rd=00100 op=0010011
        // 111111111111_00001_010_00100_0010011 = 32'hfff0a213
        // ===================================================================
        $display("-- SLTI x4,x1,-1  (32'hfff0a213) --");
        id_instr = 32'hfff0a213;
        #1;
        check4("SLTI alu_op", id_alu_op, ALU_SLT);
        check32("SLTI imm",   id_imm,    32'hFFFF_FFFF);

        // ===================================================================
        // SLTIU x4, x1, 1
        // imm=000000000001 rs1=00001 funct3=011 rd=00100 op=0010011
        // 000000000001_00001_011_00100_0010011 = 32'h0010b213
        // ===================================================================
        $display("-- SLTIU x4,x1,1  (32'h0010b213) --");
        id_instr = 32'h0010b213;
        #1;
        check4("SLTIU alu_op", id_alu_op, ALU_SLTU);

        // ===================================================================
        // XORI x4, x1, 0xFF
        // imm=000011111111 rs1=00001 funct3=100 rd=00100 op=0010011
        // 000011111111_00001_100_00100_0010011 = 32'h0ff0c213
        // ===================================================================
        $display("-- XORI x4,x1,0xff  (32'h0ff0c213) --");
        id_instr = 32'h0ff0c213;
        #1;
        check4("XORI alu_op", id_alu_op, ALU_XOR);
        check32("XORI imm",   id_imm,    32'hFF);

        // ===================================================================
        // SLLI x2, x1, 3
        // imm[11:5]=0000000 shamt=00011 rs1=00001 funct3=001 rd=00010 op=0010011
        // 0000000_00011_00001_001_00010_0010011 = 32'h00309113
        // ===================================================================
        $display("-- SLLI x2,x1,3  (32'h00309113) --");
        id_instr = 32'h00309113;
        #1;
        check4("SLLI alu_op", id_alu_op, ALU_SLL);

        // ===================================================================
        // SRLI x2, x1, 2
        // 0000000_00010_00001_101_00010_0010011 = 32'h0020d113
        // ===================================================================
        $display("-- SRLI x2,x1,2  (32'h0020d113) --");
        id_instr = 32'h0020d113;
        #1;
        check4("SRLI alu_op", id_alu_op, ALU_SRL);

        // ===================================================================
        // SRAI x2, x1, 2
        // 0100000_00010_00001_101_00010_0010011 = 32'h4020d113
        // ===================================================================
        $display("-- SRAI x2,x1,2  (32'h4020d113) --");
        id_instr = 32'h4020d113;
        #1;
        check4("SRAI alu_op", id_alu_op, ALU_SRA);

        // ===================================================================
        // LW x5, 4(x3)
        // imm=000000000100 rs1=00011 funct3=010 rd=00101 op=0000011
        // 000000000100_00011_010_00101_0000011 = 32'h0041a283
        // ===================================================================
        $display("-- LW x5,4(x3)  (32'h0041a283) --");
        id_instr = 32'h0041a283;
        #1;
        check5("LW rs1_addr",     id_rs1_addr,   5'd3);
        check5("LW rd_addr",      id_rd_addr,    5'd5);
        check32("LW imm",         id_imm,        32'd4);
        check4("LW alu_op",       id_alu_op,     ALU_ADD);
        check1("LW alu_src",      id_alu_src,    1'b1);
        check1("LW mem_re",       id_mem_re,     1'b1);
        check1("LW mem_to_reg",   id_mem_to_reg, 1'b1);
        check1("LW reg_we",       id_reg_we,     1'b1);
        check1("LW mem_we",       id_mem_we,     1'b0);

        // ===================================================================
        // LB x1, -1(x2)
        // imm=111111111111 rs1=00010 funct3=000 rd=00001 op=0000011
        // 111111111111_00010_000_00001_0000011 = 32'hfff10083
        // ===================================================================
        $display("-- LB x1,-1(x2)  (32'hfff10083) --");
        id_instr = 32'hfff10083;
        #1;
        check32("LB imm",       id_imm,    32'hFFFF_FFFF);
        check1("LB mem_re",     id_mem_re, 1'b1);

        // ===================================================================
        // SW x7, 8(x4)
        // imm[11:5]=0000000 rs2=00111 rs1=00100 funct3=010 imm[4:0]=01000 op=0100011
        // 0000000_00111_00100_010_01000_0100011 = 32'h00722423
        // ===================================================================
        $display("-- SW x7,8(x4)  (32'h00722423) --");
        id_instr = 32'h00722423;
        #1;
        check5("SW rs1_addr",  id_rs1_addr, 5'd4);
        check5("SW rs2_addr",  id_rs2_addr, 5'd7);
        check32("SW imm",      id_imm,      32'd8);
        check1("SW alu_src",   id_alu_src,  1'b1);
        check1("SW mem_we",    id_mem_we,   1'b1);
        check1("SW reg_we",    id_reg_we,   1'b0);
        check1("SW mem_re",    id_mem_re,   1'b0);

        // ===================================================================
        // BEQ x1, x2, +8
        // offset=8: bit12=0,bits10:5=000000,bits4:1=0100,bit11=0
        // 0_000000_00010_00001_000_0100_0_1100011 = 32'h00208463
        // ===================================================================
        $display("-- BEQ x1,x2,+8  (32'h00208463) --");
        id_instr = 32'h00208463;
        #1;
        check5("BEQ rs1_addr",  id_rs1_addr, 5'd1);
        check5("BEQ rs2_addr",  id_rs2_addr, 5'd2);
        check32("BEQ imm",      id_imm,      32'd8);
        check1("BEQ branch",    id_branch,   1'b1);
        check1("BEQ reg_we",    id_reg_we,   1'b0);
        check1("BEQ mem_we",    id_mem_we,   1'b0);
        check1("BEQ jump",      id_jump,     1'b0);

        // ===================================================================
        // BNE x3, x4, +16
        // offset=16=0x10: bit12=0,bits10:5=000000,bits4:1=1000,bit11=0
        // 0_000000_00100_00011_001_1000_0_1100011 = 32'h00419863
        // ===================================================================
        $display("-- BNE x3,x4,+16  (32'h00419863) --");
        id_instr = 32'h00419863;
        #1;
        check32("BNE imm",   id_imm,   32'd16);
        check1("BNE branch", id_branch, 1'b1);

        // ===================================================================
        // BLT x1, x2, +4
        // offset=4: bits4:1=0010,bit11=0,bits10:5=000000,bit12=0
        // 0_000000_00010_00001_100_0010_0_1100011 = 32'h00204263
        // ===================================================================
        $display("-- BLT x1,x2,+4  (32'h00204263) --");
        id_instr = 32'h00204263;
        #1;
        check32("BLT imm",   id_imm,    32'd4);
        check1("BLT branch", id_branch, 1'b1);

        // ===================================================================
        // JAL x1, +8
        // offset=8: bit20=0,bits10:1=0000000100,bit11=0,bits19:12=00000000
        // 0_00000000_0_0000000100_00001_1101111 = 32'h008000ef
        // ===================================================================
        $display("-- JAL x1,+8  (32'h008000ef) --");
        id_instr = 32'h008000ef;
        #1;
        check5("JAL rd_addr",     id_rd_addr,   5'd1);
        check32("JAL imm",        id_imm,       32'd8);
        check1("JAL jump",        id_jump,      1'b1);
        check1("JAL jalr",        id_jalr,      1'b0);
        check1("JAL pc_to_reg",   id_pc_to_reg, 1'b1);
        check1("JAL reg_we",      id_reg_we,    1'b1);
        check1("JAL branch",      id_branch,    1'b0);

        // ===================================================================
        // JALR x1, x2, 4
        // imm=000000000100 rs1=x2=00010 funct3=000 rd=x1=00001 op=1100111
        // 000000000100_00010_000_00001_1100111 = 32'h004100e7
        // ===================================================================
        $display("-- JALR x1,x2,4  (32'h004100e7) --");
        id_instr = 32'h004100e7;
        #1;
        check5("JALR rs1_addr",   id_rs1_addr,  5'd2);
        check5("JALR rd_addr",    id_rd_addr,   5'd1);
        check32("JALR imm",       id_imm,       32'd4);
        check1("JALR jump",       id_jump,      1'b1);
        check1("JALR jalr",       id_jalr,      1'b1);
        check1("JALR pc_to_reg",  id_pc_to_reg, 1'b1);
        check1("JALR reg_we",     id_reg_we,    1'b1);
        check1("JALR alu_src",    id_alu_src,   1'b1);

        // ===================================================================
        // LUI x1, 0x12345
        // imm[31:12]=0x12345, rd=x1, opcode=0110111
        // 00010010001101000101_00001_0110111 = 32'h123450b7
        // ===================================================================
        $display("-- LUI x1,0x12345  (32'h123450b7) --");
        id_instr = 32'h123450b7;
        #1;
        check5("LUI rd_addr",  id_rd_addr,  5'd1);
        check32("LUI imm",     id_imm,      32'h1234_5000);
        check4("LUI alu_op",   id_alu_op,   ALU_PASS_B);
        check1("LUI alu_src",  id_alu_src,  1'b1);
        check1("LUI reg_we",   id_reg_we,   1'b1);
        check1("LUI mem_we",   id_mem_we,   1'b0);
        check1("LUI branch",   id_branch,   1'b0);
        check1("LUI auipc",    id_auipc,    1'b0);

        // ===================================================================
        // AUIPC x2, 0x10
        // imm[31:12]=0x00010, rd=x2, opcode=0010111
        // 00000000000000010000_00010_0010111 = 32'h00010117
        // ===================================================================
        $display("-- AUIPC x2,0x10  (32'h00010117) --");
        id_instr = 32'h00010117;
        #1;
        check5("AUIPC rd_addr",  id_rd_addr,  5'd2);
        check32("AUIPC imm",     id_imm,      32'h0001_0000);
        check4("AUIPC alu_op",   id_alu_op,   ALU_ADD);
        check1("AUIPC alu_src",  id_alu_src,  1'b1);
        check1("AUIPC reg_we",   id_reg_we,   1'b1);
        check1("AUIPC auipc",    id_auipc,    1'b1);
        check1("AUIPC branch",   id_branch,   1'b0);

        // ===================================================================
        // NOP (ADDI x0, x0, 0) — should not write registers
        // ===================================================================
        $display("-- NOP (32'h00000013) --");
        id_instr = 32'h00000013;
        #1;
        check5("NOP rd_addr",  id_rd_addr, 5'd0);
        check5("NOP rs1_addr", id_rs1_addr, 5'd0);
        check32("NOP imm",     id_imm,      32'd0);
        check1("NOP mem_we",   id_mem_we,   1'b0);
        check1("NOP branch",   id_branch,   1'b0);

        // ===================================================================
        // Unknown opcode — all zeroed
        // Use opcode 7'b0001011 (custom-0, never a valid RV32I opcode)
        // 32'hDEAD000B has opcode bits [6:0] = 0b0001011
        // ===================================================================
        $display("-- Unknown opcode (32'hDEAD000B) --");
        id_instr = 32'hDEAD000B;
        #1;
        check1("Unknown reg_we",  id_reg_we,  1'b0);
        check1("Unknown mem_we",  id_mem_we,  1'b0);
        check1("Unknown branch",  id_branch,  1'b0);
        check1("Unknown jump",    id_jump,    1'b0);

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

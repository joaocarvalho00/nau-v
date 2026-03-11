// tb_prog.sv — Generic program runner for Claude-V
//
// Loads a compiled program into the core's instruction and data memories
// via $readmemh, runs the simulation, and waits for the program to write
// a result to the "tohost" address.
//
// Plusargs (all optional):
//   +TEXT_HEX=<path>       — imem hex file (default: all NOPs)
//   +DATA_HEX=<path>       — dmem hex file (default: none)
//   +TOHOST_ADDR=<hex>     — byte address the program writes result to
//                            (default: 1000 hex = 0x1000)
//   +TIMEOUT=<cycles>      — max clock cycles before declaring timeout
//                            (default: 100000)
//   +DUMP_VCD              — if present, dump waveforms to tb_prog.vcd
//
// Exit convention (program writes a 32-bit word to TOHOST_ADDR):
//   value == 1   → PASS
//   value != 1   → FAIL (value encodes which test failed)
//   timeout      → FAIL

`timescale 1ns/1ps

module tb_prog;

    // -----------------------------------------------------------------------
    // Plusarg strings / scalars (collected in initial block)
    // -----------------------------------------------------------------------
    string       text_hex;
    string       data_hex;
    logic [31:0] tohost_addr;
    int          timeout_cyc;

    // -----------------------------------------------------------------------
    // Clock & reset
    // -----------------------------------------------------------------------
    logic clk;
    logic rst;

    initial clk = 0;
    always  #5 clk = ~clk;   // 100 MHz

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
    logic [31:0] dbg_pc, dbg_instr, dbg_rf_data;
    logic [31:0] dbg_mem_addr, dbg_mem_wdata;
    logic        dbg_mem_we;
    logic [4:0]  dbg_rf_addr;

    core dut (
        .clk           (clk),
        .rst           (rst),
        .imem_init_we  (1'b0),
        .imem_init_addr(32'd0),
        .imem_init_data(32'd0),
        .dbg_pc        (dbg_pc),
        .dbg_instr     (dbg_instr),
        .dbg_rf_addr   (dbg_rf_addr),
        .dbg_rf_data   (dbg_rf_data),
        .dbg_mem_addr  (dbg_mem_addr),
        .dbg_mem_wdata (dbg_mem_wdata),
        .dbg_mem_we    (dbg_mem_we)
    );

    // -----------------------------------------------------------------------
    // Tohost monitor
    // -----------------------------------------------------------------------
    logic        tohost_written;
    logic [31:0] tohost_value;

    always_ff @(posedge clk) begin
        if (rst) begin
            tohost_written <= 1'b0;
            tohost_value   <= 32'd0;
        end else if (dbg_mem_we && (dbg_mem_addr == tohost_addr)) begin
            tohost_written <= 1'b1;
            tohost_value   <= dbg_mem_wdata;
        end
    end

    // -----------------------------------------------------------------------
    // Cycle counter
    // -----------------------------------------------------------------------
    int cycle_count;

    always_ff @(posedge clk) begin
        if (rst) cycle_count <= 0;
        else     cycle_count <= cycle_count + 1;
    end

    // -----------------------------------------------------------------------
    // Main test flow
    // -----------------------------------------------------------------------
    initial begin : main_flow
        // Defaults
        text_hex    = "";
        data_hex    = "";
        tohost_addr = 32'h0000_1000;
        timeout_cyc = 100_000;
        dbg_rf_addr = 5'd0;

        // Collect plusargs
        void'($value$plusargs("TEXT_HEX=%s",    text_hex));
        void'($value$plusargs("DATA_HEX=%s",    data_hex));
        void'($value$plusargs("TOHOST_ADDR=%h", tohost_addr));
        void'($value$plusargs("TIMEOUT=%d",     timeout_cyc));

        // Optional VCD dump
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("tb_prog.vcd");
            $dumpvars(0, tb_prog);
        end

        $display("=== tb_prog ===");
        $display("  TEXT_HEX    : %s", (text_hex == "") ? "(none)" : text_hex);
        $display("  DATA_HEX    : %s", (data_hex == "") ? "(none)" : data_hex);
        $display("  TOHOST_ADDR : 0x%08h", tohost_addr);
        $display("  TIMEOUT     : %0d cycles", timeout_cyc);

        // Assert reset, allow DUT initial blocks to run
        rst = 1'b1;
        @(posedge clk);
        #1;

        // Load memories via hierarchical $readmemh
        if (text_hex != "") begin
            $readmemh(text_hex, dut.u_imem.mem);
            $display("  Loaded imem from %s", text_hex);
        end
        if (data_hex != "") begin
            $readmemh(data_hex, dut.u_dmem.mem);
            $display("  Loaded dmem from %s", data_hex);
        end

        // Hold reset one more cycle, then release
        @(posedge clk);
        rst = 1'b0;
        $display("  Reset released, running...");

        // Wait for tohost write or timeout
        fork
            begin : wait_tohost
                wait (tohost_written);
            end
            begin : watchdog
                repeat (timeout_cyc) @(posedge clk);
            end
        join_any
        disable fork;

        // Report
        $display("");
        if (tohost_written) begin
            if (tohost_value == 32'h1) begin
                $display("  [PASS]  tohost=0x%08h  (%0d cycles)", tohost_value, cycle_count);
                $display("ALL TESTS PASSED");
            end else begin
                $display("  [FAIL]  tohost=0x%08h  (failing test #%0d, %0d cycles)",
                         tohost_value, tohost_value, cycle_count);
                $display("TESTS FAILED");
                $fatal(1);
            end
        end else begin
            $display("  [FAIL]  Timeout after %0d cycles (PC=0x%08h)", cycle_count, dbg_pc);
            $display("TESTS FAILED");
            $fatal(1);
        end

        $finish;
    end

endmodule

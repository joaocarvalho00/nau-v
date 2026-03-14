// NauV — 5-Stage Pipelined RV32I Core
//
// Module name is `core` (identical interface to the single-cycle core.sv)
// so that all testbenches and synthesis scripts work unchanged.  The
// Makefile selects which file to compile: PIPELINE=0 → core.sv,
//                                         PIPELINE=1 → core_pipeline.sv.
//
// Pipeline stages:
//   IF  — fetch instruction from imem, advance PC
//   ID  — decode instruction, read register file
//   EX  — execute ALU operation, resolve branch/jump
//   MEM — data memory access (load/store)
//   WB  — write result back to register file
//
// Hazard handling (hazard_unit.sv):
//   · Load-use stall  : 1 cycle bubble when a LOAD in EX is followed by an
//                       instruction that reads the loaded register.
//   · Branch/jump flush: 2-cycle penalty; IF/ID and ID/EX flushed when EX
//                        resolves a taken branch or jump.
//
// Forwarding (combinational, inside this module):
//   · EX/MEM → EX  : non-load instruction result forwarded to the next ALU op
//   · MEM/WB → EX  : WB data (ALU result or loaded value) forwarded one cycle
//                     later, handling the load result after the stall cycle.

module core (
    input  logic        clk,
    input  logic        rst,

    // Instruction-memory init port (for testbench program loading)
    input  logic        imem_init_we,
    input  logic [31:0] imem_init_addr,
    input  logic [31:0] imem_init_data,

    // Debug outputs
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_instr,
    input  logic [4:0]  dbg_rf_addr,
    output logic [31:0] dbg_rf_data,
    // Memory bus observation (for tohost monitoring in tb_prog)
    output logic [31:0] dbg_mem_addr,
    output logic [31:0] dbg_mem_wdata,
    output logic        dbg_mem_we
);

    // =========================================================================
    // Hazard / forwarding control
    // =========================================================================
    logic        stall;
    logic        flush_if_id;
    logic        flush_id_ex;
    logic [1:0]  fwd_rs1_sel;   // 00=regfile, 01=EX/MEM fwd, 10=MEM/WB fwd
    logic [1:0]  fwd_rs2_sel;

    // =========================================================================
    // IF stage wires
    // =========================================================================
    logic [31:0] if_pc;
    logic [31:0] if_pc_plus4;
    logic [31:0] if_instr;      // raw imem output

    // =========================================================================
    // IF/ID pipeline register
    // =========================================================================
    logic [31:0] if_id_pc;
    logic [31:0] if_id_pc_plus4;
    logic [31:0] if_id_instr;

    // =========================================================================
    // ID stage wires (decoder + regfile)
    // =========================================================================
    logic [4:0]  id_rs1_addr, id_rs2_addr;  // for hazard unit (via id_stage)
    logic [31:0] id_rs1_data, id_rs2_data;
    logic [31:0] id_imm;
    logic [4:0]  id_rd_addr;
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

    // =========================================================================
    // ID/EX pipeline register
    // =========================================================================
    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_pc_plus4;
    logic [31:0] id_ex_rs1_data;
    logic [31:0] id_ex_rs2_data;
    logic [31:0] id_ex_imm;
    logic [4:0]  id_ex_rs1_addr;
    logic [4:0]  id_ex_rs2_addr;
    logic [4:0]  id_ex_rd_addr;
    logic [3:0]  id_ex_alu_op;
    logic        id_ex_alu_src;
    logic        id_ex_mem_we;
    logic [2:0]  id_ex_mem_funct3;
    logic        id_ex_mem_re;
    logic        id_ex_reg_we;
    logic        id_ex_mem_to_reg;
    logic        id_ex_branch;
    logic        id_ex_jump;
    logic        id_ex_jalr;
    logic        id_ex_pc_to_reg;
    logic        id_ex_auipc;

    // =========================================================================
    // EX stage wires
    // =========================================================================
    logic [31:0] ex_fwd_rs1_data;  // forwarded operands into EX
    logic [31:0] ex_fwd_rs2_data;
    logic [31:0] ex_alu_result;
    logic        ex_pc_sel;
    logic [31:0] ex_pc_target;

    // =========================================================================
    // EX/MEM pipeline register
    // =========================================================================
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_rs2_data;   // forwarded rs2 (store data)
    logic [31:0] ex_mem_pc_plus4;
    logic [4:0]  ex_mem_rd_addr;
    logic        ex_mem_mem_we;
    logic [2:0]  ex_mem_mem_funct3;
    logic        ex_mem_mem_re;
    logic        ex_mem_reg_we;
    logic        ex_mem_mem_to_reg;
    logic        ex_mem_pc_to_reg;

    // =========================================================================
    // MEM stage wires
    // =========================================================================
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_byte_en;
    logic        mem_we_out;
    logic [31:0] mem_rdata_raw;
    logic [31:0] mem_rdata;

    // =========================================================================
    // MEM/WB pipeline register
    // =========================================================================
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_mem_rdata;
    logic [31:0] mem_wb_pc_plus4;
    logic [4:0]  mem_wb_rd_addr;
    logic        mem_wb_reg_we;
    logic        mem_wb_mem_to_reg;
    logic        mem_wb_pc_to_reg;

    // =========================================================================
    // WB stage wires
    // =========================================================================
    logic [31:0] wb_rd_data;
    logic [4:0]  wb_rd_addr;
    logic        wb_rd_we;

    // =========================================================================
    // Forwarding data (what each stage will ultimately write to the register file)
    // EX/MEM forward: ALU result, or PC+4 for JAL/JALR (never a load — stall handles that)
    // MEM/WB forward: final WB mux output (correct for loads, ALU ops, JAL/JALR)
    // =========================================================================
    logic [31:0] ex_mem_fwd_data;
    assign ex_mem_fwd_data = ex_mem_pc_to_reg ? ex_mem_pc_plus4 : ex_mem_alu_result;
    // wb_rd_data is the MEM/WB forwarding source (combinational from WB stage)

    // =========================================================================
    // Forwarding muxes — select operands entering the EX stage
    // =========================================================================
    always_comb begin
        case (fwd_rs1_sel)
            2'b01:   ex_fwd_rs1_data = ex_mem_fwd_data;
            2'b10:   ex_fwd_rs1_data = wb_rd_data;
            default: ex_fwd_rs1_data = id_ex_rs1_data;
        endcase
    end

    always_comb begin
        case (fwd_rs2_sel)
            2'b01:   ex_fwd_rs2_data = ex_mem_fwd_data;
            2'b10:   ex_fwd_rs2_data = wb_rd_data;
            default: ex_fwd_rs2_data = id_ex_rs2_data;
        endcase
    end

    // =========================================================================
    // Forwarding unit — combinational select logic
    // EX/MEM forwarding takes priority over MEM/WB (more recent result).
    // EX/MEM forwarding is suppressed for loads (mem_to_reg=1) because the
    // loaded value isn't yet available; the hazard unit stalls in that case.
    // =========================================================================
    always_comb begin
        // rs1 forwarding
        if (ex_mem_reg_we && (ex_mem_rd_addr != 5'b0)
                          && !ex_mem_mem_to_reg
                          && (ex_mem_rd_addr == id_ex_rs1_addr))
            fwd_rs1_sel = 2'b01;
        else if (mem_wb_reg_we && (mem_wb_rd_addr != 5'b0)
                               && (mem_wb_rd_addr == id_ex_rs1_addr))
            fwd_rs1_sel = 2'b10;
        else
            fwd_rs1_sel = 2'b00;

        // rs2 forwarding
        if (ex_mem_reg_we && (ex_mem_rd_addr != 5'b0)
                          && !ex_mem_mem_to_reg
                          && (ex_mem_rd_addr == id_ex_rs2_addr))
            fwd_rs2_sel = 2'b01;
        else if (mem_wb_reg_we && (mem_wb_rd_addr != 5'b0)
                               && (mem_wb_rd_addr == id_ex_rs2_addr))
            fwd_rs2_sel = 2'b10;
        else
            fwd_rs2_sel = 2'b00;
    end

    // =========================================================================
    // IF Stage
    // =========================================================================
    if_stage u_if_stage (
        .clk          (clk),
        .rst          (rst),
        .pc_en        (~stall),       // hold PC on load-use stall
        .pc_sel       (ex_pc_sel),
        .if_pc_target (ex_pc_target),
        .if_pc        (if_pc),
        .if_pc_plus4  (if_pc_plus4)
    );

    imem u_imem (
        .clk       (clk),
        .addr      (if_pc),
        .rdata     (if_instr),
        .init_we   (imem_init_we),
        .init_addr (imem_init_addr),
        .init_data (imem_init_data)
    );

    // =========================================================================
    // IF/ID Pipeline Register
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst || flush_if_id) begin
            if_id_pc       <= 32'h0;
            if_id_pc_plus4 <= 32'h0;
            if_id_instr    <= 32'h0000_0013;  // NOP (ADDI x0,x0,0)
        end else if (!stall) begin
            if_id_pc       <= if_pc;
            if_id_pc_plus4 <= if_pc_plus4;
            if_id_instr    <= if_instr;
        end
        // stall: hold current values (do nothing)
    end

    // =========================================================================
    // ID Stage
    // =========================================================================
    id_stage u_id_stage (
        .clk          (clk),
        .rst          (rst),
        .id_instr     (if_id_instr),
        .id_pc        (if_id_pc),
        // Write-back feed-through
        .wb_rd_addr   (wb_rd_addr),
        .wb_rd_data   (wb_rd_data),
        .wb_rd_we     (wb_rd_we),
        // Decoder outputs
        .id_rs1_data  (id_rs1_data),
        .id_rs2_data  (id_rs2_data),
        .id_imm       (id_imm),
        .id_rd_addr   (id_rd_addr),
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
        .id_auipc     (id_auipc),
        .dbg_addr     (dbg_rf_addr),
        .dbg_data     (dbg_rf_data)
    );

    // =========================================================================
    // Hazard Unit
    // =========================================================================
    hazard_unit u_hazard (
        .if_id_instr   (if_id_instr),
        .id_ex_rd_addr (id_ex_rd_addr),
        .id_ex_mem_re  (id_ex_mem_re),
        .ex_pc_sel     (ex_pc_sel),
        .stall         (stall),
        .flush_if_id   (flush_if_id),
        .flush_id_ex   (flush_id_ex)
    );

    // =========================================================================
    // ID/EX Pipeline Register
    // On stall: insert bubble (zero all control signals) while the dependent
    // instruction waits in IF/ID for the load to complete.
    // On flush: insert bubble to discard the wrong-path instruction.
    //
    // WB→ID bypass (3-cycle-apart hazard):
    //   When WB writes register X in the same cycle that ID reads register X,
    //   the regfile's synchronous write hasn't yet taken effect (its NBA is
    //   still pending at posedge time).  We capture wb_rd_data directly here
    //   so the ID/EX register holds the correct value.
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst || flush_id_ex || stall) begin
            id_ex_pc          <= 32'h0;
            id_ex_pc_plus4    <= 32'h0;
            id_ex_rs1_data    <= 32'h0;
            id_ex_rs2_data    <= 32'h0;
            id_ex_imm         <= 32'h0;
            id_ex_rs1_addr    <= 5'h0;
            id_ex_rs2_addr    <= 5'h0;
            id_ex_rd_addr     <= 5'h0;
            id_ex_alu_op      <= 4'h0;
            id_ex_alu_src     <= 1'b0;
            id_ex_mem_we      <= 1'b0;
            id_ex_mem_funct3  <= 3'h0;
            id_ex_mem_re      <= 1'b0;
            id_ex_reg_we      <= 1'b0;
            id_ex_mem_to_reg  <= 1'b0;
            id_ex_branch      <= 1'b0;
            id_ex_jump        <= 1'b0;
            id_ex_jalr        <= 1'b0;
            id_ex_pc_to_reg   <= 1'b0;
            id_ex_auipc       <= 1'b0;
        end else begin
            id_ex_pc          <= if_id_pc;
            id_ex_pc_plus4    <= if_id_pc_plus4;
            // WB bypass for rs1: if WB is writing the register ID is reading,
            // use WB's result directly (regfile NBA hasn't settled yet).
            if (wb_rd_we && (wb_rd_addr != 5'b0)
                         && (wb_rd_addr == if_id_instr[19:15]))
                id_ex_rs1_data <= wb_rd_data;
            else
                id_ex_rs1_data <= id_rs1_data;
            // WB bypass for rs2
            if (wb_rd_we && (wb_rd_addr != 5'b0)
                         && (wb_rd_addr == if_id_instr[24:20]))
                id_ex_rs2_data <= wb_rd_data;
            else
                id_ex_rs2_data <= id_rs2_data;
            id_ex_imm         <= id_imm;
            id_ex_rs1_addr    <= if_id_instr[19:15];  // raw rs1 field for fwding
            id_ex_rs2_addr    <= if_id_instr[24:20];  // raw rs2 field for fwding
            id_ex_rd_addr     <= id_rd_addr;
            id_ex_alu_op      <= id_alu_op;
            id_ex_alu_src     <= id_alu_src;
            id_ex_mem_we      <= id_mem_we;
            id_ex_mem_funct3  <= id_mem_funct3;
            id_ex_mem_re      <= id_mem_re;
            id_ex_reg_we      <= id_reg_we;
            id_ex_mem_to_reg  <= id_mem_to_reg;
            id_ex_branch      <= id_branch;
            id_ex_jump        <= id_jump;
            id_ex_jalr        <= id_jalr;
            id_ex_pc_to_reg   <= id_pc_to_reg;
            id_ex_auipc       <= id_auipc;
        end
    end

    // =========================================================================
    // EX Stage
    // =========================================================================
    ex_stage u_ex_stage (
        .ex_pc         (id_ex_pc),
        .ex_rs1_data   (ex_fwd_rs1_data),
        .ex_rs2_data   (ex_fwd_rs2_data),
        .ex_imm        (id_ex_imm),
        .ex_alu_op     (id_ex_alu_op),
        .ex_alu_src    (id_ex_alu_src),
        .ex_branch     (id_ex_branch),
        .ex_jump       (id_ex_jump),
        .ex_jalr       (id_ex_jalr),
        .ex_auipc      (id_ex_auipc),
        .ex_funct3     (id_ex_mem_funct3),
        .ex_alu_result (ex_alu_result),
        .ex_pc_sel     (ex_pc_sel),
        .ex_pc_target  (ex_pc_target)
    );

    // =========================================================================
    // EX/MEM Pipeline Register
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            ex_mem_alu_result  <= 32'h0;
            ex_mem_rs2_data    <= 32'h0;
            ex_mem_pc_plus4    <= 32'h0;
            ex_mem_rd_addr     <= 5'h0;
            ex_mem_mem_we      <= 1'b0;
            ex_mem_mem_funct3  <= 3'h0;
            ex_mem_mem_re      <= 1'b0;
            ex_mem_reg_we      <= 1'b0;
            ex_mem_mem_to_reg  <= 1'b0;
            ex_mem_pc_to_reg   <= 1'b0;
        end else begin
            ex_mem_alu_result  <= ex_alu_result;
            ex_mem_rs2_data    <= ex_fwd_rs2_data;  // forwarded store data
            ex_mem_pc_plus4    <= id_ex_pc_plus4;
            ex_mem_rd_addr     <= id_ex_rd_addr;
            ex_mem_mem_we      <= id_ex_mem_we;
            ex_mem_mem_funct3  <= id_ex_mem_funct3;
            ex_mem_mem_re      <= id_ex_mem_re;
            ex_mem_reg_we      <= id_ex_reg_we;
            ex_mem_mem_to_reg  <= id_ex_mem_to_reg;
            ex_mem_pc_to_reg   <= id_ex_pc_to_reg;
        end
    end

    // =========================================================================
    // MEM Stage (combinational)
    // =========================================================================
    mem_stage u_mem_stage (
        .mem_alu_result (ex_mem_alu_result),
        .mem_rs2_data   (ex_mem_rs2_data),
        .mem_we         (ex_mem_mem_we),
        .mem_re         (ex_mem_mem_re),
        .mem_funct3     (ex_mem_mem_funct3),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        .mem_byte_en    (mem_byte_en),
        .mem_we_out     (mem_we_out),
        .mem_rdata_raw  (mem_rdata_raw),
        .mem_rdata      (mem_rdata)
    );

    dmem u_dmem (
        .clk     (clk),
        .addr    (mem_addr),
        .wdata   (mem_wdata),
        .byte_en (mem_byte_en),
        .we      (mem_we_out),
        .rdata   (mem_rdata_raw)
    );

    // =========================================================================
    // MEM/WB Pipeline Register
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            mem_wb_alu_result  <= 32'h0;
            mem_wb_mem_rdata   <= 32'h0;
            mem_wb_pc_plus4    <= 32'h0;
            mem_wb_rd_addr     <= 5'h0;
            mem_wb_reg_we      <= 1'b0;
            mem_wb_mem_to_reg  <= 1'b0;
            mem_wb_pc_to_reg   <= 1'b0;
        end else begin
            mem_wb_alu_result  <= ex_mem_alu_result;
            mem_wb_mem_rdata   <= mem_rdata;
            mem_wb_pc_plus4    <= ex_mem_pc_plus4;
            mem_wb_rd_addr     <= ex_mem_rd_addr;
            mem_wb_reg_we      <= ex_mem_reg_we;
            mem_wb_mem_to_reg  <= ex_mem_mem_to_reg;
            mem_wb_pc_to_reg   <= ex_mem_pc_to_reg;
        end
    end

    // =========================================================================
    // WB Stage
    // =========================================================================
    wb_stage u_wb_stage (
        .wb_alu_result  (mem_wb_alu_result),
        .wb_mem_rdata   (mem_wb_mem_rdata),
        .wb_pc_plus4    (mem_wb_pc_plus4),
        .wb_mem_to_reg  (mem_wb_mem_to_reg),
        .wb_pc_to_reg   (mem_wb_pc_to_reg),
        .wb_reg_we      (mem_wb_reg_we),
        .wb_rd_addr_in  (mem_wb_rd_addr),
        .wb_rd_data     (wb_rd_data),
        .wb_rd_addr     (wb_rd_addr),
        .wb_rd_we       (wb_rd_we)
    );

    // =========================================================================
    // Debug outputs
    // dbg_pc / dbg_instr reflect the IF stage (what's being fetched now).
    // dbg_mem_* reflect the actual memory-write bus (MEM stage), enabling
    // tohost detection in tb_prog regardless of pipeline depth.
    // =========================================================================
    always_comb begin
        dbg_pc        = if_pc;
        dbg_instr     = if_instr;
        dbg_mem_addr  = mem_addr;
        dbg_mem_wdata = mem_wdata;
        dbg_mem_we    = mem_we_out;
    end

    // =========================================================================
    // Pipeline latency assertion (simulation only — excluded from synthesis)
    //
    // Each real (non-bubble) instruction is tagged with the clock cycle at
    // which it was first captured in the IF/ID register.  The tag travels
    // through shadow registers that mirror the main pipeline registers.
    // When an instruction is about to enter MEM/WB the elapsed cycles are
    // checked against MAX_PIPELINE_CYCLES.
    //
    // Latency budget (from IF/ID capture to MEM/WB capture):
    //   · Normal execution   : 3 register crossings   (5 pipeline stages total)
    //   · Load-use stall     : 4 register crossings   (6 stages total — 1 extra
    //                          cycle held in IF/ID while a bubble enters ID/EX)
    //
    // MAX_PIPELINE_CYCLES = 4 is the tight upper bound: any instruction that
    // takes more than 4 crossings has been stalled more than once, which
    // indicates a bug in the hazard unit (no other stall source exists).
    // =========================================================================
    `ifndef SYNTHESIS

    localparam int MAX_PIPELINE_CYCLES = 4;

    // Free-running clock counter (32-bit wraps after ~4 billion cycles, fine)
    int unsigned _pipe_cycle;
    always_ff @(posedge clk) begin
        if (rst) _pipe_cycle <= 0;
        else     _pipe_cycle <= _pipe_cycle + 1;
    end

    // Shadow valid flags and birth timestamps for each pipeline register.
    // Prefixed with _ to avoid confusion with the main pipeline signals.
    logic        _if_id_sv;  int unsigned _if_id_sb;   // IF/ID shadow
    logic        _id_ex_sv;  int unsigned _id_ex_sb;   // ID/EX shadow
    logic        _ex_mem_sv; int unsigned _ex_mem_sb;  // EX/MEM shadow

    always_ff @(posedge clk) begin
        // -----------------------------------------------------------------
        // IF/ID shadow
        //   rst / flush  → mark as bubble (valid = 0)
        //   stall        → hold (instruction waits; valid and birth unchanged)
        //   normal       → tag real instruction with current cycle number
        // -----------------------------------------------------------------
        if (rst || flush_if_id) begin
            _if_id_sv <= 1'b0;
            _if_id_sb <= '0;
        end else if (!stall) begin
            _if_id_sv <= 1'b1;
            _if_id_sb <= _pipe_cycle;
        end
        // else stall: hold — non-blocking assignments to nothing = keep values

        // -----------------------------------------------------------------
        // ID/EX shadow
        //   rst / flush / stall → bubble (stall inserts NOP into ID/EX)
        //   normal              → propagate from IF/ID shadow
        // -----------------------------------------------------------------
        if (rst || flush_id_ex || stall) begin
            _id_ex_sv <= 1'b0;
            _id_ex_sb <= '0;
        end else begin
            _id_ex_sv <= _if_id_sv;
            _id_ex_sb <= _if_id_sb;
        end

        // -----------------------------------------------------------------
        // EX/MEM shadow — EX/MEM is never individually flushed; only rst clears it
        // -----------------------------------------------------------------
        if (rst) begin
            _ex_mem_sv <= 1'b0;
            _ex_mem_sb <= '0;
        end else begin
            _ex_mem_sv <= _id_ex_sv;
            _ex_mem_sb <= _id_ex_sb;
        end

        // -----------------------------------------------------------------
        // Latency check — fires at the posedge when MEM/WB captures.
        // Reads old (pre-posedge) values of _ex_mem_sv/_ex_mem_sb and
        // _pipe_cycle, so the elapsed count is exact.
        // -----------------------------------------------------------------
        if (!rst && _ex_mem_sv) begin
            assert (_pipe_cycle - _ex_mem_sb <= MAX_PIPELINE_CYCLES)
                else $error("[PIPELINE ASSERT] Instruction exceeded max latency: born=%0d now=%0d elapsed=%0d max=%0d",
                            _ex_mem_sb, _pipe_cycle, _pipe_cycle - _ex_mem_sb, MAX_PIPELINE_CYCLES);
        end
    end

    `endif // SYNTHESIS

endmodule

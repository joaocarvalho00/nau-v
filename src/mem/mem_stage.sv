// MEM Stage — Memory Access
// Computes byte-enable signals and data alignment for stores, and performs
// sign/zero extension for loads.  This module is purely combinational; the
// actual SRAM (dmem) is instantiated in core.sv and its outputs are fed back
// here as mem_rdata_raw.

module mem_stage (
    input  logic [31:0] mem_alu_result,  // effective address from EX
    input  logic [31:0] mem_rs2_data,    // data to write (stores)
    input  logic        mem_we,          // store enable
    input  logic        mem_re,          // load enable
    input  logic [2:0]  mem_funct3,      // encodes width and sign-extension

    // To dmem
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_byte_en,
    output logic        mem_we_out,

    // From dmem (raw 32-bit word) and processed load result
    input  logic [31:0] mem_rdata_raw,
    output logic [31:0] mem_rdata
);

    // -----------------------------------------------------------------------
    // Address pass-through (word-aligned in hardware; alignment exceptions
    // are not implemented in this single-cycle version)
    // -----------------------------------------------------------------------
    always_comb begin
        mem_addr   = mem_alu_result;
        mem_we_out = mem_we;
    end

    // -----------------------------------------------------------------------
    // Store data and byte-enable generation
    //   SB (3'b000): replicate byte into all lanes; select lane via addr[1:0]
    //   SH (3'b001): replicate halfword into upper/lower half; addr[1] selects
    //   SW (3'b010): full 32-bit word
    // -----------------------------------------------------------------------
    always_comb begin
        // Defaults prevent latches
        mem_wdata   = 32'h0;
        mem_byte_en = 4'b0000;

        case (mem_funct3)
            3'b000: begin // SB
                mem_byte_en = 4'b0001 << mem_alu_result[1:0];
                mem_wdata   = {4{mem_rs2_data[7:0]}};
            end
            3'b001: begin // SH
                mem_byte_en = mem_alu_result[1] ? 4'b1100 : 4'b0011;
                mem_wdata   = {2{mem_rs2_data[15:0]}};
            end
            3'b010: begin // SW
                mem_byte_en = 4'b1111;
                mem_wdata   = mem_rs2_data;
            end
            default: begin
                mem_byte_en = 4'b0000;
                mem_wdata   = 32'h0;
            end
        endcase
    end

    // -----------------------------------------------------------------------
    // Load data extraction and sign/zero extension
    //   LB  (3'b000): byte at addr[1:0], sign-extend
    //   LH  (3'b001): halfword at addr[1], sign-extend
    //   LW  (3'b010): full word
    //   LBU (3'b100): byte at addr[1:0], zero-extend
    //   LHU (3'b101): halfword at addr[1], zero-extend
    // -----------------------------------------------------------------------
    logic [7:0]  load_byte;
    logic [15:0] load_half;

    always_comb begin
        // Extract the correct byte lane
        case (mem_alu_result[1:0])
            2'b00: load_byte = mem_rdata_raw[7:0];
            2'b01: load_byte = mem_rdata_raw[15:8];
            2'b10: load_byte = mem_rdata_raw[23:16];
            2'b11: load_byte = mem_rdata_raw[31:24];
            default: load_byte = 8'h0;
        endcase

        // Extract the correct halfword lane
        load_half = mem_alu_result[1] ? mem_rdata_raw[31:16] : mem_rdata_raw[15:0];
    end

    always_comb begin
        // Default — prevents latch; mem_re=0 means this value is ignored
        mem_rdata = 32'h0;

        if (mem_re) begin
            case (mem_funct3)
                3'b000: mem_rdata = {{24{load_byte[7]}},  load_byte};      // LB
                3'b001: mem_rdata = {{16{load_half[15]}}, load_half};      // LH
                3'b010: mem_rdata = mem_rdata_raw;                         // LW
                3'b100: mem_rdata = {24'h0, load_byte};                    // LBU
                3'b101: mem_rdata = {16'h0, load_half};                    // LHU
                default: mem_rdata = mem_rdata_raw;
            endcase
        end
    end

endmodule

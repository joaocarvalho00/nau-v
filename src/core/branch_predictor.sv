// branch_predictor.sv — 64-entry direct-mapped BTB with 2-bit saturating counters.
//
// Prediction is fully combinational (read in IF stage each cycle).
// Update is synchronous on posedge clk (driven from EX stage when a
// branch/jump resolves).
//
// Entry layout per slot:
//   valid  : 1  — slot has been populated
//   tag    : TAG_BITS — upper PC bits for aliasing check
//   target : 32  — predicted branch target address
//   cnt    : 2   — saturating counter (00=SN, 01=WN, 10=WT, 11=ST)
//
// Prediction: taken when valid && tag-match && cnt[1]==1

module branch_predictor #(
    parameter int ENTRIES = 64   // must be a power of 2
) (
    input  logic        clk,
    input  logic        rst,

    // ----- Prediction port — combinational (used in IF stage) -----
    input  logic [31:0] bp_fetch_pc,     // PC of instruction being fetched
    output logic        bp_pred_taken,   // 1 = predict taken, redirect PC now
    output logic [31:0] bp_pred_target,  // predicted target address

    // ----- Update port — synchronous (driven from EX stage) -----
    input  logic        bp_update_en,     // 1 = a branch/jump resolved this cycle
    input  logic [31:0] bp_update_pc,     // PC of the resolved branch
    input  logic        bp_update_taken,  // 1 = branch was actually taken
    input  logic [31:0] bp_update_target  // actual branch target address
);

    localparam int IDX_BITS = $clog2(ENTRIES);      // 6 for 64 entries
    localparam int TAG_BITS = 32 - IDX_BITS - 2;    // 24 for 64-entry, 4-byte aligned

    // ---- BTB storage ----
    logic              btb_valid  [ENTRIES];
    logic [TAG_BITS-1:0] btb_tag  [ENTRIES];
    logic [31:0]       btb_target [ENTRIES];
    logic [1:0]        btb_cnt    [ENTRIES];   // 2-bit saturating counter

    // ---- Prediction (combinational) ----
    logic [IDX_BITS-1:0] fetch_idx;
    logic [TAG_BITS-1:0] fetch_tag;

    assign fetch_idx = bp_fetch_pc[IDX_BITS+1 : 2];
    assign fetch_tag = bp_fetch_pc[31 : IDX_BITS+2];

    always_comb begin
        if (btb_valid[fetch_idx]
                && btb_tag[fetch_idx] == fetch_tag
                && btb_cnt[fetch_idx][1]) begin   // cnt >= 2 → predict taken
            bp_pred_taken  = 1'b1;
            bp_pred_target = btb_target[fetch_idx];
        end else begin
            bp_pred_taken  = 1'b0;
            bp_pred_target = 32'h0;
        end
    end

    // ---- Update (synchronous) ----
    logic [IDX_BITS-1:0] upd_idx;
    logic [TAG_BITS-1:0] upd_tag;
    logic [1:0]          new_cnt;

    assign upd_idx = bp_update_pc[IDX_BITS+1 : 2];
    assign upd_tag = bp_update_pc[31 : IDX_BITS+2];

    // Saturating counter update: increment on taken, decrement on not-taken
    always_comb begin
        case (btb_cnt[upd_idx])
            2'b00: new_cnt = bp_update_taken ? 2'b01 : 2'b00;
            2'b01: new_cnt = bp_update_taken ? 2'b10 : 2'b00;
            2'b10: new_cnt = bp_update_taken ? 2'b11 : 2'b01;
            2'b11: new_cnt = bp_update_taken ? 2'b11 : 2'b10;
            default: new_cnt = 2'b01;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < ENTRIES; i++) begin
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= '0;
                btb_target[i] <= 32'h0;
                btb_cnt[i]    <= 2'b00;   // start strongly not-taken
            end
        end else if (bp_update_en) begin
            btb_valid[upd_idx]  <= 1'b1;
            btb_tag[upd_idx]    <= upd_tag;
            btb_target[upd_idx] <= bp_update_target;
            btb_cnt[upd_idx]    <= new_cnt;
        end
    end

endmodule

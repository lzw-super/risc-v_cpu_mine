// ==============================
// ID0/ID1 decode register
// ==============================
// ID0 completes instruction decode. ID1 uses the registered decode fields to
// read the regfile and feed ID/EX, cutting instr->decoder->regfile timing.

module id_decode_reg (
    input           clk,
    input           reset,
    input           stall,
    input           flush,

    input           re1_in,
    input           re2_in,
    input           we_in,
    input           imme_in,
    input           pce_in,
    input           jmpe_in,
    input           be_in,
    input  [2:0]    bop_in,
    input  [7:0]    alu_op_in,
    input  [2:0]    dmop_in,
    input           mwe_in,
    input           mem_read_in,
    input  [1:0]    wb_sel_in,

    input           predict_taken_in,
    input  [31:0]   predict_target_in,
    input           btb_hit_in,
    input           is_branch_in,
    input           is_jump_in,

    input  [31:0]   pc_in,
    input  [31:0]   pc_next_in,
    input  [31:0]   imm_in,
    input  [4:0]    rs1_addr_in,
    input  [4:0]    rs2_addr_in,
    input  [4:0]    rd_addr_in,
    input  [31:0]   instr_in,

    output reg          re1_out,
    output reg          re2_out,
    output reg          we_out,
    output reg          imme_out,
    output reg          pce_out,
    output reg          jmpe_out,
    output reg          be_out,
    output reg [2:0]    bop_out,
    output reg [7:0]    alu_op_out,
    output reg [2:0]    dmop_out,
    output reg          mwe_out,
    output reg          mem_read_out,
    output reg [1:0]    wb_sel_out,

    output reg          predict_taken_out,
    output reg [31:0]   predict_target_out,
    output reg          btb_hit_out,
    output reg          is_branch_out,
    output reg          is_jump_out,

    output reg [31:0]   pc_out,
    output reg [31:0]   pc_next_out,
    output reg [31:0]   imm_out,
    output reg [4:0]    rs1_addr_out,
    output reg [4:0]    rs2_addr_out,
    output reg [4:0]    rd_addr_out,
    output reg [31:0]   instr_out
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            re1_out <= 1'b0;
            re2_out <= 1'b0;
            we_out <= 1'b0;
            imme_out <= 1'b0;
            pce_out <= 1'b0;
            jmpe_out <= 1'b0;
            be_out <= 1'b0;
            bop_out <= 3'b0;
            alu_op_out <= 8'b0;
            dmop_out <= 3'b0;
            mwe_out <= 1'b0;
            mem_read_out <= 1'b0;
            wb_sel_out <= 2'b0;
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'h0;
            btb_hit_out <= 1'b0;
            is_branch_out <= 1'b0;
            is_jump_out <= 1'b0;
            pc_out <= 32'h0;
            pc_next_out <= 32'h0;
            imm_out <= 32'h0;
            rs1_addr_out <= 5'h0;
            rs2_addr_out <= 5'h0;
            rd_addr_out <= 5'h0;
            instr_out <= 32'h00000013;
        end
        else if (flush) begin
            re1_out <= 1'b0;
            re2_out <= 1'b0;
            we_out <= 1'b0;
            imme_out <= 1'b0;
            pce_out <= 1'b0;
            jmpe_out <= 1'b0;
            be_out <= 1'b0;
            bop_out <= 3'b0;
            alu_op_out <= 8'b0;
            dmop_out <= 3'b0;
            mwe_out <= 1'b0;
            mem_read_out <= 1'b0;
            wb_sel_out <= 2'b0;
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'h0;
            btb_hit_out <= 1'b0;
            is_branch_out <= 1'b0;
            is_jump_out <= 1'b0;
            pc_out <= 32'h0;
            pc_next_out <= 32'h0;
            imm_out <= 32'h0;
            rs1_addr_out <= 5'h0;
            rs2_addr_out <= 5'h0;
            rd_addr_out <= 5'h0;
            instr_out <= 32'h00000013;
        end
        else if (!stall) begin
            re1_out <= re1_in;
            re2_out <= re2_in;
            we_out <= we_in;
            imme_out <= imme_in;
            pce_out <= pce_in;
            jmpe_out <= jmpe_in;
            be_out <= be_in;
            bop_out <= bop_in;
            alu_op_out <= alu_op_in;
            dmop_out <= dmop_in;
            mwe_out <= mwe_in;
            mem_read_out <= mem_read_in;
            wb_sel_out <= wb_sel_in;
            predict_taken_out <= predict_taken_in;
            predict_target_out <= predict_target_in;
            btb_hit_out <= btb_hit_in;
            is_branch_out <= is_branch_in;
            is_jump_out <= is_jump_in;
            pc_out <= pc_in;
            pc_next_out <= pc_next_in;
            imm_out <= imm_in;
            rs1_addr_out <= rs1_addr_in;
            rs2_addr_out <= rs2_addr_in;
            rd_addr_out <= rd_addr_in;
            instr_out <= instr_in;
        end
    end

endmodule

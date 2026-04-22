// ==============================
// IF/ID 流水线寄存器
// ==============================

module if_id_reg (
    input           clk,
    input           reset,
    input           stall,      // 暂停信号，阻止更新
    input           flush,      // 清空信号（分支预测错误）

    input  [31:0]   pc_in,      // 来自IF阶段的PC
    input  [31:0]   instr_in,   // 来自IF阶段的指令

    // 分支预测信号（新增）
    input           predict_taken_in,  // 预测跳转
    input  [31:0]   predict_target_in, // 预测目标地址
    input           btb_hit_in,        // BTB命中

    output reg [31:0]   pc_out,     // 传递到ID阶段的PC
    output reg [31:0]   instr_out,  // 传递到ID阶段的指令

    // 分支预测信号输出（新增）
    output reg          predict_taken_out,
    output reg [31:0]   predict_target_out,
    output reg          btb_hit_out
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out            <= 32'h0;
            instr_out         <= 32'h0;
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'h0;
            btb_hit_out       <= 1'b0;
        end
        else if (flush) begin
            // 清空流水线，插入NOP (addi x0, x0, 0)
            pc_out            <= 32'h0;
            instr_out         <= 32'h00000013;  // NOP
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'h0;
            btb_hit_out       <= 1'b0;
        end
        else if (!stall) begin
            pc_out            <= pc_in;
            instr_out         <= instr_in;
            predict_taken_out <= predict_taken_in;
            predict_target_out <= predict_target_in;
            btb_hit_out       <= btb_hit_in;
        end
        // stall时保持原值不变
    end

endmodule
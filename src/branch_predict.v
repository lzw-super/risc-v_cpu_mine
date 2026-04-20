// ==============================
// 分支预测单元 - 静态预测
// ==============================
// 简单静态预测：向后跳预测跳转，向前跳预测不跳转

module branch_predict (
    input  [31:0]   pc,         // 当前PC
    input  [31:0]   imm,        // 分支偏移量（已符号扩展）
    input           is_branch,  // 是否是分支指令

    output reg      predict_taken,   // 预测是否跳转
    output reg [31:0] predict_target // 预测目标地址
);

    always @(*) begin
        if (is_branch) begin
            // 静态预测策略：
            // 向后跳（目标地址 < 当前PC）预测跳转（通常是循环）
            // 向前跳预测不跳转
            predict_target = pc + imm;
            predict_taken  = (predict_target < pc);  // 向后跳预测跳
        end
        else begin
            predict_taken  = 1'b0;
            predict_target = pc + 4;
        end
    end

endmodule
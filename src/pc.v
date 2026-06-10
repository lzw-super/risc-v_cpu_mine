// ==============================
// PC模块 - 支持Stall、预测跳转和重定向
// ==============================
// 优先级：
//   1. redirect_en（实际跳转） - 最高优先级
//   2. predicted_valid（动态预测） - 中等优先级
//   3. 顺序执行（PC+4） - 默认

module pc #(
    parameter REGISTER_NEXT_PC = 1
)(
    input           clk,
    input           reset,
    input           stall,
    input  [31:0]   predicted_pc,       // 预测的下一个PC
    input           predicted_valid,    // 预测是否有效
    input  [31:0]   redirect_pc,        // 重定向地址（实际跳转）
    input           redirect_en,        // 重定向使能

    output reg [31:0] curr_pc,
    output [31:0] next_pc
);

    // 下一个PC计算
    wire [31:0] seq_next_pc = curr_pc + 32'h4;

    generate
        if (REGISTER_NEXT_PC) begin : gen_registered_next_pc
            reg [31:0] next_pc_reg;
            assign next_pc = next_pc_reg;

            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    curr_pc <= 32'h0;
                    next_pc_reg <= 32'h4;
                end
                else if (stall) begin
                    curr_pc <= curr_pc;
                    next_pc_reg <= next_pc_reg;
                end
                else if (redirect_en) begin
                    curr_pc <= redirect_pc;
                    next_pc_reg <= redirect_pc + 32'h4;
                end
                else if (predicted_valid) begin
                    curr_pc <= predicted_pc;
                    next_pc_reg <= predicted_pc + 32'h4;
                end
                else begin
                    curr_pc <= seq_next_pc;
                    next_pc_reg <= seq_next_pc + 32'h4;
                end
            end
        end
        else begin : gen_no_next_pc_reg
            assign next_pc = 32'h0;

            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    curr_pc <= 32'h0;
                end
                else if (stall) begin
                    curr_pc <= curr_pc;
                end
                else if (redirect_en) begin
                    curr_pc <= redirect_pc;
                end
                else if (predicted_valid) begin
                    curr_pc <= predicted_pc;
                end
                else begin
                    curr_pc <= seq_next_pc;
                end
            end
        end
    endgenerate

endmodule

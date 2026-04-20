// ==============================
// 2-bit 动态分支历史表 (BHT)
// ==============================
// 状态机：00=强不跳, 01=弱不跳, 10=弱跳, 11=强跳

module bht #(
    parameter BHT_SIZE = 32  // BHT表大小
)(
    input           clk,
    input           reset,

    // 预测请求（IF阶段）
    input  [31:0]   pc,
    input           is_branch,
    output          predict_taken,

    // 更新请求（MEM阶段，分支结果确定后）
    input           update_enable,
    input  [31:0]   update_pc,
    input           actual_taken  // 实际分支结果
);

    // BHT存储：每个entry 2-bit
    reg [1:0] bht_table [BHT_SIZE-1:0];

    // 预测逻辑
    wire [BHT_SIZE-1:0] predict_index = pc[$clog2(BHT_SIZE)-1:0];
    wire [1:0] predict_state = bht_table[predict_index];
    // 状态 >= 10 预测跳转
    assign predict_taken = predict_state[1];

    // 更新逻辑
    wire [BHT_SIZE-1:0] update_index = update_pc[$clog2(BHT_SIZE)-1:0];

    always @(posedge clk) begin
        if (reset) begin
            // 初始化为弱不跳（01），偏向不跳转但易于改变
            for (integer i = 0; i < BHT_SIZE; i = i + 1) begin
                bht_table[i] <= 2'b01;
            end
        end
        else if (update_enable) begin
            // 根据实际结果更新状态
            case (bht_table[update_index])
                2'b00: // 强不跳
                    bht_table[update_index] <= actual_taken ? 2'b01 : 2'b00;
                2'b01: // 弱不跳
                    bht_table[update_index] <= actual_taken ? 2'b10 : 2'b00;
                2'b10: // 弱跳
                    bht_table[update_index] <= actual_taken ? 2'b11 : 2'b01;
                2'b11: // 强跳
                    bht_table[update_index] <= actual_taken ? 2'b11 : 2'b10;
                default:
                    bht_table[update_index] <= 2'b01;
            endcase
        end
    end

endmodule
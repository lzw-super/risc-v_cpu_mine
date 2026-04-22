// ==============================
// 分支历史表 (Branch History Table, BHT)
// ==============================
// 使用2位饱和计数器预测分支行为
// 状态机：00=强不跳, 01=弱不跳, 10=弱跳, 11=强跳
// 预测规则：最高位=1预测跳转，最高位=0预测不跳转

module bht #(
    parameter BHT_ENTRIES    = 256,      // BHT表大小
    parameter BHT_INDEX_BITS = 8         // 索引位数：log2(256) = 8
)(
    input           clk,
    input           reset,

    // IF阶段查询（取指）
    input  [31:0]   fetch_pc,
    output          predict_taken,       // 预测是否跳转

    // EX阶段更新（分支执行后）
    input           update_enable,       // 更新使能（是分支指令）
    input  [31:0]   branch_pc,           // 分支指令的PC
    input           actual_taken         // 实际分支结果
);

    // BHT存储：每个entry 2-bit计数器
    reg [1:0] bht_table [0:BHT_ENTRIES-1];

    // 索引计算（与BTB一致）
    wire [BHT_INDEX_BITS-1:0] fetch_index = fetch_pc[BHT_INDEX_BITS+1:2];
    wire [BHT_INDEX_BITS-1:0] update_index = branch_pc[BHT_INDEX_BITS+1:2];

    // 预测逻辑：最高位决定预测
    // 1x（10或11）→ 预测跳转
    // 0x（00或01）→ 预测不跳转
    assign predict_taken = bht_table[fetch_index][1];

    // 更新逻辑
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // 复位时初始化为"弱不跳"（01）
            // 保守初始状态，假设分支大概率不跳转
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht_table[i] <= 2'b01;
            end
        end
        else if (update_enable) begin
            // 根据实际结果更新计数器
            if (actual_taken) begin
                // 实际跳转：计数器递增（饱和在11）
                if (bht_table[update_index] != 2'b11)
                    bht_table[update_index] <= bht_table[update_index] + 1;
            end
            else begin
                // 实际不跳转：计数器递减（饱和在00）
                if (bht_table[update_index] != 2'b00)
                    bht_table[update_index] <= bht_table[update_index] - 1;
            end
        end
    end

endmodule
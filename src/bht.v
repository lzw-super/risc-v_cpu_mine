// ==============================
// 分支历史表 (Branch History Table, BHT)
// ==============================
// 使用2位饱和计数器预测分支行为
// 状态机：00=强不跳, 01=弱不跳, 10=弱跳, 11=强跳
// 预测规则：最高位=1预测跳转，最高位=0预测不跳转
//
// 跳转指令(JAL/JALR)总是跳转，不需要方向预测，
// 但BHT仍会更新状态以保持一致性

module bht #(
    parameter BHT_ENTRIES    = 256,      // BHT表大小
    parameter BHT_INDEX_BITS = 8         // 索引位数：log2(256) = 8
)(
    input           clk,
    input           reset,

    // IF阶段查询（取指）
    input  [31:0]   fetch_pc,
    output          predict_taken,       // 预测是否跳转

    // EX阶段更新（分支/跳转执行后）
    input           update_enable,       // 更新使能（是分支或跳转指令）
    input           is_jump,             // 是否是跳转指令 (JAL/JALR)
    input  [31:0]   branch_pc,           // 分支/跳转指令的PC
    input           actual_taken         // 实际分支/跳转结果
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
            // 注意：跳转指令首次执行时会立即更新为强跳转
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht_table[i] <= 2'b01;
            end
        end
        else if (update_enable) begin
            if (is_jump) begin
                // 跳转指令总是跳转，直接设置为"强跳转"(11)
                // 这确保后续预测正确
                bht_table[update_index] <= 2'b11;
            end
            else if (actual_taken) begin
                // 分支指令实际跳转：计数器递增（饱和在11）
                if (bht_table[update_index] != 2'b11)
                    bht_table[update_index] <= bht_table[update_index] + 1;
            end
            else begin
                // 分支指令实际不跳转：计数器递减（饱和在00）
                if (bht_table[update_index] != 2'b00)
                    bht_table[update_index] <= bht_table[update_index] - 1;
            end
        end
    end

endmodule
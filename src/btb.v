// ==============================
// 分支目标缓冲 (Branch Target Buffer, BTB)
// ==============================
// BTB缓存分支指令的目标地址，加速分支预测
// 与BHT配合使用：
//   - BHT：预测是否跳转
//   - BTB：预测跳转到哪里
//
// 结构：
//   - 256条目，每个条目包含：valid位、tag(12位)、target地址(32位)
//   - 索引：PC[9:2]（跳过低2位字节对齐）
//   - 标签：用于区分同索引的不同分支指令

module btb #(
    parameter BTB_ENTRIES    = 256,      // BTB表大小
    parameter BTB_INDEX_BITS = 8,        // 索引位数：log2(256) = 8
    parameter TAG_BITS       = 12        // 标签位数
)(
    input           clk,
    input           reset,

    // IF阶段查询（取指）
    input  [31:0]   fetch_pc,
    output          btb_hit,
    output [31:0]   predicted_target,

    // EX阶段更新（分支执行后）
    input           update_enable,       // 更新使能（是分支指令）
    input  [31:0]   branch_pc,           // 分支指令的PC
    input  [31:0]   actual_target,       // 实际分支目标地址
    input           branch_taken         // 实际是否跳转
);

    // BTB存储结构
    reg valid [0:BTB_ENTRIES-1];                     // 有效位数组
    reg [TAG_BITS-1:0] tag_array [0:BTB_ENTRIES-1];  // 标签数组
    reg [31:0] target_array [0:BTB_ENTRIES-1];       // 目标地址数组

    // 索引和标签计算
    wire [BTB_INDEX_BITS-1:0] fetch_index;
    wire [TAG_BITS-1:0] fetch_tag;
    wire [BTB_INDEX_BITS-1:0] update_index;
    wire [TAG_BITS-1:0] update_tag;

    // 取指索引：PC[9:2]（跳过低2位字节对齐）
    assign fetch_index  = fetch_pc[BTB_INDEX_BITS+1:2];
    // 取指标签：PC高位（用于区分同索引的不同分支）
    assign fetch_tag    = fetch_pc[BTB_INDEX_BITS+TAG_BITS+1:BTB_INDEX_BITS+2];

    // 更新索引和标签（类似取指）
    assign update_index = branch_pc[BTB_INDEX_BITS+1:2];
    assign update_tag   = branch_pc[BTB_INDEX_BITS+TAG_BITS+1:BTB_INDEX_BITS+2];

    // BTB查找逻辑（组合逻辑）
    // 命中条件：条目有效且标签匹配
    assign btb_hit = valid[fetch_index] && (tag_array[fetch_index] == fetch_tag);
    assign predicted_target = btb_hit ? target_array[fetch_index] : 32'h0;

    // BTB更新逻辑（同步逻辑）
    // 当分支实际跳转时，将目标地址缓存到BTB
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // 复位时清除所有条目
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
                tag_array[i] <= {TAG_BITS{1'b0}};
                target_array[i] <= 32'h0;
            end
        end
        else if (update_enable && branch_taken) begin
            // 遇到分支指令且分支实际跳转时，缓存目标地址
            valid[update_index] <= 1'b1;
            tag_array[update_index] <= update_tag;
            target_array[update_index] <= actual_target;
        end
    end

endmodule
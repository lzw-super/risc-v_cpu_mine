// ==============================
// EX/MEM 流水线寄存器
// ==============================

module ex_mem_reg (
    input           clk,
    input           reset,
    input           flush,      // 清空信号

    // 来自EX阶段的控制信号
    input           we_in,      // regfile写使能
    input  [2:0]    dmop_in,    // 数据内存操作类型
    input           mwe_in,     // 内存写使能
    input           mem_read_in, // 内存读使能
    input  [1:0]    wb_sel_in,  // WB数据选择信号

    // 来自EX阶段的分支预测信号（新增）
    input           predict_taken_in,  // 预测跳转
    input  [31:0]   predict_target_in, // 预测目标地址
    input           btb_hit_in,        // BTB命中
    input           is_branch_in,      // 是否是分支指令

    // 来自EX阶段的数据
    input  [31:0]   alu_out_in,
    input  [31:0]   rs2_val_in, // 用于Store
    input  [31:0]   imm_in,     // 立即数（用于计算分支目标）
    input  [4:0]    rd_addr_in,
    input  [31:0]   pc_in,      // 用于分支/JAL
    input  [31:0]   pc_next_in, // PC+4 用于JAL/JALR写回
    input           branch_taken_in, // 分支是否发生

    // 输出到MEM阶段
    output reg          we_out,
    output reg [2:0]    dmop_out,
    output reg          mwe_out,
    output reg          mem_read_out,
    output reg [1:0]    wb_sel_out, // WB数据选择信号

    // 分支预测信号输出（新增）
    output reg          predict_taken_out,
    output reg [31:0]   predict_target_out,
    output reg          btb_hit_out,
    output reg          is_branch_out,

    output reg [31:0]   alu_out_out,
    output reg [31:0]   rs2_val_out,
    output reg [31:0]   imm_out,     // 立即数输出
    output reg [4:0]    rd_addr_out,
    output reg [31:0]   pc_out,
    output reg [31:0]   pc_next_out, // PC+4 用于JAL/JALR写回
    output reg          branch_taken_out
);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            we_out            <= 1'b0;
            dmop_out          <= 3'b0;
            mwe_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            wb_sel_out        <= 2'b0;    // WB选择初始化
            alu_out_out       <= 32'h0;
            rs2_val_out       <= 32'h0;
            imm_out           <= 32'h0;
            rd_addr_out       <= 5'b0;
            pc_out            <= 32'h0;
            pc_next_out       <= 32'h0;   // PC+4初始化
            branch_taken_out  <= 1'b0;
            // 新增信号初始化
            predict_taken_out <= 1'b0;
            predict_target_out <= 32'h0;
            btb_hit_out <= 1'b0;
            is_branch_out <= 1'b0;
        end
        else if (flush) begin
            we_out            <= 1'b0;
            mwe_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            wb_sel_out        <= 2'b0;    // WB选择清空
            branch_taken_out  <= 1'b0;
            // 新增信号清空
            predict_taken_out <= 1'b0;
            btb_hit_out <= 1'b0;
            is_branch_out <= 1'b0;
        end
        else begin
            we_out            <= we_in;
            dmop_out          <= dmop_in;
            mwe_out           <= mwe_in;
            mem_read_out      <= mem_read_in;
            wb_sel_out        <= wb_sel_in;   // WB选择传递
            alu_out_out       <= alu_out_in;
            rs2_val_out       <= rs2_val_in;
            imm_out           <= imm_in;
            rd_addr_out       <= rd_addr_in;
            pc_out            <= pc_in;
            pc_next_out       <= pc_next_in;  // PC+4传递
            branch_taken_out  <= branch_taken_in;
            // 新增信号传递
            predict_taken_out <= predict_taken_in;
            predict_target_out <= predict_target_in;
            btb_hit_out <= btb_hit_in;
            is_branch_out <= is_branch_in;
        end
    end

endmodule
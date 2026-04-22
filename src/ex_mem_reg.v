// ==============================
// EX/MEM 流水线寄存器
// ==============================
// 注：分支预测相关信号已移除，mispredict检测在EX阶段完成

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

    // 来自EX阶段的数据
    input  [31:0]   alu_out_in,
    input  [31:0]   rs2_val_in, // 用于Store
    input  [31:0]   imm_in,     // 立即数（用于LUI写回）
    input  [4:0]    rd_addr_in,
    input  [31:0]   pc_next_in, // PC+4 用于JAL/JALR写回

    // 输出到MEM阶段
    output reg          we_out,
    output reg [2:0]    dmop_out,
    output reg          mwe_out,
    output reg          mem_read_out,
    output reg [1:0]    wb_sel_out, // WB数据选择信号

    output reg [31:0]   alu_out_out,
    output reg [31:0]   rs2_val_out,
    output reg [31:0]   imm_out,     // 立即数输出（用于LUI）
    output reg [4:0]    rd_addr_out,
    output reg [31:0]   pc_next_out  // PC+4 用于JAL/JALR写回
);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            we_out            <= 1'b0;
            dmop_out          <= 3'b0;
            mwe_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            wb_sel_out        <= 2'b0;
            alu_out_out       <= 32'h0;
            rs2_val_out       <= 32'h0;
            imm_out           <= 32'h0;
            rd_addr_out       <= 5'b0;
            pc_next_out       <= 32'h0;
        end
        else if (flush) begin
            we_out            <= 1'b0;
            mwe_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            wb_sel_out        <= 2'b0;
        end
        else begin
            we_out            <= we_in;
            dmop_out          <= dmop_in;
            mwe_out           <= mwe_in;
            mem_read_out      <= mem_read_in;
            wb_sel_out        <= wb_sel_in;
            alu_out_out       <= alu_out_in;
            rs2_val_out       <= rs2_val_in;
            imm_out           <= imm_in;
            rd_addr_out       <= rd_addr_in;
            pc_next_out       <= pc_next_in;
        end
    end

endmodule
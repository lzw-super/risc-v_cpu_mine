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

    // 来自EX阶段的数据
    input  [31:0]   alu_out_in,
    input  [31:0]   rs2_val_in, // 用于Store
    input  [4:0]    rd_addr_in,
    input  [31:0]   pc_in,      // 用于分支/JAL
    input           branch_taken_in, // 分支是否发生

    // 输出到MEM阶段
    output reg          we_out,
    output reg [2:0]    dmop_out,
    output reg          mwe_out,
    output reg          mem_read_out,

    output reg [31:0]   alu_out_out,
    output reg [31:0]   rs2_val_out,
    output reg [4:0]    rd_addr_out,
    output reg [31:0]   pc_out,
    output reg          branch_taken_out
);

    always @(posedge clk) begin
        if (reset) begin
            we_out            <= 1'b0;
            dmop_out          <= 3'b0;
            mwe_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            alu_out_out       <= 32'h0;
            rs2_val_out       <= 32'h0;
            rd_addr_out       <= 5'b0;
            pc_out            <= 32'h0;
            branch_taken_out  <= 1'b0;
        end
        else if (flush) begin
            we_out            <= 1'b0;
            mwe_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            branch_taken_out  <= 1'b0;
        end
        else begin
            we_out            <= we_in;
            dmop_out          <= dmop_in;
            mwe_out           <= mwe_in;
            mem_read_out      <= mem_read_in;
            alu_out_out       <= alu_out_in;
            rs2_val_out       <= rs2_val_in;
            rd_addr_out       <= rd_addr_in;
            pc_out            <= pc_in;
            branch_taken_out  <= branch_taken_in;
        end
    end

endmodule
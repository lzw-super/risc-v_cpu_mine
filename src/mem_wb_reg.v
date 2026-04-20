// ==============================
// MEM/WB 流水线寄存器
// ==============================

module mem_wb_reg (
    input           clk,
    input           reset,

    // 来自MEM阶段的控制信号
    input           we_in,      // regfile写使能

    // 来自MEM阶段的数据
    input  [31:0]   mem_data_in, // 内存读取数据
    input  [31:0]   alu_out_in,  // ALU结果（非Load指令）
    input  [4:0]    rd_addr_in,
    input           mem_read_in, // 判断数据来源

    // 输出到WB阶段
    output reg          we_out,
    output reg [31:0]   wb_data_out,
    output reg [4:0]    rd_addr_out
);

    always @(posedge clk) begin
        if (reset) begin
            we_out       <= 1'b0;
            wb_data_out  <= 32'h0;
            rd_addr_out  <= 5'b0;
        end
        else begin
            we_out       <= we_in;
            // WB数据来源：Load指令用内存数据，其他用ALU结果
            wb_data_out  <= mem_read_in ? mem_data_in : alu_out_in;
            rd_addr_out  <= rd_addr_in;
        end
    end

endmodule
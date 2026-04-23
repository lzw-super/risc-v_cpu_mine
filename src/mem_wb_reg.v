// ==============================
// MEM/WB 流水线寄存器
// ==============================
// 修复WB数据选择：在always块内直接计算wb_mux，确保使用正确的wb_sel

module mem_wb_reg (
    input           clk,
    input           reset,

    // 来自MEM阶段的控制信号
    input           we_in,      // regfile写使能
    input  [1:0]    wb_sel_in,  // WB数据选择信号

    // 来自MEM阶段的数据
    input  [31:0]   mem_data_in, // 内存读取数据 (v0)
    input  [31:0]   alu_out_in,  // ALU结果 (v1)
    input  [31:0]   imm_in,      // 立即数 (v2) - 用于LUI
    input  [31:0]   pc_next_in,  // PC+4 (v3) - 用于JAL/JALR
    input  [4:0]    rd_addr_in,

    // 输出到WB阶段
    output reg          we_out,
    output reg [31:0]   wb_data_out,
    output reg [4:0]    rd_addr_out,
    output reg [1:0]    wb_sel_out  // 用于转发检测等
);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            we_out       <= 1'b0;
            wb_data_out  <= 32'h0;
            rd_addr_out  <= 5'b0;
            wb_sel_out   <= 2'b0;
        end
        else begin
            we_out       <= we_in;
            rd_addr_out  <= rd_addr_in;
            wb_sel_out   <= wb_sel_in;
            // 在时钟边沿直接计算wb_mux，使用wb_sel_in（当前MEM阶段的wb_sel）
            case (wb_sel_in)
                2'b00: wb_data_out <= mem_data_in;  // Load
                2'b01: wb_data_out <= alu_out_in;   // ALU result
                2'b10: wb_data_out <= imm_in;       // LUI
                2'b11: wb_data_out <= pc_next_in;   // JAL/JALR return address
                default: wb_data_out <= 32'h0;
            endcase
        end
    end

endmodule
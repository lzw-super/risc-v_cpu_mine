// ==============================
// MEM/WB 流水线寄存器
// ==============================

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
    output reg [4:0]    rd_addr_out
);

    // 四选一MUX用于WB数据选择
    wire [31:0] wb_mux_out;

    mul4to1 u_wb_mux (
        .v0(mem_data_in),     // 00: mem_data (Load)
        .v1(alu_out_in),      // 01: alu_out (R/I型算术)
        .v2(imm_in),          // 10: imm (LUI)
        .v3(pc_next_in),      // 11: pc+4 (JAL/JALR)
        .s(wb_sel_in),
        .value(wb_mux_out)
    );

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            we_out       <= 1'b0;
            wb_data_out  <= 32'h0;
            rd_addr_out  <= 5'b0;
        end
        else begin
            we_out       <= we_in;
            wb_data_out  <= wb_mux_out;  // 使用四选一MUX输出
            rd_addr_out  <= rd_addr_in;
        end
    end

endmodule
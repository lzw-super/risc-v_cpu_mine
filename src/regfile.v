/*
写入使用时序，读出使用逻辑
使用下降沿触发写入以确保单周期CPU的写回时序正确
复位时将所有寄存器置零
*/
module regfile (
    input clk,
    input reset,

    // 读出信号
    input [4:0] rs1,
    input [4:0] rs2,
    input re1,
    input re2,

    // 写入信号
    input [4:0] wd,
    input we,
    input [31:0] wdata,

    output reg [31:0] rs1_value,
    output reg [31:0] rs2_value
);
    reg [31:0] regfile [31:0];

    // 写入逻辑：下降沿触发（单周期CPU需要）  多周期则使用上升沿触发
    always @(negedge clk) begin
        if (reset) begin
            // 复位时将所有寄存器置零
            regfile[0]  <= 32'h0;
            regfile[1]  <= 32'h0;
            regfile[2]  <= 32'h0;
            regfile[3]  <= 32'h0;
            regfile[4]  <= 32'h0;
            regfile[5]  <= 32'h0;
            regfile[6]  <= 32'h0;
            regfile[7]  <= 32'h0;
            regfile[8]  <= 32'h0;
            regfile[9]  <= 32'h0;
            regfile[10] <= 32'h0;
            regfile[11] <= 32'h0;
            regfile[12] <= 32'h0;
            regfile[13] <= 32'h0;
            regfile[14] <= 32'h0;
            regfile[15] <= 32'h0;
            regfile[16] <= 32'h0;
            regfile[17] <= 32'h0;
            regfile[18] <= 32'h0;
            regfile[19] <= 32'h0;
            regfile[20] <= 32'h0;
            regfile[21] <= 32'h0;
            regfile[22] <= 32'h0;
            regfile[23] <= 32'h0;
            regfile[24] <= 32'h0;
            regfile[25] <= 32'h0;
            regfile[26] <= 32'h0;
            regfile[27] <= 32'h0;
            regfile[28] <= 32'h0;
            regfile[29] <= 32'h0;
            regfile[30] <= 32'h0;
            regfile[31] <= 32'h0;
        end
        else if (we && wd != 0) begin
            regfile[wd] <= wdata;
        end
    end

    // 读出逻辑：组合逻辑，x0永远为0
    always @(*) begin
        if (!re1 || rs1 == 0) begin
            rs1_value = 32'h0;
        end
        else begin
            rs1_value = regfile[rs1];
        end
    end

    always @(*) begin
        if (!re2 || rs2 == 0) begin
            rs2_value = 32'h0;
        end
        else begin
            rs2_value = regfile[rs2];
        end
    end

endmodule
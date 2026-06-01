// ==============================
// 双端口指令RAM
// ==============================
// 写端口：UART控制器写入指令
// 读端口：CPU读取指令（小端序）
// 使用FPGA Block RAM资源
// 存储256条32位指令（1024字节）
// ==============================

module instr_ram (
    input  clk,
    // 写端口（UART）
    input  [9:0] wr_addr,     // 字节地址
    input  [31:0] wr_data,    // 32位指令数据
    input  wr_en,
    // 读端口（CPU）
    input  [31:0] rd_addr,    // 字节地址
    output [31:0] rd_data     // 32位指令数据
);

    // RAM存储：1024字节 = 256条指令
    reg [7:0] ram [0:1023];

    // ==================== 写端口 ====================
    // UART写入：4字节同时写入
    always @(posedge clk) begin
        if (wr_en) begin
            ram[wr_addr]     <= wr_data[7:0];
            ram[wr_addr + 1] <= wr_data[15:8];
            ram[wr_addr + 2] <= wr_data[23:16];
            ram[wr_addr + 3] <= wr_data[31:24];
        end
    end

    // ==================== 读端口 ====================
    // CPU读取：小端序组合32位指令
    // 组合逻辑读（Block RAM风格）
    assign rd_data = {ram[rd_addr + 3],
                      ram[rd_addr + 2],
                      ram[rd_addr + 1],
                      ram[rd_addr]};

    // ==================== 初始化 ====================
    // FPGA综合时，Block RAM默认初始化为0
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            ram[i] = 8'h00;
        end
    end

endmodule
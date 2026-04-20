// ==============================
// 指令内存 - 使用 $readmemh 加载
// ==============================

/*
输入pc地址输出32位指令  逻辑
使用小端序：地址0存储最低字节
*/
module instr_mem (
    input [31:0] address,
    output [31:0] instr
);
    reg [7:0] imem [1023:0];  // 1024个8位的寄存器，可存储256条指令（32位）

    // 使用 $readmemh 加载指令文件
    initial begin
        $readmemh("instructions.hex", imem);
    end

    // 小端序读取
    assign instr = {imem[address+3],
                    imem[address+2],
                    imem[address+1],
                    imem[address]};
endmodule
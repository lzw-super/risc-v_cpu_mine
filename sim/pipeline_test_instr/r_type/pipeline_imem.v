// ==============================
// Pipeline Instruction Memory - R-Type Test Version
// ==============================
// 加载r_type_test.hex文件

module pipeline_imem (
    input  [31:0] address,
    output [31:0] instr
);
    reg [7:0] imem [1023:0];

    initial begin
        $readmemh("r_type_test.hex", imem);
    end;

    // 小端序读取
    assign instr = {imem[address+3],
                    imem[address+2],
                    imem[address+1],
                    imem[address]};
endmodule
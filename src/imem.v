/*
输入pc地址输出32位指令  逻辑*/
module instr_mem (
    input [31:0] address , 
    output [31:0] instr
    );
    reg [7:0] instr_mem [1023:0]  // 1024个8位的寄存器，可存储256条指令（32位） 
    /*initial begin
        {INST_memory[0],    INST_memory[1], INST_memory[2], INST_memory[3]} =32'h00900513; 
        {INST_memory[4],    INST_memory[5], INST_memory[6], INST_memory[7]} =32'h00600593;
        {INST_memory[8],    INST_memory[9], INST_memory[10],INST_memory[11]}=32'h00b50633;
        {INST_memory[12],   INST_memory[13],INST_memory[14],INST_memory[15]}=32'h40b506b3;
        {INST_memory[16],   INST_memory[17],INST_memory[18],INST_memory[19]}=32'h00d67733;
        {INST_memory[20],   INST_memory[21],INST_memory[22],INST_memory[23]}=32'h00000000;
    end*/
    // 00 90 05 13        //addi x10 x0 9
    // 00 60 05 93        //addi x11 x0 6
    // 00 00 07 13        //addi x14 x0 0
    // 00 b5 06 33        //add x12 x10 x11
    // 40 b5 06 b3        //sub x13 x10 x11
    // 00 b6 06 33        //add x12 x12 x11
    // 00 57 07 13        //addi x14 x14 5
    // ff 9f fa 6f        //jal x20 -8
    // 00 00 00 00		//end

    assign instr = {instr_mem[address],
                    instr_mem[address+1],
                    instr_mem[address+2]
                    instr_mem[address+3]};   //逻辑赋值 因为是一个stage
endmodule
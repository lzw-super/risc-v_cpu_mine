// ==============================
// 冒险检测单元 - 解决Load-Use冒险
// ==============================

module hazard_unit (
    // 来自ID1阶段（已寄存译码、准备读寄存器并进入ID/EX的指令）
    input  [4:0]    id_rs1_addr,
    input  [4:0]    id_rs2_addr,
    input           id_re1,      // rs1读使能
    input           id_re2,      // rs2读使能

    // 来自ID/EX寄存器（上一条指令）
    input  [4:0]    id_ex_rd,
    input           id_ex_we,

    // 来自EX0/EX1寄存器（更深一级的producer）
    input  [4:0]    ex1_rd,
    input           ex1_mem_read,

    // 输出控制信号
    output reg      stall_pc,       // PC暂停
    output reg      stall_if_id,    // IF/ID暂停
    output reg      stall_id_ex     // ID/EX插入NOP（清空控制信号）
);

    wire id_uses_id_ex_rd;
    wire id_uses_ex1_rd;

    assign id_uses_id_ex_rd = (id_ex_rd != 5'b0) &&
        ((id_re1 && (id_ex_rd == id_rs1_addr)) ||
         (id_re2 && (id_ex_rd == id_rs2_addr)));

    assign id_uses_ex1_rd = (ex1_rd != 5'b0) &&
        ((id_re1 && (ex1_rd == id_rs1_addr)) ||
         (id_re2 && (ex1_rd == id_rs2_addr)));

    // EX0/EX1切分后，紧邻ALU producer需要停1拍，load producer需要停2拍。
    always @(*) begin
        if ((id_ex_we && id_uses_id_ex_rd) ||
            (ex1_mem_read && id_uses_ex1_rd)) begin
            stall_pc      = 1'b1;
            stall_if_id   = 1'b1;
            stall_id_ex   = 1'b1;
        end
        else begin
            stall_pc      = 1'b0;
            stall_if_id   = 1'b0;
            stall_id_ex   = 1'b0;
        end
    end

endmodule

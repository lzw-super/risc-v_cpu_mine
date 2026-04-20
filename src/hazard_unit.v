// ==============================
// 冒险检测单元 - 解决Load-Use冒险
// ==============================

module hazard_unit (
    // 来自ID阶段（当前译码的指令）
    input  [4:0]    id_rs1_addr,
    input  [4:0]    id_rs2_addr,
    input           id_re1,      // rs1读使能
    input           id_re2,      // rs2读使能

    // 来自ID/EX寄存器（上一条指令）
    input  [4:0]    id_ex_rd,
    input           id_ex_mem_read,  // 上一条是Load指令

    // 输出控制信号
    output reg      stall_pc,       // PC暂停
    output reg      stall_if_id,    // IF/ID暂停
    output reg      stall_id_ex     // ID/EX插入NOP（清空控制信号）
);

    // Load-Use冒险检测：
    // 当前指令需要读取的寄存器 == 上一条Load指令的目标寄存器
    always @(*) begin
        if (id_ex_mem_read && (id_ex_rd != 5'b0) &&
            ((id_re1 && (id_ex_rd == id_rs1_addr)) ||
             (id_re2 && (id_ex_rd == id_rs2_addr)))) begin
            // Load-Use冒险发生，需要暂停
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
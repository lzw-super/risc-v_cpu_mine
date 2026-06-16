// ==============================
// 转发单元 - 解决数据冒险
// ==============================
// EX0/EX1切分后不做EX1组合旁路回EX0，避免重建关键路径。
// 紧邻producer由hazard_unit插入bubble；可见结果从EX/MEM或MEM/WB前递。

module forward_unit (
    // 来自ID/EX寄存器
    input  [4:0]    rs1_addr,   // 当前指令rs1
    input  [4:0]    rs2_addr,   // 当前指令rs2

    // 来自EX/MEM寄存器
    input  [4:0]    ex_mem_rd,  // EX1结果进入EX/MEM后的rd
    input           ex_mem_we,  // EX/MEM阶段是否写寄存器

    // 来自MEM/WB寄存器
    input  [4:0]    mem_wb_rd,  // MEM/WB阶段的rd
    input           mem_wb_we,  // MEM/WB阶段是否写寄存器

    // 输出转发控制信号
    output reg [1:0] forward_a, // rs1转发选择：00=regfile, 01=EX/MEM, 10=MEM/WB
    output reg [1:0] forward_b  // rs2转发选择
);

    always @(*) begin
        // rs1转发逻辑
        // 优先级：EX/MEM > MEM/WB（最新数据优先）
        if (ex_mem_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs1_addr)) begin
            forward_a = 2'b01;  // 从EX/MEM转发ALU结果
        end
        else if (mem_wb_we && (mem_wb_rd != 5'b0) && (mem_wb_rd == rs1_addr)) begin
            forward_a = 2'b10;  // 从MEM/WB转发
        end
        else begin
            forward_a = 2'b00;  // 正常从regfile读取
        end

        // rs2转发逻辑
        if (ex_mem_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs2_addr)) begin
            forward_b = 2'b01;
        end
        else if (mem_wb_we && (mem_wb_rd != 5'b0) && (mem_wb_rd == rs2_addr)) begin
            forward_b = 2'b10;
        end
        else begin
            forward_b = 2'b00;
        end
    end

endmodule

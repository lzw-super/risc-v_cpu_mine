// ==============================
// IF/ID 流水线寄存器
// ==============================

module if_id_reg (
    input           clk,
    input           reset,
    input           stall,      // 暂停信号，阻止更新
    input           flush,      // 清空信号（分支预测错误）

    input  [31:0]   pc_in,      // 来自IF阶段的PC
    input  [31:0]   instr_in,   // 来自IF阶段的指令

    output reg [31:0] pc_out,     // 传递到ID阶段的PC
    output reg [31:0] instr_out   // 传递到ID阶段的指令
);

    always @(posedge clk) begin
        if (reset) begin
            pc_out    <= 32'h0;
            instr_out <= 32'h0;
        end
        else if (flush) begin
            // 清空流水线，插入NOP (addi x0, x0, 0)
            pc_out    <= 32'h0;
            instr_out <= 32'h00000013;  // NOP
        end
        else if (!stall) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
        // stall时保持原值不变
    end

endmodule
// ==============================
// PC模块 - 支持Stall控制和动态预测
// ==============================

module pc (
    input           clk,
    input           reset,
    input           stall,
    input  [31:0]   jmp,
    input           jmp_en,
    input           branch_en,

    output reg [31:0] curr_pc,
    output reg [31:0] next_pc
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            curr_pc <= 32'h0;
            next_pc <= 32'h4;
        end
        else if (stall) begin
            curr_pc <= curr_pc;
            next_pc <= next_pc;
        end
        else if (jmp_en || branch_en) begin
            curr_pc <= jmp;
            next_pc <= jmp + 32'h4;
        end
        else begin
            curr_pc <= next_pc;
            next_pc <= next_pc + 32'h4;
        end
    end

endmodule
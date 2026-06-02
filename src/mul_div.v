// ==============================
// 乘除法执行单元 (RV32M)
// ==============================
// 支持 MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU
// ALU op 编码:
// 0x0b: MUL      0x0c: MULH     0x0d: MULHSU   0x0e: MULHU
// 0x0f: DIV      0x10: DIVU     0x11: REM       0x12: REMU
// 除零和溢出按 RISC-V spec 处理

module mul_div (
    input  [31:0] data1,
    input  [31:0] data2,
    input  [7:0]  op,
    output [31:0] res
);

    // 显式符号扩展，避免 $signed/$unsigned 混合上下文问题
    wire signed [63:0] s1_ext = {{32{data1[31]}}, data1};
    wire signed [63:0] s2_ext = {{32{data2[31]}}, data2};
    wire [63:0] u1_ext = {32'b0, data1};
    wire [63:0] u2_ext = {32'b0, data2};

    // MUL: signed * signed, 取低32位
    wire [63:0] mul_ss = s1_ext * s2_ext;
    // MULHU: unsigned * unsigned, 取高32位
    wire [63:0] mul_uu = u1_ext * u2_ext;
    // MULHSU: signed * unsigned, 取高32位
    wire [63:0] mul_su = s1_ext * u2_ext;

    // 除零和溢出检测
    wire div_by_zero = (data2 == 32'b0);
    wire div_overflow = (data1 == 32'h80000000) && (data2 == 32'hFFFFFFFF);

    // DIV: signed 除法（用64位signed运算再截断，避免32位上下文丢失符号）
    wire signed [63:0] div_s64 = s1_ext / s2_ext;
    wire [31:0] div_result = div_by_zero  ? 32'hFFFFFFFF :
                             div_overflow  ? 32'h80000000 :
                             div_s64[31:0];

    // REM: signed 取余
    wire signed [63:0] rem_s64 = s1_ext % s2_ext;
    wire [31:0] rem_result = div_by_zero  ? data1 :
                             div_overflow  ? 32'b0 :
                             rem_s64[31:0];

    // DIVU: unsigned 除法
    wire [31:0] divu_result = div_by_zero ? 32'hFFFFFFFF : data1 / data2;
    // REMU: unsigned 取余
    wire [31:0] remu_result = div_by_zero ? data1 : data1 % data2;

    assign res = (op == 8'h0b) ? mul_ss[31:0]   :
                 (op == 8'h0c) ? mul_ss[63:32]  :
                 (op == 8'h0d) ? mul_su[63:32]  :
                 (op == 8'h0e) ? mul_uu[63:32]  :
                 (op == 8'h0f) ? div_result      :
                 (op == 8'h10) ? divu_result     :
                 (op == 8'h11) ? rem_result      :
                 (op == 8'h12) ? remu_result     :
                 32'b0;

endmodule

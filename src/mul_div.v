// ==============================
// 迭代式乘除法执行单元 (RV32M)
// ==============================

module mul_div (
    input         clk,
    input         reset,
    input         start,
    input  [31:0] data1,
    input  [31:0] data2,
    input  [7:0]  op,
    output reg [31:0] res,
    output reg    busy,
    output reg    done
);

    localparam OP_MUL    = 8'h0b;
    localparam OP_MULH   = 8'h0c;
    localparam OP_MULHSU = 8'h0d;
    localparam OP_MULHU  = 8'h0e;
    localparam OP_DIV    = 8'h0f;
    localparam OP_DIVU   = 8'h10;
    localparam OP_REM    = 8'h11;
    localparam OP_REMU   = 8'h12;

    reg [7:0]  op_reg;
    reg [5:0]  count;
    reg        is_mul;
    reg        result_neg;
    reg        rem_neg;

    reg [63:0] product;
    reg [63:0] multiplicand;
    reg [31:0] multiplier;

    reg [31:0] divisor;
    reg [31:0] quotient;
    reg [32:0] remainder;
    reg [31:0] dividend_shift;

    wire op_signed_a = (op == OP_MUL) || (op == OP_MULH) || (op == OP_MULHSU) ||
                       (op == OP_DIV) || (op == OP_REM);
    wire op_signed_b = (op == OP_MUL) || (op == OP_MULH) ||
                       (op == OP_DIV) || (op == OP_REM);

    wire data1_neg = op_signed_a && data1[31];
    wire data2_neg = op_signed_b && data2[31];
    wire [31:0] abs_data1 = data1_neg ? (~data1 + 32'b1) : data1;
    wire [31:0] abs_data2 = data2_neg ? (~data2 + 32'b1) : data2;

    wire div_by_zero = (data2 == 32'b0);
    wire div_overflow = (data1 == 32'h80000000) && (data2 == 32'hFFFFFFFF) &&
                        ((op == OP_DIV) || (op == OP_REM));

    wire [32:0] div_remainder_shift = {remainder[31:0], dividend_shift[31]};
    wire div_can_subtract = div_remainder_shift >= {1'b0, divisor};
    wire [32:0] div_remainder_next = div_can_subtract ?
                                     (div_remainder_shift - {1'b0, divisor}) :
                                     div_remainder_shift;
    wire [31:0] div_quotient_next = {quotient[30:0], div_can_subtract};
    wire [31:0] div_dividend_next = {dividend_shift[30:0], 1'b0};

    wire [63:0] product_abs_done = product;
    wire [63:0] product_signed_done = result_neg ? (~product_abs_done + 64'b1) : product_abs_done;

    wire [31:0] quotient_signed_done = result_neg ? (~div_quotient_next + 32'b1) : div_quotient_next;
    wire [31:0] remainder_signed_done = rem_neg ? (~div_remainder_next[31:0] + 32'b1) : div_remainder_next[31:0];

    wire [63:0] mul_addend = multiplier[0] ? multiplicand : 64'b0;
    wire [63:0] mul_next = product + mul_addend;
    wire [63:0] mul_signed_next = result_neg ? (~mul_next + 64'b1) : mul_next;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            res <= 32'b0;
            busy <= 1'b0;
            done <= 1'b0;
            op_reg <= 8'b0;
            count <= 6'b0;
            is_mul <= 1'b0;
            result_neg <= 1'b0;
            rem_neg <= 1'b0;
            product <= 64'b0;
            multiplicand <= 64'b0;
            multiplier <= 32'b0;
            divisor <= 32'b0;
            quotient <= 32'b0;
            remainder <= 33'b0;
            dividend_shift <= 32'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                op_reg <= op;
                count <= 6'd0;
                result_neg <= data1_neg ^ data2_neg;
                rem_neg <= data1_neg;

                if ((op == OP_DIV || op == OP_DIVU || op == OP_REM || op == OP_REMU) && div_by_zero) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    res <= (op == OP_DIV || op == OP_DIVU) ? 32'hFFFFFFFF : data1;
                end else if (div_overflow) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    res <= (op == OP_DIV) ? 32'h80000000 : 32'b0;
                end else begin
                    busy <= 1'b1;
                    is_mul <= (op == OP_MUL) || (op == OP_MULH) || (op == OP_MULHSU) || (op == OP_MULHU);
                    if ((op == OP_MUL) || (op == OP_MULH) || (op == OP_MULHSU) || (op == OP_MULHU)) begin
                        product <= 64'b0;
                        multiplicand <= {32'b0, abs_data1};
                        multiplier <= abs_data2;
                    end else begin
                        divisor <= abs_data2;
                        quotient <= 32'b0;
                        remainder <= 33'b0;
                        dividend_shift <= abs_data1;
                    end
                end
            end else if (busy) begin
                count <= count + 6'd1;

                if (is_mul) begin
                    if (multiplier[0]) begin
                        product <= product + multiplicand;
                    end
                    multiplicand <= multiplicand << 1;
                    multiplier <= multiplier >> 1;

                    if (count == 6'd31) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        case (op_reg)
                            OP_MUL:    res <= mul_signed_next[31:0];
                            OP_MULH:   res <= mul_signed_next[63:32];
                            OP_MULHSU: res <= mul_signed_next[63:32];
                            OP_MULHU:  res <= mul_next[63:32];
                            default:   res <= 32'b0;
                        endcase
                    end
                end else begin
                    remainder <= div_remainder_next;
                    quotient <= div_quotient_next;
                    dividend_shift <= div_dividend_next;

                    if (count == 6'd31) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        case (op_reg)
                            OP_DIV:  res <= quotient_signed_done;
                            OP_DIVU: res <= div_quotient_next;
                            OP_REM:  res <= remainder_signed_done;
                            OP_REMU: res <= div_remainder_next[31:0];
                            default: res <= 32'b0;
                        endcase
                    end
                end
            end
        end
    end

endmodule

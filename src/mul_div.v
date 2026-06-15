// ==============================
// RV32M multiply/divide unit
// ==============================
//
// Timing-oriented implementation:
// - Multiplication uses a carry-save iterative accumulator, so each multiply
//   iteration avoids a 64-bit carry-propagate adder.
// - Final multiply carry-propagate addition and two's-complement correction are
//   split into 16-bit chunks.
// - Divide keeps the existing one-bit-per-cycle algorithm, but final sign
//   correction is also split into 16-bit chunks.
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

    localparam ST_IDLE     = 4'd0;
    localparam ST_MUL_ITER = 4'd1;
    localparam ST_MUL_ADD0 = 4'd2;
    localparam ST_MUL_ADD1 = 4'd3;
    localparam ST_MUL_ADD2 = 4'd4;
    localparam ST_MUL_ADD3 = 4'd5;
    localparam ST_MUL_NEG0 = 4'd6;
    localparam ST_MUL_NEG1 = 4'd7;
    localparam ST_MUL_NEG2 = 4'd8;
    localparam ST_MUL_NEG3 = 4'd9;
    localparam ST_MUL_DONE = 4'd10;
    localparam ST_DIV_ITER = 4'd11;
    localparam ST_DIV_NEG0 = 4'd12;
    localparam ST_DIV_NEG1 = 4'd13;
    localparam ST_DIV_DONE = 4'd14;

    reg [3:0]  state;
    reg [7:0]  op_reg;
    reg [5:0]  count;
    reg        result_neg;
    reg        rem_neg;

    reg [63:0] mul_sum;
    reg [63:0] mul_carry;
    reg [63:0] multiplicand;
    reg [31:0] multiplier;
    reg [63:0] final_product;
    reg        final_carry;

    reg [31:0] divisor;
    reg [31:0] quotient;
    reg [32:0] remainder;
    reg [31:0] dividend_shift;
    reg [31:0] div_result_abs;
    reg [31:0] div_result;
    reg        div_negate_result;
    reg        div_fix_carry;

    wire op_is_mul = (op == OP_MUL) || (op == OP_MULH) ||
                     (op == OP_MULHSU) || (op == OP_MULHU);
    wire op_is_div = (op == OP_DIV) || (op == OP_DIVU) ||
                     (op == OP_REM) || (op == OP_REMU);

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

    wire [63:0] mul_addend = multiplier[0] ? multiplicand : 64'b0;
    wire [63:0] mul_sum_next = mul_sum ^ mul_carry ^ mul_addend;
    wire [63:0] mul_carry_next = ((mul_sum & mul_carry) |
                                  (mul_sum & mul_addend) |
                                  (mul_carry & mul_addend)) << 1;

    wire [32:0] div_remainder_shift = {remainder[31:0], dividend_shift[31]};
    wire div_can_subtract = div_remainder_shift >= {1'b0, divisor};
    wire [32:0] div_remainder_next = div_can_subtract ?
                                     (div_remainder_shift - {1'b0, divisor}) :
                                     div_remainder_shift;
    wire [31:0] div_quotient_next = {quotient[30:0], div_can_subtract};
    wire [31:0] div_dividend_next = {dividend_shift[30:0], 1'b0};

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            res <= 32'b0;
            busy <= 1'b0;
            done <= 1'b0;
            state <= ST_IDLE;
            op_reg <= 8'b0;
            count <= 6'b0;
            result_neg <= 1'b0;
            rem_neg <= 1'b0;
            mul_sum <= 64'b0;
            mul_carry <= 64'b0;
            multiplicand <= 64'b0;
            multiplier <= 32'b0;
            final_product <= 64'b0;
            final_carry <= 1'b0;
            divisor <= 32'b0;
            quotient <= 32'b0;
            remainder <= 33'b0;
            dividend_shift <= 32'b0;
            div_result_abs <= 32'b0;
            div_result <= 32'b0;
            div_negate_result <= 1'b0;
            div_fix_carry <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        op_reg <= op;
                        count <= 6'd0;
                        result_neg <= data1_neg ^ data2_neg;
                        rem_neg <= data1_neg;

                        if (op_is_div && div_by_zero) begin
                            done <= 1'b1;
                            res <= ((op == OP_DIV) || (op == OP_DIVU)) ? 32'hFFFFFFFF : data1;
                        end else if (div_overflow) begin
                            done <= 1'b1;
                            res <= (op == OP_DIV) ? 32'h80000000 : 32'b0;
                        end else if (op_is_mul) begin
                            busy <= 1'b1;
                            state <= ST_MUL_ITER;
                            mul_sum <= 64'b0;
                            mul_carry <= 64'b0;
                            multiplicand <= {32'b0, abs_data1};
                            multiplier <= abs_data2;
                            final_product <= 64'b0;
                            final_carry <= 1'b0;
                        end else if (op_is_div) begin
                            busy <= 1'b1;
                            state <= ST_DIV_ITER;
                            divisor <= abs_data2;
                            quotient <= 32'b0;
                            remainder <= 33'b0;
                            dividend_shift <= abs_data1;
                            div_result_abs <= 32'b0;
                            div_result <= 32'b0;
                            div_negate_result <= 1'b0;
                            div_fix_carry <= 1'b0;
                        end else begin
                            done <= 1'b1;
                            res <= 32'b0;
                        end
                    end
                end

                ST_MUL_ITER: begin
                    mul_sum <= mul_sum_next;
                    mul_carry <= mul_carry_next;
                    multiplicand <= multiplicand << 1;
                    multiplier <= multiplier >> 1;

                    if (count == 6'd31) begin
                        count <= 6'd0;
                        final_carry <= 1'b0;
                        state <= ST_MUL_ADD0;
                    end else begin
                        count <= count + 6'd1;
                    end
                end

                ST_MUL_ADD0: begin
                    {final_carry, final_product[15:0]} <=
                        {1'b0, mul_sum[15:0]} + {1'b0, mul_carry[15:0]};
                    state <= ST_MUL_ADD1;
                end

                ST_MUL_ADD1: begin
                    {final_carry, final_product[31:16]} <=
                        {1'b0, mul_sum[31:16]} + {1'b0, mul_carry[31:16]} + final_carry;
                    state <= ST_MUL_ADD2;
                end

                ST_MUL_ADD2: begin
                    {final_carry, final_product[47:32]} <=
                        {1'b0, mul_sum[47:32]} + {1'b0, mul_carry[47:32]} + final_carry;
                    state <= ST_MUL_ADD3;
                end

                ST_MUL_ADD3: begin
                    {final_carry, final_product[63:48]} <=
                        {1'b0, mul_sum[63:48]} + {1'b0, mul_carry[63:48]} + final_carry;
                    state <= result_neg ? ST_MUL_NEG0 : ST_MUL_DONE;
                end

                ST_MUL_NEG0: begin
                    {final_carry, final_product[15:0]} <= {1'b0, ~final_product[15:0]} + 17'd1;
                    state <= ST_MUL_NEG1;
                end

                ST_MUL_NEG1: begin
                    {final_carry, final_product[31:16]} <= {1'b0, ~final_product[31:16]} + final_carry;
                    state <= ST_MUL_NEG2;
                end

                ST_MUL_NEG2: begin
                    {final_carry, final_product[47:32]} <= {1'b0, ~final_product[47:32]} + final_carry;
                    state <= ST_MUL_NEG3;
                end

                ST_MUL_NEG3: begin
                    {final_carry, final_product[63:48]} <= {1'b0, ~final_product[63:48]} + final_carry;
                    state <= ST_MUL_DONE;
                end

                ST_MUL_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                    case (op_reg)
                        OP_MUL:    res <= final_product[31:0];
                        OP_MULH:   res <= final_product[63:32];
                        OP_MULHSU: res <= final_product[63:32];
                        OP_MULHU:  res <= final_product[63:32];
                        default:   res <= 32'b0;
                    endcase
                end

                ST_DIV_ITER: begin
                    remainder <= div_remainder_next;
                    quotient <= div_quotient_next;
                    dividend_shift <= div_dividend_next;

                    if (count == 6'd31) begin
                        count <= 6'd0;
                        if ((op_reg == OP_DIV) || (op_reg == OP_DIVU)) begin
                            div_result_abs <= div_quotient_next;
                            div_negate_result <= (op_reg == OP_DIV) && result_neg;
                            if ((op_reg == OP_DIV) && result_neg) begin
                                div_fix_carry <= 1'b0;
                                state <= ST_DIV_NEG0;
                            end else begin
                                div_result <= div_quotient_next;
                                state <= ST_DIV_DONE;
                            end
                        end else begin
                            div_result_abs <= div_remainder_next[31:0];
                            div_negate_result <= (op_reg == OP_REM) && rem_neg;
                            if ((op_reg == OP_REM) && rem_neg) begin
                                div_fix_carry <= 1'b0;
                                state <= ST_DIV_NEG0;
                            end else begin
                                div_result <= div_remainder_next[31:0];
                                state <= ST_DIV_DONE;
                            end
                        end
                    end else begin
                        count <= count + 6'd1;
                    end
                end

                ST_DIV_NEG0: begin
                    {div_fix_carry, div_result[15:0]} <= {1'b0, ~div_result_abs[15:0]} + 17'd1;
                    state <= ST_DIV_NEG1;
                end

                ST_DIV_NEG1: begin
                    {div_fix_carry, div_result[31:16]} <=
                        {1'b0, ~div_result_abs[31:16]} + div_fix_carry;
                    state <= ST_DIV_DONE;
                end

                ST_DIV_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                    res <= div_result;
                end

                default: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    state <= ST_IDLE;
                    res <= 32'b0;
                end
            endcase
        end
    end

endmodule

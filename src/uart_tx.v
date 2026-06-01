// ==============================
// UART发送模块
// ==============================
// 波特率: 115200
// 系统时钟: 50MHz
// 分频系数: 50MHz / 115200 = 434
// 数据格式: 8位数据, 无校验, 1位停止位
// ==============================

module uart_tx (
    input  clk,          // 系统时钟 50MHz
    input  reset,        // 异步复位
    input  [7:0] data,   // 待发送字节
    input  send_start,   // 发送开始信号
    output uart_tx,      // UART TX物理引脚
    output busy          // 发送忙标志
);

    // 波特率分频参数
    parameter BAUD_DIV = 434;  // 50MHz / 115200

    // 状态定义
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam STOP   = 3'b011;

    reg [2:0] state;
    reg [7:0] tx_data;
    reg [15:0] baud_cnt;     // 波特率计数器
    reg [2:0] bit_cnt;       // 数据位计数器
    reg tx_bit;              // 当前发送位
    reg busy_reg;

    assign uart_tx = tx_bit;
    assign busy = busy_reg;

    // 发送状态机
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx_data <= 8'h0;
            baud_cnt <= 16'h0;
            bit_cnt <= 3'h0;
            tx_bit <= 1'b1;        // IDLE时TX为高电平
            busy_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_bit <= 1'b1;  // 空闲状态保持高电平
                    baud_cnt <= 16'h0;
                    bit_cnt <= 3'h0;
                    busy_reg <= 1'b0;
                    if (send_start) begin
                        tx_data <= data;
                        state <= START;
                        baud_cnt <= BAUD_DIV - 1;
                        busy_reg <= 1'b1;
                    end
                end

                START: begin
                    tx_bit <= 1'b0;  // 发送起始位（低电平）
                    if (baud_cnt == 0) begin
                        state <= DATA;
                        baud_cnt <= BAUD_DIV - 1;
                        bit_cnt <= 3'h0;
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                DATA: begin
                    // 发送数据位（低位先发送）
                    tx_bit <= tx_data[bit_cnt];
                    if (baud_cnt == 0) begin
                        if (bit_cnt == 7) begin
                            state <= STOP;
                            baud_cnt <= BAUD_DIV - 1;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                            baud_cnt <= BAUD_DIV - 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                STOP: begin
                    tx_bit <= 1'b1;  // 发送停止位（高电平）
                    if (baud_cnt == 0) begin
                        state <= IDLE;
                        busy_reg <= 1'b0;
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
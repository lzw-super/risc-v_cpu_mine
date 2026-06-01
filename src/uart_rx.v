// ==============================
// UART接收模块
// ==============================
// 波特率: 115200
// 系统时钟: 50MHz
// 分频系数: 50MHz / 115200 = 434
// 数据格式: 8位数据, 无校验, 1位停止位
// ==============================

module uart_rx (
    input  clk,          // 系统时钟 50MHz
    input  reset,        // 异步复位
    input  uart_rx,      // UART RX物理引脚
    output [7:0] data,   // 接收到的字节
    output valid         // 数据有效标志（单周期脉冲）
);

    // 波特率分频参数
    parameter BAUD_DIV = 434;  // 50MHz / 115200

    // 状态定义
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam STOP   = 3'b011;

    reg [2:0] state;
    reg [7:0] rx_data;
    reg [15:0] baud_cnt;     // 波特率计数器
    reg [2:0] bit_cnt;       // 数据位计数器
    reg valid_reg;

    assign data = rx_data;
    assign valid = valid_reg;

    // UART RX信号同步（防止亚稳态）
    reg uart_rx_sync1, uart_rx_sync2;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_rx_sync1 <= 1'b1;
            uart_rx_sync2 <= 1'b1;
        end else begin
            uart_rx_sync1 <= uart_rx;
            uart_rx_sync2 <= uart_rx_sync1;
        end
    end

    // 检测起始位下降沿
    wire start_edge = uart_rx_sync2 && !uart_rx_sync1;

    // 接收状态机
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            rx_data <= 8'h0;
            baud_cnt <= 16'h0;
            bit_cnt <= 3'h0;
            valid_reg <= 1'b0;
        end else begin
            valid_reg <= 1'b0;  // 默认无效

            case (state)
                IDLE: begin
                    baud_cnt <= 16'h0;
                    bit_cnt <= 3'h0;
                    if (start_edge) begin
                        state <= START;
                        baud_cnt <= BAUD_DIV / 2;  // 在半周期后采样起始位
                    end
                end

                START: begin
                    if (baud_cnt == 0) begin
                        if (!uart_rx_sync2) begin  // 起始位应为低电平
                            state <= DATA;
                            baud_cnt <= BAUD_DIV - 1;
                        end else begin
                            state <= IDLE;  // 噪声，返回IDLE
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                DATA: begin
                    if (baud_cnt == 0) begin
                        // 采样数据位（低位先发送）
                        rx_data[bit_cnt] <= uart_rx_sync2;
                        baud_cnt <= BAUD_DIV - 1;
                        if (bit_cnt == 7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                STOP: begin
                    if (baud_cnt == 0) begin
                        if (uart_rx_sync2) begin  // 停止位应为高电平
                            valid_reg <= 1'b1;    // 数据有效
                        end
                        state <= IDLE;
                    end else begin
                        baud_cnt <= baud_cnt - 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
// ==============================
// UART控制器
// ==============================
// 功能：
//   1. 接收UART数据，解析后写入指令RAM
//   2. 控制观测数据的周期性发送
// 接收协议：每条指令发送4字节（小端序），自动顺序写入
// 发送协议：每帧12字节（PC 4字节 + ALU输出 4字节 + 寄存器数据 4字节）
// ==============================

module uart_ctrl (
    input  clk,
    input  reset,
    // UART RX接口
    input  [7:0] uart_rx_data,
    input  uart_rx_valid,
    // UART TX接口
    output [7:0] uart_tx_data,
    output uart_tx_start,
    input  uart_tx_busy,
    // 指令RAM写入接口
    output [9:0] ram_addr,
    output [31:0] ram_data,
    output ram_we,
    output instr_loaded,    // 指令加载完成（检测到特定结束标志）
    // 观测数据输入（来自CPU）
    input  [31:0] monitor_pc,
    input  [31:0] monitor_alu_out,
    input  [31:0] monitor_rd_data,
    input        monitor_rd_valid,
    // 控制信号
    input  cpu_run,         // CPU运行使能
    output cpu_reset        // CPU复位（加载新指令时）
);

    // ==================== 接收状态机 ====================
    // 接收字节顺序：Byte0, Byte1, Byte2, Byte3（小端序）
    // 每接收4字节组成一条32位指令，写入RAM

    localparam RX_IDLE   = 3'b000;
    localparam RX_BYTE0  = 3'b001;
    localparam RX_BYTE1  = 3'b010;
    localparam RX_BYTE2  = 3'b011;
    localparam RX_WRITE  = 3'b100;  // 专门的写入状态

    reg [2:0] rx_state;
    reg [9:0] rx_addr;         // 当前写入地址（字节地址）
    reg [31:0] rx_instr_buff;  // 指令缓冲
    reg instr_loaded_reg;
    reg cpu_reset_reg;

    assign ram_addr = rx_addr;
    assign ram_data = rx_instr_buff;
    assign ram_we = (rx_state == RX_WRITE);  // 在写入状态才产生写使能
    assign instr_loaded = instr_loaded_reg;
    assign cpu_reset = cpu_reset_reg;

    // 接收状态机：组装指令
    // 状态流程：IDLE -> BYTE0 -> BYTE1 -> BYTE2 -> WRITE -> IDLE
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_state <= RX_IDLE;
            rx_addr <= 10'h0;
            rx_instr_buff <= 32'h0;
            instr_loaded_reg <= 1'b0;
            cpu_reset_reg <= 1'b1;  // 复位CPU
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    if (uart_rx_valid) begin
                        rx_instr_buff[7:0] <= uart_rx_data;  // Byte0
                        rx_state <= RX_BYTE0;
                    end
                end

                RX_BYTE0: begin
                    if (uart_rx_valid) begin
                        rx_instr_buff[15:8] <= uart_rx_data;  // Byte1
                        rx_state <= RX_BYTE1;
                    end
                end

                RX_BYTE1: begin
                    if (uart_rx_valid) begin
                        rx_instr_buff[23:16] <= uart_rx_data;  // Byte2
                        rx_state <= RX_BYTE2;
                    end
                end

                RX_BYTE2: begin
                    if (uart_rx_valid) begin
                        rx_instr_buff[31:24] <= uart_rx_data;  // Byte3
                        rx_state <= RX_WRITE;  // 进入写入状态
                        // 检测结束标志：NOP指令 (0x00000013) 作为结束
                        if ({uart_rx_data, rx_instr_buff[23:0]} == 32'h00000013) begin
                            instr_loaded_reg <= 1'b1;
                            cpu_reset_reg <= 1'b0;  // 释放CPU复位
                        end
                    end
                end

                RX_WRITE: begin
                    // 写入RAM（ram_we = 1）
                    rx_addr <= rx_addr + 10'h4;  // 增加地址（为下一条指令准备）
                    rx_state <= RX_IDLE;
                end
            endcase

            // 指定结束指令后，CPU开始运行
            // 如果收到新数据，重新复位CPU开始加载
            if (instr_loaded_reg && uart_rx_valid && rx_state == RX_IDLE) begin
                instr_loaded_reg <= 1'b0;
                cpu_reset_reg <= 1'b1;
                rx_addr <= 10'h0;
            end
        end
    end

    // ==================== 发送状态机 ====================
    // 周期性发送观测数据（仅当CPU运行时）
    // 发送顺序：PC[7:0], PC[15:8], PC[23:16], PC[31:24],
    //           ALU[7:0], ALU[15:8], ALU[23:16], ALU[31:24],
    //           RD[7:0], RD[15:8], RD[23:16], RD[31:24]

    localparam TX_IDLE = 0;
    localparam TX_SEND = 1;

    reg tx_state;
    reg [3:0] tx_byte_cnt;    // 发送字节计数（0-11）
    reg [31:0] tx_pc_buff;    // 缓存PC
    reg [31:0] tx_alu_buff;   // 缓存ALU输出
    reg [31:0] tx_rd_buff;    // 缓存寄存器数据
    reg [15:0] tx_interval_cnt;  // 发送间隔计数器
    reg uart_tx_start_reg;

    assign uart_tx_start = uart_tx_start_reg;

    // 选择当前发送字节
    wire [7:0] tx_current_byte;
    assign tx_current_byte = (tx_byte_cnt < 4) ? tx_pc_buff[{tx_byte_cnt[1:0], 2'b0} +: 8] :
                             (tx_byte_cnt < 8) ? tx_alu_buff[{tx_byte_cnt[1:0], 2'b0} +: 8] :
                             tx_rd_buff[{tx_byte_cnt[1:0], 2'b0} +: 8];

    // 发送间隔参数（每10000周期发送一次）
    parameter TX_INTERVAL = 16'd10000;

    // 发送状态机
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_state <= TX_IDLE;
            tx_byte_cnt <= 4'h0;
            tx_pc_buff <= 32'h0;
            tx_alu_buff <= 32'h0;
            tx_rd_buff <= 32'h0;
            tx_interval_cnt <= 16'h0;
            uart_tx_start_reg <= 1'b0;
        end else begin
            uart_tx_start_reg <= 1'b0;  // 默认不启动发送

            case (tx_state)
                TX_IDLE: begin
                    tx_byte_cnt <= 4'h0;
                    if (cpu_run && instr_loaded_reg) begin
                        // 计数发送间隔
                        if (tx_interval_cnt == 0) begin
                            // 缓存当前观测数据
                            tx_pc_buff <= monitor_pc;
                            tx_alu_buff <= monitor_alu_out;
                            tx_rd_buff <= monitor_rd_data;
                            // 启动发送
                            if (!uart_tx_busy) begin
                                tx_state <= TX_SEND;
                                uart_tx_start_reg <= 1'b1;
                                tx_interval_cnt <= TX_INTERVAL;
                            end
                        end else begin
                            tx_interval_cnt <= tx_interval_cnt - 1;
                        end
                    end
                end

                TX_SEND: begin
                    if (!uart_tx_busy) begin
                        if (tx_byte_cnt < 11) begin
                            // 发送下一个字节
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            uart_tx_start_reg <= 1'b1;
                        end else begin
                            // 所有字节发送完成
                            tx_state <= TX_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    assign uart_tx_data = tx_current_byte;

endmodule
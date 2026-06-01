// ==============================
// FPGA顶层模块
// ==============================
// 整合UART接口、指令RAM、流水线CPU
// 系统时钟：50MHz
// UART波特率：115200
// ==============================

module fpga_top (
    input  clk,             // FPGA系统时钟 50MHz
    input  reset_btn,       // 复位按钮（按键按下时复位）
    input  uart_rx,         // UART RX物理引脚
    output uart_tx,         // UART TX物理引脚
    // GPIO观测输出（可选，用于LED显示）
    output [31:0] monitor_pc_out,
    output [31:0] monitor_alu_out_out,
    output        monitor_rd_valid_out
);

    // ==================== 信号声明 ====================

    // 系统复位（按键按下时为高）
    wire reset;
    assign reset = reset_btn;

    // UART接收信号
    wire [7:0] uart_rx_data;
    wire uart_rx_valid;

    // UART发送信号
    wire [7:0] uart_tx_data;
    wire uart_tx_start;
    wire uart_tx_busy;

    // 指令RAM信号
    wire [9:0] ram_addr;
    wire [31:0] ram_data;
    wire ram_we;
    wire instr_loaded;

    // CPU观测信号
    wire [31:0] monitor_pc;
    wire [31:0] monitor_instr;
    wire [31:0] monitor_alu_out;
    wire [4:0]  monitor_rd_addr;
    wire [31:0] monitor_rd_data;
    wire        monitor_rd_valid;
    wire [31:0] monitor_mem_addr;
    wire [31:0] monitor_mem_data;
    wire        monitor_mem_we;

    // CPU控制信号
    wire cpu_reset;
    wire cpu_run;

    // 指令输入
    wire [31:0] instr_out;

    // ==================== 模块实例化 ====================

    // UART接收模块
    uart_rx u_uart_rx (
        .clk(clk),
        .reset(reset),
        .uart_rx(uart_rx),
        .data(uart_rx_data),
        .valid(uart_rx_valid)
    );

    // UART发送模块
    uart_tx u_uart_tx (
        .clk(clk),
        .reset(reset),
        .data(uart_tx_data),
        .send_start(uart_tx_start),
        .uart_tx(uart_tx),
        .busy(uart_tx_busy)
    );

    // UART控制器
    uart_ctrl u_uart_ctrl (
        .clk(clk),
        .reset(reset),
        // UART RX接口
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        // UART TX接口
        .uart_tx_data(uart_tx_data),
        .uart_tx_start(uart_tx_start),
        .uart_tx_busy(uart_tx_busy),
        // 指令RAM写入接口
        .ram_addr(ram_addr),
        .ram_data(ram_data),
        .ram_we(ram_we),
        .instr_loaded(instr_loaded),
        // 观测数据输入（来自CPU）
        .monitor_pc(monitor_pc),
        .monitor_alu_out(monitor_alu_out),
        .monitor_rd_data(monitor_rd_data),
        .monitor_rd_valid(monitor_rd_valid),
        // 控制信号
        .cpu_run(cpu_run),
        .cpu_reset(cpu_reset)
    );

    // 指令RAM
    instr_ram u_instr_ram (
        .clk(clk),
        // 写端口（UART）
        .wr_addr(ram_addr),
        .wr_data(ram_data),
        .wr_en(ram_we),
        // 读端口（CPU）
        .rd_addr(monitor_pc),
        .rd_data(instr_out)
    );

    // FPGA版本流水线CPU
    pipeline_cpu_fpga u_cpu (
        .clk(clk),
        .reset(cpu_reset),          // UART控制器控制CPU复位
        // 外部指令输入
        .instr_in(instr_out),
        // 观测输出
        .monitor_pc(monitor_pc),
        .monitor_instr(monitor_instr),
        .monitor_alu_out(monitor_alu_out),
        .monitor_rd_addr(monitor_rd_addr),
        .monitor_rd_data(monitor_rd_data),
        .monitor_rd_valid(monitor_rd_valid),
        .monitor_mem_addr(monitor_mem_addr),
        .monitor_mem_data(monitor_mem_data),
        .monitor_mem_we(monitor_mem_we)
    );

    // ==================== GPIO输出 ====================
    // 用于LED或外部GPIO显示观测数据
    assign monitor_pc_out = monitor_pc;
    assign monitor_alu_out_out = monitor_alu_out;
    assign monitor_rd_valid_out = monitor_rd_valid;

    // CPU运行标志（可用于LED指示）
    assign cpu_run = 1'b1;  // 指令加载完成后CPU自动运行

endmodule
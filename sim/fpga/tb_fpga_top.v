// ==============================
// FPGA顶层模块仿真测试
// ==============================
// 测试UART动态加载指令并验证CPU执行
// ==============================

module tb_fpga_top;

    // 时钟和复位
    reg clk;
    reg reset_btn;

    // UART信号
    reg uart_rx;
    wire uart_tx;

    // 观测输出
    wire [31:0] monitor_pc_out;
    wire [31:0] monitor_alu_out_out;
    wire        monitor_rd_valid_out;

    // 波特率参数
    parameter BAUD_PERIOD = 8680;  // 50MHz / 115200 = 434周期

    // 测试指令序列（小端序）
    reg [7:0] test_instrs [0:15];
    integer instr_idx;
    integer byte_idx;

    // 实例化顶层模块
    fpga_top u_fpga_top (
        .clk(clk),
        .reset_btn(reset_btn),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .monitor_pc_out(monitor_pc_out),
        .monitor_alu_out_out(monitor_alu_out_out),
        .monitor_rd_valid_out(monitor_rd_valid_out)
    );

    // 监控关键信号
    wire ram_we = u_fpga_top.ram_we;
    wire [9:0] ram_addr = u_fpga_top.ram_addr;
    wire [31:0] ram_data = u_fpga_top.ram_data;
    wire instr_loaded = u_fpga_top.instr_loaded;
    wire cpu_reset = u_fpga_top.cpu_reset;
    wire [4:0] wb_rd_addr = u_fpga_top.u_cpu.wb_rd_addr;
    wire [31:0] wb_data = u_fpga_top.u_cpu.wb_data;
    wire wb_we = u_fpga_top.u_cpu.wb_we;

    // 捕获ADD指令的WB结果
    reg [4:0] wb_rd_addr_final;
    reg [31:0] wb_data_final;
    reg add_done;

    initial begin
        wb_rd_addr_final = 0;
        wb_data_final = 0;
        add_done = 0;
    end

    always @(posedge clk) begin
        if (wb_rd_addr == 3 && wb_we && !add_done) begin
            wb_rd_addr_final <= wb_rd_addr;
            wb_data_final <= wb_data;
            add_done <= 1;
        end
    end

    // 时钟生成（50MHz）
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // RAM写入监控
    always @(posedge clk) begin
        if (ram_we) begin
            $display("[%0d ns] RAM写入: 地址=0x%03x, 数据=0x%08x", $time, ram_addr, ram_data);
        end
    end

    // UART发送字节任务
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            uart_rx = 0;  // 起始位
            #BAUD_PERIOD;
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #BAUD_PERIOD;
            end
            uart_rx = 1;  // 停止位
            #BAUD_PERIOD;
        end
    endtask

    // 主测试流程
    initial begin
        $display("========================================");
        $display("FPGA UART通信仿真测试");
        $display("========================================");

        // 初始化
        reset_btn = 1;
        uart_rx = 1;

        // 测试指令（小端序）
        // ADDI x1, x0, 10  → 机器码 0x00A00093
        test_instrs[0]  = 8'h93; test_instrs[1]  = 8'h00;
        test_instrs[2]  = 8'hA0; test_instrs[3]  = 8'h00;

        // ADDI x2, x0, 20  → 机器码 0x01400113
        test_instrs[4]  = 8'h13; test_instrs[5]  = 8'h01;
        test_instrs[6]  = 8'h40; test_instrs[7]  = 8'h01;

        // ADD x3, x1, x2   → 机器码 0x002081b3
        test_instrs[8]  = 8'hb3; test_instrs[9]  = 8'h81;
        test_instrs[10] = 8'h20; test_instrs[11] = 8'h00;

        // NOP（结束标志）
        test_instrs[12] = 8'h13; test_instrs[13] = 8'h00;
        test_instrs[14] = 8'h00; test_instrs[15] = 8'h00;

        // 复位
        #1000;
        reset_btn = 0;
        #1000;

        $display("[%0d ns] 开始发送指令", $time);

        // 发送指令
        for (instr_idx = 0; instr_idx < 4; instr_idx = instr_idx + 1) begin
            for (byte_idx = 0; byte_idx < 4; byte_idx = byte_idx + 1) begin
                send_byte(test_instrs[instr_idx * 4 + byte_idx]);
            end
            #1000;
        end

        $display("[%0d ns] 指令发送完成", $time);

        // 等待CPU执行
        #200000;

        // 检查结果
        $display("========================================");
        $display("仿真结束");
        $display("========================================");

        if (wb_rd_addr_final == 3 && wb_data_final == 32'h1e) begin
            $display("TEST PASSED: ADD x3, x1, x2 wrote 30 to x3");
        end else begin
            $display("TEST FAILED: Expected rd=3, data=30, got rd=%0d, data=%0d",
                     wb_rd_addr_final, wb_data_final);
        end

        $finish;
    end

    // 波形输出
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_fpga_top);
    end

endmodule
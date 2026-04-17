// ==============================
// DataMem模块 Testbench
// ==============================

`timescale 1ns/1ps

module tb_datamem;

    // 输入信号
    reg clk;
    reg reset;
    reg [31:0] address;
    reg we;
    reg [31:0] d_in;
    reg [2:0] mode;

    // 输出信号
    wire [31:0] d_out;

    // 实例化DataMem模块
    datamem u_datamem (
        .clk(clk),
        .reset(reset),
        .address(address),
        .we(we),
        .d_in(d_in),
        .mode(mode),
        .d_out(d_out)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz时钟
    end

    // 测试任务：等待若干时钟周期
    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // 写入任务
    task do_write(
        input [31:0] addr,
        input [2:0] wmode,
        input [31:0] data
    );
        @(posedge clk);
        #1;
        address = addr;
        we = 1;
        d_in = data;
        mode = wmode;

        @(posedge clk);  // 写入时钟沿
        #1;
        we = 0;
        wait_cycles(1);
    endtask

    // 读取并验证任务
    task do_read_check(
        input [31:0] addr,
        input [2:0] rmode,
        input [31:0] expected,
        input string test_name
    );
        @(posedge clk);
        #1;
        address = addr;
        mode = rmode;
        we = 0;

        #1;  // 等待组合逻辑稳定
        if (d_out === expected) begin
            $display("[PASS] %s: d_out=%h (expected %h)", test_name, d_out, expected);
        end else begin
            $display("[FAIL] %s: d_out=%h (expected %h)", test_name, d_out, expected);
        end
        wait_cycles(1);
    endtask

    // 测试主程序
    initial begin
        // 初始化信号
        reset = 0;
        address = 32'h0;
        we = 0;
        d_in = 32'h0;
        mode = 3'h0;

        $display("========================================");
        $display("DataMem Module Test Start");
        $display("========================================");

        // ==================== 测试1: Reset ====================
        $display("\n[Test 1] Reset Test");
        #1;
        reset = 1;
        wait_cycles(2);
        $display("After Reset: d_out = %h", d_out);
        reset = 0;
        wait_cycles(1);

        // ==================== 测试2: SW/LW - Store/Load Word ====================
        $display("\n[Test 2] SW/LW Test");
        do_write(32'h10, 3'h2, 32'hDEADBEEF);
        do_read_check(32'h10, 3'h2, 32'hDEADBEEF, "SW/LW");

        // ==================== 测试3: SH/LH - Store/Load Halfword ====================
        $display("\n[Test 3] SH/LH Test (signed)");
        // 先SW写入完整数据（低16位是负数，bit15=1）
        do_write(32'h20, 3'h2, 32'hFFFF8000);  // 0x8000 bit15=1
        do_read_check(32'h20, 3'h2, 32'hFFFF8000, "SW baseline");

        // SH写入低16位（保持高16位不变）
        do_write(32'h20, 3'h1, 32'h00001234);
        do_read_check(32'h20, 3'h2, 32'hFFFF1234, "SH partial");

        // LH读取（符号扩展，0x1234 bit15=0，扩展为正数）
        do_read_check(32'h20, 3'h1, 32'h00001234, "LH positive");

        // 再次写入负数（bit15=1）
        do_write(32'h20, 3'h1, 32'h00008000);  // 0x8000 bit15=1
        do_read_check(32'h20, 3'h2, 32'hFFFF8000, "SH negative");
        // LH读取（符号扩展，0x8000 bit15=1，扩展为负数）
        do_read_check(32'h20, 3'h1, 32'hFFFF8000, "LH negative");

        // ==================== 测试4: SB/LB - Store/Load Byte ====================
        $display("\n[Test 4] SB/LB Test (signed)");
        // 先SW写入完整数据
        do_write(32'h30, 3'h2, 32'hFF000000);
        do_read_check(32'h30, 3'h2, 32'hFF000000, "SW baseline");

        // SB写入最低字节
        do_write(32'h30, 3'h0, 32'h000000AB);
        do_read_check(32'h30, 3'h2, 32'hFF0000AB, "SB partial");

        // LB读取（符号扩展，0xAB最高位是1，所以符号扩展为负）
        do_read_check(32'h30, 3'h0, 32'hFFFFFFAB, "LB signed");

        // ==================== 测试5: LBU/LHU - Unsigned Load ====================
        $display("\n[Test 5] LBU/LHU Test (unsigned)");
        // LBU - 无符号字节
        do_write(32'h40, 3'h2, 32'hFFFFFFAB);
        do_read_check(32'h40, 3'h4, 32'h000000AB, "LBU unsigned");

        // LHU - 无符号半字
        do_write(32'h44, 3'h2, 32'hFFFF1234);
        do_read_check(32'h44, 3'h5, 32'h00001234, "LHU unsigned");

        // ==================== 测试6: 多次写入同一地址 ====================
        $display("\n[Test 6] Multiple writes to same address");
        // 先写入32'hAABBCCDD
        do_write(32'h50, 3'h2, 32'hAABBCCDD);
        do_read_check(32'h50, 3'h2, 32'hAABBCCDD, "Initial SW");

        // 用SB修改最低字节
        do_write(32'h50, 3'h0, 32'h00000011);
        do_read_check(32'h50, 3'h2, 32'hAABBCC11, "SB modify");

        // 用SH修改低16位
        do_write(32'h50, 3'h1, 32'h00003344);
        do_read_check(32'h50, 3'h2, 32'hAABB3344, "SH modify");

        // ==================== 测试7: 不同地址测试 ====================
        $display("\n[Test 7] Different addresses");
        do_write(32'h0, 3'h2, 32'h12345678);
        do_read_check(32'h0, 3'h2, 32'h12345678, "Addr 0x0");

        do_write(32'h4, 3'h2, 32'h9ABCDEF0);
        do_read_check(32'h4, 3'h2, 32'h9ABCDEF0, "Addr 0x4");

        do_write(32'h100, 3'h2, 32'h55AA55AA);
        do_read_check(32'h100, 3'h2, 32'h55AA55AA, "Addr 0x100");

        // ==================== 测试8: 正数LB/LH测试 ====================
        $display("\n[Test 8] Positive LB/LH Test");
        do_write(32'h60, 3'h2, 32'h0000007F);  // 0x7F 最高位是0
        do_read_check(32'h60, 3'h0, 32'h0000007F, "LB positive");

        do_write(32'h64, 3'h2, 32'h00007FFF);  // 0x7FFF 最高位是0
        do_read_check(32'h64, 3'h1, 32'h00007FFF, "LH positive");

        // ==================== 测试结束 ====================
        $display("\n========================================");
        $display("DataMem Module Test Completed");
        $display("========================================");

        #100;
        $finish;
    end

    // 生成波形文件
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_datamem);
    end

    // 仿真时间限制
    initial begin
        #20000;
        $display("Simulation Timeout!");
        $finish;
    end

endmodule
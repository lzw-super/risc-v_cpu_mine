// ==============================
// PC模块 Testbench
// ==============================

`timescale 1ns/1ps

module tb_pc;

    // 输入信号
    reg clk;
    reg reset;
    reg [31:0] jmp;
    reg jmp_en;
    reg branch_en;

    // 输出信号
    wire [31:0] curr_pc;
    wire [31:0] next_pc;

    // 实例化PC模块
    pc u_pc (
        .clk(clk),
        .reset(reset),
        .jmp(jmp),
        .jmp_en(jmp_en),
        .branch_en(branch_en),
        .curr_pc(curr_pc),
        .next_pc(next_pc)
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

    // 测试主程序
    initial begin
        // 初始化信号
        reset = 0;
        jmp = 32'h0;
        jmp_en = 0;
        branch_en = 0;

        $display("========================================");
        $display("PC Module Test Start");
        $display("========================================");

        // ==================== 测试1: Reset ====================
        $display("\n[Test 1] Reset Test");
        #1;
        reset = 1;
        wait_cycles(2);
        if (curr_pc === 32'h0 && next_pc === 32'h0) begin
            $display("[PASS] Reset: curr_pc = %h, next_pc = %h", curr_pc, next_pc);
        end else begin
            $display("[FAIL] Reset: curr_pc = %h, next_pc = %h (expected 0)", curr_pc, next_pc);
        end

        // ==================== 测试2: 正常PC递增 ====================
        $display("\n[Test 2] Normal PC Increment");
        reset = 0;
        wait_cycles(1);

        // 检查PC是否正常递增
        repeat(5) begin
            @(posedge clk);
            #1;
            $display("PC: curr_pc = %h, next_pc = %h", curr_pc, next_pc);
        end

        // ==================== 测试3: Jump跳转 ====================
        $display("\n[Test 3] Jump Test");
        wait_cycles(1);
        jmp = 32'h1000;
        jmp_en = 1;
        wait_cycles(1);
        jmp_en = 0;

        wait_cycles(2);
        $display("After Jump to 0x1000: curr_pc = %h, next_pc = %h", curr_pc, next_pc);
        if (curr_pc == 32'h1000) begin
            $display("[PASS] Jump works correctly");
        end else begin
            $display("[FAIL] Jump: curr_pc = %h (expected 0x1000)", curr_pc);
        end

        // 继续运行几个周期，检查PC是否从新位置继续递增
        wait_cycles(3);

        // ==================== 测试4: Branch分支 ====================
        $display("\n[Test 4] Branch Test");
        branch_en = 1;
        jmp = 32'h2000;
        wait_cycles(1);
        branch_en = 0;

        wait_cycles(2);
        $display("After Branch to 0x2000: curr_pc = %h, next_pc = %h", curr_pc, next_pc);
        if (curr_pc == 32'h2000) begin
            $display("[PASS] Branch works correctly");
        end else begin
            $display("[FAIL] Branch: curr_pc = %h (expected 0x2000)", curr_pc);
        end

        wait_cycles(3);

        // ==================== 测试5: Reset恢复 ====================
        $display("\n[Test 5] Reset Recovery Test");
        reset = 1;
        wait_cycles(2);
        if (curr_pc === 32'h0 && next_pc === 32'h0) begin
            $display("[PASS] Reset Recovery: curr_pc = %h, next_pc = %h", curr_pc, next_pc);
        end else begin
            $display("[FAIL] Reset Recovery: curr_pc = %h, next_pc = %h", curr_pc, next_pc);
        end

        reset = 0;
        wait_cycles(3);

        // ==================== 测试结束 ====================
        $display("\n========================================");
        $display("PC Module Test Completed");
        $display("========================================");

        #100;
        $finish;
    end

    // 生成波形文件
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_pc);
    end

    // 仿真时间限制
    initial begin
        #10000;
        $display("Simulation Timeout!");
        $finish;
    end

endmodule
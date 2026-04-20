// ==============================
// CPU顶层模块 Testbench
// ==============================

`timescale 1ns/1ps

module tb_cpu;

    // 输入信号
    reg clk;
    reg reset;

    // 实例化CPU模块
    cpu_mine u_cpu (
        .clk(clk),
        .reset(reset)
    );

    // 时钟生成 - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试任务：等待若干时钟周期
    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // 监控PC和关键信号
    always @(posedge clk) begin
        #1;  // 等待信号稳定
        if (!reset) begin
            $display("Time=%0t: PC=%h, INSTR=%h",
                     $time, u_cpu.CURR_PC, u_cpu.INSTR);
            $display("         DATA1=%h, DATA2=%h, ALU=%h, OPCODE=%h",
                     u_cpu.DATA1, u_cpu.DATA2, u_cpu.ALU_OUTPUT, u_cpu.OPCODE);
            $display("         WB=%h, W_ADDR=%d, W_EN=%b",
                     u_cpu.WB_DATA, u_cpu.W_ADDRESS, u_cpu.W_ENABLE);
            $display("         RS1_VAL=%h, RS2_VAL=%h, IMM=%h",
                     u_cpu.RS1_VALUE, u_cpu.RS2_VALUE, u_cpu.IMM_NUMBER);
            $display("         PC_EN=%b, IMM_EN=%b",
                     u_cpu.PC_ENABLE, u_cpu.IMM_ENABLE);
        end
    end

    // 测试主程序
    initial begin
        $display("========================================");
        $display("CPU Module Test Start");
        $display("========================================");

        $display("\n[Test Instructions]");
        $display("Testing LUI, ADDI, SW, LW, SH, LH instructions");

        // 初始化并复位
        reset = 1;
        wait_cycles(2);

        // 释放复位
        reset = 0;
        $display("\n[Test 1] Reset complete, starting execution...");

        // 运行足够多的周期以完成所有指令
        wait_cycles(25);

        // 检查结果
        $display("\n========================================");
        $display("Test Results Check:");
        $display("========================================");

        // 检查寄存器值（x0始终为0）
        $display("x5        = %h (expected: 0x1f1f1f1f from LUI+ADDI)", u_cpu.u_regfile.regfile[5]);
        $display("x7        = %h (expected: 0xffffff00 from ADDI)", u_cpu.u_regfile.regfile[7]);
        $display("x8        = %h", u_cpu.u_regfile.regfile[8]);

        // 检查数据内存
        $display("\nData Memory Check:");
        $display("mem[0-3]  = %h %h %h %h", u_cpu.u_datamem.mem_mine.mem[0],
                 u_cpu.u_datamem.mem_mine.mem[1], u_cpu.u_datamem.mem_mine.mem[2],
                 u_cpu.u_datamem.mem_mine.mem[3]);

        // 验证结果
        $display("\n========================================");
        if (u_cpu.u_regfile.regfile[5] == 32'h1f1f1f1f) begin
            $display("[PASS] LUI + ADDI test for x5");
        end else begin
            $display("[FAIL] x5 = %h (expected 0x1f1f1f1f)", u_cpu.u_regfile.regfile[5]);
        end

        if (u_cpu.u_regfile.regfile[7] == 32'hffffff00) begin
            $display("[PASS] ADDI negative test for x7");
        end else begin
            $display("[FAIL] x7 = %h (expected 0xffffff00)", u_cpu.u_regfile.regfile[7]);
        end

        // 检查SW是否正确写入内存
        if ({u_cpu.u_datamem.mem_mine.mem[0], u_cpu.u_datamem.mem_mine.mem[1],
             u_cpu.u_datamem.mem_mine.mem[2], u_cpu.u_datamem.mem_mine.mem[3]} == 32'h1f1f1f1f) begin
            $display("[PASS] SW test - memory[0] = x5 value");
        end else begin
            $display("[FAIL] SW test - memory[0] != expected");
        end

        $display("========================================");
        $display("CPU Module Test Completed");
        $display("========================================");

        #100;
        $finish;
    end

    // 生成波形文件
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_cpu);
    end

    // 仿真时间限制
    initial begin
        #10000;
        $display("Simulation Timeout!");
        $finish;
    end

endmodule
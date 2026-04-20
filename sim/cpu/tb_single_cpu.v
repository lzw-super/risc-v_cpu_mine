// ==============================
// CPU顶层模块 Testbench - 单周期CPU功能验证
// 使用 INST_rom_single_cpu.txt 指令集
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

    // 指令计数器
    integer instr_count;
    integer cycle_count;
    reg [31:0] prev_pc;

    // 监控每个周期的执行状态
    always @(posedge clk) begin
        if (!reset && u_cpu.CURR_PC != prev_pc) begin
            cycle_count = cycle_count + 1;
            $display("\n=== Cycle %0d ===", cycle_count);
            $display("PC=%h, INSTR=%h", u_cpu.CURR_PC, u_cpu.INSTR);
            $display("Opcode=%b, funct3=%b", u_cpu.INSTR[6:0], u_cpu.INSTR[14:12]);
            $display("rs1_addr=%d, rs2_addr=%d, wd_addr=%d",
                     u_cpu.RS1_ADDR, u_cpu.RS2_ADDR, u_cpu.W_ADDRESS);
            $display("rs1_val=%h, rs2_val=%h", u_cpu.RS1_VALUE, u_cpu.RS2_VALUE);
            $display("imm=%h, DATA1=%h, DATA2=%h", u_cpu.IMM_NUMBER, u_cpu.DATA1, u_cpu.DATA2);
            $display("ALU_OUT=%h, WB_DATA=%h", u_cpu.ALU_OUTPUT, u_cpu.WB_DATA);
            $display("re1=%b, re2=%b, we=%b, imme=%b, pce=%b, jmpe=%b",
                     u_cpu.RS1_ENABLE, u_cpu.RS2_ENABLE, u_cpu.W_ENABLE,
                     u_cpu.IMM_ENABLE, u_cpu.PC_ENABLE, u_cpu.JUMP_ENABLE);

            // 显示关键寄存器值
            $display("Regfile: x10=%h, x11=%h, x12=%h, x13=%h, x14=%h, x20=%h",
                     u_cpu.u_regfile.regfile[10],
                     u_cpu.u_regfile.regfile[11],
                     u_cpu.u_regfile.regfile[12],
                     u_cpu.u_regfile.regfile[13],
                     u_cpu.u_regfile.regfile[14],
                     u_cpu.u_regfile.regfile[20]);

            prev_pc = u_cpu.CURR_PC;

            // 检测循环（JAL回跳）
            if (u_cpu.JUMP_ENABLE && u_cpu.ALU_OUTPUT < u_cpu.CURR_PC) begin
                $display("*** JAL backward jump detected! Entering loop mode ***");
            end

            // 检测NOP/结束
            if (u_cpu.INSTR == 32'h00000013 || u_cpu.INSTR == 32'h00000000) begin
                $display("*** NOP/END instruction detected ***");
            end
        end
    end

    // 测试主程序
    initial begin
        $display("========================================");
        $display("Single-Cycle CPU Test Start");
        $display("INST_rom_single_cpu.txt instructions:");
        $display("  0x00: ADDI x10, x0, 9");
        $display("  0x04: ADDI x11, x0, 6");
        $display("  0x08: ADDI x14, x0, 0");
        $display("  0x0c: ADD  x12, x10, x11");
        $display("  0x10: SUB  x13, x10, x11");
        $display("  0x14: ADD  x12, x12, x11");
        $display("  0x18: ADDI x14, x14, 5");
        $display("  0x1c: JAL  x20, -8 (loop)");
        $display("  0x20: NOP");
        $display("========================================");

        cycle_count = 0;
        prev_pc = 32'h0;

        // 复位CPU
        reset = 1;
        repeat(2) @(posedge clk);

        // 释放复位
        reset = 0;
        $display("\n[Reset Complete] Starting CPU execution...");

        // 等待执行完成（运行足够周期观察循环）
        repeat(20) @(posedge clk);

        // 等待一个下降沿让写回完成
        @(negedge clk);

        // ==================== 验证结果 ====================
        $display("\n========================================");
        $display("Execution Results Verification:");
        $display("========================================");

        // 检查寄存器值
        $display("\nRegister Values:");
        $display("x10 (a0)     = %h (expected: 0x00000009)", u_cpu.u_regfile.regfile[10]);
        $display("x11 (a1)     = %h (expected: 0x00000006)", u_cpu.u_regfile.regfile[11]);
        $display("x12 (a2)     = %h (expected: 0x00000012)", u_cpu.u_regfile.regfile[12]);
        $display("x13 (a3)     = %h (expected: 0x00000003)", u_cpu.u_regfile.regfile[13]);
        $display("x14 (a4)     = %h (expected: 0x00000005)", u_cpu.u_regfile.regfile[14]);
        $display("x20 (s4)     = %h (return address from JAL)", u_cpu.u_regfile.regfile[20]);

        // 验证测试用例
        $display("\n========================================");
        $display("Test Results:");
        $display("========================================");

        // Test 1: ADDI x10, x0, 9
        if (u_cpu.u_regfile.regfile[10] == 32'h00000009) begin
            $display("[PASS] ADDI x10, x0, 9 -> x10 = 9");
        end else begin
            $display("[FAIL] ADDI x10, x0, 9 -> x10 = %h (expected 9)", u_cpu.u_regfile.regfile[10]);
        end

        // Test 2: ADDI x11, x0, 6
        if (u_cpu.u_regfile.regfile[11] == 32'h00000006) begin
            $display("[PASS] ADDI x11, x0, 6 -> x11 = 6");
        end else begin
            $display("[FAIL] ADDI x11, x0, 6 -> x11 = %h (expected 6)", u_cpu.u_regfile.regfile[11]);
        end

        // Test 3: ADD x12, x10, x11 (9 + 6 = 15)
        if (u_cpu.u_regfile.regfile[12] == 32'h0000000f) begin
            $display("[PASS] ADD x12, x10, x11 -> x12 = 15");
        end else begin
            $display("[FAIL] ADD x12, x10, x11 -> x12 = %h (expected 15)", u_cpu.u_regfile.regfile[12]);
        end

        // Test 4: SUB x13, x10, x11 (9 - 6 = 3)
        if (u_cpu.u_regfile.regfile[13] == 32'h00000003) begin
            $display("[PASS] SUB x13, x10, x11 -> x13 = 3");
        end else begin
            $display("[FAIL] SUB x13, x10, x11 -> x13 = %h (expected 3)", u_cpu.u_regfile.regfile[13]);
        end

        // Test 5: ADD x12, x12, x11 (15 + 6 = 21, but loop may affect this)
        // 注意：由于JAL循环，x12可能会被多次更新
        $display("[INFO] ADD x12, x12, x11 -> x12 = %h (may vary due to loop)", u_cpu.u_regfile.regfile[12]);

        // Test 6: ADDI x14, x14, 5 (0 + 5 = 5, but loop adds more)
        $display("[INFO] ADDI x14, x14, 5 -> x14 = %h (may vary due to loop)", u_cpu.u_regfile.regfile[14]);

        // Test 7: JAL x20, -8 (should save return address)
        if (u_cpu.u_regfile.regfile[20] == 32'h00000020) begin
            $display("[PASS] JAL x20, -8 -> x20 = 0x20 (return address)");
        end else begin
            $display("[FAIL] JAL x20, -8 -> x20 = %h (expected 0x20)", u_cpu.u_regfile.regfile[20]);
        end

        $display("\n========================================");
        $display("Single-Cycle CPU Test Completed");
        $display("Total cycles executed: %0d", cycle_count);
        $display("========================================");

        #100;
        $finish;
    end

    // 生成波形文件
    initial begin
        $fsdbDumpfile("single_cpu_wave.fsdb");
        $fsdbDumpvars(0, tb_cpu);
    end

    // 仿真时间限制
    initial begin
        #50000;
        $display("\nSimulation Timeout!");
        $finish;
    end

endmodule
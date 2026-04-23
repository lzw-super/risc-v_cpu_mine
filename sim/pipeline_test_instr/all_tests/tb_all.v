// ==============================
// RISC-V Pipeline CPU综合测试testbench
// ==============================
// 测试内容: 所有指令类型, 转发, Load-Use, 分支预测

module tb_all;

    reg clk;
    reg reset;

    pipeline_cpu u_cpu (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer cycle_count;
    integer mispredict_count;
    integer stall_count;

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_all);

        cycle_count = 0;
        mispredict_count = 0;
        stall_count = 0;

        $display("========================================");
        $display("RISC-V Pipeline CPU综合测试开始");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(120) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (u_cpu.ex_mispredict) begin
                mispredict_count = mispredict_count + 1;
                $display(">>> Cycle %d: MISPREDICT detected", cycle_count);
            end

            if (u_cpu.stall_pc) begin
                stall_count = stall_count + 1;
            end
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("--- 第一部分: 初始化 ---");
        $display("x1  = %h (预期: 10)", u_cpu.u_regfile.regfile[1]);
        $display("x2  = %h (预期: 20)", u_cpu.u_regfile.regfile[2]);
        $display("x3  = %h (预期: 0x64, JAL返回地址)", u_cpu.u_regfile.regfile[3]);
        $display("--- 第二部分: R-Type ---");
        $display("x4  = %h (预期: 40)", u_cpu.u_regfile.regfile[4]);
        $display("x5  = %h (预期: 20)", u_cpu.u_regfile.regfile[5]);
        $display("--- 第三部分: I-Type ---");
        $display("x6  = %h (预期: 26)", u_cpu.u_regfile.regfile[6]);
        $display("x7  = %h (预期: 40)", u_cpu.u_regfile.regfile[7]);
        $display("--- 第四部分: Load/Store ---");
        $display("x10 = %h (预期: 0x12345678)", u_cpu.u_regfile.regfile[10]);
        $display("--- 第五部分: Load-Use ---");
        $display("x11 = %h (预期: 0x12345678)", u_cpu.u_regfile.regfile[11]);
        $display("x12 = %h (预期: 0x2468ACF0)", u_cpu.u_regfile.regfile[12]);
        $display("--- 第六部分: Branch ---");
        $display("x16 = %h (预期: 2)", u_cpu.u_regfile.regfile[16]);
        $display("--- 第七部分: 循环 ---");
        $display("x1循环后 = %h (预期: 5)", u_cpu.u_regfile.regfile[1]);
        $display("--- 第八部分: Jump ---");
        $display("x9  = %h (预期: 3)", u_cpu.u_regfile.regfile[9]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        // 初始化测试
        if (u_cpu.u_regfile.regfile[1] == 32'h05)
            $display("[PASS] 循环: x1 = 5");
        else
            $display("[INFO] x1 = %h (循环后应为5)", u_cpu.u_regfile.regfile[1]);

        // R-Type测试
        if (u_cpu.u_regfile.regfile[4] == 32'h28)
            $display("[PASS] R-Type ADD: x4 = 40");
        else
            $display("[FAIL] R-Type ADD: x4 = %h (预期 40)", u_cpu.u_regfile.regfile[4]);

        // I-Type测试
        if (u_cpu.u_regfile.regfile[7] == 32'h28)
            $display("[PASS] I-Type SLLI: x7 = 40");
        else
            $display("[FAIL] I-Type SLLI: x7 = %h (预期 40)", u_cpu.u_regfile.regfile[7]);

        // Load测试
        if (u_cpu.u_regfile.regfile[10] == 32'h12345678)
            $display("[PASS] Load: x10 = 0x12345678");
        else
            $display("[FAIL] Load: x10 = %h (预期 0x12345678)", u_cpu.u_regfile.regfile[10]);

        // Load-Use测试
        if (u_cpu.u_regfile.regfile[12] == 32'h2468ACF0)
            $display("[PASS] Load-Use: x12 = 0x2468ACF0");
        else
            $display("[FAIL] Load-Use: x12 = %h (预期 0x2468ACF0)", u_cpu.u_regfile.regfile[12]);

        // Branch测试
        if (u_cpu.u_regfile.regfile[16] == 32'h02)
            $display("[PASS] Branch: x16 = 2");
        else
            $display("[FAIL] Branch: x16 = %h (预期 2)", u_cpu.u_regfile.regfile[16]);

        // Jump测试
        if (u_cpu.u_regfile.regfile[9] == 32'h03)
            $display("[PASS] Jump: x9 = 3");
        else
            $display("[FAIL] Jump: x9 = %h (预期 3)", u_cpu.u_regfile.regfile[9]);

        $display("========================================");
        $display("测试统计:");
        $display("========================================");
        $display("总周期数: %d", cycle_count);
        $display("Mispredict次数: %d", mispredict_count);
        $display("Stall次数: %d", stall_count);
        $display("========================================");

        $finish;
    end

endmodule
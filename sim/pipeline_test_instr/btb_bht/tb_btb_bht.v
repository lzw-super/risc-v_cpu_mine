// ==============================
// RISC-V BTB/BHT动态分支预测测试testbench
// ==============================
module tb_btb_bht;
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

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_btb_bht);

        cycle_count = 0;
        mispredict_count = 0;

        $display("========================================");
        $display("RISC-V BTB/BHT动态分支预测测试开始");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(350) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // 监测mispredict
            if (u_cpu.ex_mispredict) begin
                mispredict_count = mispredict_count + 1;
                if (cycle_count <= 100)
                    $display(">>> Cycle %d: MISPREDICT detected", cycle_count);
            end
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("x1 = %h (预期: 10)", u_cpu.u_regfile.regfile[1]);
        $display("x2 = %h (预期: 10)", u_cpu.u_regfile.regfile[2]);
        $display("x3 = %h (预期: 1)", u_cpu.u_regfile.regfile[3]);
        $display("x4 = %h (预期: 5)", u_cpu.u_regfile.regfile[4]);
        $display("x5 = %h (预期: 5)", u_cpu.u_regfile.regfile[5]);
        $display("x7 = %h (预期: 1)", u_cpu.u_regfile.regfile[7]);
        $display("x8 = %h (预期: 100)", u_cpu.u_regfile.regfile[8]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        if (u_cpu.u_regfile.regfile[1] == 32'h0A)
            $display("[PASS] 外层循环: x1 = 10 (循环10次)");
        else
            $display("[FAIL] 外层循环: x1 = %h (预期 10)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[4] == 32'h05)
            $display("[PASS] 内层循环: x4 = 5");
        else
            $display("[FAIL] 内层循环: x4 = %h (预期 5)", u_cpu.u_regfile.regfile[4]);

        $display("[INFO] Mispredict次数: %d", mispredict_count);
        if (mispredict_count >= 2)
            $display("[PASS] 分支预测测试: 检测到mispredict");
        else
            $display("[FAIL] 分支预测测试: 未检测到足够的mispredict");

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end
endmodule

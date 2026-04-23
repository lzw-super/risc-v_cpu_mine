// ==============================
// RISC-V RAW冒险转发测试testbench
// ==============================
module tb_hazard_forward;
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

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_hazard_forward);

        cycle_count = 0;
        $display("========================================");
        $display("RISC-V RAW冒险转发测试开始");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(50) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("--- 基础转发测试 ---");
        $display("x1 = %h (预期: 5)", u_cpu.u_regfile.regfile[1]);
        $display("x2 = %h (预期: 15)", u_cpu.u_regfile.regfile[2]);
        $display("x3 = %h (预期: 20)", u_cpu.u_regfile.regfile[3]);
        $display("--- 多级转发测试 ---");
        $display("x4 = %h (预期: 35)", u_cpu.u_regfile.regfile[4]);
        $display("x5 = %h (预期: 70)", u_cpu.u_regfile.regfile[5]);
        $display("--- 无转发测试 ---");
        $display("x6 = %h (预期: 100)", u_cpu.u_regfile.regfile[6]);
        $display("x7 = %h (预期: 200)", u_cpu.u_regfile.regfile[7]);
        $display("--- MEM/WB转发测试 ---");
        $display("x10 = %h (预期: 3)", u_cpu.u_regfile.regfile[10]);
        $display("x11 = %h (预期: 6)", u_cpu.u_regfile.regfile[11]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        if (u_cpu.u_regfile.regfile[1] == 32'h05)
            $display("[PASS] x1 = 5");
        else
            $display("[FAIL] x1 = %h (预期 5)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[2] == 32'h0F)
            $display("[PASS] 转发: x2 = 15 (x1+10)");
        else
            $display("[FAIL] 转发: x2 = %h (预期 15)", u_cpu.u_regfile.regfile[2]);

        if (u_cpu.u_regfile.regfile[3] == 32'h14)
            $display("[PASS] 转发: x3 = 20 (x1+x2)");
        else
            $display("[FAIL] 转发: x3 = %h (预期 20)", u_cpu.u_regfile.regfile[3]);

        if (u_cpu.u_regfile.regfile[4] == 32'h23)
            $display("[PASS] 多级转发: x4 = 35 (x3+x2)");
        else
            $display("[FAIL] 多级转发: x4 = %h (预期 35)", u_cpu.u_regfile.regfile[4]);

        if (u_cpu.u_regfile.regfile[5] == 32'h46)
            $display("[PASS] 多级转发: x5 = 70 (x4+x4)");
        else
            $display("[FAIL] 多级转发: x5 = %h (预期 70)", u_cpu.u_regfile.regfile[5]);

        if (u_cpu.u_regfile.regfile[7] == 32'hC8)
            $display("[PASS] 无转发: x7 = 200 (x6+x6)");
        else
            $display("[FAIL] 无转发: x7 = %h (预期 200)", u_cpu.u_regfile.regfile[7]);

        if (u_cpu.u_regfile.regfile[11] == 32'h06)
            $display("[PASS] MEM/WB转发: x11 = 6");
        else
            $display("[FAIL] MEM/WB转发: x11 = %h (预期 6)", u_cpu.u_regfile.regfile[11]);

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end
endmodule
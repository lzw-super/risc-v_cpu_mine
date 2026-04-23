// ==============================
// RISC-V Load/Store指令测试testbench
// ==============================
// 测试内容: LB, LH, LW, LBU, LHU, SB, SH, SW, Load-Use冒险

module tb_load_store;

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
    integer stall_count;

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_load_store);

        cycle_count = 0;
        stall_count = 0;

        $display("========================================");
        $display("RISC-V Load/Store指令测试开始");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(60) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // 监测Load-Use stall
            if (u_cpu.stall_pc) begin
                stall_count = stall_count + 1;
                if (cycle_count <= 30)
                    $display(">>> Cycle %d: Load-Use stall detected", cycle_count);
            end
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("x1  = %h (预期: 0x100)", u_cpu.u_regfile.regfile[1]);
        $display("x2  = %h (预期: 0x12345678)", u_cpu.u_regfile.regfile[2]);
        $display("x10 = %h (预期: 0x80)", u_cpu.u_regfile.regfile[10]);
        $display("--- Word测试 ---");
        $display("x3  = %h (预期: 0x12345678, LW)", u_cpu.u_regfile.regfile[3]);
        $display("--- Byte测试 ---");
        $display("x4  = %h (预期: 0xFFFFFF80, LB有符号)", u_cpu.u_regfile.regfile[4]);
        $display("x5  = %h (预期: 0x80, LBU无符号)", u_cpu.u_regfile.regfile[5]);
        $display("--- Halfword测试 ---");
        $display("x6  = %h (预期: 0x5678, LH)", u_cpu.u_regfile.regfile[6]);
        $display("x7  = %h (预期: 0x5678, LHU)", u_cpu.u_regfile.regfile[7]);
        $display("--- Load-Use测试 ---");
        $display("x8  = %h (预期: 0x12345678)", u_cpu.u_regfile.regfile[8]);
        $display("x9  = %h (预期: 0x2468ACF0)", u_cpu.u_regfile.regfile[9]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        if (u_cpu.u_regfile.regfile[1] == 32'h100)
            $display("[PASS] x1 = 0x100");
        else
            $display("[FAIL] x1 = %h (预期 0x100)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[2] == 32'h12345678)
            $display("[PASS] x2 = 0x12345678");
        else
            $display("[FAIL] x2 = %h (预期 0x12345678)", u_cpu.u_regfile.regfile[2]);

        if (u_cpu.u_regfile.regfile[3] == 32'h12345678)
            $display("[PASS] LW: x3 = 0x12345678");
        else
            $display("[FAIL] LW: x3 = %h (预期 0x12345678)", u_cpu.u_regfile.regfile[3]);

        if (u_cpu.u_regfile.regfile[4] == 32'hFFFFFF80)
            $display("[PASS] LB: x4 = 0xFFFFFF80 (有符号扩展)");
        else
            $display("[FAIL] LB: x4 = %h (预期 0xFFFFFF80)", u_cpu.u_regfile.regfile[4]);

        if (u_cpu.u_regfile.regfile[5] == 32'h80)
            $display("[PASS] LBU: x5 = 0x80 (无符号)");
        else
            $display("[FAIL] LBU: x5 = %h (预期 0x80)", u_cpu.u_regfile.regfile[5]);

        if (u_cpu.u_regfile.regfile[6] == 32'h5678)
            $display("[PASS] LH: x6 = 0x5678");
        else
            $display("[FAIL] LH: x6 = %h (预期 0x5678)", u_cpu.u_regfile.regfile[6]);

        if (u_cpu.u_regfile.regfile[7] == 32'h5678)
            $display("[PASS] LHU: x7 = 0x5678");
        else
            $display("[FAIL] LHU: x7 = %h (预期 0x5678)", u_cpu.u_regfile.regfile[7]);

        if (u_cpu.u_regfile.regfile[8] == 32'h12345678)
            $display("[PASS] Load-Use: x8 = 0x12345678");
        else
            $display("[FAIL] Load-Use: x8 = %h (预期 0x12345678)", u_cpu.u_regfile.regfile[8]);

        if (u_cpu.u_regfile.regfile[9] == 32'h2468ACF0)
            $display("[PASS] Load-Use: x9 = 0x2468ACF0 (正确计算)");
        else
            $display("[FAIL] Load-Use: x9 = %h (预期 0x2468ACF0)", u_cpu.u_regfile.regfile[9]);

        if (stall_count >= 1)
            $display("[PASS] Load-Use stall检测: 检测到%d次stall", stall_count);
        else
            $display("[FAIL] Load-Use stall检测: 未检测到stall");

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end

endmodule
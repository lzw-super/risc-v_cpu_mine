// ==============================
// RISC-V R-Type指令测试testbench
// ==============================
// 测试内容: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND

module tb_r_type;

    reg clk;
    reg reset;

    // 实例化流水线CPU
    pipeline_cpu u_cpu (
        .clk(clk),
        .reset(reset)
    );

    // 时钟生成: 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer cycle_count;

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_r_type);

        cycle_count = 0;

        $display("========================================");
        $display("RISC-V R-Type指令测试开始");
        $display("========================================");

        // 复位序列
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        // 执行足够周期完成所有测试
        repeat(60) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // 最终寄存器状态
        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("x1  = %h (预期: 0x0A = 10)", u_cpu.u_regfile.regfile[1]);
        $display("x2  = %h (预期: 0x0F = 15)", u_cpu.u_regfile.regfile[2]);
        $display("x3  = %h (预期: 0x14 = 20)", u_cpu.u_regfile.regfile[3]);
        $display("x4  = %h (预期: 0x04 = 4)", u_cpu.u_regfile.regfile[4]);
        $display("--- R-Type算术结果 ---");
        $display("x5  = %h (预期: 0x1E = 30, ADD)", u_cpu.u_regfile.regfile[5]);
        $display("x6  = %h (预期: 0x0A = 10, SUB)", u_cpu.u_regfile.regfile[6]);
        $display("x7  = %h (预期: 0xA0 = 160, SLL)", u_cpu.u_regfile.regfile[7]);
        $display("x8  = %h (预期: 0x01, SLT)", u_cpu.u_regfile.regfile[8]);
        $display("x9  = %h (预期: 0x00, SLTU)", u_cpu.u_regfile.regfile[9]);
        $display("--- R-Type逻辑结果 ---");
        $display("x10 = %h (预期: 0x1E = 30, XOR)", u_cpu.u_regfile.regfile[10]);
        $display("x11 = %h (预期: 0x01, SRL)", u_cpu.u_regfile.regfile[11]);
        $display("x12 = %h (预期: 0x01, SRA)", u_cpu.u_regfile.regfile[12]);
        $display("x13 = %h (预期: 0x1E = 30, OR)", u_cpu.u_regfile.regfile[13]);
        $display("x14 = %h (预期: 0x0A = 10, AND)", u_cpu.u_regfile.regfile[14]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        // 验证结果
        if (u_cpu.u_regfile.regfile[1] == 32'h0A)
            $display("[PASS] x1 = 10");
        else
            $display("[FAIL] x1 = %h (预期 10)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[2] == 32'h0F)
            $display("[PASS] x2 = 15");
        else
            $display("[FAIL] x2 = %h (预期 15)", u_cpu.u_regfile.regfile[2]);

        if (u_cpu.u_regfile.regfile[3] == 32'h14)
            $display("[PASS] x3 = 20");
        else
            $display("[FAIL] x3 = %h (预期 20)", u_cpu.u_regfile.regfile[3]);

        if (u_cpu.u_regfile.regfile[4] == 32'h04)
            $display("[PASS] x4 = 4");
        else
            $display("[FAIL] x4 = %h (预期 4)", u_cpu.u_regfile.regfile[4]);

        if (u_cpu.u_regfile.regfile[5] == 32'h1E)
            $display("[PASS] ADD: x5 = 30");
        else
            $display("[FAIL] ADD: x5 = %h (预期 30)", u_cpu.u_regfile.regfile[5]);

        if (u_cpu.u_regfile.regfile[6] == 32'h0A)
            $display("[PASS] SUB: x6 = 10");
        else
            $display("[FAIL] SUB: x6 = %h (预期 10)", u_cpu.u_regfile.regfile[6]);

        if (u_cpu.u_regfile.regfile[7] == 32'hA0)
            $display("[PASS] SLL: x7 = 160");
        else
            $display("[FAIL] SLL: x7 = %h (预期 160)", u_cpu.u_regfile.regfile[7]);

        if (u_cpu.u_regfile.regfile[8] == 32'h01)
            $display("[PASS] SLT: x8 = 1");
        else
            $display("[FAIL] SLT: x8 = %h (预期 1)", u_cpu.u_regfile.regfile[8]);

        if (u_cpu.u_regfile.regfile[9] == 32'h00)
            $display("[PASS] SLTU: x9 = 0");
        else
            $display("[FAIL] SLTU: x9 = %h (预期 0)", u_cpu.u_regfile.regfile[9]);

        if (u_cpu.u_regfile.regfile[10] == 32'h1E)
            $display("[PASS] XOR: x10 = 30");
        else
            $display("[FAIL] XOR: x10 = %h (预期 30)", u_cpu.u_regfile.regfile[10]);

        if (u_cpu.u_regfile.regfile[11] == 32'h01)
            $display("[PASS] SRL: x11 = 1");
        else
            $display("[FAIL] SRL: x11 = %h (预期 1)", u_cpu.u_regfile.regfile[11]);

        if (u_cpu.u_regfile.regfile[12] == 32'h01)
            $display("[PASS] SRA: x12 = 1");
        else
            $display("[FAIL] SRA: x12 = %h (预期 1)", u_cpu.u_regfile.regfile[12]);

        if (u_cpu.u_regfile.regfile[13] == 32'h1E)
            $display("[PASS] OR: x13 = 30");
        else
            $display("[FAIL] OR: x13 = %h (预期 30)", u_cpu.u_regfile.regfile[13]);

        if (u_cpu.u_regfile.regfile[14] == 32'h0A)
            $display("[PASS] AND: x14 = 10");
        else
            $display("[FAIL] AND: x14 = %h (预期 10)", u_cpu.u_regfile.regfile[14]);

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end

endmodule
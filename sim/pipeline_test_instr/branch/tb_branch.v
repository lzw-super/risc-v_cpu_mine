// ==============================
// RISC-V Branch指令测试testbench
// ==============================
module tb_branch;
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
        $fsdbDumpvars(0, tb_branch);

        cycle_count = 0;
        $display("========================================");
        $display("RISC-V Branch指令测试开始");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(80) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("x1  = %h (预期: 10)", u_cpu.u_regfile.regfile[1]);
        $display("x2  = %h (预期: 10)", u_cpu.u_regfile.regfile[2]);
        $display("x3  = %h (预期: 20)", u_cpu.u_regfile.regfile[3]);
        $display("x4  = %h (预期: 5)", u_cpu.u_regfile.regfile[4]);
        $display("--- BEQ测试 ---");
        $display("x10 = %h (预期: 2)", u_cpu.u_regfile.regfile[10]);
        $display("--- BNE测试 ---");
        $display("x11 = %h (预期: 3)", u_cpu.u_regfile.regfile[11]);
        $display("--- BLT测试 ---");
        $display("x12 = %h (预期: 4)", u_cpu.u_regfile.regfile[12]);
        $display("--- BGE测试 ---");
        $display("x13 = %h (预期: 5)", u_cpu.u_regfile.regfile[13]);
        $display("x14 = %h (预期: 6)", u_cpu.u_regfile.regfile[14]);
        $display("--- BLTU测试 ---");
        $display("x18 = %h (预期: 7)", u_cpu.u_regfile.regfile[18]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        if (u_cpu.u_regfile.regfile[10] == 32'h02)
            $display("[PASS] BEQ: x10 = 2");
        else
            $display("[FAIL] BEQ: x10 = %h (预期 2)", u_cpu.u_regfile.regfile[10]);

        if (u_cpu.u_regfile.regfile[11] == 32'h03)
            $display("[PASS] BNE: x11 = 3");
        else
            $display("[FAIL] BNE: x11 = %h (预期 3)", u_cpu.u_regfile.regfile[11]);

        if (u_cpu.u_regfile.regfile[12] == 32'h04)
            $display("[PASS] BLT: x12 = 4");
        else
            $display("[FAIL] BLT: x12 = %h (预期 4)", u_cpu.u_regfile.regfile[12]);

        if (u_cpu.u_regfile.regfile[13] == 32'h05)
            $display("[PASS] BGE: x13 = 5");
        else
            $display("[FAIL] BGE: x13 = %h (预期 5)", u_cpu.u_regfile.regfile[13]);

        if (u_cpu.u_regfile.regfile[18] == 32'h07)
            $display("[PASS] BLTU/BGEU: x18 = 7");
        else
            $display("[FAIL] BLTU/BGEU: x18 = %h (预期 7)", u_cpu.u_regfile.regfile[18]);

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end
endmodule
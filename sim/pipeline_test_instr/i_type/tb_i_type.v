// ==============================
// RISC-V I-Type指令测试testbench
// ==============================
// 测试内容: ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI

module tb_i_type;

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
        $fsdbDumpvars(0, tb_i_type);

        cycle_count = 0;

        $display("========================================");
        $display("RISC-V I-Type指令测试开始");
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
        $display("x1  = %h (预期: 0x64 = 100)", u_cpu.u_regfile.regfile[1]);
        $display("--- I-Type算术结果 ---");
        $display("x2  = %h (预期: 0x32 = 50, ADDI负立即数)", u_cpu.u_regfile.regfile[2]);
        $display("x3  = %h (预期: 0x190 = 400, SLLI)", u_cpu.u_regfile.regfile[3]);
        $display("x4  = %h (预期: 0x01, SLTI)", u_cpu.u_regfile.regfile[4]);
        $display("x5  = %h (预期: 0x00, SLTIU)", u_cpu.u_regfile.regfile[5]);
        $display("--- I-Type逻辑结果 ---");
        $display("x6  = %h (预期: 0x9B = 155, XORI)", u_cpu.u_regfile.regfile[6]);
        $display("x7  = %h (预期: 0x0C = 12, SRLI)", u_cpu.u_regfile.regfile[7]);
        $display("x8  = %h (预期: 0x19 = 25, SRAI)", u_cpu.u_regfile.regfile[8]);
        $display("x9  = %h (预期: 0x6F = 111, ORI)", u_cpu.u_regfile.regfile[9]);
        $display("x10 = %h (预期: 0x60 = 96, ANDI)", u_cpu.u_regfile.regfile[10]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        if (u_cpu.u_regfile.regfile[1] == 32'h64)
            $display("[PASS] x1 = 100");
        else
            $display("[FAIL] x1 = %h (预期 100)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[2] == 32'h32)
            $display("[PASS] ADDI: x2 = 50");
        else
            $display("[FAIL] ADDI: x2 = %h (预期 50)", u_cpu.u_regfile.regfile[2]);

        if (u_cpu.u_regfile.regfile[3] == 32'h190)
            $display("[PASS] SLLI: x3 = 400");
        else
            $display("[FAIL] SLLI: x3 = %h (预期 400)", u_cpu.u_regfile.regfile[3]);

        if (u_cpu.u_regfile.regfile[4] == 32'h01)
            $display("[PASS] SLTI: x4 = 1");
        else
            $display("[FAIL] SLTI: x4 = %h (预期 1)", u_cpu.u_regfile.regfile[4]);

        if (u_cpu.u_regfile.regfile[5] == 32'h00)
            $display("[PASS] SLTIU: x5 = 0");
        else
            $display("[FAIL] SLTIU: x5 = %h (预期 0)", u_cpu.u_regfile.regfile[5]);

        if (u_cpu.u_regfile.regfile[6] == 32'h9B)
            $display("[PASS] XORI: x6 = 155");
        else
            $display("[FAIL] XORI: x6 = %h (预期 155)", u_cpu.u_regfile.regfile[6]);

        if (u_cpu.u_regfile.regfile[7] == 32'h0C)
            $display("[PASS] SRLI: x7 = 12");
        else
            $display("[FAIL] SRLI: x7 = %h (预期 12)", u_cpu.u_regfile.regfile[7]);

        if (u_cpu.u_regfile.regfile[8] == 32'h19)
            $display("[PASS] SRAI: x8 = 25");
        else
            $display("[FAIL] SRAI: x8 = %h (预期 25)", u_cpu.u_regfile.regfile[8]);

        // 正确的预期值: 100 | 15 = 0x64 | 0x0F = 0x6F = 111
        if (u_cpu.u_regfile.regfile[9] == 32'h6F)
            $display("[PASS] ORI: x9 = 111 (100|15=111)");
        else
            $display("[FAIL] ORI: x9 = %h (预期 111)", u_cpu.u_regfile.regfile[9]);

        if (u_cpu.u_regfile.regfile[10] == 32'h60)
            $display("[PASS] ANDI: x10 = 96");
        else
            $display("[FAIL] ANDI: x10 = %h (预期 96)", u_cpu.u_regfile.regfile[10]);

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end

endmodule
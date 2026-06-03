// ==============================
// RISC-V M-Type (RV32M) 乘除法指令测试
// ==============================
// 测试: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
// 包含除零测试

module tb_m_type;

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

    integer pass_count;
    integer fail_count;

    task check;
        input [255:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            if (actual === expected) begin
                $display("[PASS] %0s = %h", name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s = %h (expected %h)", name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_m_type);

        pass_count = 0;
        fail_count = 0;

        $display("========================================");
        $display("RV32M 乘除法指令测试");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成]");

        // 迭代式 MDU 每条乘除法约 33 个周期
        repeat(950) @(posedge clk);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        // 设置寄存器
        check("x1 (ADDI 10)",  u_cpu.u_regfile.regfile[1],  32'hA);
        check("x2 (ADDI 3)",   u_cpu.u_regfile.regfile[2],  32'h3);
        check("x3 (ADDI 20)",  u_cpu.u_regfile.regfile[3],  32'h14);
        check("x4 (ADDI 6)",   u_cpu.u_regfile.regfile[4],  32'h6);
        check("x5 (ADDI -1)",  u_cpu.u_regfile.regfile[5],  32'hFFFFFFFF);

        // MUL
        check("x6  (MUL 10*3)",      u_cpu.u_regfile.regfile[6],  32'h1E);
        check("x7  (MUL -1*3)",      u_cpu.u_regfile.regfile[7],  32'hFFFFFFFD);

        // MULH
        check("x8  (MULH -1*3 hi)",  u_cpu.u_regfile.regfile[8],  32'hFFFFFFFF);

        // MULHU
        check("x9  (MULHU 0xFFFF..*3 hi)", u_cpu.u_regfile.regfile[9],  32'h2);

        // MULHSU
        check("x10 (MULHSU -1*3 hi)", u_cpu.u_regfile.regfile[10], 32'hFFFFFFFF);

        // DIV
        check("x11 (DIV 20/6)",       u_cpu.u_regfile.regfile[11], 32'h3);
        check("x12 (DIV -1/3)",       u_cpu.u_regfile.regfile[12], 32'h0);

        // DIVU
        check("x13 (DIVU 20/6)",      u_cpu.u_regfile.regfile[13], 32'h3);
        check("x14 (DIVU 0xFFFF../3)", u_cpu.u_regfile.regfile[14], 32'h55555555);

        // REM
        check("x15 (REM 20%%6)",      u_cpu.u_regfile.regfile[15], 32'h2);
        check("x16 (REM -1%%3)",      u_cpu.u_regfile.regfile[16], 32'hFFFFFFFF);

        // REMU
        check("x17 (REMU 20%%6)",     u_cpu.u_regfile.regfile[17], 32'h2);
        check("x18 (REMU 0xFFFF..%%3)", u_cpu.u_regfile.regfile[18], 32'h0);

        // 除零
        check("x19 (ADDI 42)",        u_cpu.u_regfile.regfile[19], 32'h2A);
        check("x20 (DIV 42/0)",       u_cpu.u_regfile.regfile[20], 32'hFFFFFFFF);
        check("x21 (REMU 42%%0)",     u_cpu.u_regfile.regfile[21], 32'h2A);

        // 边界
        check("x22 (LUI 0x80000)",    u_cpu.u_regfile.regfile[22], 32'h80000000);
        check("x23 (DIV overflow)",   u_cpu.u_regfile.regfile[23], 32'h80000000);
        check("x24 (REM overflow)",   u_cpu.u_regfile.regfile[24], 32'h0);
        check("x25 (MULHU max*max)",  u_cpu.u_regfile.regfile[25], 32'hFFFFFFFE);
        check("x26 (ADDI -7)",        u_cpu.u_regfile.regfile[26], 32'hFFFFFFF9);
        check("x27 (REM -7%%3)",      u_cpu.u_regfile.regfile[27], 32'hFFFFFFFF);
        check("x28 (MULH min*-1)",    u_cpu.u_regfile.regfile[28], 32'h0);

        $display("========================================");
        $display("总计: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");

        $finish;
    end

endmodule

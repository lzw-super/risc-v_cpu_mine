// ==============================
// RISC-V LUI/AUIPC指令测试testbench
// ==============================
module tb_lui_auipc;
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
        $fsdbDumpvars(0, tb_lui_auipc);

        cycle_count = 0;
        $display("========================================");
        $display("RISC-V LUI/AUIPC指令测试开始");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(40) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("--- LUI测试 ---");
        $display("x1 = %h (预期: 0x12345678)", u_cpu.u_regfile.regfile[1]);
        $display("--- AUIPC测试 ---");
        $display("x2 = %h (预期: 0x10000009)", u_cpu.u_regfile.regfile[2]);
        $display("--- 验证测试 ---");
        $display("x3 = %h (预期: 0x12345679)", u_cpu.u_regfile.regfile[3]);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        if (u_cpu.u_regfile.regfile[1] == 32'h12345678)
            $display("[PASS] LUI: x1 = 0x12345678");
        else
            $display("[FAIL] LUI: x1 = %h (预期 0x12345678)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[2] == 32'h10000009)
            $display("[PASS] AUIPC: x2 = 0x10000009");
        else
            $display("[FAIL] AUIPC: x2 = %h (预期 0x10000009)", u_cpu.u_regfile.regfile[2]);

        if (u_cpu.u_regfile.regfile[3] == 32'h12345679)
            $display("[PASS] 验证: x3 = 0x12345679");
        else
            $display("[FAIL] 验证: x3 = %h (预期 0x12345679)", u_cpu.u_regfile.regfile[3]);

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end
endmodule
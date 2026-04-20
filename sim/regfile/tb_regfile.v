// ==============================
// Regfile模块 Testbench
// ==============================

`timescale 1ns/1ps

module tb_regfile;

    // 输入信号
    reg clk;
    reg reset;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg re1;
    reg re2;
    reg [4:0] wd;
    reg we;
    reg [31:0] wdata;

    // 输出信号
    wire [31:0] rs1_value;
    wire [31:0] rs2_value;

    // 实例化Regfile模块
    regfile u_regfile (
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .re1(re1),
        .re2(re2),
        .wd(wd),
        .we(we),
        .wdata(wdata),
        .rs1_value(rs1_value),
        .rs2_value(rs2_value)
    );

    // 时钟生成 - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试任务：等待若干时钟周期
    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // 写入任务
    task write_reg(
        input [4:0] reg_addr,
        input [31:0] data
    );
        @(posedge clk);
        #1;
        wd = reg_addr;
        we = 1;
        wdata = data;
        @(posedge clk);
        #1;
        we = 0;
    endtask

    // 读取验证任务
    task read_check(
        input [4:0] addr1,
        input [4:0] addr2,
        input        enable1,
        input        enable2,
        input [31:0] expected1,
        input [31:0] expected2,
        input string test_name
    );
        #1;
        rs1 = addr1;
        rs2 = addr2;
        re1 = enable1;
        re2 = enable2;
        #1;
        if (rs1_value === expected1 && rs2_value === expected2) begin
            $display("[PASS] %s: rs1_value=%h, rs2_value=%h", test_name, rs1_value, rs2_value);
        end else begin
            $display("[FAIL] %s: rs1_value=%h (exp=%h), rs2_value=%h (exp=%h)",
                     test_name, rs1_value, expected1, rs2_value, expected2);
        end
    endtask

    // 测试主程序
    initial begin
        $display("========================================");
        $display("Regfile Module Test Start");
        $display("========================================");

        // 初始化信号
        reset = 0;
        rs1 = 0;
        rs2 = 0;
        re1 = 0;
        re2 = 0;
        wd = 0;
        we = 0;
        wdata = 0;

        // ==================== 测试1: 复位 ====================
        $display("\n[Test 1] Reset Test");
        reset = 1;
        wait_cycles(2);
        reset = 0;
        wait_cycles(1);
        // 检查所有寄存器是否为 0
        read_check(1, 2, 1, 1, 32'h0, 32'h0, "After reset: x1, x2");
        read_check(5, 10, 1, 1, 32'h0, 32'h0, "After reset: x5, x10");
        read_check(31, 15, 1, 1, 32'h0, 32'h0, "After reset: x31, x15");

        // ==================== 测试2: x0 寄存器始终为 0 ====================
        $display("\n[Test 2] x0 Always Zero Test");
        // 尝试写入 x0
        write_reg(0, 32'hDEADBEEF);
        read_check(0, 0, 1, 1, 32'h0, 32'h0, "x0 after write attempt");
        // re=0 时读 x0
        read_check(0, 0, 0, 0, 32'h0, 32'h0, "x0 with re=0");

        // ==================== 测试3: 基本写入和读取 ====================
        $display("\n[Test 3] Basic Write and Read");
        write_reg(1, 32'h12345678);
        write_reg(2, 32'hABCDEF00);
        read_check(1, 2, 1, 1, 32'h12345678, 32'hABCDEF00, "x1, x2 after write");

        // ==================== 测试4: 负数写入 ====================
        $display("\n[Test 4] Negative Value Write");
        write_reg(5, 32'hFFFFFF00);  // -256
        write_reg(6, 32'h80000000);  // 最小负数
        read_check(5, 6, 1, 1, 32'hFFFFFF00, 32'h80000000, "x5, x6 negative values");

        // ==================== 测试5: 写入覆盖 ====================
        $display("\n[Test 5] Write Override");
        write_reg(10, 32'h11111111);
        read_check(10, 10, 1, 1, 32'h11111111, 32'h11111111, "x10 first write");
        write_reg(10, 32'h22222222);
        read_check(10, 10, 1, 1, 32'h22222222, 32'h22222222, "x10 after override");

        // ==================== 测试6: 读使能控制 ====================
        $display("\n[Test 6] Read Enable Control");
        write_reg(7, 32'h76543210);
        // re1=1, re2=0
        read_check(7, 7, 1, 0, 32'h76543210, 32'h0, "re1=1, re2=0");
        // re1=0, re2=1
        read_check(7, 7, 0, 1, 32'h0, 32'h76543210, "re1=0, re2=1");
        // re1=0, re2=0
        read_check(7, 7, 0, 0, 32'h0, 32'h0, "re1=0, re2=0");

        // ==================== 测试7: 不同地址读取 ====================
        $display("\n[Test 7] Different Address Read");
        write_reg(8, 32'hAAAAAAAA);
        write_reg(9, 32'hBBBBBBBB);
        write_reg(20, 32'hCCCCCCCC);
        write_reg(30, 32'hDDDDDDDD);
        read_check(8, 9, 1, 1, 32'hAAAAAAAA, 32'hBBBBBBBB, "x8, x9");
        read_check(20, 30, 1, 1, 32'hCCCCCCCC, 32'hDDDDDDDD, "x20, x30");

        // ==================== 测试8: we=0 时不能写入 ====================
        $display("\n[Test 8] Write Disable Test");
        write_reg(11, 32'hFFFFFFFF);
        read_check(11, 11, 1, 1, 32'hFFFFFFFF, 32'hFFFFFFFF, "x11 after write");
        // 尝试写入但 we=0
        @(posedge clk);
        #1;
        wd = 11;
        we = 0;
        wdata = 32'h00000000;
        @(posedge clk);
        #1;
        read_check(11, 11, 1, 1, 32'hFFFFFFFF, 32'hFFFFFFFF, "x11 after failed write (we=0)");

        // ==================== 测试9: 复位后再写入 ====================
        $display("\n[Test 9] Reset and Write Again");
        reset = 1;
        wait_cycles(2);
        reset = 0;
        wait_cycles(1);
        read_check(1, 2, 1, 1, 32'h0, 32'h0, "After second reset");
        write_reg(15, 32'h12312312);
        read_check(15, 15, 1, 1, 32'h12312312, 32'h12312312, "x15 after reset+write");

        // ==================== 测试结束 ====================
        $display("\n========================================");
        $display("Regfile Module Test Completed");
        $display("========================================");

        #100;
        $finish;
    end

    // 生成波形文件
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_regfile);
    end

    // 仿真时间限制
    initial begin
        #10000;
        $display("Simulation Timeout!");
        $finish;
    end

endmodule
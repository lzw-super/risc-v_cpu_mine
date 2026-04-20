// ==============================
// Decoder模块 Testbench - test_instructions.txt 全指令测试
// ==============================

`timescale 1ns/1ps

module tb_decoder;

    // 输入信号
    reg [31:0] instr;

    // 输出信号
    wire [4:0]  rs1;
    wire [4:0]  rs2;
    wire [31:0] imm;
    wire [4:0]  wd;
    wire [7:0]  aluop;
    wire        re1;
    wire        re2;
    wire        we;
    wire        pce;
    wire        imme;
    wire        jmpe;
    wire        be;
    wire [2:0]  bop;
    wire [2:0]  dmop;
    wire        doe;
    wire        mwe;

    // 实例化Decoder模块
    decoder u_decoder (
        .instr(instr),
        .rs1(rs1),
        .rs2(rs2),
        .imm(imm),
        .wd(wd),
        .aluop(aluop),
        .re1(re1),
        .re2(re2),
        .we(we),
        .pce(pce),
        .imme(imme),
        .jmpe(jmpe),
        .be(be),
        .bop(bop),
        .dmop(dmop),
        .doe(doe),
        .mwe(mwe)
    );

    // 测试任务
    task check_decode(
        input [31:0] test_instr,
        input string instr_name,
        input [4:0]  exp_rs1,
        input [4:0]  exp_rs2,
        input [4:0]  exp_wd,
        input [31:0] exp_imm,
        input [7:0]  exp_aluop,
        input        exp_re1,
        input        exp_re2,
        input        exp_we,
        input        exp_pce,
        input        exp_imme,
        input        exp_jmpe,
        input        exp_be,
        input [2:0]  exp_bop,
        input [2:0]  exp_dmop,
        input        exp_doe,
        input        exp_mwe
    );
        begin
            instr = test_instr;
            #1;

            if (rs1 === exp_rs1 && rs2 === exp_rs2 && wd === exp_wd &&
                imm === exp_imm && aluop === exp_aluop &&
                re1 === exp_re1 && re2 === exp_re2 && we === exp_we &&
                pce === exp_pce && imme === exp_imme && jmpe === exp_jmpe &&
                be === exp_be && bop === exp_bop && dmop === exp_dmop &&
                doe === exp_doe && mwe === exp_mwe) begin
                $display("[PASS] %s : instr=%h", instr_name, test_instr);
            end else begin
                $display("[FAIL] %s:", instr_name);
                $display("       instr=%h, opcode=%b, funct3=%b", test_instr, test_instr[6:0], test_instr[14:12]);
                $display("       rs1=%d(exp=%d), rs2=%d(exp=%d), wd=%d(exp=%d)",
                         rs1, exp_rs1, rs2, exp_rs2, wd, exp_wd);
                $display("       imm=%h(exp=%h), aluop=%h(exp=%h)",
                         imm, exp_imm, aluop, exp_aluop);
                $display("       re1=%b(exp=%b), re2=%b(exp=%b), we=%b(exp=%b)",
                         re1, exp_re1, re2, exp_re2, we, exp_we);
                $display("       pce=%b(exp=%b), imme=%b(exp=%b), jmpe=%b(exp=%b)",
                         pce, exp_pce, imme, exp_imme, jmpe, exp_jmpe);
                $display("       be=%b(exp=%b), bop=%h(exp=%h), dmop=%h(exp=%h)",
                         be, exp_be, bop, exp_bop, dmop, exp_dmop);
                $display("       doe=%b(exp=%b), mwe=%b(exp=%b)",
                         doe, exp_doe, mwe, exp_mwe);
            end
        end
    endtask

    // 测试主程序
    initial begin
        $display("========================================");
        $display("Decoder Test - test_instructions.txt");
        $display("========================================");

        // ==================== 0x00: JAL x0, 4 ====================
        // 00 40 00 6f -> 32'h0040006f
        // J-type: rd=0, 跳转偏移4字节
        $display("\n[0x00] JAL x0, 4");
        check_decode(32'h0040006f, "JAL x0, 4",
                     0, 0, 0, 32'h00000004, 8'h01,
                     0, 0, 1, 1, 1, 1, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x04: LUI x5, 0x1f1f2 ====================
        // 1f 1f 22 b7 -> 32'h1f1f22b7
        // U-type: rd=5, imm[31:12]=0x1f1f2
        $display("\n[0x04] LUI x5, 0x1f1f2");
        check_decode(32'h1f1f22b7, "LUI x5, 0x1f1f2",
                     0, 0, 5, 32'h1f1f2000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x08: ADDI x5, x5, -225 ====================
        // f1 f2 82 93 -> 32'hf1f28293
        // I-type: rd=5, rs1=5, imm=-225 (0xffffff1f)
        $display("\n[0x08] ADDI x5, x5, -225");
        check_decode(32'hf1f28293, "ADDI x5, x5, -225",
                     5, 0, 5, 32'hffffff1f, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x0c: ADDI x8, x3, 0 ====================
        // 00 01 84 13 -> 32'h00018413
        // I-type: rd=8, rs1=3, imm=0
        $display("\n[0x0c] ADDI x8, x3, 0");
        check_decode(32'h00018413, "ADDI x8, x3, 0",
                     3, 0, 8, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x10: SW x5, 0(x8) ====================
        // 00 54 20 23 -> 32'h00542023
        // S-type: rs2=5, rs1=8, imm=0, funct3=010(SW)
        $display("\n[0x10] SW x5, 0(x8)");
        check_decode(32'h00542023, "SW x5, 0(x8)",
                     8, 5, 0, 32'h00000000, 8'h01,
                     1, 1, 0, 0, 1, 0, 0, 3'b0, 3'b010, 1, 1);

        // ==================== 0x14: LW x10, 0(x8) ====================
        // 00 04 25 03 -> 32'h00042503
        // I-type load: rd=10, rs1=8, imm=0, funct3=010(LW)
        $display("\n[0x14] LW x10, 0(x8)");
        check_decode(32'h00042503, "LW x10, 0(x8)",
                     8, 0, 10, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b010, 1, 0);

        // ==================== 0x18: ADDI x8, x8, 4 ====================
        // 00 44 04 13 -> 32'h00440413
        // I-type: rd=8, rs1=8, imm=4
        $display("\n[0x18] ADDI x8, x8, 4");
        check_decode(32'h00440413, "ADDI x8, x8, 4",
                     8, 0, 8, 32'h00000004, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x1c: LUI x6, 0xe0e0e ====================
        // e0 e0 e3 37 -> 32'he0e0e337
        // U-type: rd=6, imm[31:12]=0xe0e0e
        $display("\n[0x1c] LUI x6, 0xe0e0e");
        check_decode(32'he0e0e337, "LUI x6, 0xe0e0e",
                     0, 0, 6, 32'he0e0e000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x20: ADDI x6, x6, 225 ====================
        // 0e 13 03 13 -> 32'h0e130313
        // I-type: rd=6, rs1=6, imm=225 (0xe1)
        $display("\n[0x20] ADDI x6, x6, 225");
        check_decode(32'h0e130313, "ADDI x6, x6, 225",
                     6, 0, 6, 32'h000000e1, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x24: SW x6, 0(x8) ====================
        // 00 64 20 23 -> 32'h00642023
        // S-type: rs2=6, rs1=8, imm=0
        $display("\n[0x24] SW x6, 0(x8)");
        check_decode(32'h00642023, "SW x6, 0(x8)",
                     8, 6, 0, 32'h00000000, 8'h01,
                     1, 1, 0, 0, 1, 0, 0, 3'b0, 3'b010, 1, 1);

        // ==================== 0x28: LW x11, 0(x8) ====================
        // 00 04 25 83 -> 32'h00042583
        // I-type load: rd=11, rs1=8, imm=0
        $display("\n[0x28] LW x11, 0(x8)");
        check_decode(32'h00042583, "LW x11, 0(x8)",
                     8, 0, 11, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b010, 1, 0);

        // ==================== 0x2c: ADDI x7, x0, -256 ====================
        // f0 00 03 93 -> 32'hf0000393
        // I-type: rd=7, rs1=0, imm=-256 (0xffffff00)
        $display("\n[0x2c] ADDI x7, x0, -256");
        check_decode(32'hf0000393, "ADDI x7, x0, -256",
                     0, 0, 7, 32'hffffff00, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x30: ADDI x8, x8, 4 ====================
        // 00 44 04 13 -> 32'h00440413
        $display("\n[0x30] ADDI x8, x8, 4");
        check_decode(32'h00440413, "ADDI x8, x8, 4",
                     8, 0, 8, 32'h00000004, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x34: SH x7, 0(x8) ====================
        // 00 74 10 23 -> 32'h00741023
        // S-type: rs2=7, rs1=8, imm=0, funct3=001(SH)
        $display("\n[0x34] SH x7, 0(x8)");
        check_decode(32'h00741023, "SH x7, 0(x8)",
                     8, 7, 0, 32'h00000000, 8'h01,
                     1, 1, 0, 0, 1, 0, 0, 3'b0, 3'b001, 1, 1);

        // ==================== 0x38: LH x12, 0(x8) ====================
        // 00 04 16 03 -> 32'h00041603
        // I-type load: rd=12, rs1=8, imm=0, funct3=001(LH)
        $display("\n[0x38] LH x12, 0(x8)");
        check_decode(32'h00041603, "LH x12, 0(x8)",
                     8, 0, 12, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b001, 1, 0);

        // ==================== 0x3c: ADDI x8, x8, 4 ====================
        // 00 44 04 13 -> 32'h00440413
        $display("\n[0x3c] ADDI x8, x8, 4");
        check_decode(32'h00440413, "ADDI x8, x8, 4",
                     8, 0, 8, 32'h00000004, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x40: ADDI x28, x0, -256 ====================
        // f0 00 0e 13 -> 32'hf0000e13
        // I-type: rd=28, rs1=0, imm=-256
        $display("\n[0x40] ADDI x28, x0, -256");
        check_decode(32'hf0000e13, "ADDI x28, x0, -256",
                     0, 0, 28, 32'hffffff00, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x44: SH x28, 0(x8) ====================
        // 01 c4 10 23 -> 32'h01c41023
        // S-type: rs2=28, rs1=8, imm=0, funct3=001(SH)
        $display("\n[0x44] SH x28, 0(x8)");
        check_decode(32'h01c41023, "SH x28, 0(x8)",
                     8, 28, 0, 32'h00000000, 8'h01,
                     1, 1, 0, 0, 1, 0, 0, 3'b0, 3'b001, 1, 1);

        // ==================== 0x48: LHU x13, 0(x8) ====================
        // 00 04 56 83 -> 32'h00045683
        // I-type load: rd=13, rs1=8, imm=0, funct3=101(LHU)
        $display("\n[0x48] LHU x13, 0(x8)");
        check_decode(32'h00045683, "LHU x13, 0(x8)",
                     8, 0, 13, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b101, 1, 0);

        // ==================== 0x4c: ADDI x29, x0, -31 ====================
        // fe 10 0e 93 -> 32'hfe100e93
        // I-type: rd=29, rs1=0, imm=-31 (0xffffffe1)
        $display("\n[0x4c] ADDI x29, x0, -31");
        check_decode(32'hfe100e93, "ADDI x29, x0, -31",
                     0, 0, 29, 32'hffffffe1, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x50: ADDI x8, x8, 4 ====================
        // 00 44 04 13 -> 32'h00440413
        $display("\n[0x50] ADDI x8, x8, 4");
        check_decode(32'h00440413, "ADDI x8, x8, 4",
                     8, 0, 8, 32'h00000004, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x54: SB x29, 0(x8) ====================
        // 01 d4 00 23 -> 32'h01d40023
        // S-type: rs2=29, rs1=8, imm=0, funct3=000(SB)
        $display("\n[0x54] SB x29, 0(x8)");
        check_decode(32'h01d40023, "SB x29, 0(x8)",
                     8, 29, 0, 32'h00000000, 8'h01,
                     1, 1, 0, 0, 1, 0, 0, 3'b0, 3'b000, 1, 1);

        // ==================== 0x58: LB x14, 0(x8) ====================
        // 00 04 07 03 -> 32'h00040703
        // I-type load: rd=14, rs1=8, imm=0, funct3=000(LB)
        $display("\n[0x58] LB x14, 0(x8)");
        check_decode(32'h00040703, "LB x14, 0(x8)",
                     8, 0, 14, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b000, 1, 0);

        // ==================== 0x5c: ADDI x8, x8, 4 ====================
        // 00 44 04 13 -> 32'h00440413
        $display("\n[0x5c] ADDI x8, x8, 4");
        check_decode(32'h00440413, "ADDI x8, x8, 4",
                     8, 0, 8, 32'h00000004, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x60: ADDI x30, x0, -31 ====================
        // fe 10 0f 13 -> 32'hfe100f13
        // I-type: rd=30, rs1=0, imm=-31
        $display("\n[0x60] ADDI x30, x0, -31");
        check_decode(32'hfe100f13, "ADDI x30, x0, -31",
                     0, 0, 30, 32'hffffffe1, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b0, 0, 0);

        // ==================== 0x64: SB x30, 0(x8) ====================
        // 01 e4 00 23 -> 32'h01e40023
        // S-type: rs2=30, rs1=8, imm=0, funct3=000(SB)
        $display("\n[0x64] SB x30, 0(x8)");
        check_decode(32'h01e40023, "SB x30, 0(x8)",
                     8, 30, 0, 32'h00000000, 8'h01,
                     1, 1, 0, 0, 1, 0, 0, 3'b0, 3'b000, 1, 1);

        // ==================== 0x68: LBU x15, 0(x8) ====================
        // 00 04 47 83 -> 32'h00044783
        // I-type load: rd=15, rs1=8, imm=0, funct3=100(LBU)
        $display("\n[0x68] LBU x15, 0(x8)");
        check_decode(32'h00044783, "LBU x15, 0(x8)",
                     8, 0, 15, 32'h00000000, 8'h01,
                     1, 0, 1, 0, 1, 0, 0, 3'b0, 3'b100, 1, 0);

        // ==================== 测试结束 ====================
        $display("\n========================================");
        $display("Decoder Test Completed");
        $display("========================================");

        #100;
        $finish;
    end

    // 生成波形文件
    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_decoder);
    end

    initial begin
        #5000;
        $display("Simulation Timeout!");
        $finish;
    end

endmodule
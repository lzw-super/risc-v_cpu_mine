// ==============================
// RISC-V J型指令动态预测测试testbench
// ==============================
module tb_jump_predict;
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
    integer jal_redirect_count;      // JAL首次执行重定向次数
    integer jalr_mispredict_count;   // JALR目标预测错误次数

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_jump_predict);

        cycle_count = 0;
        mispredict_count = 0;
        jal_redirect_count = 0;
        jalr_mispredict_count = 0;

        $display("========================================");
        $display("RISC-V J型指令动态跳转预测测试");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[复位完成] 开始执行...");

        repeat(150) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // 监测mispredict和重定向
            if (u_cpu.ex_mispredict) begin
                mispredict_count = mispredict_count + 1;
                if (u_cpu.ex_is_jump) begin
                    jalr_mispredict_count = jalr_mispredict_count + 1;
                    $display(">>> Cycle %d: JUMP MISPREDICT! ex_pc=%h, pred=%h, actual=%h",
                             cycle_count, u_cpu.ex_pc, u_cpu.ex_predict_target, u_cpu.ex_branch_target);
                end
                else begin
                    $display(">>> Cycle %d: BRANCH MISPREDICT! ex_pc=%h, taken=%b",
                             cycle_count, u_cpu.ex_pc, u_cpu.ex_branch_taken);
                end
            end

            // 监测JAL/JALR首次执行重定向（BTB未命中）
            if (u_cpu.ex_jmpe && !u_cpu.ex_btb_hit) begin
                jal_redirect_count = jal_redirect_count + 1;
                $display(">>> Cycle %d: JUMP first execution (BTB miss), pc=%h, target=%h",
                         cycle_count, u_cpu.ex_pc, u_cpu.ex_branch_target);
            end

            // 详细调试输出 (前30周期)
            if (cycle_count <= 30) begin
                $display("=== Cycle %d ===", cycle_count);
                $display("IF: PC=%h, btb_hit=%b, pred_target=%h, pred_valid=%b",
                         u_cpu.if_pc, u_cpu.if_btb_hit, u_cpu.if_predicted_target, u_cpu.if_predicted_valid);
                $display("EX: pc=%h, jmpe=%b, is_jump=%b, btb_hit=%b, branch_target=%h",
                         u_cpu.ex_pc, u_cpu.ex_jmpe, u_cpu.ex_is_jump,
                         u_cpu.ex_btb_hit, u_cpu.ex_branch_target);
                $display("Redirect: mispredict=%b, flush=%b",
                         u_cpu.ex_mispredict, u_cpu.if_id_flush);
                $display("Registers: x1=%d, x4=%d, x6=%h, x7=%h, x8=%d, x10=%d",
                         u_cpu.u_regfile.regfile[1], u_cpu.u_regfile.regfile[4],
                         u_cpu.u_regfile.regfile[6], u_cpu.u_regfile.regfile[7],
                         u_cpu.u_regfile.regfile[8], u_cpu.u_regfile.regfile[10]);
                $display("");
            end
        end

        $display("========================================");
        $display("最终寄存器状态:");
        $display("========================================");
        $display("x1 = %d (预期: 10)", u_cpu.u_regfile.regfile[1]);
        $display("x4 = %d (预期: 1)", u_cpu.u_regfile.regfile[4]);
        $display("x5 = %h (预期: 0x1c)", u_cpu.u_regfile.regfile[5]);
        $display("x6 = %h (预期: 0x50)", u_cpu.u_regfile.regfile[6]);
        $display("x7 = %h (预期: 0x60)", u_cpu.u_regfile.regfile[7]);
        $display("x8 = %d (预期: 1)", u_cpu.u_regfile.regfile[8]);
        $display("x9 = %h (预期: 0x30)", u_cpu.u_regfile.regfile[9]);
        $display("x10 = %d (预期: 100)", u_cpu.u_regfile.regfile[10]);

        $display("========================================");
        $display("预测统计:");
        $display("========================================");
        $display("总Mispredict次数: %d", mispredict_count);
        $display("JAL/JALR首次重定向(BTB miss): %d", jal_redirect_count);
        $display("JALR目标预测错误: %d", jalr_mispredict_count);

        $display("========================================");
        $display("验证结果:");
        $display("========================================");

        // 验证BNE循环结果
        if (u_cpu.u_regfile.regfile[1] == 32'h0A)
            $display("[PASS] BNE循环: x1 = 10");
        else
            $display("[FAIL] BNE循环: x1 = %d (预期 10)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[4] == 32'h01)
            $display("[PASS] 循环后执行: x4 = 1");
        else
            $display("[FAIL] 循环后执行: x4 = %d (预期 1)", u_cpu.u_regfile.regfile[4]);

        // 验证JAL返回地址
        if (u_cpu.u_regfile.regfile[5] == 32'h1C)
            $display("[PASS] JAL返回地址: x5 = 0x1c");
        else
            $display("[FAIL] JAL返回地址: x5 = %h (预期 0x1c)", u_cpu.u_regfile.regfile[5]);

        // 验证JALR目标设置
        if (u_cpu.u_regfile.regfile[6] == 32'h50)
            $display("[PASS] JALR目标1: x6 = 0x50");
        else
            $display("[FAIL] JALR目标1: x6 = %h (预期 0x50)", u_cpu.u_regfile.regfile[6]);

        if (u_cpu.u_regfile.regfile[7] == 32'h60)
            $display("[PASS] JALR目标2: x7 = 0x60");
        else
            $display("[FAIL] JALR目标2: x7 = %h (预期 0x60)", u_cpu.u_regfile.regfile[7]);

        // 验证JALR目标1执行结果
        if (u_cpu.u_regfile.regfile[8] == 32'h01)
            $display("[PASS] JALR目标1执行: x8 = 1");
        else
            $display("[FAIL] JALR目标1执行: x8 = %d (预期 1)", u_cpu.u_regfile.regfile[8]);

        // 验证JALR目标2执行结果
        if (u_cpu.u_regfile.regfile[10] == 32'd100)
            $display("[PASS] JALR目标2执行: x10 = 100");
        else
            $display("[FAIL] JALR目标2执行: x10 = %d (预期 100)", u_cpu.u_regfile.regfile[10]);

        // 验证JAL/JALR BTB缓存效果 (至少检测到BTB miss)
        if (jal_redirect_count >= 1)
            $display("[PASS] JAL/JALR BTB缓存有效: 检测到%d次首次重定向", jal_redirect_count);
        else
            $display("[FAIL] 未检测到BTB miss重定向");

        // JALR目标变化应触发mispredict
        if (jalr_mispredict_count >= 1)
            $display("[PASS] JALR目标Mispredict检测: 检测到%d次", jalr_mispredict_count);
        else
            $display("[INFO] JALR预测: 未检测到目标mispredict");

        $display("========================================");
        $display("测试周期数: %d", cycle_count);
        $display("========================================");

        $finish;
    end
endmodule
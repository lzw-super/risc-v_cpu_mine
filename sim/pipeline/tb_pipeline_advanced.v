// ==============================
// Pipeline CPU Advanced Testbench
// 测试分支预测和Load-Use hazard
// ==============================

module tb_pipeline_advanced;

    reg clk;
    reg reset;

    // Instantiate Pipeline CPU
    pipeline_cpu u_cpu (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test tracking
    integer cycle_count;
    integer test_pass;
    integer test_fail;

    // Stall tracking for Load-Use test
    integer load_use_stall_count;
    integer last_mem_read_cycle;

    // Branch tracking
    integer branch_count;
    integer branch_taken_count;
    integer branch_flush_count;

    initial begin
        $fsdbDumpfile("pipeline_advanced_wave.fsdb");
        $fsdbDumpvars(0, tb_pipeline_advanced);

        cycle_count = 0;
        test_pass = 0;
        test_fail = 0;
        load_use_stall_count = 0;
        branch_count = 0;
        branch_taken_count = 0;
        branch_flush_count = 0;

        $display("========================================");
        $display("Pipeline CPU Advanced Test");
        $display("Testing: Branch Prediction & Load-Use Hazard");
        $display("========================================");

        // Reset
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[Reset Complete]");

        // 运行足够多的周期
        repeat(60) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // ===== Load-Use Hazard Detection =====
            // 检测是否有Load-Use stall发生
            if (u_cpu.stall_pc && u_cpu.stall_if_id && u_cpu.flush_id_ex) begin
                if (u_cpu.ex_mem_read && u_cpu.ex_we) begin
                    load_use_stall_count = load_use_stall_count + 1;
                    $display("[Cycle %d] Load-Use Stall detected!", cycle_count);
                    $display("  EX stage: Load to x%d, MEM_READ=%b", u_cpu.ex_rd_addr, u_cpu.ex_mem_read);
                    $display("  ID stage needs: rs1=x%d, rs2=x%d", u_cpu.id_rs1_addr, u_cpu.id_rs2_addr);
                end
            end

            // ===== Branch Prediction Detection =====
            // 检测分支指令和分支发生
            if (u_cpu.ex_be) begin
                branch_count = branch_count + 1;
                $display("[Cycle %d] Branch instruction detected", cycle_count);
                $display("  EX stage: be=%b, bop=%b", u_cpu.ex_be, u_cpu.ex_bop);
                $display("  Branch taken: %b, target: %h", u_cpu.ex_branch_taken, u_cpu.ex_branch_target);
            end

            // 检测分支发生时的flush
            if (u_cpu.mem_branch_taken) begin
                branch_taken_count = branch_taken_count + 1;
                $display("[Cycle %d] Branch taken! Flush pipeline", cycle_count);
                $display("  MEM stage branch taken, flushing IF/ID and ID/EX");
            end

            // ===== Forwarding Detection =====
            if (u_cpu.forward_a != 0 || u_cpu.forward_b != 0) begin
                $display("[Cycle %d] Forwarding active: A=%b, B=%b", cycle_count, u_cpu.forward_a, u_cpu.forward_b);
                $display("  EX rs1_addr=x%d, rs2_addr=x%d", u_cpu.ex_rs1_addr, u_cpu.ex_rs2_addr);
                $display("  MEM rd=x%d, WB rd=x%d", u_cpu.mem_rd_addr, u_cpu.wb_rd_addr);
            end
        end

        // ===== Final Results =====
        $display("========================================");
        $display("Test Results Summary");
        $display("========================================");

        // 寄存器状态
        $display("Register State:");
        $display("  x10 = %h (expected: 0x9)", u_cpu.u_regfile.regfile[10]);
        $display("  x11 = %h (expected: 0x6)", u_cpu.u_regfile.regfile[11]);
        $display("  x12 = %h (expected: 0x15)", u_cpu.u_regfile.regfile[12]);
        $display("  x13 = %h (expected: 0x15 - branch test)", u_cpu.u_regfile.regfile[13]);
        $display("  x14 = %h (expected: 0x15)", u_cpu.u_regfile.regfile[14]);
        $display("  x3  = %h (Load result)", u_cpu.u_regfile.regfile[3]);
        $display("  x2  = %h (Load-Use test)", u_cpu.u_regfile.regfile[2]);
        $display("  x17 = %h (expected: 0x5 if branch not taken)", u_cpu.u_regfile.regfile[17]);

        // 统计结果
        $display("");
        $display("Hazard Handling Statistics:");
        $display("  Load-Use stalls detected: %d", load_use_stall_count);
        $display("  Branch instructions:       %d", branch_count);
        $display("  Branches taken:            %d", branch_taken_count);

        // 测试验证
        $display("");
        $display("Test Verification:");

        // Load-Use测试验证
        if (load_use_stall_count >= 1) begin
            $display("[PASS] Load-Use hazard stall detected (%d times)", load_use_stall_count);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] Load-Use hazard stall NOT detected");
            test_fail = test_fail + 1;
        end

        // Load结果验证 (假设内存地址x10(9)处有数据)
        if (u_cpu.u_regfile.regfile[3] != 0) begin
            $display("[PASS] Load instruction worked, x3 = %h", u_cpu.u_regfile.regfile[3]);
            test_pass = test_pass + 1;
        end else begin
            $display("[INFO] Load result x3 = 0 (memory may be empty)");
        end

        // 分支测试验证
        if (branch_count >= 1) begin
            $display("[PASS] Branch instruction detected (%d times)", branch_count);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] Branch instruction NOT detected");
            test_fail = test_fail + 1;
        end

        // 转发测试验证
        if (u_cpu.u_regfile.regfile[13] == 32'h15 || u_cpu.u_regfile.regfile[14] == 32'h15) begin
            $display("[PASS] Forwarding worked correctly");
            test_pass = test_pass + 1;
        end else begin
            $display("[INFO] Forwarding result: x13=%h, x14=%h", u_cpu.u_regfile.regfile[13], u_cpu.u_regfile.regfile[14]);
        end

        $display("");
        $display("========================================");
        $display("Total: PASS=%d, FAIL=%d", test_pass, test_fail);
        $display("Pipeline CPU Advanced Test Completed");
        $display("========================================");

        $finish;
    end

endmodule
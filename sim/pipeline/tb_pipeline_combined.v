// ==============================
// Pipeline CPU Combined Testbench
// ==============================
// 测试内容: 转发、Load-Use、分支预测、循环

module tb_pipeline_combined;

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

    // Test counters
    integer cycle_count;
    integer mispredict_count;

    // 中间结果记录
    reg [31:0] load_use_x3_result;
    reg [31:0] load_use_x2_result;
    reg        load_use_checked;

    initial begin
        $fsdbDumpfile("pipeline_combined_wave.fsdb");
        $fsdbDumpvars(0, tb_pipeline_combined);

        cycle_count = 0;
        mispredict_count = 0;
        load_use_checked = 0;

        $display("========================================");
        $display("Pipeline CPU Combined Test Start");
        $display("========================================");

        // Reset sequence
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[Reset Complete] Starting execution...");

        // Run for enough cycles to complete all tests
        repeat(150) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // Track mispredicts
            if (u_cpu.ex_mispredict) begin
                mispredict_count = mispredict_count + 1;
                $display("!!! MISPREDICT at cycle %d: predicted=%b, actual=%b !!!",
                         cycle_count, u_cpu.ex_predict_taken, u_cpu.ex_branch_taken);
            end

            // 检查Load-Use测试中间结果 (在cycle 12时x2应该已经计算完成)
            if (cycle_count == 12 && !load_use_checked) begin
                load_use_x3_result = u_cpu.u_regfile.regfile[3];
                load_use_x2_result = u_cpu.u_regfile.regfile[2];
                load_use_checked = 1;
                $display(">>> Load-Use Test captured at cycle 12: x3=%h, x2=%h",
                         load_use_x3_result, load_use_x2_result);
            end

            // Detailed monitoring for first 50 cycles
            if (cycle_count <= 50) begin
                $display("=== Cycle %d ===", cycle_count);
                $display("IF:  PC=%h", u_cpu.if_pc);
                $display("ID:  instr=%h, we=%b, rd=%d", u_cpu.id_instr, u_cpu.id_we, u_cpu.id_rd_addr);
                $display("EX:  PC=%h, we=%b, rd=%d, mispredict=%b",
                         u_cpu.ex_pc, u_cpu.ex_we, u_cpu.ex_rd_addr, u_cpu.ex_mispredict);
                $display("MEM: we=%b, rd=%d", u_cpu.mem_we, u_cpu.mem_rd_addr);
                $display("WB:  we=%b, rd=%d, data=%h", u_cpu.wb_we, u_cpu.wb_rd_addr, u_cpu.wb_data);
                $display("Hazard: stall=%b, if_flush=%b, id_ex_flush=%b",
                         u_cpu.stall_pc, u_cpu.if_id_flush, u_cpu.id_ex_flush);
                $display("Registers: x1=%h, x2=%h, x3=%h, x4=%h, x10=%h, x11=%h, x12=%h, x13=%h",
                         u_cpu.u_regfile.regfile[1], u_cpu.u_regfile.regfile[2],
                         u_cpu.u_regfile.regfile[3], u_cpu.u_regfile.regfile[4],
                         u_cpu.u_regfile.regfile[10], u_cpu.u_regfile.regfile[11],
                         u_cpu.u_regfile.regfile[12], u_cpu.u_regfile.regfile[13]);
                $display("");
            end
        end

        // Final register state
        $display("========================================");
        $display("Final Register State:");
        $display("========================================");
        $display("--- Part 1: Forwarding Test ---");
        $display("x10 = %h (expected: 0x09)", u_cpu.u_regfile.regfile[10]);
        $display("x11 = %h (expected: 0x01 after modification)", u_cpu.u_regfile.regfile[11]);
        $display("x12 = %h (expected: 0x0F = 15)", u_cpu.u_regfile.regfile[12]);
        $display("x13 = %h (expected: 0x15 = 21)", u_cpu.u_regfile.regfile[13]);
        $display("x14 = %h (expected: 0x0F = 15)", u_cpu.u_regfile.regfile[14]);
        $display("--- Part 2: Load-Use Test ---");
        $display("x3  = %h (expected: 0x06)", u_cpu.u_regfile.regfile[3]);
        $display("x2  = %h (expected: 0x0C = 12)", u_cpu.u_regfile.regfile[2]);
        $display("--- Part 3: Branch Test ---");
        $display("x17 = %h (expected: 0x05)", u_cpu.u_regfile.regfile[17]);
        $display("--- Part 4: Loop Test (BTB/BHT) ---");
        $display("x1  = %h (expected: 0x06)", u_cpu.u_regfile.regfile[1]);
        $display("x4  = %h (expected: 0x05)", u_cpu.u_regfile.regfile[4]);

        $display("========================================");
        $display("Test Summary:");
        $display("Total cycles: %d", cycle_count);
        $display("Mispredict count: %d (expected: 2)", mispredict_count);
        $display("========================================");

        // Verification
        $display("\n--- Verification Results ---");

        // Part 1: Forwarding
        if (u_cpu.u_regfile.regfile[12] == 32'h0F)
            $display("[PASS] Forwarding test: x12 = 15");
        else
            $display("[FAIL] Forwarding test: x12 = %h (expected 15)", u_cpu.u_regfile.regfile[12]);

        if (u_cpu.u_regfile.regfile[13] == 32'h15)
            $display("[PASS] Forwarding test: x13 = 21");
        else
            $display("[FAIL] Forwarding test: x13 = %h (expected 21)", u_cpu.u_regfile.regfile[13]);

        if (u_cpu.u_regfile.regfile[14] == 32'h0F)
            $display("[PASS] Forwarding test: x14 = 15");
        else
            $display("[FAIL] Forwarding test: x14 = %h (expected 15)", u_cpu.u_regfile.regfile[14]);

        // Part 2: Load-Use (使用中间捕获的结果)
        if (load_use_x3_result == 32'h06)
            $display("[PASS] Load-Use test: x3 = 6 (captured at cycle 12)");
        else
            $display("[FAIL] Load-Use test: x3 = %h (expected 6, captured at cycle 12)", load_use_x3_result);

        if (load_use_x2_result == 32'h0C)
            $display("[PASS] Load-Use test: x2 = 12 (captured at cycle 12)");
        else
            $display("[FAIL] Load-Use test: x2 = %h (expected 12, captured at cycle 12)", load_use_x2_result);

        // Part 3: Branch
        if (u_cpu.u_regfile.regfile[17] == 32'h05)
            $display("[PASS] Branch test: x17 = 5");
        else
            $display("[FAIL] Branch test: x17 = %h (expected 5)", u_cpu.u_regfile.regfile[17]);

        // Part 4: Loop
        if (u_cpu.u_regfile.regfile[1] == 32'h06)
            $display("[PASS] Loop test: x1 = 6 (5 loops with increment 1, starting at 1)");
        else
            $display("[FAIL] Loop test: x1 = %h (expected 6)", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[4] == 32'h05)
            $display("[PASS] Loop counter: x4 = 5");
        else
            $display("[FAIL] Loop counter: x4 = %h (expected 5)", u_cpu.u_regfile.regfile[4]);

        // Mispredict count
        if (mispredict_count == 2)
            $display("[PASS] Mispredict count: 2");
        else
            $display("[FAIL] Mispredict count: %d (expected 2)", mispredict_count);

        $finish;
    end

endmodule
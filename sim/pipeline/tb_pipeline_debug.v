// ==============================
// Pipeline CPU Testbench with BTB/BHT Debug
// ==============================

module tb_pipeline_debug;

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

    // Test sequence
    integer cycle_count;
    integer mispredict_count;

    initial begin
        $fsdbDumpfile("pipeline_btb_wave.fsdb");
        $fsdbDumpvars(0, tb_pipeline_debug);

        cycle_count = 0;
        mispredict_count = 0;

        $display("========================================");
        $display("Pipeline CPU with BTB/BHT Test Start");
        $display("========================================");

        // Reset sequence
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[Reset Complete] Starting Pipeline CPU execution...");

        // Run for multiple cycles
        repeat(100) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // Track mispredicts
            if (u_cpu.mem_mispredict) begin
                mispredict_count = mispredict_count + 1;
                $display("!!! MISPREDICT at cycle %d: predicted=%b, actual=%b !!!",
                         cycle_count, u_cpu.mem_predict_taken, u_cpu.mem_branch_taken);
            end

            // Monitor key signals every cycle
            if (cycle_count <= 30) begin
                $display("=== Cycle %d ===", cycle_count);
                $display("ID:  instr=%h, we=%b, rd=%d", u_cpu.id_instr, u_cpu.id_we, u_cpu.id_rd_addr);
                $display("EX:  PC=%h, we=%b, rd=%d", u_cpu.ex_pc, u_cpu.ex_we, u_cpu.ex_rd_addr);
                $display("MEM: PC=%h, we=%b, rd=%d", u_cpu.mem_pc, u_cpu.mem_we, u_cpu.mem_rd_addr);
                $display("WB:  we=%b, rd=%d, data=%h", u_cpu.wb_we, u_cpu.wb_rd_addr, u_cpu.wb_data);
                $display("Hazard: stall=%b, flush=%b, id_ex_flush=%b",
                         u_cpu.stall_pc, u_cpu.if_id_flush, u_cpu.id_ex_flush);
                $display("Registers: x1=%h, x2 = %h , x3=%h, x4=%h , x7 = %h",
                         u_cpu.u_regfile.regfile[1],u_cpu.u_regfile.regfile[2], u_cpu.u_regfile.regfile[3], u_cpu.u_regfile.regfile[4],u_cpu.u_regfile.regfile[3]);
                $display("");
            end
        end

        // Final register state check
        $display("========================================");
        $display("Final Register State:");
        $display("========================================");
        $display("x1 (accumulator) = %h (expected: 0x0A)", u_cpu.u_regfile.regfile[1]);
        $display("x4 (loop counter) = %h (expected: 0x0A)", u_cpu.u_regfile.regfile[4]);
        $display("x7 (branch test)  = %h (expected: 0x63)", u_cpu.u_regfile.regfile[7]);
        $display("x8 (loop2 counter)= %h (expected: 0x05)", u_cpu.u_regfile.regfile[8]);

        $display("========================================");
        $display("Pipeline CPU Test Completed");
        $display("Total cycles: %d", cycle_count);
        $display("Mispredict count: %d", mispredict_count);
        $display("========================================");

        // Verification
        if (u_cpu.u_regfile.regfile[1] == 32'h0A)
            $display("[PASS] Loop accumulator correct: x1 = 10");
        else
            $display("[FAIL] Loop accumulator wrong: x1 = %h", u_cpu.u_regfile.regfile[1]);

        if (u_cpu.u_regfile.regfile[8] == 32'h05)
            $display("[PASS] Loop2 counter correct: x8 = 5");
        else
            $display("[FAIL] Loop2 counter wrong: x8 = %h", u_cpu.u_regfile.regfile[8]);

        $finish;
    end

endmodule
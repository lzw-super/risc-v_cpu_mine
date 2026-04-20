// ==============================
// Pipeline CPU Testbench
// ==============================

module tb_pipeline;

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
    integer test_pass_count;
    integer test_fail_count;

    initial begin
        $fsdbDumpfile("pipeline_wave.fsdb");
        $fsdbDumpvars(0, tb_pipeline);

        cycle_count = 0;
        test_pass_count = 0;
        test_fail_count = 0;

        $display("========================================");
        $display("Pipeline CPU Test Start");
        $display("========================================");

        // Reset sequence
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[Reset Complete] Starting Pipeline CPU execution...");

        // Run for multiple cycles
        repeat(50) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // Monitor key signals every cycle
            if (cycle_count <= 20) begin
                $display("=== Cycle %d ===", cycle_count);
                $display("IF:  PC=%h", u_cpu.if_pc);
                $display("ID:  PC=%h, Instr=%h", u_cpu.id_pc, u_cpu.id_instr);
                $display("EX:  ALU_out=%h, Branch=%b", u_cpu.ex_alu_out, u_cpu.ex_branch_taken);
                $display("MEM: ALU_out=%h, Mem_we=%b", u_cpu.mem_alu_out, u_cpu.mem_mwe);
                $display("WB:  rd=%d, we=%b, data=%h", u_cpu.wb_rd_addr, u_cpu.wb_we, u_cpu.wb_data);
                $display("Forward: A=%b, B=%b", u_cpu.forward_a, u_cpu.forward_b);
                $display("Stall: PC=%b, IF/ID=%b, ID/EX=%b",
                         u_cpu.stall_pc, u_cpu.stall_if_id, u_cpu.flush_id_ex);
            end
        end

        // Final register state check
        $display("========================================");
        $display("Final Register State:");
        $display("========================================");
        $display("x10 = %h", u_cpu.u_regfile.regfile[10]);
        $display("x11 = %h", u_cpu.u_regfile.regfile[11]);
        $display("x12 = %h", u_cpu.u_regfile.regfile[12]);
        $display("x13 = %h", u_cpu.u_regfile.regfile[13]);

        $display("========================================");
        $display("Pipeline CPU Test Completed");
        $display("Total cycles: %d", cycle_count);
        $display("========================================");

        $finish;
    end

endmodule
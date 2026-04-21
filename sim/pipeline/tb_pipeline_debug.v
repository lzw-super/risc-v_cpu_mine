// ==============================
// PC Stall 详细调试 Testbench
// ==============================

module tb_pipeline_debug;

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
    integer pc_stall_count;

    initial begin
        $fsdbDumpfile("pipeline_debug_wave.fsdb");
        $fsdbDumpvars(0, tb_pipeline_debug);

        cycle_count = 0;
        pc_stall_count = 0;

        $display("========================================");
        $display("PC Stall Detailed Debug Test");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[Reset Complete]");

        repeat(30) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            // 详细追踪PC变化
            $display("=== Cycle %d ===", cycle_count);
            $display("  stall_pc=%b, stall_if_id=%b, flush_id_ex=%b",
                     u_cpu.stall_pc, u_cpu.stall_if_id, u_cpu.flush_id_ex);
            $display("  IF: PC=%h", u_cpu.if_pc);
            $display("  ID: PC=%h, Instr=%h, rs1=%d, rs2=%d",
                     u_cpu.id_pc, u_cpu.id_instr, u_cpu.id_rs1_addr, u_cpu.id_rs2_addr);
            $display("  EX: rd=%d, mem_read=%b, be=%b, branch=%b",
                     u_cpu.ex_rd_addr, u_cpu.ex_mem_read, u_cpu.ex_be, u_cpu.ex_branch_taken);

            // PC stall计数
            if (u_cpu.stall_pc) begin
                pc_stall_count = pc_stall_count + 1;
                $display("  *** PC STALL ACTIVE! PC frozen at %h ***", u_cpu.if_pc);
            end

            // 检查PC是否真的没变
            if (cycle_count > 1 && !u_cpu.stall_pc && !u_cpu.ex_branch_taken) begin
                // 正常情况下PC应该增加4
            end
        end

        $display("========================================");
        $display("Final Statistics:");
        $display("  Total cycles:     %d", cycle_count);
        $display("  PC stall count:   %d", pc_stall_count);
        $display("========================================");
        $display("Register Values:");
        $display("  x10 = %h", u_cpu.u_regfile.regfile[10]);
        $display("  x11 = %h", u_cpu.u_regfile.regfile[11]);
        $display("  x12 = %h", u_cpu.u_regfile.regfile[12]);
        $display("  x13 = %h", u_cpu.u_regfile.regfile[13]);
        $display("  x14 = %h", u_cpu.u_regfile.regfile[14]);
        $display("  x3  = %h (Load result)", u_cpu.u_regfile.regfile[3]);
        $display("  x2  = %h (Load-Use result)", u_cpu.u_regfile.regfile[2]);
        $display("  x17 = %h (Branch not taken result)", u_cpu.u_regfile.regfile[17]);
        $display("========================================");

        // 验证测试
        if (pc_stall_count >= 1)
            $display("[PASS] PC stall occurred %d times", pc_stall_count);
        else
            $display("[FAIL] PC stall did NOT occur!");

        if (u_cpu.u_regfile.regfile[17] == 32'h5)
            $display("[PASS] Branch instruction executed correctly, x17=5");
        else
            $display("[FAIL] Branch not executed correctly, x17=%h", u_cpu.u_regfile.regfile[17]);

        $display("========================================");
        $finish;
    end

endmodule
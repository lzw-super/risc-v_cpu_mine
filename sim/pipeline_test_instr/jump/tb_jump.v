// ==============================
// RISC-V Jump指令测试testbench (带调试)
// ==============================
module tb_jump;
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
        $fsdbDumpvars(0, tb_jump);

        cycle_count = 0;
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;

        repeat(60) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            
            // 详细调试输出
            if (cycle_count >= 5 && cycle_count <= 30) begin
                $display("=== Cycle %d ===", cycle_count);
                $display("IF: PC=%h, instr=%h", u_cpu.if_pc, u_cpu.if_instr);
                $display("ID: instr=%h, we=%b, rd=%d, wb_sel=%b, jmpe=%b", 
                         u_cpu.id_instr, u_cpu.id_we, u_cpu.id_rd_addr, u_cpu.id_wb_sel, u_cpu.id_jmpe);
                $display("EX: we=%b, rd=%d, wb_sel=%b, jmpe=%b, pc_next=%h, flush=%b",
                         u_cpu.ex_we, u_cpu.ex_rd_addr, u_cpu.ex_wb_sel, u_cpu.ex_jmpe, u_cpu.ex_pc_next, u_cpu.id_ex_flush);
                $display("MEM: we=%b, rd=%d, wb_sel=%b, pc_next=%h",
                         u_cpu.mem_we, u_cpu.mem_rd_addr, u_cpu.mem_wb_sel, u_cpu.mem_pc_next);
                $display("WB: we=%b, rd=%d, data=%h",
                         u_cpu.wb_we, u_cpu.wb_rd_addr, u_cpu.wb_data);
                $display("Registers: x3=%h, x6=%h, x7=%h, x8=%h",
                         u_cpu.u_regfile.regfile[3], u_cpu.u_regfile.regfile[6],
                         u_cpu.u_regfile.regfile[7], u_cpu.u_regfile.regfile[8]);
                $display("");
            end
        end

        $display("Final: x3=%h (expected 0x0C), x6=%h (expected 2), x7=%h (expected 0x20), x8=%h (expected 10)",
                 u_cpu.u_regfile.regfile[3], u_cpu.u_regfile.regfile[6],
                 u_cpu.u_regfile.regfile[7], u_cpu.u_regfile.regfile[8]);
        $finish;
    end
endmodule

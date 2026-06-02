module tb_baseline_a;
    reg clk;
    reg reset;
    integer cycle_count;
    integer stall_count;
    integer error_count;

    pipeline_cpu u_cpu (
        .clk(clk),
        .reset(reset),
        .aluout()
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task check_reg;
        input [4:0] reg_index;
        input [31:0] expected;
        input [511:0] label;
        begin
            if (u_cpu.u_regfile.regfile[reg_index] == expected) begin
                $display("[PASS] %0s: x%0d = %h", label, reg_index, expected);
            end
            else begin
                $display("[FAIL] %0s: x%0d = %h, expected %h",
                         label, reg_index, u_cpu.u_regfile.regfile[reg_index], expected);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_baseline_a);

        cycle_count = 0;
        stall_count = 0;
        error_count = 0;

        $display("========================================");
        $display("Baseline(A) pipeline verification start");
        $display("========================================");

        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;

        u_cpu.u_datamem.mem_mine.mem_word[8'h20] = 32'ha55ac33c;
        if (u_cpu.u_datamem.mem_mine.mem_word[8'h20] === 32'ha55ac33c) begin
            $display("[PASS] datamem word-array sanity: mem_word[8'h20] readback matched");
        end
        else begin
            $display("[FAIL] datamem word-array sanity: mem_word[8'h20] = %h, expected a55ac33c",
                     u_cpu.u_datamem.mem_mine.mem_word[8'h20]);
            error_count = error_count + 1;
        end

        repeat (90) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (u_cpu.stall_pc) begin
                stall_count = stall_count + 1;
                $display(">>> Cycle %0d: stall_pc asserted", cycle_count);
            end
        end

        $display("========================================");
        $display("Final register checks");
        $display("========================================");

        check_reg(5'd3,  32'd5,   "x0 write suppression and forwarding filter");
        check_reg(5'd5,  32'd7,   "EX/MEM forwarding priority");
        check_reg(5'd7,  32'd17,  "MEM/WB forwarding fallback");
        check_reg(5'd11, 32'd42,  "load value");
        check_reg(5'd12, 32'd43,  "load-use ALU dependency");
        check_reg(5'd14, 32'd2,   "load-use branch and wrong-path register flush");
        check_reg(5'd16, 32'd42,  "load-use store data dependency");
        check_reg(5'd19, 32'd100, "JALR link register");
        check_reg(5'd20, 32'd104, "load-use JALR target source");
        check_reg(5'd22, 32'd2,   "JALR wrong-path register flush");
        check_reg(5'd23, 32'd0,   "branch wrong-path store suppression");

        if (stall_count >= 4) begin
            $display("[PASS] load-use stall count = %0d", stall_count);
        end
        else begin
            $display("[FAIL] load-use stall count = %0d, expected at least 4", stall_count);
            error_count = error_count + 1;
        end

        $display("========================================");
        $display("Cycles: %0d", cycle_count);
        $display("Errors: %0d", error_count);
        $display("========================================");

        if (error_count == 0) begin
            $display("[PASS] Baseline(A) pipeline verification passed");
        end
        else begin
            $display("[FAIL] Baseline(A) pipeline verification failed with %0d errors", error_count);
        end

        $finish;
    end
endmodule

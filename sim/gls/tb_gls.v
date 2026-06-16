// ==============================
// GLS (Gate-Level Simulation) testbench
// Targets the post-synthesis pipeline_cpu_core netlist.
// External imem + dmem modeled outside the core.
// Register file values reconstructed from monitor_* ports.
// ==============================

`timescale 1ns/1ps

module tb_gls;

    // Clock period - read from plusarg before any clock generation
    real clk_period;
    real half_period;

    reg clk;
    reg reset;
    reg clk_en;

    reg [255:0] hex_file;
    integer max_cycles;
    integer i;
    integer cycle_count;
    integer error_count;

    wire [31:0] instr_in;
    wire [31:0] dmem_addr;
    wire        dmem_we;
    wire [31:0] dmem_wdata;
    wire [2:0]  dmem_mode;
    wire [31:0] dmem_rdata;

    wire [31:0] monitor_pc;
    wire [31:0] monitor_instr;
    wire [31:0] monitor_alu_out;
    wire [4:0]  monitor_rd_addr;
    wire [31:0] monitor_rd_data;
    wire        monitor_rd_valid;
    wire [31:0] monitor_mem_addr;
    wire [31:0] monitor_mem_data;
    wire        monitor_mem_we;

    reg [31:0] shadow_regs [0:31];

    pipeline_cpu_core_BTB_ENTRIES16_BTB_INDEX_BITS4_TAG_BITS16_BHT_ENTRIES16_BHT_INDEX_BITS4 u_dut (
        .clk(clk),
        .reset(reset),
        .instr_in(instr_in),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_mode(dmem_mode),
        .dmem_rdata(dmem_rdata),
        .monitor_pc(monitor_pc),
        .monitor_instr(monitor_instr),
        .monitor_alu_out(monitor_alu_out),
        .monitor_rd_addr(monitor_rd_addr),
        .monitor_rd_data(monitor_rd_data),
        .monitor_rd_valid(monitor_rd_valid),
        .monitor_mem_addr(monitor_mem_addr),
        .monitor_mem_data(monitor_mem_data),
        .monitor_mem_we(monitor_mem_we)
    );

    gls_imem u_imem (
        .address(monitor_pc),
        .instr(instr_in)
    );

    datamem u_dmem (
        .clk(clk),
        .reset(reset),
        .address(dmem_addr),
        .we(dmem_we),
        .d_in(dmem_wdata),
        .mode(dmem_mode),
        .d_out(dmem_rdata)
    );

    // Clock generator - runs after clk_en is set so half_period is valid.
    always begin
        @(posedge clk_en);
        forever #(half_period) clk = ~clk;
    end

    // Shadow register file capture from WB stage
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                shadow_regs[i] <= 32'b0;
        end else if (monitor_rd_valid && (monitor_rd_addr != 5'd0)) begin
            shadow_regs[monitor_rd_addr] <= monitor_rd_data;
        end
    end

    // SDF back-annotation
    initial begin
        $sdf_annotate(
            "../../syn/outputs/pipeline_cpu_core.sdf",
            u_dut,
            ,
            "sdf.log",
            "MAXIMUM"
        );
    end

    initial begin
        if (!$value$plusargs("CLK_PERIOD=%f", clk_period))
            clk_period = 5.2;
        half_period = clk_period / 2.0;

        if (!$value$plusargs("HEX_FILE=%s", hex_file))
            hex_file = "all_tests.hex";

        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 200;

        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_gls);

        cycle_count = 0;
        error_count = 0;
        for (i = 0; i < 32; i = i + 1)
            shadow_regs[i] = 32'b0;

        // Initial values
        clk    = 1'b0;
        clk_en = 1'b0;
        // Pulse reset while the clock is stopped. With SDF timing checks enabled,
        // deasserting an asynchronous reset close to an active clock edge creates
        // recovery/removal violations that hide real GLS behavior.
        reset  = 1'b0;
        #1;
        reset  = 1'b1;
        #(10.0 * clk_period);
        reset = 1'b0;
        #(10.0 * clk_period);

        $display("============================================================");
        $display(" Gate-Level Simulation (GLS) - pipeline_cpu_core (synthesized)");
        $display("============================================================");
        $display(" CLK period      : %0.2f ns  (%.2f MHz)", clk_period, 1000.0/clk_period);
        $display(" HEX file        : %0s", hex_file);
        $display(" Max cycles      : %0d", max_cycles);
        $display("------------------------------------------------------------");

        // Now enable clock generator
        clk_en = 1'b1;
        $display("[%0t ns] Reset released, monitor_pc=0x%08h", $time, monitor_pc);

        repeat (max_cycles) @(posedge clk);
        cycle_count = max_cycles;

        @(negedge clk);

        $display("============================================================");
        $display(" Run finished after %0d cycles (sim time = %0t ns)", cycle_count, $time);
        $display(" Final shadow register state (reconstructed from WB):");
        $display("------------------------------------------------------------");
        for (i = 0; i < 32; i = i + 1) begin
            $display("   x%0d = 0x%08h", i, shadow_regs[i]);
        end

        $display("============================================================");
        $display(" Expected results for %0s :", hex_file);
        $display("------------------------------------------------------------");

        // Defaults validate all_tests.hex
        // Note: x1/x2/x3/x8/x9 are reassigned by parts 7-8 (loop & JAL),
        // so final values differ from initialization.
        check_reg(5'd1,  32'h00000005, "Loop counter x1=5 (Part 7 final)");
        check_reg(5'd2,  32'h00000005, "Loop limit x2=5 (Part 7 overwrite)");
        check_reg(5'd3,  32'h00000064, "JAL return addr x3=0x64 (Part 8 overwrite)");
        check_reg(5'd4,  32'h00000028, "R-Type ADD x4=40");
        check_reg(5'd5,  32'h00000014, "R-Type SUB x5=20");
        check_reg(5'd6,  32'h0000001A, "I-Type ADDI x6=26");
        check_reg(5'd7,  32'h00000028, "I-Type SLLI x7=40");
        check_reg(5'd8,  32'h00000100, "Base addr x8=0x100 (JAL skipped overwrite)");
        check_reg(5'd9,  32'h00000003, "JAL target x9=3 (Part 8 overwrite)");
        check_reg(5'd10, 32'h12345678, "Load x10");
        check_reg(5'd11, 32'h12345678, "Load-use x11");
        check_reg(5'd12, 32'h2468ACF0, "Load-use ALU x12");
        check_reg(5'd14, 32'h00000000, "Branch skip x14=0");
        check_reg(5'd15, 32'h00000000, "Branch skip x15=0");
        check_reg(5'd16, 32'h00000002, "BNE target x16=2");

        $display("============================================================");
        if (error_count == 0) begin
            $display(" [PASS] GLS checks completed with 0 errors.");
            $finish;
        end else begin
            $display(" [FAIL] GLS checks completed with %0d errors.", error_count);
            $finish;
        end
    end

    task check_reg(input [4:0] idx, input [31:0] expected, input [511:0] label);
        begin
            if (shadow_regs[idx] === expected)
                $display(" [PASS] %0s: x%0d = 0x%08h", label, idx, expected);
            else begin
                $display(" [FAIL] %0s: x%0d = 0x%08h (expected 0x%08h)",
                         label, idx, shadow_regs[idx], expected);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        #(2_000_000);
        $display(" [TIMEOUT] Simulation exceeded 2 ms wall clock, force finish.");
        $finish;
    end

endmodule

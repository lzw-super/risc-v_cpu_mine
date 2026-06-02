module pipeline_cpu_fpga (
    input           clk,
    input           reset,
    input  [31:0]   instr_in,
    output [31:0]   monitor_pc,
    output [31:0]   monitor_instr,
    output [31:0]   monitor_alu_out,
    output [4:0]    monitor_rd_addr,
    output [31:0]   monitor_rd_data,
    output          monitor_rd_valid,
    output [31:0]   monitor_mem_addr,
    output [31:0]   monitor_mem_data,
    output          monitor_mem_we
);

    wire [31:0] dmem_addr;
    wire        dmem_we;
    wire [31:0] dmem_wdata;
    wire [2:0]  dmem_mode;
    wire [31:0] dmem_rdata;

    pipeline_cpu_core u_core (
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

    datamem u_datamem (
        .clk(clk),
        .reset(reset),
        .address(dmem_addr),
        .we(dmem_we),
        .d_in(dmem_wdata),
        .mode(dmem_mode),
        .d_out(dmem_rdata)
    );

endmodule

// ==============================
// 五级流水线 CPU 顶层模块
// ==============================
// IF -> ID -> EX -> MEM -> WB
// 包含转发单元和冒险检测单元

module pipeline_cpu (
    input           clk,
    input           reset
);

    // ==================== Wire Declarations ====================

    // ========== IF Stage Signals ==========
    wire [31:0]   if_pc;
    wire [31:0]   if_instr;
    wire [31:0]   if_next_pc;
    wire          if_stall;      // PC暂停控制

    // ========== ID Stage Signals ==========
    wire [31:0]   id_pc;
    wire [31:0]   id_instr;
    // Decoder outputs
    wire [4:0]    id_rs1_addr;
    wire [4:0]    id_rs2_addr;
    wire [31:0]   id_imm;
    wire [4:0]    id_rd_addr;
    wire [7:0]    id_aluop;
    wire          id_re1, id_re2, id_we;
    wire          id_pce, id_imme, id_jmpe, id_be;
    wire [2:0]    id_bop, id_dmop;
    wire          id_mwe, id_doe;
    // Regfile outputs (原始值)
    wire [31:0]   id_rs1_val_raw;
    wire [31:0]   id_rs2_val_raw;

    // ========== ID/EX Register Signals ==========
    wire [31:0]   ex_pc;
    wire [31:0]   ex_rs1_val;
    wire [31:0]   ex_rs2_val;
    wire [31:0]   ex_imm;
    wire [4:0]    ex_rs1_addr;
    wire [4:0]    ex_rs2_addr;
    wire [4:0]    ex_rd_addr;
    wire [7:0]    ex_aluop;
    wire          ex_re1, ex_re2, ex_we;
    wire          ex_pce, ex_imme, ex_jmpe, ex_be;
    wire [2:0]    ex_bop, ex_dmop;
    wire          ex_mwe, ex_mem_read;

    // ========== EX Stage Signals ==========
    // Forwarding
    wire [1:0]    forward_a, forward_b;
    wire [31:0]   ex_data1_forwarded;
    wire [31:0]   ex_data2_forwarded;
    // ALU inputs
    wire [31:0]   ex_alu_data1;
    wire [31:0]   ex_alu_data2;
    wire [31:0]   ex_alu_out;
    // Branch result
    wire          ex_branch_taken;
    wire [31:0]   ex_branch_target;

    // ========== EX/MEM Register Signals ==========
    wire [31:0]   mem_alu_out;
    wire [31:0]   mem_rs2_val;
    wire [4:0]    mem_rd_addr;
    wire          mem_we;
    wire [2:0]    mem_dmop;
    wire          mem_mwe, mem_mem_read;
    wire          mem_branch_taken;

    // ========== MEM Stage Signals ==========
    wire [31:0]   mem_data_out;
    wire          mem_actual_taken;    // 实际分支结果
    wire [31:0]   mem_actual_target;

    // ========== MEM/WB Register Signals ==========
    wire [31:0]   wb_data;
    wire [4:0]    wb_rd_addr;
    wire          wb_we;

    // ========== Control Signals ==========
    wire          stall_pc;
    wire          stall_if_id;
    wire          flush_id_ex;
    wire          branch_mispredict;
    wire          id_is_branch;

    // Branch flush control
    reg           branch_mispredict_quiet;

    // ==================== Module Instantiations ====================

    // ========== IF Stage ==========

    // PC Module
    pc u_pc (
        .clk(clk),
        .reset(reset), 
        .stall(stall_pc),
        .jmp(ex_branch_target),
        .jmp_en(ex_jmpe || ex_branch_taken),
        .branch_en(ex_branch_taken),
        .curr_pc(if_pc),
        .next_pc(if_next_pc)
    );

    // Pipeline Instruction Memory
    pipeline_imem u_imem (
        .address(if_pc),
        .instr(if_instr)
    );

    // ========== IF/ID Register ==========

    if_id_reg u_if_id (
        .clk(clk),
        .reset(reset),
        .stall(stall_if_id),
        .flush(branch_mispredict),
        .pc_in(if_pc),
        .instr_in(if_instr),
        .pc_out(id_pc),
        .instr_out(id_instr)
    );

    // ========== ID Stage ==========

    // Decoder
    decoder u_decoder (
        .instr(id_instr),
        .rs1(id_rs1_addr),
        .rs2(id_rs2_addr),
        .imm(id_imm),
        .wd(id_rd_addr),
        .aluop(id_aluop),
        .re1(id_re1),
        .re2(id_re2),
        .we(id_we),
        .pce(id_pce),
        .imme(id_imme),
        .jmpe(id_jmpe),
        .be(id_be),
        .bop(id_bop),
        .dmop(id_dmop),
        .doe(id_doe),
        .mwe(id_mwe)
    );

    // Regfile - 在流水线中，WB阶段写回
    regfile u_regfile (
        .clk(clk),
        .reset(reset),
        .rs1(id_rs1_addr),
        .rs2(id_rs2_addr),
        .re1(id_re1),
        .re2(id_re2),
        .wd(wb_rd_addr),        // 来自MEM/WB
        .we(wb_we),             // 来自MEM/WB
        .wdata(wb_data),        // 来自MEM/WB
        .rs1_value(id_rs1_val_raw),
        .rs2_value(id_rs2_val_raw)
    );

    // 判断是否是分支指令
    assign id_is_branch = (id_instr[6:0] == 7'b1100011);
    // Load指令判断（opcode == 0000011）
    wire id_is_load = (id_instr[6:0] == 7'b0000011);

    // ========== ID/EX Register ==========

    id_ex_reg u_id_ex (
        .clk(clk),
        .reset(reset),
        .stall(flush_id_ex),
        .flush(branch_mispredict),
        // Control signals
        .re1_in(id_re1),
        .re2_in(id_re2),
        .we_in(id_we),
        .imme_in(id_imme),
        .pce_in(id_pce),
        .jmpe_in(id_jmpe),
        .be_in(id_be),
        .alu_op_in(id_aluop),
        .dmop_in(id_dmop),
        .mwe_in(id_mwe),
        .mem_read_in(id_is_load),
        // Data
        .pc_in(id_pc),
        .rs1_val_in(id_rs1_val_raw),
        .rs2_val_in(id_rs2_val_raw),
        .imm_in(id_imm),
        .rs1_addr_in(id_rs1_addr),
        .rs2_addr_in(id_rs2_addr),
        .rd_addr_in(id_rd_addr),
        .instr_in(id_instr),
        // Outputs
        .re1_out(ex_re1),
        .re2_out(ex_re2),
        .we_out(ex_we),
        .imme_out(ex_imme),
        .pce_out(ex_pce),
        .jmpe_out(ex_jmpe),
        .be_out(ex_be),
        .alu_op_out(ex_aluop),
        .dmop_out(ex_dmop),
        .mwe_out(ex_mwe),
        .mem_read_out(ex_mem_read),
        .pc_out(ex_pc),
        .rs1_val_out(ex_rs1_val),
        .rs2_val_out(ex_rs2_val),
        .imm_out(ex_imm),
        .rs1_addr_out(ex_rs1_addr),
        .rs2_addr_out(ex_rs2_addr),
        .rd_addr_out(ex_rd_addr),
        .instr_out()
    );

    // ========== EX Stage ==========

    // Forward Unit
    forward_unit u_forward (
        .rs1_addr(ex_rs1_addr),
        .rs2_addr(ex_rs2_addr),
        .ex_mem_rd(mem_rd_addr),
        .ex_mem_we(mem_we),
        .mem_wb_rd(wb_rd_addr),
        .mem_wb_we(wb_we),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // Forwarding MUX for rs1
    assign ex_data1_forwarded = (forward_a == 2'b01) ? mem_alu_out :
                                (forward_a == 2'b10) ? wb_data :
                                ex_rs1_val;

    // Forwarding MUX for rs2
    assign ex_data2_forwarded = (forward_b == 2'b01) ? mem_alu_out :
                                (forward_b == 2'b10) ? wb_data :
                                ex_rs2_val;

    // ALU input MUX (PC vs rs1, imm vs rs2)
    assign ex_alu_data1 = ex_pce ? ex_pc : ex_data1_forwarded;
    assign ex_alu_data2 = ex_imme ? ex_imm : ex_data2_forwarded;

    // ALU
    alu u_alu (
        .data1(ex_alu_data1),
        .data2(ex_alu_data2),
        .op(ex_aluop),
        .res(ex_alu_out)
    );

    // Branch Module - 在EX阶段计算分支
    branch u_branch (
        .enable(ex_be),
        .op(ex_bop),
        .v1(ex_data1_forwarded),
        .v2(ex_data2_forwarded),
        .out(ex_branch_taken)
    );

    // 分支目标地址
    assign ex_branch_target = ex_pc + ex_imm;

    // ========== EX/MEM Register ==========

    ex_mem_reg u_ex_mem (
        .clk(clk),
        .reset(reset),
        .flush(1'b0),  // 通常不需要flush
        .we_in(ex_we),
        .dmop_in(ex_dmop),
        .mwe_in(ex_mwe),
        .mem_read_in(ex_mem_read),
        .alu_out_in(ex_alu_out),
        .rs2_val_in(ex_data2_forwarded),
        .rd_addr_in(ex_rd_addr),
        .pc_in(ex_pc),
        .branch_taken_in(ex_branch_taken),
        .we_out(mem_we),
        .dmop_out(mem_dmop),
        .mwe_out(mem_mwe),
        .mem_read_out(mem_mem_read),
        .alu_out_out(mem_alu_out),
        .rs2_val_out(mem_rs2_val),
        .rd_addr_out(mem_rd_addr),
        .pc_out(),
        .branch_taken_out(mem_branch_taken)
    );

    // ========== MEM Stage ==========

    // Data Memory
    datamem u_datamem (
        .clk(clk),
        .reset(reset),
        .address(mem_alu_out),
        .we(mem_mwe),
        .d_in(mem_rs2_val),
        .mode(mem_dmop),
        .d_out(mem_data_out)
    );

    // 实际分支结果（MEM阶段确认）
    assign mem_actual_taken = mem_branch_taken;
    assign mem_actual_target = mem_alu_out;  // 对于JALR，目标地址是ALU结果

    // ========== MEM/WB Register ==========

    mem_wb_reg u_mem_wb (
        .clk(clk),
        .reset(reset),
        .we_in(mem_we),
        .mem_data_in(mem_data_out),
        .alu_out_in(mem_alu_out),
        .rd_addr_in(mem_rd_addr),
        .mem_read_in(mem_mem_read),
        .we_out(wb_we),
        .wb_data_out(wb_data),
        .rd_addr_out(wb_rd_addr)
    );

    // ========== WB Stage ==========
    // WB操作在MEM/WB寄存器中完成，直接输出到regfile

    // ========== Hazard Detection Unit ==========

    hazard_unit u_hazard (
        .id_rs1_addr(id_rs1_addr),
        .id_rs2_addr(id_rs2_addr),
        .id_re1(id_re1),
        .id_re2(id_re2),
        .id_ex_rd(ex_rd_addr),
        .id_ex_mem_read(ex_mem_read),
        .stall_pc(stall_pc),
        .stall_if_id(stall_if_id),
        .stall_id_ex(flush_id_ex)
    );

    // ========== Branch Mispredict Detection ==========
    // 简化实现：分支总是等到EX阶段才确定，预测错误的flush信号
    assign branch_mispredict = mem_branch_taken && !branch_mispredict_quiet;

    // 用于控制分支flush（简化处理）
    always @(posedge clk) begin
        if (reset)
            branch_mispredict_quiet <= 1'b0;
        else
            branch_mispredict_quiet <= mem_branch_taken;
    end

    // 实际使用简单的flush逻辑：当分支发生时flush
    wire branch_flush = mem_branch_taken;

    // ==================== Pipeline Control Logic ====================

    // 这里简化实现：
    // 1. Load-Use冒险由hazard_unit处理
    // 2. 分支冒险：采用简单的"总是flush"策略（静态预测不跳转）

    // 替代flush信号：当分支发生时，清空IF/ID和ID/EX
    // 实际使用ex_mem输出的branch_taken来控制flush

endmodule
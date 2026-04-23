// ==============================
// 五级流水线 CPU 顶层模块
// ==============================
// IF -> ID -> EX -> MEM -> WB
// 包含转发单元、冒险检测单元和动态分支预测(BTB+BHT)
//
// 分支预测优化：mispredict检测在EX阶段完成，减少1周期惩罚
// J型指令预测：JAL/JALR使用BTB缓存目标地址，动态预测跳转
// ==============================

module pipeline_cpu (
    input           clk,
    input           reset
);

    // ==================== Wire Declarations ====================

    // ========== IF Stage Signals ==========
    wire [31:0]   if_pc;
    wire [31:0]   if_instr;
    wire [31:0]   if_next_pc_seq;   // 顺序下一个PC (PC+4)
    // BTB/BHT预测信号
    wire          if_btb_hit;
    wire [31:0]   if_predicted_target;
    wire          if_predict_taken;
    wire          if_predicted_valid;
    wire [31:0]   if_predicted_pc;

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
    wire          id_is_load;    // load指令标志
    wire [1:0]    id_wb_sel;     // WB数据选择
    wire          id_is_jump;    // jump指令标志 (JAL/JALR)
    // 预测信号（来自IF/ID寄存器）
    wire          id_predict_taken;
    wire [31:0]   id_predict_target;
    wire          id_btb_hit;
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
    wire [1:0]    ex_wb_sel;     // WB数据选择
    wire [31:0]   ex_pc_next;    // PC+4 用于JAL/JALR写回
    // 预测信号（用于EX阶段mispredict检测）
    wire          ex_predict_taken;
    wire [31:0]   ex_predict_target;
    wire          ex_btb_hit;
    wire          ex_is_branch;
    wire          ex_is_jump;    // jump指令标志

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
    // Mispredict detection (在EX阶段检测)
    wire          ex_mispredict;
    wire [31:0]   ex_correct_target;

    // ========== EX/MEM Register Signals ==========
    // 仅保留MEM/WB阶段需要的数据信号
    wire [31:0]   mem_alu_out;
    wire [31:0]   mem_rs2_val;    // 用于Store指令
    wire [31:0]   mem_imm;        // 用于LUI写回
    wire [4:0]    mem_rd_addr;
    wire          mem_we;
    wire [2:0]    mem_dmop;
    wire          mem_mwe, mem_mem_read;
    wire [1:0]    mem_wb_sel;     // WB数据选择
    wire [31:0]   mem_pc_next;    // PC+4 用于JAL/JALR写回

    // ========== MEM Stage Signals ==========
    wire [31:0]   mem_data_out;   // 内存读取数据

    // ========== MEM/WB Register Signals ==========
    wire [31:0]   wb_data;
    wire [4:0]    wb_rd_addr;
    wire          wb_we;

    // ========== Control Signals ==========
    wire          stall_pc;
    wire          stall_if_id;
    wire          flush_id_ex;
    wire          if_id_flush;
    wire          id_ex_flush;

    // ==================== Module Instantiations ====================

    // ========== IF Stage ==========

    // BTB实例化（查询在IF阶段，更新在EX阶段）
    // 支持分支指令和跳转指令(JAL/JALR)
    btb u_btb (
        .clk(clk),
        .reset(reset),
        .fetch_pc(if_pc),
        .btb_hit(if_btb_hit),
        .predicted_target(if_predicted_target),
        .update_enable(ex_is_branch || ex_is_jump),  // 分支或跳转指令
        .is_jump(ex_is_jump),                         // 跳转指令标志
        .branch_pc(ex_pc),
        .actual_target(ex_branch_target),
        .branch_taken(ex_branch_taken || ex_jmpe)    // 跳转指令总是跳转
    );

    // BHT实例化（查询在IF阶段，更新在EX阶段）
    // 支持分支指令和跳转指令
    bht u_bht (
        .clk(clk),
        .reset(reset),
        .fetch_pc(if_pc),
        .predict_taken(if_predict_taken),
        .update_enable(ex_is_branch || ex_is_jump),  // 分支或跳转指令
        .is_jump(ex_is_jump),                         // 跳转指令标志
        .branch_pc(ex_pc),
        .actual_taken(ex_branch_taken || ex_jmpe)    // 跳转指令总是跳转
    );

    // 预测逻辑
    // 跳转指令(JAL/JALR)总是预测跳转，分支指令使用BHT预测
    assign if_predicted_valid = if_predict_taken && if_btb_hit;
    assign if_predicted_pc = if_predicted_valid ? if_predicted_target : (if_pc + 32'h4);
    assign if_next_pc_seq = if_pc + 32'h4;

    // ========== EX Stage Mispredict Detection ==========

    // 在EX阶段检测mispredict（比MEM阶段早一个周期）
    // 分支指令：预测方向错误
    // 跳转指令：预测目标地址错误（跳转指令总是跳转，只需检测目标）

    // 分支方向预测错误检测
    wire ex_branch_dir_mispredict = ex_is_branch &&
        ((ex_predict_taken && !ex_branch_taken) ||
         (!ex_predict_taken && ex_branch_taken));

    // 跳转目标预测错误检测（仅在BTB命中且目标不匹配时）
    wire ex_jump_target_mispredict = ex_is_jump && ex_btb_hit &&
        (ex_predict_target != ex_branch_target);

    // 综合mispredict信号
    assign ex_mispredict = ex_branch_dir_mispredict || ex_jump_target_mispredict;

    // 计算正确的目标地址（在EX阶段）
    // 分支不跳转时：PC+4
    // 分支跳转或跳转指令：实际目标地址
    assign ex_correct_target = (ex_is_branch && !ex_branch_taken) ? (ex_pc + 32'h4) :
                               ex_branch_target;

    // PC重定向控制
    // Mispredict修正：使用正确目标地址
    // 非预测跳转指令首次执行：使用实际目标地址（此时BTB未命中）
    wire redirect_en;
    wire [31:0] redirect_pc;
    assign redirect_en = ex_mispredict || (ex_jmpe && !ex_btb_hit);
    assign redirect_pc = ex_mispredict ? ex_correct_target : ex_branch_target;

    pc u_pc (
        .clk(clk),
        .reset(reset),
        .stall(stall_pc),
        .predicted_pc(if_predicted_pc),
        .predicted_valid(if_predicted_valid),
        .redirect_pc(redirect_pc),
        .redirect_en(redirect_en),
        .curr_pc(if_pc),
        .next_pc(if_next_pc_seq)
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
        .flush(if_id_flush),
        .pc_in(if_pc),
        .instr_in(if_instr),
        .predict_taken_in(if_predict_taken),
        .predict_target_in(if_predicted_target),
        .btb_hit_in(if_btb_hit),
        .pc_out(id_pc),
        .instr_out(id_instr),
        .predict_taken_out(id_predict_taken),
        .predict_target_out(id_predict_target),
        .btb_hit_out(id_btb_hit)
    );

    // ========== ID Stage ==========

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
        .mwe(id_mwe),
        .is_load(id_is_load),
        .wb_sel(id_wb_sel),
        .is_jump(id_is_jump)    // 新增：跳转指令标志
    );

    // Regfile - WB阶段写回
    regfile u_regfile (
        .clk(clk),
        .reset(reset),
        .rs1(id_rs1_addr),
        .rs2(id_rs2_addr),
        .re1(id_re1),
        .re2(id_re2),
        .wd(wb_rd_addr),
        .we(wb_we),
        .wdata(wb_data),
        .rs1_value(id_rs1_val_raw),
        .rs2_value(id_rs2_val_raw)
    );

    // ========== ID/EX Register ==========

    id_ex_reg u_id_ex (
        .clk(clk),
        .reset(reset),
        .stall(flush_id_ex),
        .flush(id_ex_flush),
        // Control signals
        .re1_in(id_re1),
        .re2_in(id_re2),
        .we_in(id_we),
        .imme_in(id_imme),
        .pce_in(id_pce),
        .jmpe_in(id_jmpe),
        .be_in(id_be),
        .bop_in(id_bop),
        .alu_op_in(id_aluop),
        .dmop_in(id_dmop),
        .mwe_in(id_mwe),
        .mem_read_in(id_is_load),
        .wb_sel_in(id_wb_sel),
        // Prediction signals
        .predict_taken_in(id_predict_taken),
        .predict_target_in(id_predict_target),
        .btb_hit_in(id_btb_hit),
        .is_branch_in(id_be),
        .is_jump_in(id_is_jump),    // 新增：跳转指令标志
        // Data
        .pc_in(id_pc),
        .pc_next_in(id_pc + 32'h4),
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
        .bop_out(ex_bop),
        .alu_op_out(ex_aluop),
        .dmop_out(ex_dmop),
        .mwe_out(ex_mwe),
        .mem_read_out(ex_mem_read),
        .wb_sel_out(ex_wb_sel),
        .predict_taken_out(ex_predict_taken),
        .predict_target_out(ex_predict_target),
        .btb_hit_out(ex_btb_hit),
        .is_branch_out(ex_is_branch),
        .is_jump_out(ex_is_jump),   // 新增：跳转指令标志
        .pc_out(ex_pc),
        .pc_next_out(ex_pc_next),
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

    // Forwarding MUX
    assign ex_data1_forwarded = (forward_a == 2'b01) ? mem_alu_out :
                                (forward_a == 2'b10) ? wb_data :
                                ex_rs1_val;

    assign ex_data2_forwarded = (forward_b == 2'b01) ? mem_alu_out :
                                (forward_b == 2'b10) ? wb_data :
                                ex_rs2_val;

    // ALU input MUX
    assign ex_alu_data1 = ex_pce ? ex_pc : ex_data1_forwarded;
    assign ex_alu_data2 = ex_imme ? ex_imm : ex_data2_forwarded;

    // ALU
    alu u_alu (
        .data1(ex_alu_data1),
        .data2(ex_alu_data2),
        .op(ex_aluop),
        .res(ex_alu_out)
    );

    // Branch Module
    branch u_branch (
        .enable(ex_be),
        .op(ex_bop),
        .v1(ex_data1_forwarded),
        .v2(ex_data2_forwarded),
        .out(ex_branch_taken)
    );

    // 分支目标地址
    // JAL: target = PC + imm (pce=1时, ALU使用PC)
    // JALR: target = rs1 + imm (pce=0时, ALU使用rs1)
    // Branch: target = PC + imm
    // 使用ALU输出作为跳转目标地址，因为ALU已经正确计算了
    assign ex_branch_target = ex_jmpe ? ex_alu_out : (ex_pc + ex_imm);

    // ========== EX/MEM Register ==========

    ex_mem_reg u_ex_mem (
        .clk(clk),
        .reset(reset),
        .flush(1'b0),
        .we_in(ex_we),
        .dmop_in(ex_dmop),
        .mwe_in(ex_mwe),
        .mem_read_in(ex_mem_read),
        .wb_sel_in(ex_wb_sel),
        .alu_out_in(ex_alu_out),
        .rs2_val_in(ex_data2_forwarded),
        .imm_in(ex_imm),
        .rd_addr_in(ex_rd_addr),
        .pc_next_in(ex_pc_next),
        .we_out(mem_we),
        .dmop_out(mem_dmop),
        .mwe_out(mem_mwe),
        .mem_read_out(mem_mem_read),
        .wb_sel_out(mem_wb_sel),
        .alu_out_out(mem_alu_out),
        .rs2_val_out(mem_rs2_val),
        .imm_out(mem_imm),
        .rd_addr_out(mem_rd_addr),
        .pc_next_out(mem_pc_next)
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

    // ========== MEM/WB Register ==========

    mem_wb_reg u_mem_wb (
        .clk(clk),
        .reset(reset),
        .we_in(mem_we),
        .wb_sel_in(mem_wb_sel),
        .mem_data_in(mem_data_out),
        .alu_out_in(mem_alu_out),
        .imm_in(mem_imm),
        .pc_next_in(mem_pc_next),
        .rd_addr_in(mem_rd_addr),
        .we_out(wb_we),
        .wb_data_out(wb_data),
        .rd_addr_out(wb_rd_addr),
        .wb_sel_out()  // 不需要外部使用，仅用于内部wb_mux
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

    // ========== Pipeline Flush Control ==========

    // Flush流水线条件：
    // 1. 分支方向预测错误
    // 2. 跳转目标预测错误
    // 3. 跳转指令首次执行（BTB未命中，需要建立缓存）
    assign if_id_flush = ex_mispredict || (ex_jmpe && !ex_btb_hit);
    assign id_ex_flush = ex_mispredict || (ex_jmpe && !ex_btb_hit);

endmodule
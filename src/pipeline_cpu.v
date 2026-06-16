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
    input           reset,
    output [31:0]   aluout
);

    // ==================== Wire Declarations ====================

    // ========== IF Stage Signals ==========
    wire [31:0]   if_pc;
    wire [31:0]   if_instr;
    // BTB/BHT预测信号
    wire          if_btb_hit;
    wire [31:0]   if_predicted_target;
    wire          if_predict_taken;
    wire          if_predicted_valid;
    reg           if_predicted_valid_q;
    reg  [31:0]   if_predicted_pc_q;

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
    // ========== ID1 Registered Decode Signals ==========
    wire [31:0]   id1_pc;
    wire [31:0]   id1_pc_next;
    wire [31:0]   id1_instr;
    wire [4:0]    id1_rs1_addr;
    wire [4:0]    id1_rs2_addr;
    wire [31:0]   id1_imm;
    wire [4:0]    id1_rd_addr;
    wire [7:0]    id1_aluop;
    wire          id1_re1, id1_re2, id1_we;
    wire          id1_pce, id1_imme, id1_jmpe, id1_be;
    wire [2:0]    id1_bop, id1_dmop;
    wire          id1_mwe;
    wire          id1_is_load;
    wire [1:0]    id1_wb_sel;
    wire          id1_is_branch;
    wire          id1_is_jump;
    wire          id1_predict_taken;
    wire [31:0]   id1_predict_target;
    wire          id1_btb_hit;
    wire [31:0]   id1_rs1_val_raw;
    wire [31:0]   id1_rs2_val_raw;

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
    wire [31:0]   ex_data1_ready;
    wire [31:0]   ex_data2_ready;
    // ALU inputs
    wire [31:0]   ex0_alu_data1;
    wire [31:0]   ex0_alu_data2;
    wire [31:0]   ex_alu_data1;
    wire [31:0]   ex_alu_data2;
    wire [31:0]   ex_alu_result;  // ALU原始输出
    wire [31:0]   ex_mdu_out;     // MDU输出
    wire          ex_is_m_type;   // 当前EX阶段是否为M-type指令
    wire          ex_mdu_start;
    wire          ex_mdu_busy;
    wire          ex_mdu_done;
    wire          ex_mdu_stall_raw;
    wire          ex_mdu_stall;
    wire          id_ex_hold;
    wire [31:0]   ex_alu_out;     // ALU/MDU结果（MUX后）
    // Branch result
    wire          ex_branch_taken;
    wire [31:0]   ex_branch_target;
    // Redirect evaluation is split across EX and a lightweight EX2 stage.
    wire          ex_branch_dir_mispredict;
    wire          ex_jump_target_mispredict_debug;
    wire          ex_mispredict;
    wire          ex_branch_predicted_taken;
    wire          ex_control_redirect_early;
    wire          ex_jump_redirect_early;
    wire [31:0]   ex_debug_target;
    wire          ex_redirect_prepare;
    wire          redirect_pending_q;
    wire          redirect_eval_request;
    wire [31:0]   redirect_eval_target;
    wire [31:0]   redirect_eval_correct_pc;

    // ========== EX0/EX1 Register Signals ==========
    reg [31:0]    ex1_pc;
    reg [31:0]    ex1_pc_next;
    reg [31:0]    ex1_imm;
    reg [31:0]    ex1_branch_data1;
    reg [31:0]    ex1_alu_data1;
    reg [31:0]    ex1_alu_data2;
    reg [31:0]    ex1_store_data;
    reg [4:0]     ex1_rd_addr;
    reg [7:0]     ex1_aluop;
    reg           ex1_alu_add;
    reg           ex1_alu_sub;
    reg           ex1_alu_sll;
    reg           ex1_alu_slt;
    reg           ex1_alu_sltu;
    reg           ex1_alu_xor;
    reg           ex1_alu_srl;
    reg           ex1_alu_sra;
    reg           ex1_alu_or;
    reg           ex1_alu_and;
    reg           ex1_we;
    reg           ex1_pce;
    reg           ex1_jmpe;
    reg           ex1_be;
    reg [2:0]     ex1_bop;
    reg [2:0]     ex1_dmop;
    reg           ex1_mwe;
    reg           ex1_mem_read;
    reg [1:0]     ex1_wb_sel;
    reg           ex1_predict_taken;
    reg [31:0]    ex1_predict_target;
    reg           ex1_btb_hit;
    reg           ex1_is_branch;
    reg           ex1_is_jump;

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
    wire          if_prediction_flush;
    wire          id_ex_flush;
    wire          id_decode_stall;
    wire          id_decode_flush;
    wire          redirect_flush;
    wire          redirect_block_ex;
    wire          pc_stall;
    wire          predictor_update_enable;
    wire          predictor_update_is_jump;
    wire [31:0]   predictor_update_pc;
    wire [31:0]   predictor_update_target;
    wire          predictor_update_taken;
    reg           predictor_update_valid_q;
    reg           predictor_update_is_jump_q;
    reg           predictor_update_taken_q;
    reg  [31:0]   predictor_update_pc_q;
    reg  [31:0]   predictor_update_target_q;
    reg           redirect_eval_valid_q;
    reg           redirect_eval_is_branch_q;
    reg           redirect_eval_is_jump_q;
    reg           redirect_eval_branch_mispredict_q;
    reg           redirect_eval_branch_taken_q;
    reg           redirect_eval_btb_hit_q;
    reg  [31:0]   redirect_eval_predict_target_q;
    reg  [31:0]   redirect_eval_pc_q;
    reg  [31:0]   redirect_eval_base_q;
    reg  [31:0]   redirect_eval_imm_q;
    reg           redirect_valid_q;
    reg  [31:0]   redirect_pc_q;
    reg           ex_operand_hold_valid_q;
    reg  [31:0]   ex_operand_hold_data1_q;
    reg  [31:0]   ex_operand_hold_data2_q;

    // ==================== Module Instantiations ====================
    assign aluout = ex_alu_out ; 
    // ========== IF Stage ==========

    // BTB实例化（查询在IF阶段，更新在EX阶段）
    // 支持分支指令和跳转指令(JAL/JALR)
    btb u_btb (
        .clk(clk),
        .reset(reset),
        .fetch_pc(if_pc),
        .btb_hit(if_btb_hit),
        .predicted_target(if_predicted_target),
        .update_enable(predictor_update_enable),      // 分支或跳转指令
        .is_jump(predictor_update_is_jump),           // 跳转指令标志
        .branch_pc(predictor_update_pc),
        .actual_target(predictor_update_target),
        .branch_taken(predictor_update_taken)         // 跳转指令总是跳转
    );

    // BHT实例化（查询在IF阶段，更新在EX阶段）
    // 支持分支指令和跳转指令
    bht u_bht (
        .clk(clk),
        .reset(reset),
        .fetch_pc(if_pc),
        .predict_taken(if_predict_taken),
        .update_enable(predictor_update_enable),      // 分支或跳转指令
        .is_jump(predictor_update_is_jump),           // 跳转指令标志
        .branch_pc(predictor_update_pc),
        .actual_taken(predictor_update_taken)         // 跳转指令总是跳转
    );

    // 预测逻辑
    // 跳转指令(JAL/JALR)总是预测跳转，分支指令使用BHT预测
    assign if_predicted_valid = if_predict_taken && if_btb_hit;

    // ========== EX/EX2 Redirect Evaluation ==========

    assign redirect_pending_q = redirect_eval_request || redirect_flush;

    // 分支方向预测错误检测仍在EX完成；target计算延后到EX2。
    assign ex_branch_predicted_taken = ex1_predict_taken && ex1_btb_hit;
    assign ex_branch_dir_mispredict = !redirect_pending_q && ex1_is_branch &&
        ((ex_branch_taken != ex_branch_predicted_taken) ||
         (ex_branch_taken && ex1_btb_hit && (ex1_predict_target != ex_debug_target)));

    assign ex_debug_target = ((ex1_is_branch || ex1_pce) ? ex1_pc : ex1_alu_data1) + ex1_imm;
    assign ex_jump_redirect_early = !redirect_pending_q && ex1_is_jump &&
        (!ex1_btb_hit || (ex1_predict_target != ex_debug_target));
    assign ex_jump_target_mispredict_debug = ex_jump_redirect_early && ex1_btb_hit;
    assign ex_control_redirect_early = ex_branch_dir_mispredict || ex_jump_redirect_early;
    assign ex_mispredict = ex_control_redirect_early;

    // JAL/JALR统一进入EX2做target计算和BTB target比较，切断EX forwarding到redirect寄存器的长路径。
    assign ex_redirect_prepare = !redirect_pending_q && (ex1_is_branch || ex1_is_jump);

    assign redirect_block_ex = redirect_pending_q;

    assign redirect_eval_target = redirect_eval_base_q + redirect_eval_imm_q;
    assign redirect_eval_request = redirect_eval_valid_q &&
        (redirect_eval_branch_mispredict_q ||
         (redirect_eval_is_jump_q &&
          (!redirect_eval_btb_hit_q ||
           (redirect_eval_predict_target_q != redirect_eval_target))));
    assign redirect_eval_correct_pc =
        (redirect_eval_is_branch_q && !redirect_eval_branch_taken_q) ?
        (redirect_eval_pc_q + 32'h4) : redirect_eval_target;

    assign predictor_update_is_jump = predictor_update_is_jump_q;
    assign predictor_update_enable = predictor_update_valid_q;
    assign predictor_update_pc = predictor_update_pc_q;
    assign predictor_update_target = predictor_update_target_q;
    assign predictor_update_taken = predictor_update_taken_q;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            predictor_update_valid_q <= 1'b0;
            predictor_update_is_jump_q <= 1'b0;
            predictor_update_taken_q <= 1'b0;
            predictor_update_pc_q <= 32'h0;
            predictor_update_target_q <= 32'h0;
            redirect_eval_valid_q <= 1'b0;
            redirect_eval_is_branch_q <= 1'b0;
            redirect_eval_is_jump_q <= 1'b0;
            redirect_eval_branch_mispredict_q <= 1'b0;
            redirect_eval_branch_taken_q <= 1'b0;
            redirect_eval_btb_hit_q <= 1'b0;
            redirect_eval_predict_target_q <= 32'h0;
            redirect_eval_pc_q <= 32'h0;
            redirect_eval_base_q <= 32'h0;
            redirect_eval_imm_q <= 32'h0;
            redirect_valid_q <= 1'b0;
            redirect_pc_q <= 32'h0;
        end else begin
            predictor_update_valid_q <= redirect_eval_valid_q;
            predictor_update_is_jump_q <= redirect_eval_is_jump_q;
            predictor_update_taken_q <= redirect_eval_is_jump_q ? 1'b1 : redirect_eval_branch_taken_q;
            predictor_update_pc_q <= redirect_eval_pc_q;
            predictor_update_target_q <= redirect_eval_target;

            redirect_eval_valid_q <= ex_redirect_prepare;
            if (ex_redirect_prepare) begin
                redirect_eval_is_branch_q <= ex1_is_branch;
                redirect_eval_is_jump_q <= ex1_is_jump;
                redirect_eval_branch_mispredict_q <= ex_branch_dir_mispredict;
                redirect_eval_branch_taken_q <= ex_branch_taken;
                redirect_eval_btb_hit_q <= ex1_btb_hit;
                redirect_eval_predict_target_q <= ex1_predict_target;
                redirect_eval_pc_q <= ex1_pc;
                redirect_eval_base_q <= (ex1_is_branch || ex1_pce) ? ex1_pc : ex1_alu_data1;
                redirect_eval_imm_q <= ex1_imm;
            end

            redirect_valid_q <= redirect_eval_request;
            redirect_pc_q <= redirect_eval_request ? redirect_eval_correct_pc : 32'h0;
        end
    end

    wire redirect_en;
    wire [31:0] redirect_pc;
    assign redirect_en = redirect_valid_q;
    assign redirect_pc = redirect_pc_q;
    assign redirect_flush = redirect_valid_q;
    assign pc_stall = (stall_pc || ex_mdu_stall) && !redirect_flush;
    assign id_decode_stall = stall_if_id || ex_mdu_stall_raw;
    assign id_decode_flush = id_ex_flush;
    assign if_prediction_flush = if_predicted_valid_q && !pc_stall && !redirect_flush;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            if_predicted_valid_q <= 1'b0;
            if_predicted_pc_q <= 32'h0;
        end else if (redirect_flush || if_prediction_flush) begin
            if_predicted_valid_q <= 1'b0;
            if_predicted_pc_q <= 32'h0;
        end else if (!pc_stall) begin
            if_predicted_valid_q <= if_predicted_valid;
            if_predicted_pc_q <= if_predicted_target;
        end
    end

    pc #(
        .REGISTER_NEXT_PC(0)
    ) u_pc (
        .clk(clk),
        .reset(reset),
        .stall(pc_stall),
        .predicted_pc(if_predicted_pc_q),
        .predicted_valid(if_predicted_valid_q),
        .redirect_pc(redirect_pc),
        .redirect_en(redirect_en),
        .curr_pc(if_pc),
        .next_pc()
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
        .stall(stall_if_id || ex_mdu_stall_raw),
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

    // ID0/ID1 Register: cut decoder outputs before regfile read.
    id_decode_reg u_id_decode (
        .clk(clk),
        .reset(reset),
        .stall(id_decode_stall),
        .flush(id_decode_flush),
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
        .predict_taken_in(id_predict_taken),
        .predict_target_in(id_predict_target),
        .btb_hit_in(id_btb_hit),
        .is_branch_in(id_be),
        .is_jump_in(id_is_jump),
        .pc_in(id_pc),
        .pc_next_in(id_pc + 32'h4),
        .imm_in(id_imm),
        .rs1_addr_in(id_rs1_addr),
        .rs2_addr_in(id_rs2_addr),
        .rd_addr_in(id_rd_addr),
        .instr_in(id_instr),
        .re1_out(id1_re1),
        .re2_out(id1_re2),
        .we_out(id1_we),
        .imme_out(id1_imme),
        .pce_out(id1_pce),
        .jmpe_out(id1_jmpe),
        .be_out(id1_be),
        .bop_out(id1_bop),
        .alu_op_out(id1_aluop),
        .dmop_out(id1_dmop),
        .mwe_out(id1_mwe),
        .mem_read_out(id1_is_load),
        .wb_sel_out(id1_wb_sel),
        .predict_taken_out(id1_predict_taken),
        .predict_target_out(id1_predict_target),
        .btb_hit_out(id1_btb_hit),
        .is_branch_out(id1_is_branch),
        .is_jump_out(id1_is_jump),
        .pc_out(id1_pc),
        .pc_next_out(id1_pc_next),
        .imm_out(id1_imm),
        .rs1_addr_out(id1_rs1_addr),
        .rs2_addr_out(id1_rs2_addr),
        .rd_addr_out(id1_rd_addr),
        .instr_out(id1_instr)
    );

    // Regfile - WB阶段写回
    regfile u_regfile (
        .clk(clk),
        .reset(reset),
        .rs1(id1_rs1_addr),
        .rs2(id1_rs2_addr),
        .re1(id1_re1),
        .re2(id1_re2),
        .wd(wb_rd_addr),
        .we(wb_we),
        .wdata(wb_data),
        .rs1_value(id1_rs1_val_raw),
        .rs2_value(id1_rs2_val_raw)
    );

    // ========== ID/EX Register ==========

    id_ex_reg u_id_ex (
        .clk(clk),
        .reset(reset),
        .stall(flush_id_ex),
        .hold(id_ex_hold),
        .flush(id_ex_flush),
        // Control signals
        .re1_in(id1_re1),
        .re2_in(id1_re2),
        .we_in(id1_we),
        .imme_in(id1_imme),
        .pce_in(id1_pce),
        .jmpe_in(id1_jmpe),
        .be_in(id1_be),
        .bop_in(id1_bop),
        .alu_op_in(id1_aluop),
        .dmop_in(id1_dmop),
        .mwe_in(id1_mwe),
        .mem_read_in(id1_is_load),
        .wb_sel_in(id1_wb_sel),
        // Prediction signals
        .predict_taken_in(id1_predict_taken),
        .predict_target_in(id1_predict_target),
        .btb_hit_in(id1_btb_hit),
        .is_branch_in(id1_is_branch),
        .is_jump_in(id1_is_jump),    // 新增：跳转指令标志
        // Data
        .pc_in(id1_pc),
        .pc_next_in(id1_pc_next),
        .rs1_val_in(id1_rs1_val_raw),
        .rs2_val_in(id1_rs2_val_raw),
        .imm_in(id1_imm),
        .rs1_addr_in(id1_rs1_addr),
        .rs2_addr_in(id1_rs2_addr),
        .rd_addr_in(id1_rd_addr),
        .instr_in(id1_instr),
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

    assign ex_data1_ready = ex_operand_hold_valid_q ? ex_operand_hold_data1_q : ex_data1_forwarded;
    assign ex_data2_ready = ex_operand_hold_valid_q ? ex_operand_hold_data2_q : ex_data2_forwarded;

    // EX0: forwarding and operand select.
    assign ex0_alu_data1 = ex_pce ? ex_pc : ex_data1_ready;
    assign ex0_alu_data2 = ex_imme ? ex_imm : ex_data2_ready;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ex_operand_hold_valid_q <= 1'b0;
            ex_operand_hold_data1_q <= 32'h0;
            ex_operand_hold_data2_q <= 32'h0;
        end else if (redirect_flush) begin
            ex_operand_hold_valid_q <= 1'b0;
        end else if (ex_mdu_stall) begin
            ex_operand_hold_valid_q <= 1'b1;
            if (!ex_operand_hold_valid_q || (forward_a != 2'b00)) begin
                ex_operand_hold_data1_q <= ex_data1_forwarded;
            end
            if (!ex_operand_hold_valid_q || (forward_b != 2'b00)) begin
                ex_operand_hold_data2_q <= ex_data2_forwarded;
            end
        end else begin
            ex_operand_hold_valid_q <= 1'b0;
        end
    end

    // EX0/EX1 cuts the forwarding window; these hold registers preserve operands
    // for the ID/EX instruction waiting behind a multi-cycle MDU operation.

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ex1_pc <= 32'h0;
            ex1_pc_next <= 32'h0;
            ex1_imm <= 32'h0;
            ex1_branch_data1 <= 32'h0;
            ex1_alu_data1 <= 32'h0;
            ex1_alu_data2 <= 32'h0;
            ex1_store_data <= 32'h0;
            ex1_rd_addr <= 5'h0;
            ex1_aluop <= 8'h0;
            ex1_alu_add <= 1'b0;
            ex1_alu_sub <= 1'b0;
            ex1_alu_sll <= 1'b0;
            ex1_alu_slt <= 1'b0;
            ex1_alu_sltu <= 1'b0;
            ex1_alu_xor <= 1'b0;
            ex1_alu_srl <= 1'b0;
            ex1_alu_sra <= 1'b0;
            ex1_alu_or <= 1'b0;
            ex1_alu_and <= 1'b0;
            ex1_predict_target <= 32'h0;
        end else if (!ex_mdu_stall) begin
            ex1_pc <= ex_pc;
            ex1_pc_next <= ex_pc_next;
            ex1_imm <= ex_imm;
            ex1_branch_data1 <= ex_data1_ready;
            ex1_alu_data1 <= ex0_alu_data1;
            ex1_alu_data2 <= ex0_alu_data2;
            ex1_store_data <= ex_data2_ready;
            ex1_rd_addr <= ex_rd_addr;
            ex1_aluop <= ex_aluop;
            ex1_alu_add <= (ex_aluop == 8'h01);
            ex1_alu_sub <= (ex_aluop == 8'h02);
            ex1_alu_sll <= (ex_aluop == 8'h03);
            ex1_alu_slt <= (ex_aluop == 8'h04);
            ex1_alu_sltu <= (ex_aluop == 8'h05);
            ex1_alu_xor <= (ex_aluop == 8'h06);
            ex1_alu_srl <= (ex_aluop == 8'h07);
            ex1_alu_sra <= (ex_aluop == 8'h08);
            ex1_alu_or <= (ex_aluop == 8'h09);
            ex1_alu_and <= (ex_aluop == 8'h0a);
            ex1_predict_target <= ex_predict_target;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ex1_we <= 1'b0;
            ex1_pce <= 1'b0;
            ex1_jmpe <= 1'b0;
            ex1_be <= 1'b0;
            ex1_bop <= 3'h0;
            ex1_dmop <= 3'h0;
            ex1_mwe <= 1'b0;
            ex1_mem_read <= 1'b0;
            ex1_wb_sel <= 2'h0;
            ex1_predict_taken <= 1'b0;
            ex1_btb_hit <= 1'b0;
            ex1_is_branch <= 1'b0;
            ex1_is_jump <= 1'b0;
        end else if (redirect_flush) begin
            ex1_we <= 1'b0;
            ex1_pce <= 1'b0;
            ex1_jmpe <= 1'b0;
            ex1_be <= 1'b0;
            ex1_bop <= 3'h0;
            ex1_dmop <= 3'h0;
            ex1_mwe <= 1'b0;
            ex1_mem_read <= 1'b0;
            ex1_wb_sel <= 2'h0;
            ex1_predict_taken <= 1'b0;
            ex1_btb_hit <= 1'b0;
            ex1_is_branch <= 1'b0;
            ex1_is_jump <= 1'b0;
        end else if (!ex_mdu_stall) begin
            ex1_we <= ex_we;
            ex1_pce <= ex_pce;
            ex1_jmpe <= ex_jmpe;
            ex1_be <= ex_be;
            ex1_bop <= ex_bop;
            ex1_dmop <= ex_dmop;
            ex1_mwe <= ex_mwe;
            ex1_mem_read <= ex_mem_read;
            ex1_wb_sel <= ex_wb_sel;
            ex1_predict_taken <= ex_predict_taken;
            ex1_btb_hit <= ex_btb_hit;
            ex1_is_branch <= ex_is_branch;
            ex1_is_jump <= ex_is_jump;
        end
    end

    // EX1: ALU, branch compare, MDU, and redirect metadata.
    assign ex_alu_data1 = ex1_alu_data1;
    assign ex_alu_data2 = ex1_alu_data2;

    // ALU
    alu_fast u_alu (
        .data1(ex_alu_data1),
        .data2(ex_alu_data2),
        .op_add(ex1_alu_add),
        .op_sub(ex1_alu_sub),
        .op_sll(ex1_alu_sll),
        .op_slt(ex1_alu_slt),
        .op_sltu(ex1_alu_sltu),
        .op_xor(ex1_alu_xor),
        .op_srl(ex1_alu_srl),
        .op_sra(ex1_alu_sra),
        .op_or(ex1_alu_or),
        .op_and(ex1_alu_and),
        .res(ex_alu_result)
    );

    // MDU (Multiply/Divide Unit)
    assign ex_is_m_type = ex1_we && (ex1_aluop >= 8'h0b) && (ex1_aluop <= 8'h12);
    assign ex_mdu_stall_raw = ex_is_m_type && !ex_mdu_done;
    // ID/EX only needs to preserve the instruction waiting behind an active
    // MDU op; redirect cleanup is handled by redirect_flush on the next cycle.
    assign id_ex_hold = ex_mdu_stall_raw;
    assign ex_mdu_start = ex_mdu_stall_raw && !redirect_block_ex && !ex_mdu_busy;
    assign ex_mdu_stall = ex_mdu_stall_raw && !redirect_block_ex;

    mul_div u_mul_div (
        .clk(clk),
        .reset(reset),
        .start(ex_mdu_start),
        .data1(ex_alu_data1),
        .data2(ex_alu_data2),
        .op(ex1_aluop),
        .res(ex_mdu_out),
        .busy(ex_mdu_busy),
        .done(ex_mdu_done)
    );

    // ALU/MDU 结果选择
    assign ex_alu_out = ex_is_m_type ? ex_mdu_out : ex_alu_result;

    // Branch Module
    branch u_branch (
        .enable(ex1_be),
        .op(ex1_bop),
        .v1(ex1_branch_data1),
        .v2(ex1_store_data),
        .out(ex_branch_taken)
    );

    // 调试观测用实际控制流目标；真实redirect target在EX2使用寄存后的base+imm计算。
    assign ex_branch_target = ex_debug_target;

    // ========== EX/MEM Register ==========

    ex_mem_reg u_ex_mem (
        .clk(clk),
        .reset(reset),
        .flush(ex_mdu_stall || redirect_eval_request || redirect_flush),
        .we_in(ex1_we),
        .dmop_in(ex1_dmop),
        .mwe_in(ex1_mwe),
        .mem_read_in(ex1_mem_read),
        .wb_sel_in(ex1_wb_sel),
        .alu_out_in(ex_alu_out),
        .rs2_val_in(ex1_store_data),
        .imm_in(ex1_imm),
        .rd_addr_in(ex1_rd_addr),
        .pc_next_in(ex1_pc_next),
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
        .id_rs1_addr(id1_rs1_addr),
        .id_rs2_addr(id1_rs2_addr),
        .id_re1(id1_re1),
        .id_re2(id1_re2),
        .id_ex_rd(ex_rd_addr),
        .id_ex_we(ex_we),
        .ex1_rd(ex1_rd_addr),
        .ex1_mem_read(ex1_mem_read),
        .stall_pc(stall_pc),
        .stall_if_id(stall_if_id),
        .stall_id_ex(flush_id_ex)
    );

    // ========== Pipeline Flush Control ==========

    // Flush流水线条件：
    // 1. 分支方向预测错误
    // 2. 跳转目标预测错误
    // 3. 跳转指令首次执行（BTB未命中，需要建立缓存）
    assign if_id_flush = redirect_flush || if_prediction_flush;
    assign id_ex_flush = redirect_flush;

endmodule

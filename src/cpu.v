/*
顶层模块连接之前定义的所有模块
*/
module cpu_mine (
    input clk,
    input reset
);

    // ==================== Wire Declarations ====================

    // PC
    wire [31:0] CURR_PC;
    wire [31:0] NEXT_PC;

    // Instruction
    wire [31:0] INSTR;

    // Decoder outputs
    wire [4:0]  RS1_ADDR;
    wire [4:0]  RS2_ADDR;
    wire [31:0] IMM_NUMBER;
    wire [4:0]  W_ADDRESS;
    wire [7:0]  OPCODE;
    wire        RS1_ENABLE;
    wire        RS2_ENABLE;
    wire        W_ENABLE;
    wire        PC_ENABLE;
    wire        IMM_ENABLE;
    wire        JUMP_ENABLE;
    wire        BRANCH_MODULE_EN;
    wire [2:0]  BRANCH_OP;
    wire [2:0]  DM_OP;
    wire        DM_WRITE_ENABLE;
    wire        MEM_DATA_OUT_ENABLE;

    // Regfile outputs
    wire [31:0] RS1_VALUE;
    wire [31:0] RS2_VALUE;

    // MUX outputs for ALU
    wire [31:0] DATA1;
    wire [31:0] DATA2;

    // ALU output
    wire [31:0] ALU_OUTPUT;

    // Branch output
    wire        BRANCH_EN;

    // Data memory
    wire [31:0] MEM_DATA_ADDR;
    wire [31:0] MEM_DATA_IN;
    wire [31:0] MEM_DATA_OUT;

    // Writeback data
    wire [31:0] WB_DATA;

    // ==================== Module Instantiations ====================

    // PC Module
    pc u_pc (
        .clk(clk),
        .reset(reset),
        .jmp(ALU_OUTPUT),
        .jmp_en(JUMP_ENABLE),
        .branch_en(BRANCH_EN),
        .curr_pc(CURR_PC),
        .next_pc(NEXT_PC)
    );

    // Instruction Memory
    instr_mem u_imem (
        .address(CURR_PC),
        .instr(INSTR)
    );

    // Decoder
    decoder u_decoder (
        .instr(INSTR),
        // Register
        .rs1(RS1_ADDR),
        .rs2(RS2_ADDR),
        .wd(W_ADDRESS),
        .re1(RS1_ENABLE),
        .re2(RS2_ENABLE),
        .we(W_ENABLE),
        // ALU MUX
        .imm(IMM_NUMBER),
        .imme(IMM_ENABLE),
        .pce(PC_ENABLE),
        .aluop(OPCODE),
        // Program Counter
        .jmpe(JUMP_ENABLE),
        // Branch
        .be(BRANCH_MODULE_EN),
        .bop(BRANCH_OP),
        // Memory
        .mwe(DM_WRITE_ENABLE),
        .dmop(DM_OP),
        .doe(MEM_DATA_OUT_ENABLE)
    );

    // Register File
    regfile u_regfile (
        .clk(clk),
        .reset(reset),
        .rs1(RS1_ADDR),
        .rs2(RS2_ADDR),
        .re1(RS1_ENABLE),
        .re2(RS2_ENABLE),
        .wd(W_ADDRESS),
        .we(W_ENABLE),
        .wdata(WB_DATA),
        .rs1_value(RS1_VALUE),
        .rs2_value(RS2_VALUE)
    );

    // MUX2to1 for ALU data1 (PC or rs1)
    mul2to1 u_mux_data1 (
        .v0(RS1_VALUE),
        .v1(CURR_PC),
        .s(PC_ENABLE),
        .value(DATA1)
    );

    // MUX2to1 for ALU data2 (rs2 or imm)
    mul2to1 u_mux_data2 (
        .v0(RS2_VALUE),
        .v1(IMM_NUMBER),
        .s(IMM_ENABLE),
        .value(DATA2)
    );

    // ALU
    alu u_alu (
        .data1(DATA1),
        .data2(DATA2),
        .op(OPCODE),
        .res(ALU_OUTPUT)
    );

    // Branch Module
    branch u_branch (
        .enable(BRANCH_MODULE_EN),
        .op(BRANCH_OP),
        .v1(RS1_VALUE),
        .v2(RS2_VALUE),
        .out(BRANCH_EN)
    );

    // MUX4to1 for Writeback
    mul4to1 u_mux_wb (
        .v0(ALU_OUTPUT),
        .v1(NEXT_PC),
        .v2(MEM_DATA_OUT),
        .v3(32'h0),
        .s({MEM_DATA_OUT_ENABLE, JUMP_ENABLE}),
        .value(WB_DATA)
    );

    // Data Memory address and data connections
    assign MEM_DATA_ADDR = ALU_OUTPUT;
    assign MEM_DATA_IN   = RS2_VALUE;

    // Data Memory
    datamem u_datamem (
        .clk(clk),
        .reset(reset),
        .address(MEM_DATA_ADDR),
        .we(DM_WRITE_ENABLE),
        .d_in(MEM_DATA_IN),
        .mode(DM_OP),
        .d_out(MEM_DATA_OUT)
    );

endmodule
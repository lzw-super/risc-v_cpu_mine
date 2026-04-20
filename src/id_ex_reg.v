// ==============================
// ID/EX 流水线寄存器
// ==============================

module id_ex_reg (
    input           clk,
    input           reset,
    input           stall,      // 暂停信号（Load-Use冒险）
    input           flush,      // 清空信号

    // 来自ID阶段的控制信号
    input           re1_in,     // rs1读使能
    input           re2_in,     // rs2读使能
    input           we_in,      // regfile写使能
    input           imme_in,    // 立即数选择
    input           pce_in,     // PC选择（ALU输入A）
    input           jmpe_in,    // 跳转使能
    input           be_in,      // 分支使能
    input  [7:0]    alu_op_in,  // ALU操作
    input  [2:0]    dmop_in,    // 数据内存操作类型
    input           mwe_in,     // 内存写使能
    input           mem_read_in, // 内存读使能

    // 来自ID阶段的数据
    input  [31:0]   pc_in,
    input  [31:0]   rs1_val_in,
    input  [31:0]   rs2_val_in,
    input  [31:0]   imm_in,
    input  [4:0]    rs1_addr_in,
    input  [4:0]    rs2_addr_in,
    input  [4:0]    rd_addr_in,
    input  [31:0]   instr_in,

    // 输出到EX阶段
    output reg          re1_out,
    output reg          re2_out,
    output reg          we_out,
    output reg          imme_out,
    output reg          pce_out,
    output reg          jmpe_out,
    output reg          be_out,
    output reg [7:0]    alu_op_out,
    output reg [2:0]    dmop_out,
    output reg          mwe_out,
    output reg          mem_read_out,

    output reg [31:0]   pc_out,
    output reg [31:0]   rs1_val_out,
    output reg [31:0]   rs2_val_out,
    output reg [31:0]   imm_out,
    output reg [4:0]    rs1_addr_out,
    output reg [4:0]    rs2_addr_out,
    output reg [4:0]    rd_addr_out,
    output reg [31:0]   instr_out
);

    always @(posedge clk) begin
        if (reset) begin
            // 清空所有信号
            re1_out       <= 1'b0;
            re2_out       <= 1'b0;
            we_out        <= 1'b0;
            imme_out      <= 1'b0;
            pce_out       <= 1'b0;
            jmpe_out      <= 1'b0;
            be_out        <= 1'b0;
            alu_op_out    <= 3'b0;
            dmop_out      <= 3'b0;
            mwe_out       <= 1'b0;
            mem_read_out  <= 1'b0;
            pc_out        <= 32'h0;
            rs1_val_out   <= 32'h0;
            rs2_val_out   <= 32'h0;
            imm_out       <= 32'h0;
            rs1_addr_out  <= 5'b0;
            rs2_addr_out  <= 5'b0;
            rd_addr_out   <= 5'b0;
            instr_out     <= 32'h00000013;  // NOP
        end
        else if (flush || stall) begin
            // flush或stall时插入NOP（清空控制信号）
            re1_out       <= 1'b0;
            re2_out       <= 1'b0;
            we_out        <= 1'b0;
            imme_out      <= 1'b0;
            pce_out       <= 1'b0;
            jmpe_out      <= 1'b0;
            be_out        <= 1'b0;
            alu_op_out    <= 3'b0;
            dmop_out      <= 3'b0;
            mwe_out       <= 1'b0;
            mem_read_out  <= 1'b0;
            instr_out     <= 32'h00000013;  // NOP
            // 数据保持不变或清零
            if (flush) begin
                pc_out        <= 32'h0;
                rs1_val_out   <= 32'h0;
                rs2_val_out   <= 32'h0;
                imm_out       <= 32'h0;
                rs1_addr_out  <= 5'b0;
                rs2_addr_out  <= 5'b0;
                rd_addr_out   <= 5'b0;
            end
        end
        else begin
            // 正常更新
            re1_out       <= re1_in;
            re2_out       <= re2_in;
            we_out        <= we_in;
            imme_out      <= imme_in;
            pce_out       <= pce_in;
            jmpe_out      <= jmpe_in;
            be_out        <= be_in;
            alu_op_out    <= alu_op_in;
            dmop_out      <= dmop_in;
            mwe_out       <= mwe_in;
            mem_read_out  <= mem_read_in;
            pc_out        <= pc_in;
            rs1_val_out   <= rs1_val_in;
            rs2_val_out   <= rs2_val_in;
            imm_out       <= imm_in;
            rs1_addr_out  <= rs1_addr_in;
            rs2_addr_out  <= rs2_addr_in;
            rd_addr_out   <= rd_addr_in;
            instr_out     <= instr_in;
        end
    end

endmodule
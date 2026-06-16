/*
 * One-hot controlled ALU for the high-frequency EX1 stage.
 * The opcode is decoded and registered before EX1 so this module only sees
 * simple one-hot selects on the timing-critical ALU result path.
 */
module alu_fast(
    input  [31:0] data1,
    input  [31:0] data2,
    input         op_add,
    input         op_sub,
    input         op_sll,
    input         op_slt,
    input         op_sltu,
    input         op_xor,
    input         op_srl,
    input         op_sra,
    input         op_or,
    input         op_and,
    output [31:0] res
    );

    wire [31:0] add_res  = $signed(data1) + $signed(data2);
    wire [31:0] sub_res  = $signed(data1) - $signed(data2);
    wire [31:0] sll_res  = data1 << data2[4:0];
    wire [31:0] slt_res  = ($signed(data1) < $signed(data2)) ? 32'h1 : 32'h0;
    wire [31:0] sltu_res = (data1 < data2) ? 32'h1 : 32'h0;
    wire [31:0] xor_res  = data1 ^ data2;
    wire [31:0] srl_res  = data1 >> data2[4:0];
    wire [31:0] sra_res  = $signed(data1) >>> data2[4:0];
    wire [31:0] or_res   = data1 | data2;
    wire [31:0] and_res  = data1 & data2;

    assign res =
        ({32{op_add}}  & add_res)  |
        ({32{op_sub}}  & sub_res)  |
        ({32{op_sll}}  & sll_res)  |
        ({32{op_slt}}  & slt_res)  |
        ({32{op_sltu}} & sltu_res) |
        ({32{op_xor}}  & xor_res)  |
        ({32{op_srl}}  & srl_res)  |
        ({32{op_sra}}  & sra_res)  |
        ({32{op_or}}   & or_res)   |
        ({32{op_and}}  & and_res);

endmodule

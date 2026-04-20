/*
根据输入的两个值，来计算B型指令是否跳转*/
module branch (
    input enable,
    input [2:0] op,
    input [31:0] v1,
    input [31:0] v2,
    output reg out
);
    always @(*) begin
        if (enable) begin
            case (op)
                3'b000: // beq
                    out = (v1 == v2) ? 1 : 0;
                3'b001: // bne
                    out = (v1 == v2) ? 0 : 1;
                3'b100: // blt
                    out = ($signed(v1) < $signed(v2)) ? 1 : 0;
                3'b101: // bge
                    out = ($signed(v1) < $signed(v2)) ? 0 : 1;
                3'b110: // bltu
                    out = (v1 < v2) ? 1 : 0;
                3'b111: // bgeu
                    out = (v1 < v2) ? 0 : 1;
                default:
                    out = 0;
            endcase
        end
        else out = 0;
    end
endmodule
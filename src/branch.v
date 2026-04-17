/*
根据输入的两个值，来计算B型指令是否跳转*/ 
module branch (
    input enable , 
    input op ,
    input v1 , 
    input v2 , 
    output reg out 
    );
    always @(*) begin
        if (enable) begin
            case (op)
                3'b000: // beq
                    out = (data1 == data2) ? 1 : 0;
                3'b001: // bne
                    out = (data1 == data2) ? 0 : 1;
                3'b100: // blt
                    out = ($signed(data1) < $signed(data2)) ? 1 : 0;
                3'b101: // bge
                    out = ($signed(data1) < $signed(data2)) ? 0 : 1;
                3'b110: // bltu
                    out = (data1 < data2) ? 1 : 0;
                3'b111: // bgeu
                    out = (data1 < data2) ? 0 : 1;
                default:
                    out = 0;
            endcase
        end
        else out = 0;
    end
endmodule
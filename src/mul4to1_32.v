/*四选一*/
module mul4to1 (
    input [31:0]v0,
    input [31:0]v1,
    input [31:0]v2,
    input [31:0]v3,
    input [1:0]s,

    output reg [31:0]value
    );
    always @(*) begin
        case (s)
            00 : value = v0 ; 
            01 : value = v1 ;
            10 : value = v2 ;
            11 : value = v3 ; 
            default : value = 32'h0 ;
        endcase
    end
endmodule
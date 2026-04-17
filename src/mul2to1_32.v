/*
二选一选择器*/ 
module mul2to1 (
    input [31:0]v0,
    input [31:0]v1,
    input s,

    output [31:0]value
    );
    assign value = (s==0) ? v0 : v1 ;
endmodule
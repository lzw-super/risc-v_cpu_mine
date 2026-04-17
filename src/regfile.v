/*
写入使用时序，读出使用逻辑*/
module regfile (
    input clk , 
    input reset , 

    // 读出信号
    input [4:0]rs1, 
    input [4:0]rs2 , 
    input re1, 
    input re2 ,

    // 写入信号
    input wd , 
    input we , 
    input [31:0]wdata,

    output reg [31:0]rs1_value , 
    output reg [31:0]rs2_value,
    )
    reg [31:0] regfile [31:0];

    always @(posedge clk ) begin
        if (we && wd != 0 ) begin
            regfile[wd] <= wdata ;
        end
    end 

    always @(*) begin
        if (!re1) begin
            rs1_value = 0 ;
        end
        else if (re1 && rs1!=0) begin
            rs1_value = regfile[rs1] ;
        end 
        else 
            rs1_value = 0 ;
    end

    always @(*) begin
        if (!re2) begin
            rs2_value = 0 ;
        end
        else if (re2 && rs2!=0) begin
            rs2_value = regfile[rs2] ;
        end 
        else 
            rs2_value = 0 ;
    end
endmodule
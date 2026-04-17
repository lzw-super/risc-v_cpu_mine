/* 
输入跳转使能以及跳转地址   输出pc地址（更新）  延迟一个周期*/
module pc ( 
    // 基础输入
    input clk , 
    input reset ,  
    // 跳转输入
    input [31:0] jmp ,  
    input jmp_en , 
    input branch_en , 

    output reg [31:0] curr_pc , 
    output reg [31:0] next_pc 
    );
    always @(posedge clk or negedge reset) begin 
        if (reset) begin 
            curr_pc <= 0 ; 
            next_pc <= 0 ;
        end 
        else if (jmp_en | branch_en) begin
            curr_pc <= jmp ; 
            next_pc <= jmp + 32'h4 ;
        end
        else begin
            curr_pc <= next_pc ; 
            next_pc <= next_pc + 32'h4 ; 
        end
    end
endmodule
/*数据存储器的执行  时序写入(需要覆盖原始内容)  逻辑读出   读写与控制分离 
对于写入，需要先读出mem原始内容再替换为实际输入，然后在根据mode来写入  
对于读出，只需要根据地址读出并按照mode更改格式  
对于硬件最好是多分层 分模块化设计  这样思路清晰一些*/ 
module datamem (
    input clk ,
    input reset , 

    input [31:0]address ,
    input we , 
    input [31:0]d_in , 
    input [2:0]mode ,

    output reg [31:0] d_out 
    ); 

    wire [31:0]d_out_wire ;  
    reg [31:0]data_in_buff;
    // 读写 模块


    mem mem_mine(.clk(clk), .addr(address), .we(we), .d_in(data_in_buff), .d_out(d_out_wire));

    // 控制逻辑
    always @(*) begin
        data_in_buff = d_out_wire;
        d_out = 32'b0;

        if (reset) begin
            data_in_buff  = 32'b0;
            d_out = 32'b0;
        end
        else begin
            if (we) begin
                data_in_buff = d_out_wire;
                case (mode)
                    'h0: //sb
                        data_in_buff[7:0]  = d_in[7:0]; 
                    'h1: //sh
                        data_in_buff[15:0] = d_in[15:0]; 
                    'h2: //s2
                        data_in_buff  = {d_in}; 
                    default: 
                        data_in_buff  = 32'b0;
                endcase
            end 
            else begin
                case (mode)
                    'h0: //lb
                        d_out = {{24{d_out_wire[7]}}, d_out_wire[7:0]};
                    'h1: //lh 
                        d_out = {{16{d_out_wire[15]}}, d_out_wire[15:0]};
                    'h2: //lw 
                        d_out = {d_out_wire};
                    'h4: //lbu 
                        d_out = {{24{1'b0}},         d_out_wire[7:0]}; 
                    'h5: //lhu 
                        d_out = {{16{1'b0}},         d_out_wire[15:0]}; 
                    default: 
                        d_out = 32'b0;
                endcase
            end
        end
    end 
    // integer i = 0;
    // initial begin
    //     {mem[i],mem[i+1],mem[i+2],mem[i+3]} = 'h12345678;
    //     i = 4;
    //     {mem[i],mem[i+1],mem[i+2],mem[i+3]} = 'h87654321;
    // end
endmodule

module mem (
    input clk ,

    input [31:0]addr ,
    input we , 
    input [31:0]d_in , 

    output reg [31:0] d_out 
    ); 
        reg [7:0] mem [1023:0] ;
        integer i;
        initial begin
            for (i = 0; i < 1024; i = i + 1) begin
                mem[i] = 8'h00;
            end
        end
        always @(posedge clk ) begin
            if (we) begin
                {mem[addr],mem[addr+1],mem[addr+2],mem[addr+3]} <= d_in ;
            end
        end
        always @(*) begin
            d_out = {mem[addr],mem[addr+1],mem[addr+2],mem[addr+3]} ;
        end
endmodule

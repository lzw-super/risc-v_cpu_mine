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
    reg [31:0]write_data;
    reg [3:0]wmask;
    reg [7:0]load_byte;
    reg [15:0]load_half;
    // 读写 模块


    mem mem_mine(.clk(clk), .addr(address), .we(we), .wmask(wmask), .d_in(write_data), .d_out(d_out_wire));

    // 控制逻辑
    always @(*) begin
        write_data = 32'b0;
        wmask = 4'b0000;
        load_byte = 8'b0;
        load_half = 16'b0;
        d_out = 32'b0;

        case (address[1:0])
            2'b00: load_byte = d_out_wire[7:0];
            2'b01: load_byte = d_out_wire[15:8];
            2'b10: load_byte = d_out_wire[23:16];
            2'b11: load_byte = d_out_wire[31:24];
        endcase

        case (address[1])
            1'b0: load_half = d_out_wire[15:0];
            1'b1: load_half = d_out_wire[31:16];
        endcase

        if (reset) begin
            write_data = 32'b0;
            wmask = 4'b0000;
            d_out = 32'b0;
        end
        else begin
            if (we) begin
                case (mode)
                    'h0: begin //sb
                        case (address[1:0])
                            2'b00: begin
                                write_data = {24'b0, d_in[7:0]};
                                wmask = 4'b0001;
                            end
                            2'b01: begin
                                write_data = {16'b0, d_in[7:0], 8'b0};
                                wmask = 4'b0010;
                            end
                            2'b10: begin
                                write_data = {8'b0, d_in[7:0], 16'b0};
                                wmask = 4'b0100;
                            end
                            2'b11: begin
                                write_data = {d_in[7:0], 24'b0};
                                wmask = 4'b1000;
                            end
                        endcase
                    end
                    'h1: begin //sh
                        if (address[1]) begin
                            write_data = {d_in[15:0], 16'b0};
                            wmask = 4'b1100;
                        end
                        else begin
                            write_data = {16'b0, d_in[15:0]};
                            wmask = 4'b0011;
                        end
                    end
                    'h2: begin //sw
                        write_data = d_in;
                        wmask = 4'b1111;
                    end
                    default: begin
                        write_data = 32'b0;
                        wmask = 4'b0000;
                    end
                endcase
            end
            else begin
                case (mode)
                    'h0: //lb
                        d_out = {{24{load_byte[7]}}, load_byte};
                    'h1: //lh
                        d_out = {{16{load_half[15]}}, load_half};
                    'h2: //lw
                        d_out = d_out_wire;
                    'h4: //lbu
                        d_out = {{24{1'b0}}, load_byte};
                    'h5: //lhu
                        d_out = {{16{1'b0}}, load_half};
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
    input [3:0]wmask ,
    input [31:0]d_in ,

    output reg [31:0] d_out
    );
        reg [31:0] mem_word [0:255] ;
        wire [7:0] word_addr;
        integer i;

        assign word_addr = addr[9:2];

        initial begin
            for (i = 0; i < 256; i = i + 1) begin
                mem_word[i] = 32'h00000000;
            end
        end
        always @(posedge clk ) begin
            if (we) begin
                if (wmask[0]) begin
                    mem_word[word_addr][7:0] <= d_in[7:0];
                end
                if (wmask[1]) begin
                    mem_word[word_addr][15:8] <= d_in[15:8];
                end
                if (wmask[2]) begin
                    mem_word[word_addr][23:16] <= d_in[23:16];
                end
                if (wmask[3]) begin
                    mem_word[word_addr][31:24] <= d_in[31:24];
                end
            end
        end
        always @(*) begin
            d_out = mem_word[word_addr];
        end
endmodule

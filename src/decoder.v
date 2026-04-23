/*
解码指令  分析出所需的信号*/
module decoder (
    input[31:0] instr ,

    output reg  [4:0]       rs1,    // rs1 address
    output reg  [4:0]       rs2,    // rs2 address
    output reg  [31:0]      imm,    // reconstructed imm value
    output reg  [4:0]       wd,     // rd address
    output reg  [7:0]       aluop,  // alu opcode

    output reg              re1,    // rs1 enable 是否使用rs1
    output reg              re2,    // rs2 enable 是否使用rs2
    output reg              we,     // rd enable 是否需要写回寄存器组
    output reg              pce,    // mux_data1  二选一  pc和rs1
    output reg              imme,   // mux_data2 二选一  imm和rs2

    output reg              jmpe,   // pc jump
    output reg              be,     // branch enable
    output reg  [2:0]       bop,    // opcode funct3 as branch op
    output reg  [2:0]       dmop,   // memory operation
    output reg              doe,    // memory data out enable
    output reg              mwe,    // memory disable
    output reg              is_load,// load instruction flag
    output reg  [1:0]       wb_sel, // WB data select (新增)
    output reg              is_jump // jump instruction flag (新增: JAL/JALR)
    );
    // WB Select encoding:
    // 00: mem_data (Load指令)
    // 01: alu_out (R型、I型算术、AUIPC等)
    // 10: imm (LUI指令)
    // 11: pc+4 (JAL、JALR指令)
    // ALU OP
    // ----------------
    // 0x00: nop
    // 0x01: add
    // 0x02: sub
    // 0x03: sll
    // 0x04: slt
    // 0x05: sltu
    // 0x06: xor
    // 0x07: srl
    // 0x08: sra
    // 0x09: or
    // 0x0a: and

    localparam  _enable     = 1'b1;
    localparam  _disable    = 1'b0;
    
        
    always@(*) begin
        case(instr[6:0])                    // Type
            7'b0110011: begin               // R-Type  两输入并写入 加减、逻辑操作以及移位等操作 寄存器以及立即数等操作

                rs1         = instr[19:15];  // rs1 implied
                rs2         = instr[24:20];  // rs2 implied
                wd          = instr[11:7];   // rd implied
                imm         = 32'b0;        // imm not implied
                re1         = _enable;      // rs1 required
                re2         = _enable;      // rs2 required
                we          = _enable;      // rd required
                pce         = _disable;     // use rs1 on ALU-data1
                imme        = _disable;     // use rs2 on ALU-data2
                jmpe        = _disable;     // use pc+4 on PC
                doe         = _disable;     // use Data Out to/Register
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b01;        // select alu_out
                is_jump     = _disable;     // not a jump instruction

                case(instr[14:12])           // Func3
                    3'b000:                 // add / sub
                        case(instr[31:25])   // Func7
                            7'b0000000:     // add
                                aluop = 8'h1;
                            7'b0100000:     // sub
                                aluop = 8'h2;
                            default: 
                                aluop = 8'h0;
                        endcase
                    3'b001:                 // sll
                        aluop = 8'h3;
                    3'b010:                 // slt
                        aluop = 8'h4;   
                    3'b011:                 // sltu
                        aluop = 8'h5;
                    3'b100:                 // xor
                        aluop = 8'h6;
                    3'b101:                 // srl / sra
                        case(instr[31:25])  // Func7
                            7'b0000000:     // srl
                                aluop = 8'h7;
                            7'b0100000:     // sra
                                aluop = 8'h8;
                            default: 
                                aluop = 8'h0;
                        endcase
                    3'b110:                 // or
                        aluop = 8'h9;
                    3'b111:                 // and
                        aluop = 8'ha;
                    default:  
                        aluop = 8'h0;
                endcase
            end
            /*
                * ========================================================
                */
            7'b0010011: begin               // I-Type  与立即数的基础运算
                rs1         = instr[19:15];  // rs1 implied
                rs2         = 5'b0;         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = {{20{instr[31]}}, instr[31:20]};  // imm implied
                re1         = _enable;      // rs1 required
                re2         = _disable;     // rs2 not used
                we          = _enable;      // rd required
                pce         = _disable;     // use rs1 on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _disable;     // use pc+4 on PC
                doe         = _disable;     // use Data Out to/Register
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b01;        // select alu_out
                is_jump     = _disable;     // not a jump instruction

                case(instr[14:12])          // Func3
                    3'b000:                 // addi
                        aluop = 8'h1;
                    3'b001:                 // slli
                        aluop = 8'h3;
                    3'b010:                 // slti
                        aluop = 8'h4;   
                    3'b011:                 // sltiu
                        aluop = 8'h5;
                    3'b100:                 // xori
                        aluop = 8'h6;
                    3'b101:                 // srli / srai
                        case(instr[31:25])  // Func7
                            7'b0000000:     // srli
                                aluop = 8'h7;
                            7'b0100000:     // srai
                                aluop = 8'h8;
                            default: 
                                aluop = 8'h0;
                        endcase
                    3'b110:                 // ori
                        aluop = 8'h9;
                    3'b111:                 // andi
                        aluop = 8'ha;
                    default:  
                        aluop = 8'h0;
                endcase
            end
            /*
                * ========================================================
                */
            7'b1101111:   begin             // J-Type : JAL  pc与立即数的运算结果为跳转的目标地址，且写回到regfile
                rs1         = 5'b0;         // rs1 not implied
                rs2         = 5'b0;         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = { {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 };  // imm implied
                re1         = _disable;     // rs1 not used
                re2         = _disable;     // rs2 not used
                we          = _enable;      // rd required
                pce         = _enable;      // use pc on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _enable;      // use jmp on PC
                doe         = _disable;     // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b11;        // select pc+4 (return address)
                is_jump     = _enable;      // JAL is a jump instruction
            end

            7'b1100111: begin               // I-Type : JALR  rs1与立即数的运算得到跳转地址
                rs1         = instr[19:15];  // rs1 implied
                rs2         = 5'b0;         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = { {20{instr[31]}}, instr[31:20] };  // imm implied
                re1         = _enable;      // rs1 used
                re2         = _disable;     // rs2 not used
                we          = _enable;      // rd required
                pce         = _disable;     // use pc on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _enable;      // use jmp on PC
                doe         = _disable;     // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b11;        // select pc+4 (return address)
                is_jump     = _enable;      // JALR is a jump instruction
            end
            7'b0000011: begin               // I-Type : LB/LH/LW/LBU/LHU  load指令
                rs1         = instr[19:15];  // rs1 implied
                rs2         = 5'b0;         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = { {20{instr[31]}}, instr[31:20] };  // imm implied
                re1         = _enable;      // rs1 used
                re2         = _disable;     // rs2 not used
                we          = _enable;      // rd required
                pce         = _disable;     // use pc on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _disable;      // use jmp on PC
                doe         = _enable;      // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = instr[14:12];  // memory operation
                mwe         = _disable;     // memory enable
                is_load     = _enable;      // this is a load instruction
                wb_sel      = 2'b00;        // select mem_data
                is_jump     = _disable;     // not a jump instruction
            end
            7'b0100011: begin               // S-Type :  store 指令
                rs1         = instr[19:15];  // rs1 implied
                rs2         = instr[24:20];         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = { {20{instr[31]}}, instr[31:25],instr[11:7] };  // imm implied
                re1         = _enable;      // rs1 used
                re2         = _enable;     // rs2 not used
                we          = _disable;      // rd required
                pce         = _disable;     // use pc on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _disable;      // use jmp on PC
                doe         = _enable;      // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = instr[14:12];  // memory operation
                mwe         = _enable;      // memory enable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b00;        // don't care (we=0)
                is_jump     = _disable;     // not a jump instruction
            end
            7'b0110111: begin               // U-Type : LUI 存储高位立即数到regfile
                rs1         = 5'b0;         // rs1 not implied, but forced to use X0
                rs2         = 5'b0;         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = { instr[31:12], 12'b0 };  // imm implied
                re1         = _enable;      // forced to use X0, expecting 32'b0
                re2         = _disable;     // rs2 not used
                we          = _enable;      // rd required
                pce         = _disable;     // expecting 32'b0 on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _disable;      // use pc+4 on PC
                doe         = _disable;     // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b10;        // select imm (LUI)
                is_jump     = _disable;     // not a jump instruction
            end

            7'b0010111: begin               // U-Type : AUIPC  立即数加到pc上并存入regfile
                rs1         = 5'b0;         // rs1 not implied
                rs2         = 5'b0;         // rs2 not implied
                wd          = instr[11:7];   // rd implied
                imm         = { instr[31:12], 12'b0 };  // imm implied
                re1         = _disable;     // rs1 not used
                re2         = _disable;     // rs2 not used
                we          = _enable;      // rd required
                pce         = _enable;      // use pc on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _disable;     // use pc+4 on PC
                doe         = _disable;     // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b01;        // select alu_out (pc+imm result)
                is_jump     = _disable;     // not a jump instruction
            end

            7'b1100011: begin               // B-Type   分支判断类
                rs1         = instr[19:15];  // rs1 implied
                rs2         = instr[24:20];  // rs2 implied
                wd          = 5'b0;         // rd not implied
                imm         = {{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};  // imm implied
                re1         = _enable;      // rs1 required
                re2         = _enable;      // rs2 required
                we          = _disable;     // rd not required
                pce         = _enable;      // use pc on ALU-data1
                imme        = _enable;      // use imm on ALU-data2
                jmpe        = _disable;     // use pc+4 on PC
                doe         = _disable;     // use Data Out to/Register
                aluop       = 8'h1;         // data1 + data2
                be          = _enable;      // branch enabled
                bop         = instr[14:12];  // branch enabled  使用那种分支判断
                dmop        = 'b0;          // memory operation 是否操作内存
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b00;        // don't care (we=0)
                is_jump     = _disable;     // not a jump instruction (branch)
            end

            default: begin
                rs1         = 5'b0;         // rs1 not implied
                rs2         = 5'b0;         // rs2 not implied
                wd          = 5'b0;         // rd not implied
                imm         = 32'b0;        // imm not implied
                re1         = _disable;     // rs1 not used
                re2         = _disable;     // rs2 not used
                we          = _disable;     // rd not used
                pce         = _disable;     // use rs1 on ALU-data1
                imme        = _disable;     // use rs2 on ALU-data2
                jmpe        = _disable;     // use pc+4 on PC/Register
                doe         = _disable;     // use Data Out to/Register
                aluop       = 8'h0;         // do nothing
                be          = _disable;     // branch disabled
                bop         = 3'b000;       // branch disabled
                dmop        = 'b0;          // memory operation
                mwe         = _disable;     // memory disable
                is_load     = _disable;     // not a load instruction
                wb_sel      = 2'b00;        // default
                is_jump     = _disable;     // not a jump instruction
            end
        endcase
    end
endmodule
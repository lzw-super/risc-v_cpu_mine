// ==============================
// GLS Instruction Memory (combinational)
// Loads HEX_FILE via plusarg +HEX_FILE=<path>
// ==============================
module gls_imem (
    input  [31:0] address,
    output [31:0] instr
);
    reg [7:0] imem [1023:0];
    reg [255:0] hex_path;

    initial begin
        if (!$value$plusargs("HEX_FILE=%s", hex_path)) begin
            hex_path = "all_tests.hex";
        end
        $readmemh(hex_path, imem);
    end

    assign instr = {imem[address+3],
                    imem[address+2],
                    imem[address+1],
                    imem[address]};
endmodule

#!/usr/bin/env python3
"""
RISC-V Instruction Encoder
Generates .txt and .hex files for pipeline CPU testing
"""

import argparse
import sys

# ==================== Instruction Encoding Functions ====================

def encode_i_type(imm, rs1, funct3, rd, opcode):
    """Encode I-type instruction (12-bit immediate)"""
    if imm < 0:
        imm = imm & 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_r_type(funct7, rs2, rs1, funct3, rd, opcode):
    """Encode R-type instruction"""
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s_type(imm, rs2, rs1, funct3, opcode):
    """Encode S-type store instruction"""
    if imm < 0:
        imm = imm & 0xFFF
    imm_hi = (imm >> 5) & 0x7F
    imm_lo = imm & 0x1F
    return (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_lo << 7) | opcode

def encode_branch(offset, rs2, rs1, funct3):
    """Encode B-type branch instruction (13-bit signed byte offset)"""
    opcode = 0b1100011
    if offset < 0:
        imm13 = offset & 0x1FFF
    else:
        imm13 = offset

    imm_bit12 = (imm13 >> 12) & 1
    imm_bits10_5 = (imm13 >> 5) & 0x3F
    imm_bits4_1 = (imm13 >> 1) & 0xF
    imm_bit11 = (imm13 >> 11) & 1

    return (imm_bit12 << 31) | (imm_bits10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (imm_bits4_1 << 8) | (imm_bit11 << 7) | opcode

def encode_jal(offset, rd):
    """Encode JAL instruction (21-bit signed byte offset)"""
    opcode = 0b1101111
    if offset < 0:
        imm21 = offset & 0x1FFFFF
    else:
        imm21 = offset

    imm_bit20 = (imm21 >> 20) & 1
    imm_bits10_1 = (imm21 >> 1) & 0x3FF
    imm_bit11 = (imm21 >> 11) & 1
    imm_bits19_12 = (imm21 >> 12) & 0xFF

    return (imm_bit20 << 31) | (imm_bits10_1 << 21) | (imm_bit11 << 20) | \
           (imm_bits19_12 << 12) | (rd << 7) | opcode

def encode_jalr(imm, rs1, rd):
    """Encode JALR instruction"""
    opcode = 0b1100111
    funct3 = 0b000
    if imm < 0:
        imm = imm & 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_u_type(imm, rd, opcode):
    """Encode U-type instruction (LUI, AUIPC)"""
    return (imm << 12) | (rd << 7) | opcode

def nop():
    """NOP instruction (ADDI x0, x0, 0)"""
    return encode_i_type(0, 0, 0b000, 0, 0b0010011)

def instr_to_bytes(instr):
    """Convert 32-bit instruction to little-endian bytes"""
    return [(instr >> i*8) & 0xFF for i in range(4)]

# ==================== Instruction Helpers ====================

def addi(rd, rs1, imm):
    """ADDI rd, rs1, imm"""
    return encode_i_type(imm, rs1, 0b000, rd, 0b0010011)

def add(rd, rs1, rs2):
    """ADD rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b000, rd, 0b0110011)

def sub(rd, rs1, rs2):
    """SUB rd, rs1, rs2"""
    return encode_r_type(0b0100000, rs2, rs1, 0b000, rd, 0b0110011)

def and_(rd, rs1, rs2):
    """AND rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b111, rd, 0b0110011)

def or_(rd, rs1, rs2):
    """OR rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b110, rd, 0b0110011)

def xor_(rd, rs1, rs2):
    """XOR rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b100, rd, 0b0110011)

def sll(rd, rs1, rs2):
    """SLL rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b001, rd, 0b0110011)

def srl(rd, rs1, rs2):
    """SRL rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b101, rd, 0b0110011)

def sra(rd, rs1, rs2):
    """SRA rd, rs1, rs2"""
    return encode_r_type(0b0100000, rs2, rs1, 0b101, rd, 0b0110011)

def slt(rd, rs1, rs2):
    """SLT rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b010, rd, 0b0110011)

def sltu(rd, rs1, rs2):
    """SLTU rd, rs1, rs2"""
    return encode_r_type(0b0000000, rs2, rs1, 0b011, rd, 0b0110011)

def andi(rd, rs1, imm):
    """ANDI rd, rs1, imm"""
    return encode_i_type(imm, rs1, 0b111, rd, 0b0010011)

def ori(rd, rs1, imm):
    """ORI rd, rs1, imm"""
    return encode_i_type(imm, rs1, 0b110, rd, 0b0010011)

def xori(rd, rs1, imm):
    """XORI rd, rs1, imm"""
    return encode_i_type(imm, rs1, 0b100, rd, 0b0010011)

def slli(rd, rs1, shamt):
    """SLLI rd, rs1, shamt"""
    return encode_i_type(shamt, rs1, 0b001, rd, 0b0010011)

def srli(rd, rs1, shamt):
    """SRLI rd, rs1, shamt"""
    return encode_i_type(shamt, rs1, 0b101, rd, 0b0010011)

def srai(rd, rs1, shamt):
    """SRAI rd, rs1, shamt"""
    imm = (0b0100000 << 5) | shamt
    return encode_i_type(imm, rs1, 0b101, rd, 0b0010011)

def slti(rd, rs1, imm):
    """SLTI rd, rs1, imm"""
    return encode_i_type(imm, rs1, 0b010, rd, 0b0010011)

def sltiu(rd, rs1, imm):
    """SLTIU rd, rs1, imm"""
    return encode_i_type(imm, rs1, 0b011, rd, 0b0010011)

def lw(rd, rs1, offset):
    """LW rd, offset(rs1)"""
    return encode_i_type(offset, rs1, 0b010, rd, 0b0000011)

def lb(rd, rs1, offset):
    """LB rd, offset(rs1)"""
    return encode_i_type(offset, rs1, 0b000, rd, 0b0000011)

def lh(rd, rs1, offset):
    """LH rd, offset(rs1)"""
    return encode_i_type(offset, rs1, 0b001, rd, 0b0000011)

def lbu(rd, rs1, offset):
    """LBU rd, offset(rs1)"""
    return encode_i_type(offset, rs1, 0b100, rd, 0b0000011)

def lhu(rd, rs1, offset):
    """LHU rd, offset(rs1)"""
    return encode_i_type(offset, rs1, 0b101, rd, 0b0000011)

def sw(rs2, rs1, offset):
    """SW rs2, offset(rs1)"""
    return encode_s_type(offset, rs2, rs1, 0b010, 0b0100011)

def sb(rs2, rs1, offset):
    """SB rs2, offset(rs1)"""
    return encode_s_type(offset, rs2, rs1, 0b000, 0b0100011)

def sh(rs2, rs1, offset):
    """SH rs2, offset(rs1)"""
    return encode_s_type(offset, rs2, rs1, 0b001, 0b0100011)

def beq(rs1, rs2, offset):
    """BEQ rs1, rs2, offset"""
    return encode_branch(offset, rs2, rs1, 0b000)

def bne(rs1, rs2, offset):
    """BNE rs1, rs2, offset"""
    return encode_branch(offset, rs2, rs1, 0b001)

def blt(rs1, rs2, offset):
    """BLT rs1, rs2, offset"""
    return encode_branch(offset, rs2, rs1, 0b100)

def bge(rs1, rs2, offset):
    """BGE rs1, rs2, offset"""
    return encode_branch(offset, rs2, rs1, 0b101)

def bltu(rs1, rs2, offset):
    """BLTU rs1, rs2, offset"""
    return encode_branch(offset, rs2, rs1, 0b110)

def bgeu(rs1, rs2, offset):
    """BGEU rs1, rs2, offset"""
    return encode_branch(offset, rs2, rs1, 0b111)

def jal(rd, offset):
    """JAL rd, offset"""
    return encode_jal(offset, rd)

def jalr(rd, rs1, offset):
    """JALR rd, offset(rs1)"""
    return encode_jalr(offset, rs1, rd)

def lui(rd, imm):
    """LUI rd, imm"""
    return encode_u_type(imm, rd, 0b0110111)

def auipc(rd, imm):
    """AUIPC rd, imm"""
    return encode_u_type(imm, rd, 0b0010111)

# ==================== Output Generation ====================

def generate_txt_file(program, descriptions, test_name, feature_desc):
    """Generate .txt file with human-readable format"""
    lines = []
    lines.append(f"========================================")
    lines.append(f"RISC-V {feature_desc} Test Program")
    lines.append(f"========================================")
    lines.append(f"Test Name: {test_name}")
    lines.append("")
    lines.append(f"地址    | 机器码      | Bytes (LE)    | 指令                    | 说明")
    lines.append(f"--------|-------------|---------------|------------------------|--------------------------")

    for i, instr in enumerate(program):
        addr = i * 4
        desc = descriptions[i] if i < len(descriptions) else ""
        bytes_str = ' '.join(f'{b:02X}' for b in instr_to_bytes(instr))
        lines.append(f"0x{addr:02X}    | 0x{instr:08X} | {bytes_str}    | {desc}")

    lines.append("")
    lines.append("========================================")
    lines.append("预期执行结果:")
    lines.append("========================================")
    lines.append("(请根据具体测试填写预期结果)")

    return '\n'.join(lines)

def generate_hex_file(program):
    """Generate .hex file with little-endian encoding"""
    lines = []
    for instr in program:
        for b in instr_to_bytes(instr):
            lines.append(f'{b:02X}')
    return '\n'.join(lines)

# ==================== Main Entry Point ====================

def main():
    parser = argparse.ArgumentParser(description='RISC-V Test File Generator')
    parser.add_argument('--test-name', required=True, help='Test directory name')
    parser.add_argument('--feature', required=True, help='Feature description')
    parser.add_argument('--output-dir', default='.', help='Output directory')
    parser.add_argument('--program', help='Python file defining program list')

    args = parser.parse_args()

    # Example program generation
    print(f"Generating test files for: {args.test_name}")
    print(f"Feature: {args.feature}")
    print(f"Output directory: {args.output_dir}")

    # Default example program
    program = [
        addi(1, 0, 10),    # x1 = 10
        addi(2, 0, 20),    # x2 = 20
        add(3, 1, 2),      # x3 = x1 + x2
        nop(), nop(), nop(), nop()
    ]

    descriptions = [
        "ADDI x1, x0, 10",
        "ADDI x2, x0, 20",
        "ADD x3, x1, x2",
        "NOP",
        "NOP",
        "NOP",
        "NOP"
    ]

    # Generate files
    txt_content = generate_txt_file(program, descriptions, args.test_name, args.feature)
    hex_content = generate_hex_file(program)

    txt_path = f"{args.output_dir}/{args.test_name}.txt"
    hex_path = f"{args.output_dir}/{args.test_name}.hex"

    with open(txt_path, 'w') as f:
        f.write(txt_content)
    print(f"Generated: {txt_path}")

    with open(hex_path, 'w') as f:
        f.write(hex_content)
    print(f"Generated: {hex_path}")

if __name__ == '__main__':
    main()
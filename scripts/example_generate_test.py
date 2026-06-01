#!/usr/bin/env python3
"""
Example: Generate test files for a new instruction type
使用方法: python3 example_generate_test.py
"""

import sys
sys.path.append('../scripts')
from riscv_encoder import *

# ==================== Define Test Program ====================
test_name = "example_test"
feature = "Example Instruction Test"
output_dir = "../sim/pipeline_test_instr/example_test"

# 构建测试程序
program = []
descriptions = []

# Part 1: Initialize registers
program.append(addi(1, 0, 0))       # x1 = 0
descriptions.append("ADDI x1, x0, 0")

program.append(addi(2, 0, 10))      # x2 = 10 (loop limit)
descriptions.append("ADDI x2, x0, 10")

program.append(addi(3, 0, 1))       # x3 = 1 (increment)
descriptions.append("ADDI x3, x0, 1")

# Part 2: Loop body
program.append(add(1, 1, 3))        # x1 += x3
descriptions.append("ADD x1, x1, x3")

program.append(bne(1, 2, -4))       # loop back if x1 != x2
descriptions.append("BNE x1, x2, -4 (loop)")

# Part 3: After loop
program.append(addi(4, 0, 1))       # x4 = 1
descriptions.append("ADDI x4, x0, 1")

# Part 4: NOP padding
for i in range(10):
    program.append(nop())
    descriptions.append("NOP")

# ==================== Generate Files ====================
txt_content = generate_txt_file(program, descriptions, test_name, feature)
hex_content = generate_hex_file(program)

# Write files
import os
os.makedirs(output_dir, exist_ok=True)

with open(f"{output_dir}/{test_name}.txt", 'w') as f:
    f.write(txt_content)
print(f"Generated: {output_dir}/{test_name}.txt")

with open(f"{output_dir}/{test_name}.hex", 'w') as f:
    f.write(hex_content)
print(f"Generated: {output_dir}/{test_name}.hex")

print("\nDone! Next steps:")
print("1. Create pipeline_imem.v to load the .hex file")
print("2. Create filelist.f for VCS compilation")
print("3. Create tb_example_test.v testbench")
print("4. Add test target to Makefile")
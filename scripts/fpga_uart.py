#!/usr/bin/env python3
"""
FPGA UART通信脚本
用于通过UART向FPGA发送指令并接收观测数据

使用方法:
    python fpga_uart.py --port /dev/ttyUSB0 --instr instructions.hex

指令格式: 小端序，每条指令4字节
"""

import serial
import argparse
import time
import struct

def load_hex_file(hex_file):
    """加载.hex文件，返回字节列表"""
    bytes_list = []
    with open(hex_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                # 每行是一个字节（十六进制）
                byte_val = int(line, 16)
                bytes_list.append(byte_val)
    return bytes_list

def send_instructions(ser, instructions_bytes):
    """发送指令到FPGA"""
    print(f"发送 {len(instructions_bytes) // 4} 条指令...")

    for i, byte in enumerate(instructions_bytes):
        ser.write(bytes([byte]))
        time.sleep(0.0001)  # 等待发送完成

    # 发送NOP作为结束标志
    nop_bytes = [0x13, 0x00, 0x00, 0x00]
    for byte in nop_bytes:
        ser.write(bytes([byte]))
        time.sleep(0.0001)

    print("指令发送完成")

def receive_monitor_data(ser, num_frames=10):
    """接收观测数据"""
    print("接收观测数据...")

    for frame in range(num_frames):
        # 每帧12字节: PC(4) + ALU(4) + RD(4)
        data = ser.read(12)
        if len(data) == 12:
            pc = struct.unpack('<I', data[0:4])[0]
            alu_out = struct.unpack('<I', data[4:8])[0]
            rd_data = struct.unpack('<I', data[8:12])[0]

            print(f"Frame {frame}: PC=0x{pc:08x}, ALU=0x{alu_out:08x}, RD=0x{rd_data:08x}")
        else:
            print(f"接收不完整: {len(data)} bytes")
            break

def main():
    parser = argparse.ArgumentParser(description='FPGA UART通信脚本')
    parser.add_argument('--port', required=True, help='UART端口 (如 /dev/ttyUSB0)')
    parser.add_argument('--instr', required=True, help='指令hex文件路径')
    parser.add_argument('--baud', default=115200, type=int, help='波特率')
    parser.add_argument('--frames', default=10, type=int, help='接收观测数据帧数')

    args = parser.parse_args()

    # 打开串口
    ser = serial.Serial(args.port, args.baud, timeout=1)
    print(f"串口 {args.port} 已打开，波特率 {args.baud}")

    # 加载指令
    instr_bytes = load_hex_file(args.instr)

    # 发送指令
    send_instructions(ser, instr_bytes)

    # 等待CPU执行
    time.sleep(0.5)

    # 接收观测数据
    receive_monitor_data(ser, args.frames)

    ser.close()
    print("串口已关闭")

if __name__ == '__main__':
    main()
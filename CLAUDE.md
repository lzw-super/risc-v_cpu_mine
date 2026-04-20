# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

Each module has dedicated simulation environment under `sim/<module>/`.

```bash
# Compile and run simulation for a specific module
cd sim/<module>
make all        # compile + simulate
make compile    # only compile
make simulate   # run after compile
make view       # open Verdi waveform viewer
make clean      # remove generated files
```

## Architecture Overview

This is a RISC-V processor implementation with both single-cycle and five-stage pipeline versions.

### Single-Cycle CPU (`src/cpu.v`)

Simple CPU executing one instruction per clock cycle.

**Data Path Components:**
- `pc.v` - Program Counter with jump/branch support
- `regfile.v` - 32-register file (x0 hardwired to 0), negedge write, combinational read
- `alu.v` - ALU with 10 operations (add/sub/shifts/logical/comparisons)
- `datamem.v` - Data memory supporting LB/LH/LW/LBU/LHU and SB/SH/SW
- `imem.v` - Instruction memory, combinational read

**Control Components:**
- `decoder.v` - Instruction decoder; outputs control signals based on opcode/funct3/funct7
- `branch.v` - Branch condition evaluator (BEQ/BNE/BLT/BGE/BLTU/BGEU)

### Five-Stage Pipeline CPU (`src/pipeline_cpu.v`)

Classic RISC pipeline: IF → ID → EX → MEM → WB

**Pipeline Registers:**
- `if_id_reg.v` - IF/ID pipeline register (PC, instruction)
- `id_ex_reg.v` - ID/EX pipeline register (control signals, register values, immediate)
- `ex_mem_reg.v` - EX/MEM pipeline register (ALU result, memory control)
- `mem_wb_reg.v` - MEM/WB pipeline register (writeback data)

**Hazard Handling:**
- `forward_unit.v` - Data forwarding unit (EX/MEM and MEM/WB forwarding)
- `hazard_unit.v` - Load-Use hazard detection and stall control

**Branch Prediction:**
- `branch_predict.v` - Static branch prediction (backward jump predicted taken)
- `bht.v` - 2-bit dynamic branch history table (optional enhancement)

**Pipeline-Specific Modules:**
- `pipeline_imem.v` - Instruction memory for pipeline (loads pipeline_instructions.hex)

## Hazard Solutions

### Data Hazards

1. **RAW (Read After Write)**: Forwarding from EX/MEM or MEM/WB to EX stage
   - Forward A: selects data for rs1 (00=regfile, 01=EX/MEM, 10=MEM/WB)
   - Forward B: selects data for rs2

2. **Load-Use Hazard**: Detected by hazard_unit, inserts one stall cycle
   - Stall signals: stall_pc, stall_if_id, flush_id_ex

### Control Hazards

- Static prediction: backward branches predicted taken (for loops)
- Flush on mispredict: clear IF/ID and ID/EX registers
- Optional: 2-bit BHT for dynamic prediction

## Decoder Signal Conventions

- `pce` - select PC vs rs1 for ALU input
- `imme` - select immediate vs rs2 for ALU input
- `jmpe` - jump enable for PC
- `be` - branch enable
- `dmop` - memory operation mode (funct3 for load/store)
- `mwe` - memory write enable
- `doe` - data output enable (selects memory data for writeback)

## Simulation Structure

Each testbench in `sim/<module>/tb_<module>.v` follows VCS + Verdi pattern:
- `filelist.f` lists RTL and testbench sources
- Uses `$fsdbDumpfile`/`$fsdbDumpvars` for waveform generation
- Output: `wave.fsdb`, `sim.log`, `compile.log`

## Module Directory Structure

```
src/
├── cpu.v              # Single-cycle CPU top
├── pipeline_cpu.v     # Five-stage pipeline CPU top
├── pc.v               # Program Counter
├── regfile.v          # Register File
├── alu.v              # Arithmetic Logic Unit
├── decoder.v          # Instruction Decoder
├── branch.v           # Branch Condition Logic
├── imem.v             # Instruction Memory (single-cycle)
├── pipeline_imem.v    # Instruction Memory (pipeline)
├── datamem.v          # Data Memory
├── if_id_reg.v        # IF/ID Pipeline Register
├── id_ex_reg.v        # ID/EX Pipeline Register
├── ex_mem_reg.v       # EX/MEM Pipeline Register
├── mem_wb_reg.v       # MEM/WB Pipeline Register
├── forward_unit.v     # Forwarding Unit
├── hazard_unit.v      # Hazard Detection Unit
├── branch_predict.v   # Branch Prediction
├── bht.v              # Branch History Table
├── mul2to1_32.v       # 2-to-1 32-bit MUX
├── mul4to1_32.v       # 4-to-1 32-bit MUX

sim/
├── cpu/               # Single-cycle CPU tests
├── pipeline/          # Pipeline CPU tests
├── decoder/           # Decoder tests
├── regfile/           # Register File tests
├── pc/                # PC tests
```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

Each module has dedicated simulation environment under `sim/<module>/`.

```bash
# 单模块测试 (在sim/<module>/目录下)
cd sim/<module>
make all        # compile + simulate
make compile    # only compile
make simulate   # run after compile
make view       # open Verdi waveform viewer
make clean      # remove generated files

# 流水线指令测试 (在项目根目录或sim/pipeline_test_instr/)
make -C sim/pipeline_test_instr <test_name>   # 运行特定测试
make -C sim/pipeline_test_instr all           # 运行综合测试
make -C sim/pipeline_test_instr clean         # 清理所有测试文件

# 可用的测试目标:
# r_type, i_type, load_store, branch, jump, lui_auipc
# hazard_forward, btb_bht, jump_predict, all_tests
```

## Architecture Overview

This is a RISC-V processor implementation with both single-cycle and five-stage pipeline versions.

### Supported Instruction Set (RV32I Base Integer)

**R-Type Arithmetic:**
- ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND

**I-Type Arithmetic:**
- ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI

**I-Type Load:**
- LB, LH, LW, LBU, LHU

**S-Type Store:**
- SB, SH, SW

**B-Type Branch:**
- BEQ, BNE, BLT, BGE, BLTU, BGEU

**J-Type Jump:**
- JAL (Jump and Link)

**I-Type Jump:**
- JALR (Jump and Link Register)

**U-Type:**
- LUI (Load Upper Immediate), AUIPC (Add Upper Immediate to PC)

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
- `if_id_reg.v` - IF/ID pipeline register (PC, instruction, prediction signals)
- `id_ex_reg.v` - ID/EX pipeline register (control signals, register values, immediate, prediction)
- `ex_mem_reg.v` - EX/MEM pipeline register (ALU result, memory control, branch info)
- `mem_wb_reg.v` - MEM/WB pipeline register (writeback data, wb_sel for data selection)

**Hazard Handling:**
- `forward_unit.v` - Data forwarding unit (EX/MEM and MEM/WB forwarding)
- `hazard_unit.v` - Load-Use hazard detection and stall control

**Dynamic Branch/Jump Prediction:**
- `btb.v` - Branch Target Buffer (256 entries, caches branch/jump targets)
- `bht.v` - 2-bit saturating counter Branch History Table (256 entries)
- `branch_predict.v` - Static prediction fallback (backward branches predicted taken)

**Pipeline-Specific Modules:**
- `pipeline_imem.v` - Instruction memory for pipeline (loads .hex file)

## Branch/Jump Prediction Details

### BTB (Branch Target Buffer)
- **Structure:** 256 entries, each containing valid bit, 12-bit tag, and 32-bit target address
- **Indexing:** PC[9:2] (256 possible addresses)
- **Supported Instructions:** B-Type branches, JAL, JALR
- **Behavior:** 
  - First execution: BTB miss → flush pipeline, cache target
  - Subsequent executions: BTB hit → predict target, no flush
  - JAL target is fixed (PC+offset) → perfect prediction after first cache
  - JALR target may change (rs1+imm) → mispredict detection if target differs

### BHT (Branch History Table)
- **Structure:** 256 entries of 2-bit saturating counters
- **States:** 00=Strong NT, 01=Weak NT, 10=Weak T, 11=Strong T
- **Prediction Rule:** MSB=1 → predict taken, MSB=0 → predict not taken
- **Jump Instructions:** Always set to "Strong Taken" (11) since JAL/JALR always jump

### Mispredict Handling
- **Detection:** EX stage compares predicted vs actual target/direction
- **Penalty:** Flush IF/ID and ID/EX registers (2-cycle penalty)
- **Update:** BTB and BHT updated with actual target/direction after execution

## Hazard Solutions

### Data Hazards

1. **RAW (Read After Write):** Forwarding from EX/MEM or MEM/WB to EX stage
   - Forward A: selects data for rs1 (00=regfile, 01=EX/MEM, 10=MEM/WB)
   - Forward B: selects data for rs2

2. **Load-Use Hazard:** Detected by hazard_unit, inserts one stall cycle
   - Stall signals: stall_pc, stall_if_id, flush_id_ex

### Control Hazards

- **Dynamic Prediction:** BTB+BHT for branches and jumps
- **Mispredict Flush:** Clear IF/ID and ID/EX registers when mispredict detected
- **Static Fallback:** Backward branches predicted taken when BTB/BHT not valid

## Decoder Signal Conventions

| Signal | Description |
|--------|-------------|
| `pce` | Select PC vs rs1 for ALU input (JALR uses rs1) |
| `imme` | Select immediate vs rs2 for ALU input |
| `jmpe` | Jump enable for PC (JAL/JALR) |
| `be` | Branch enable (B-Type) |
| `dmop` | Memory operation mode (funct3 for load/store) |
| `mwe` | Memory write enable |
| `doe` | Data output enable (memory to WB) |
| `wb_sel` | WB data source: 00=mem, 01=alu, 10=imm, 11=pc+4 |
| `is_jump` | Jump instruction flag (JAL/JALR) for prediction |
| `is_load` | Load instruction flag for hazard detection |

## Simulation Structure

Each testbench follows VCS + Verdi pattern:
- `filelist.f` lists RTL and testbench sources
- Uses `$fsdbDumpfile`/`$fsdbDumpvars` for waveform generation
- Output: `wave.fsdb`, `sim.log`, `compile.log`

### Pipeline Test Instructions (`sim/pipeline_test_instr/`)

Comprehensive test suite for each instruction category:

| Test Directory | Purpose |
|----------------|---------|
| `r_type/` | R-Type arithmetic (ADD, SUB, SLL, SLT, etc.) |
| `i_type/` | I-Type arithmetic (ADDI, SLLI, SLTI, etc.) |
| `load_store/` | Memory operations (LB, LH, LW, SB, SH, SW) |
| `branch/` | All 6 branch types (BEQ, BNE, BLT, BGE, BLTU, BGEU) |
| `jump/` | Jump instructions (JAL, JALR) |
| `lui_auipc/` | U-Type instructions (LUI, AUIPC) |
| `hazard_forward/` | RAW hazard forwarding tests |
| `btb_bht/` | Nested loops for branch prediction stress test |
| `jump_predict/` | JAL/JALR dynamic prediction verification |
| `all_tests/` | Comprehensive test combining all categories |

Each test directory contains:
- `tb_<test>.v` - Testbench with pass/fail verification
- `<test>.hex` - Little-endian instruction encoding
- `<test>.txt` - Human-readable test description
- `pipeline_imem.v` - Modified to load specific .hex file
- `filelist.f` - File list for VCS compilation

## Module Directory Structure

```
src/
├── cpu.v              # Single-cycle CPU top
├── pipeline_cpu.v     # Five-stage pipeline CPU top
├── pc.v               # Program Counter
├── regfile.v          # Register File (32 registers, negedge write)
├── alu.v              # Arithmetic Logic Unit (10 operations)
├── decoder.v          # Instruction Decoder (RV32I base)
├── branch.v           # Branch Condition Logic
├── imem.v             # Instruction Memory (single-cycle)
├── pipeline_imem.v    # Instruction Memory (pipeline)
├── datamem.v          # Data Memory (LB/LH/LW/SB/SH/SW)
├── if_id_reg.v        # IF/ID Pipeline Register
├── id_ex_reg.v        # ID/EX Pipeline Register
├── ex_mem_reg.v       # EX/MEM Pipeline Register
├── mem_wb_reg.v       # MEM/WB Pipeline Register
├── forward_unit.v     # Forwarding Unit (RAW hazard)
├── hazard_unit.v      # Hazard Detection Unit (Load-Use)
├── btb.v              # Branch Target Buffer (256 entries)
├── bht.v              # Branch History Table (2-bit counters)
├── branch_predict.v   # Static prediction fallback
├── mul4to1_32.v       # 4-to-1 32-bit MUX

sim/
├── cpu/               # Single-cycle CPU tests
├── pipeline/          # Pipeline CPU tests
├── decoder/           # Decoder tests
├── regfile/           # Register File tests
├── pc/                # PC tests
├── datamem/           # Data Memory tests
├── pipeline_test_instr/   # Comprehensive instruction tests
│   ├── Makefile       # Unified test runner
│   ├── r_type/        # R-Type tests
│   ├── i_type/        # I-Type tests
│   ├── load_store/    # Load/Store tests
│   ├── branch/        # Branch tests
│   ├── jump/          # Jump tests
│   ├── lui_auipc/     # U-Type tests
│   ├── hazard_forward/ # Forwarding tests
│   ├── btb_bht/       # Branch prediction tests
│   ├── jump_predict/  # Jump prediction tests
│   └── all_tests/     # Comprehensive tests
```

## Hex File Format

Instructions encoded in little-endian format (4 bytes per instruction):
```
Byte0 Byte1 Byte2 Byte3
[7:0] [15:8] [23:16] [31:24]
```

Example: `ADDI x1, x0, 10` → machine code `0x00A00093`
Little-endian bytes: `93 00 A0 00` (written as 4 lines in .hex file)
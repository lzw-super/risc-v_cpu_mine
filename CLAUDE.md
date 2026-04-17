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

This is a modular RISC-V processor implementation. Key components:

**Data Path Components (`src/`):**
- `pc.v` - Program Counter with jump/branch support
- `regfile.v` - 32-register file (x0 hardwired to 0), sequential write, combinational read
- `alu.v` - ALU with 10 operations (add/sub/shifts/logical/comparisons)
- `datamem.v` - Data memory with `mem` sub-module; supports LB/LH/LW/LBU/LHU (load) and SB/SH/SW (store)
- `imem.v` - Instruction memory, combinational read

**Control Components:**
- `decoder.v` - Central instruction decoder; outputs all control signals based on opcode/funct3/funct7
- `branch.v` - Branch condition evaluator (BEQ/BNE/BLT/BGE/BLTU/BGEU)

**Utility Modules:**
- `mul2to1.v`, `mul4to1.v` - Multiplexers for data path routing

**Decoder Signal Conventions:**
- `pce` - select PC vs rs1 for ALU input
- `imme` - select immediate vs rs2 for ALU input
- `jmpe` - jump enable for PC
- `be` - branch enable
- `dmop` - memory operation mode (matches funct3 for load/store)
- `mwe` - memory write enable

## Simulation Structure

Each testbench in `sim/<module>/tb_<module>.v` follows VCS + Verdi pattern:
- `filelist.f` lists RTL and testbench sources
- Uses `$fsdbDumpfile`/`$fsdbDumpvars` for waveform generation
- Output: `wave.fsdb`, `sim.log`, `compile.log`
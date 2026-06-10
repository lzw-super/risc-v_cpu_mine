# PPA 优化后 Baseline 说明文档

本文档用于说明当前 PPA 优化后 baseline 的设计功能、支持指令、仿真验证和 DC 综合报告。当前 baseline 的正式综合顶层为 `pipeline_cpu_core`，不把 `datamem` 映射进 core PPA；数据存储器后续计划通过 SRAM adapter/wrapper 接入。

## 1. 设计层面功能

当前处理器核是 32 位 RISC-V 五级流水线实现，流水级如下：

| 流水级 | 主要功能 |
| --- | --- |
| IF | PC 更新、指令输入、BTB/BHT 分支预测查询 |
| ID | 指令译码、寄存器堆读取、立即数生成、控制信号生成 |
| EX | ALU、branch 判断、JAL/JALR 目标计算、forwarding 选择、RV32M MDU 启动/等待 |
| MEM | 外部数据存储器接口输出地址、写使能、写数据、访存模式，并接收读数据 |
| WB | 根据 `wb_sel` 写回 load 数据、ALU 结果、LUI 立即数或 PC+4 |

已实现的流水线控制能力：

- 数据前递：`forward_unit` 支持 EX/MEM 与 MEM/WB 到 EX 阶段操作数前递。
- Load-use 冒险处理：`hazard_unit` 可暂停 PC、IF/ID，并向 ID/EX 插入 bubble。
- 控制冒险处理：BTB+BHT 动态预测，EX 阶段检测方向或目标错误后 flush IF/ID 和 ID/EX。
- RV32M 多周期执行：`mul_div` 采用迭代式 MDU，通过 `start/busy/done` 与流水线握手，避免把乘除法综合成大组合除法器。
- Core-only 存储边界：`pipeline_cpu_core` 暴露 `dmem_addr`、`dmem_we`、`dmem_wdata`、`dmem_mode`、`dmem_rdata`，正式 core PPA 不包含 `datamem`。

本轮 PPA 优化点：

- 默认预测器从 BTB/BHT=256 缩小为 BTB/BHT=16。
- BTB 默认参数：`BTB_ENTRIES=16`、`BTB_INDEX_BITS=4`、`TAG_BITS=16`。
- BHT 默认参数：`BHT_ENTRIES=16`、`BHT_INDEX_BITS=4`。
- `pc` 新增 `REGISTER_NEXT_PC` 参数；`pipeline_cpu` 和 `pipeline_cpu_core` 关闭未使用的 `next_pc` 寄存器，避免无连接寄存器成为时序终点。
- DC 默认综合 top 固化为 `pipeline_cpu_core`，默认 BTB/BHT=16。

## 2. 支持的指令

当前 RTL 已实现并通过专项或综合场景验证的指令如下。

### RV32I 整数/访存/跳转分支指令

| 类型 | 指令 |
| --- | --- |
| R-Type | `ADD`、`SUB`、`SLL`、`SLT`、`SLTU`、`XOR`、`SRL`、`SRA`、`OR`、`AND` |
| I-Type 算术/逻辑 | `ADDI`、`SLTI`、`SLTIU`、`XORI`、`ORI`、`ANDI`、`SLLI`、`SRLI`、`SRAI` |
| Load | `LB`、`LH`、`LW`、`LBU`、`LHU` |
| Store | `SB`、`SH`、`SW` |
| Branch | `BEQ`、`BNE`、`BLT`、`BGE`、`BLTU`、`BGEU` |
| Jump | `JAL`、`JALR` |
| U-Type | `LUI`、`AUIPC` |

### RV32M 乘除法扩展

| 类型 | 指令 |
| --- | --- |
| Multiply | `MUL`、`MULH`、`MULHSU`、`MULHU` |
| Divide/Remainder | `DIV`、`DIVU`、`REM`、`REMU` |

RV32M 边界行为已按 RISC-V 语义处理：

- 除零：`DIV/DIVU` 返回全 1，`REM/REMU` 返回被除数。
- `0x80000000 / -1` 溢出：商为 `0x80000000`，余数为 `0`。

当前 baseline 未纳入的范围：

- `FENCE`、`ECALL`、`EBREAK`、CSR/特权架构指令。
- `A` 原子扩展、`C` 压缩指令扩展、浮点扩展。

## 3. 仿真层面：如何运行测试并查看波形

仿真目录为 `sim/pipeline_test_instr/`。每个测试目标会调用 VCS 编译运行，并在对应子目录生成：

- `compile.log`：编译日志。
- `sim.log`：仿真结果日志，包含 `[PASS]` / `[FAIL]` 和统计信息。
- `wave.fsdb`：FSDB 波形文件。

### 推荐回归命令

从仓库根目录运行：

```sh
make -C sim/pipeline_test_instr baseline_a
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr jump_predict
make -C sim/pipeline_test_instr all_tests
make -C sim/pipeline_test_instr m_type
```

各测试关注点：

| 测试目标 | 主要验证内容 | 波形路径 |
| --- | --- | --- |
| `baseline_a` | forwarding、load-use stall、branch/JALR flush、错误路径写回抑制 | `sim/pipeline_test_instr/baseline_a/wave.fsdb` |
| `btb_bht` | BTB/BHT 动态预测、循环分支、mispredict 统计 | `sim/pipeline_test_instr/btb_bht/wave.fsdb` |
| `jump_predict` | JAL/JALR BTB 缓存、首次重定向、JALR 目标预测 | `sim/pipeline_test_instr/jump_predict/wave.fsdb` |
| `all_tests` | R/I/load/branch/jump 的综合流水线场景 | `sim/pipeline_test_instr/all_tests/wave.fsdb` |
| `m_type` | RV32M 乘除法、除零、溢出和大数边界 | `sim/pipeline_test_instr/m_type/wave.fsdb` |

### 查看波形

部分目标已有 Makefile view 入口，例如：

```sh
make -C sim/pipeline_test_instr view_all
make -C sim/pipeline_test_instr view_btb_bht
make -C sim/pipeline_test_instr view_jump_predict
```

也可以直接打开任意 FSDB：

```sh
verdi -ssf sim/pipeline_test_instr/baseline_a/wave.fsdb &
verdi -ssf sim/pipeline_test_instr/m_type/wave.fsdb &
```

### 波形中建议观察的关键信号

| 目标 | 建议观察信号/层级 |
| --- | --- |
| PC 和取指 | `u_cpu.u_pc.curr_pc`、`instr`、`if_id_*` |
| 数据冒险 | `stall_pc`、`stall_if_id`、`flush_id_ex`、`forward_a`、`forward_b` |
| 控制冒险 | `ex_mispredict`、`flush_if_id`、`flush_id_ex`、`redirect_en`、`redirect_pc` |
| 分支预测 | `predict_taken`、`predict_target`、`btb_hit`、`u_btb.*`、`u_bht.*` |
| 写回正确性 | `wb_we`、`wb_rd_addr`、`wb_data`、`u_regfile.regfile[*]` |
| RV32M | `u_mul_div.start`、`u_mul_div.busy`、`u_mul_div.done`、`u_mul_div.result` |
| 数据存储器 | `dmem_addr`、`dmem_we`、`dmem_wdata`、`dmem_mode`、`dmem_rdata` |

判断功能正确性的基本方法：

1. 先看 `sim.log` 是否出现 `[FAIL]`。
2. 再看测试末尾的 `[PASS]` 汇总或关键统计，例如 `baseline_a` 的 load-use stall count、`m_type` 的 `28 PASS, 0 FAIL`。
3. 打开 `wave.fsdb`，对照 PC、flush/stall、writeback 和目标寄存器值，确认错误路径没有提交。

## 4. DC 综合：如何生成报告

综合目录为 `syn/`。当前默认参数为：

- `TOP=pipeline_cpu_core`
- `BTB_ENTRIES=16`
- `BHT_ENTRIES=16`
- `COMPILE_MODE=quick`
- 默认时钟周期为 10 ns；最终 PPA 高频报告使用 5.2 ns。

### 运行综合检查

```sh
make -C syn check
```

该命令执行 analyze/elaborate/link/check，不代表最终 mapped PPA。

### 生成最终 quick PPA 报告

```sh
make -C syn synth CLK_PERIOD_NS=5.2
```

该命令会覆盖 `syn/reports/pipeline_cpu_core.*.rpt` 和 `syn/outputs/pipeline_cpu_core_*` 输出文件。

可选地运行 ultra：

```sh
make -C syn ultra CLK_PERIOD_NS=5.2
```

当前最终记录以 quick 高频档为准，`compile_ultra` 尚待作为后续对照补跑。

## 5. DC 报告路径

最终标准报告路径：

| 类型 | 路径 | 用途 |
| --- | --- | --- |
| Timing | `syn/reports/pipeline_cpu_core.timing.rpt` | 关键路径、起点/终点、data arrival/required、slack |
| Area | `syn/reports/pipeline_cpu_core.area.rpt` | 总 cell 数、组合/时序面积、层级面积占比 |
| Power | `syn/reports/pipeline_cpu_core.power.rpt` | dynamic power、leakage power |
| QoR | `syn/reports/pipeline_cpu_core.qor.rpt` | critical path、slack、TNS、violating paths、leaf cells、area |
| Constraints | `syn/reports/pipeline_cpu_core.constraints.rpt` | setup/hold/DRC 是否有 violated constraints |
| Check | `syn/reports/pipeline_cpu_core.check.rpt` | 设计结构检查结果 |
| High fanout | `syn/reports/pipeline_cpu_core.high_fanout.rpt` | 高扇出网络观察 |

最终输出文件：

| 类型 | 路径 |
| --- | --- |
| Mapped netlist | `syn/outputs/pipeline_cpu_core_mapped.v` |
| DDC | `syn/outputs/pipeline_cpu_core.ddc` |
| SDC | `syn/outputs/pipeline_cpu_core.sdc` |
| SDF | `syn/outputs/pipeline_cpu_core.sdf` |

本轮 Fmax sweep 归档目录：

```text
syn/reports/ppa_opt_6p0ns/
syn/reports/ppa_opt_5p9ns/
syn/reports/ppa_opt_5p8ns/
syn/reports/ppa_opt_5p7ns/
syn/reports/ppa_opt_5p6ns/
syn/reports/ppa_opt_5p5ns/
syn/reports/ppa_opt_5p4ns/
syn/reports/ppa_opt_5p3ns/
syn/reports/ppa_opt_5p2ns/
```

## 6. DC 综合报告总结

最终选定配置：

```text
TOP            = pipeline_cpu_core
CLK_PERIOD_NS  = 5.2
COMPILE_MODE   = quick
BTB_ENTRIES    = 16
BHT_ENTRIES    = 16
Library        = Nangate45
```

最终 PPA 指标：

| 指标 | 数值 |
| --- | ---: |
| Clean target period | 5.2 ns |
| 保守最高工作频率 | 192.3 MHz |
| QoR critical path length | 5.16 ns |
| 报告派生 Fmax | 193.8 MHz |
| Critical path slack | 0.00 ns |
| TNS | 0.00 |
| Violating paths | 0 |
| Number of cells | 15878 |
| QoR leaf cell count | 15818 |
| Total cell area | 28670.810297 |
| Total dynamic power | 4.3106 mW |
| Cell leakage power | 584.2822 uW |
| Constraint status | no violated constraints |

层级面积占比：

| 层级 | 面积 | 占比 |
| --- | ---: | ---: |
| `u_regfile` | 9676.5482 | 33.8% |
| `u_btb` | 5725.9159 | 20.0% |
| `u_mul_div` | 4970.2101 | 17.3% |
| `u_id_ex` | 2003.5121 | 7.0% |
| `u_alu` | 1749.4820 | 6.1% |
| `u_bht` | 340.7460 | 1.2% |

时序结论：

- 5.2 ns quick synth 已 clean，`constraints.rpt` 显示 no violated constraints。
- 当前最坏路径位于 `u_mul_div` 内部，主要经过乘法迭代 datapath，从 `multiplicand/product/multiplier` 相关寄存器到 `res/product` 寄存器。
- PPA 优化前的旧 core 基线最坏路径经过 forwarding、ALU/branch redirect、PC 选择和 `u_pc/next_pc_reg`。关闭未使用 `next_pc` 寄存器后，PC 更新链路不再是最终最坏路径。

面积/性能量化：

| 对比对象 | Fmax 变化 | cell area 变化 | cell count 变化 |
| --- | ---: | ---: | ---: |
| RV32M core quick BTB/BHT=256 | 157.7 MHz -> 192.3 MHz，约 +21.9% | 110936.895427 -> 28670.810297，约 -74.2% | 52945 -> 15878，约 -70.0% |
| 旧 BTB/BHT=16 10 ns 临时对照 | 157.7 MHz -> 192.3 MHz | 28723.744323 -> 28670.810297，约 -0.18% | 15460 -> 15878 |

功耗量化趋势：

| 对比对象 | dynamic power | leakage power |
| --- | ---: | ---: |
| RV32M core quick BTB/BHT=256 | 10.6420 mW -> 4.3106 mW，约 -59.5% | 2.3379 mW -> 0.5843 mW，约 -75.0% |
| 旧 BTB/BHT=16 10 ns 临时对照 | 2.2693 mW -> 4.3106 mW | 576.4267 uW -> 584.2822 uW |

功耗备注：当前 power report 未读入应用级 SAIF/VCD switching activity，因此功耗只适合同一 DC flow 下的趋势分析。正式提交前建议从 `baseline_a` 或应用级程序导出活动文件后重新 `report_power`。

## 7. 后续优化方向

- SRAM adapter/wrapper：保持 core 不映射 `datamem`，补充 byte write mask、load sign/zero extension 和 SRAM read latency 对齐。
- BTB/BHT 配置矩阵：补跑 32/64 项，并结合 branch counter、mispredict counter、IPC 判断是否值得作为 bonus 性能配置。
- MDU 高频优化：当前 Fmax 主要受 `u_mul_div` 限制，可评估拆分乘法 product/res 更新路径、carry-save 累加或更细粒度状态机。
- Regfile 面积优化：当前 `u_regfile` 是最大层级，可考虑 2R1W macro 或更贴近 SRAM/register-file macro 的实现。
- Power 精确化：导出代表性程序 SAIF/VCD，读入 DC 后重新生成 `power.rpt`。

# RISC-V CPU 赛题实现清单

本文档基于当前仓库代码和「合见工软企业命题-第九届中国研究生创'芯'大赛」赛题要求整理。赛题页面发布时间为 2026-03-23，核心目标是完成一款高性能、可综合、可验证的 32 位 RISC-V 处理器核，并提交仿真、综合、覆盖率、时序和设计文档。

参考赛题页：https://cpipc.acge.org.cn/cw/contestNews/detail/10/2c9080159d18295c019d19b4e714034b?page=1

## 当前项目基线

当前 RTL 已实现经典 5 级流水线：

- IF：`pc`、指令输入、BTB/BHT 查询。
- ID：`decoder`、`regfile`、立即数生成和控制信号生成。
- EX：`alu`、`branch`、数据转发选择、分支/跳转实际目标计算。
- MEM：`pipeline_cpu_core` 暴露外部数据存储器接口（`dmem_addr/we/wdata/mode/rdata`）；仿真/FPGA wrapper 可继续接 `datamem`，后续物理实现计划接 SRAM wrapper。
- WB：`mem_wb_reg` 根据 `wb_sel` 写回 load/ALU/LUI/PC+4。

当前已有冒险处理：

- RAW 数据冒险：`forward_unit` 支持 EX/MEM 和 MEM/WB 到 EX 阶段前递。
- Load-use 冒险：`hazard_unit` 暂停 PC、IF/ID，并向 ID/EX 插入 NOP。
- 控制冒险：`btb` + `bht` 动态预测，EX 阶段检测方向或目标预测错误并 flush IF/ID、ID/EX。

当前已具备的验证资产：

- `sim/pipeline_test_instr/` 下按指令类型拆分的 VCS/Verdi 测试。
- `all_tests`、`hazard_forward`、`btb_bht`、`jump_predict` 等流水线综合场景。
- `pipeline_cpu_fpga` 提供 PC、指令、写回寄存器、访存等观测端口。

## 赛题要求映射

| 赛题要求 | 当前状态 | 后续动作 |
| --- | --- | --- |
| RV32I 基础整数指令集全部指令 | 基本完成，覆盖 R/I/load/store/branch/jump/U 型 | 保留逐条指令回归，补充异常边界值和随机组合程序 |
| RV32M 乘除法扩展全部指令 | 已完成 | 保留 `m_type` 专项回归，后续并入应用级复杂程序验证 |
| A: 经典 5 级流水线 | 已完成 IF/ID/EX/MEM/WB，并通过 `baseline_a` 与 `all_tests` 回归观测 | 归档关键波形截图作为提交材料 |
| A: forwarding | 已完成，并通过 `baseline_a` 覆盖 rd=x0、EX/MEM 优先级、MEM/WB 回退 | 后续可继续扩展随机依赖序列 |
| A: 数据冒险和控制冒险处理 | 已完成基础处理，并通过 `baseline_a` 覆盖 load 后接 ALU/branch/store/JALR 与错误路径 flush | 保留交叉用例回归 |
| A: 稳定运行无死循环、无功能错误 | `baseline_a`、`hazard_forward`、`branch`、`jump`、`btb_bht`、`jump_predict`、`all_tests` 已回归通过 | 将 `sim.log` 和通过截图归档到提交材料 |
| B: 分支预测 | 已完成 BTB+BHT 动态预测 | 增加 cycle counter、mispredict counter，量化开启/关闭预测的收益 |
| B: 静态多发射 | 未计划 | 若时间有限，不作为主线 |
| B: 乱序执行前端 | 未计划 | 若时间有限，不作为主线 |
| 独立指令存储器与数据存储器 | 综合默认顶层已切到 `pipeline_cpu_core`：外部指令输入 + 外部数据存储器接口，不再把 `datamem` 映射进 core PPA | 后续补 SRAM wrapper/adapter，明确 load sign/zero extension、store byte-enable 与 SRAM macro 时序 |
| PC、寄存器可见 | `pipeline_cpu_fpga` 已输出 PC、写回 rd/data/valid 等观测信号 | 扩展寄存器 dump 或调试 CSR/trace 机制 |
| 复杂程序：排序、矩阵、卷积等 | 未见完整应用级测试 | 至少补 3 个完整程序和 golden check |
| RTL 可综合、无 latch、无组合环 | 已新增 DC 综合流程 | 跑通 DC，修复 check/timing 报告中的问题 |
| 覆盖率不低于 95% | 未建立覆盖率目标 | 在 VCS 中加入 line/branch/condition/toggle 覆盖率收集和 URG 报告 |
| 综合资源/频率报告 | 已新增 `syn/` 流程 | 归档 area/timing/power/qor/constraints 报告 |
| UDA 平台使用记录 | 本地仓库未包含 | 若正式参赛，需在 UDA/UVS/UVSYN 上复现并导出对话、仿真、综合、覆盖率记录 |

## 第一阶段：综合基线

目标：先得到可重复的 DC 综合结果，作为后续 PPA 优化基准。

- [x] 新增 `syn/filelist.f`，排除 testbench 和仿真专用 `pipeline_imem`。
- [x] 新增 `syn/run_dc.tcl`；`syn/Makefile` 当前默认顶层为 `pipeline_cpu_core`，`pipeline_cpu_fpga` 仅作为 wrapper/历史对照综合入口。
- [x] 新增 `syn/Makefile`，支持一条命令运行综合。
- [x] 跑通 `make -C syn check`，确认 analyze/elaborate/link/check 可重复。
- [x] 跑通 `make -C syn synth`，得到快速映射结果；2026-06-02 RV32M 后默认使用 `pipeline_cpu_core`、10 ns、quick compile 生成 mapped netlist 和 PPA 报告，不映射 `datamem`。
- [x] 跑通 `make -C syn ultra`，得到历史 core-only PPA 报告。RV32M 合入后当前主基线以 `make -C syn synth CLK_PERIOD_NS=5.2` 的 core-only quick 报告为准；最终提交流程仍需补跑选定配置的 `compile_ultra` 和平台复现。
- [x] 检查 `reports/pipeline_cpu_fpga.check.rpt`，当前已无 latch、多驱动、组合环和端口方向冲突；剩余 lint 主要是未使用高位索引、monitor 直通和常量控制位。
- [x] 检查 `reports/pipeline_cpu_fpga.constraints.rpt`；2026-06-01 DRC 闭环后 10 ns setup/hold 时序满足，报告显示 `This design has no violated constraints.`。
- [x] 闭环 `reports/pipeline_cpu_fpga.constraints.rpt` 中的设计规则违例；2026-06-01 本轮 DRC 闭环后 max_transition/max_capacitance/max_fanout 违例均为 0。
- [x] 检查 `outputs/pipeline_cpu_fpga_mapped.v`，已确认映射到 Nangate45 标准单元。
- [x] 记录历史 fpga-wrapper PPA：DRC 闭环后 85251 cells，cell area 169530.310568，critical path 6.23 ns，slack 3.73 ns，dynamic power 16.0826 mW，leakage power 3.4746 mW。
- [x] 记录当前 core-only PPA：RV32M 后、BTB=256/BHT=256、quick compile 为 52945 cells，cell area 110936.895427，critical path 6.31 ns，setup slack 3.66 ns，报告推算 Fmax 约 157.7 MHz；2026-06-04 PPA 优化后默认 baseline 改为 BTB/BHT=16，5.2 ns quick synth clean，保守支持 192.3 MHz。

默认综合命令：

```sh
make -C syn check
make -C syn synth
make -C syn ultra
```

调整时钟周期：

```sh
make -C syn synth CLK_PERIOD_NS=8.0
```

## 综合/PPA 记录

2026-06-01 快速综合命令：

```sh
make -C syn synth
```

综合配置：`TOP=pipeline_cpu_fpga`，`CLK_PERIOD_NS=10.0`，`COMPILE_MODE=quick`，目标库为 Nangate45。

快速综合结果：

- 输出文件：`syn/outputs/pipeline_cpu_fpga_mapped.v`、`pipeline_cpu_fpga.ddc`、`pipeline_cpu_fpga.sdc`、`pipeline_cpu_fpga.sdf`。
- 规模：122583 cells，100698 combinational cells，21856 sequential cells，macro/black box 为 0。
- 面积：cell area 248272.699964；其中 `u_datamem` 约占 53.0%，`u_btb` 约占 37.4%。
- 时序：10 ns 约束下 critical path 6.32 ns，setup slack 3.63 ns，TNS 0，violating paths 0。
- 功耗：total dynamic power 16.1542 mW，cell leakage power 4.9368 mW；该结果来自低精度、未标注 activity 的 DC 初版估算，仅作趋势参考，最终需结合代表性仿真活动文件重新评估。
- 约束：仍存在大量设计规则违例，QoR 汇总为 max transition 24610、max capacitance 35、max fanout 36；当前报告中的主要来源包括寄存器阵列实现的 `datamem`、`u_btb/n12156`、全局 reset，以及少量 `u_ex_mem`/`u_pc` 网络，后续需通过 SRAM macro、缩小表项或更强约束/缓冲优化闭环。

### 2026-06-01 DRC 闭环优化记录

本轮优化仍以 `TOP=pipeline_cpu_fpga`、`CLK_PERIOD_NS=10.0`、`COMPILE_MODE=quick`、Nangate45 为综合配置，目标是先闭环 standard-cell prototype 的 DRC 违例并形成可交付 quick synth 基线。

变更内容：

- `datamem` 内部从 byte-array/read-modify-write 形态改为 word-array + byte-enable，外部端口保持不变。
- `baseline_a` datamem 层级 sanity check 迁移到 `mem_word[8'h20]`。
- BTB reset 只清 `valid`，不再 reset tag/target 大数组。
- DC reset 约束默认允许 reset buffering，仅在 `DONT_TOUCH_RESET=1` 时启用 `set_dont_touch_network reset`。
- 新增 `syn/reports/pipeline_cpu_fpga.high_fanout.rpt` 用于保留高扇出网络观察。
- BHT reset 本轮未修改；quick synth 已显示 `constraints.rpt` 无 violated constraints，因此按计划跳过。

回归和综合结果：

- `make -C sim/pipeline_test_instr baseline_a`：通过。
- `make -C sim/pipeline_test_instr load_store`：通过。
- `make -C sim/pipeline_test_instr btb_bht`：通过。
- `make -C sim/pipeline_test_instr jump_predict`：通过。
- `make -C sim/pipeline_test_instr all_tests`：通过。
- `make -C syn check`：通过。
- `make -C syn synth`：通过。

PPA/DRC 对比：

| 指标 | 初版 quick synth | DRC 闭环后 quick synth | 变化 |
| --- | ---: | ---: | ---: |
| max transition violations | 24610 | 0 | -24610 |
| max capacitance violations | 35 | 0 | -35 |
| max fanout violations | 36 | 0 | -36 |
| cell count | 122583 | 85251 | -37332 |
| cell area | 248272.699964 | 169530.310568 | -78742.389396 |
| critical path | 6.32 ns | 6.23 ns | -0.09 ns |
| setup slack | 3.63 ns | 3.73 ns | +0.10 ns |
| dynamic power | 16.1542 mW | 16.0826 mW | -0.0716 mW |
| leakage power | 4.9368 mW | 3.4746 mW | -1.4622 mW |

优化后报告摘录：

- `syn/reports/pipeline_cpu_fpga.constraints.rpt`：`This design has no violated constraints.`；DRC max_transition/max_capacitance/max_fanout 违例均为 0。
- `syn/reports/pipeline_cpu_fpga.area.rpt`：85251 cells，63367 combinational cells，21856 sequential cells，20105 buf/inv，total cell area 169530.310568。
- hierarchy 面积：`u_datamem` 63340.4512，占 37.4%；`u_datamem/mem_mine` 63153.1872，占 37.3%；`u_btb` 83284.5989，占 49.1%；`u_bht` 5007.9821，占 3.0%。
- `syn/reports/pipeline_cpu_fpga.qor.rpt`：critical path 6.23 ns，critical path slack 3.73 ns，TNS 0，violating paths 0，hold violations 0，leaf cell count 85194，cell area 169530.310568。
- `syn/reports/pipeline_cpu_fpga.power.rpt`：total dynamic power 16.0826 mW，cell leakage power 3.4746 mW；仍是未标注 activity 的低精度趋势估算。
- `syn/reports/pipeline_cpu_fpga.high_fanout.rpt` 已生成；DC log 仍提示 1 条 high-fanout net 用于 delay 估算：`u_datamem/mem_mine/clk` 20836 loads，但 constraints 已无 violated constraints。

备注：constraints 已 clean；BHT reset 未改；standard-cell memory/predictor 原型面积仍偏大，后续可继续做 core-only 综合边界、SRAM macro 接入和 predictor 参数化。

### 当前 Core-Only quick synth（RV32M 后，BTB=256, BHT=256）

综合配置：`TOP=pipeline_cpu_core`，`CLK_PERIOD_NS=10.0`，`COMPILE_MODE=quick`，`BTB_ENTRIES=256 BHT_ENTRIES=256`，Nangate45。当前综合边界只包含 core、预测器、regfile、流水寄存器和 MDU；`datamem` 仅被 analyze，不被 top 实例化，因此不进入 core PPA。

- 输出文件：`syn/outputs/pipeline_cpu_core_mapped.v`、`pipeline_cpu_core.ddc`、`pipeline_cpu_core.sdc`、`pipeline_cpu_core.sdf`。
- 规模：52945 cells，38907 combinational，14002 sequential，macro/black box 为 0。
- 面积：cell area 110936.895427；`u_btb` 占 75.1%（83283.5349），`u_regfile` 占 8.7%（9670.9622），`u_bht` 占 4.5%（5007.9821），`u_mul_div` 占 4.1%（4509.4981）。
- 时序：10 ns 约束下 critical path 6.31 ns，setup slack 3.66 ns，TNS 0，violating paths 0。按 `10.00 ns - 3.66 ns = 6.34 ns` 估算，当前报告可支持 Fmax 约 157.7 MHz；严格最高频率仍需用更紧时钟重新综合并 sweep。
- 关键路径：`u_ex_mem/rd_addr_out_reg[0]` -> `u_forward` -> `u_alu/sub_16` -> redirect/PC 选择 -> `u_pc/add_39` -> `u_pc/next_pc_reg[31]`。因此频率瓶颈主要是 forwarding + ALU/branch redirect + PC 更新链路，不是 BTB/BHT 查表。
- 功耗：total dynamic power 10.6420 mW，cell leakage power 2.3379 mW（未标注真实 switching activity，仅作趋势参考；本清单的 PPA 中 P 优先使用 Fmax）。
- 约束：DRC clean，`This design has no violated constraints.`

### 当前 Core-Only quick synth 对照（RV32M 后，BTB=16, BHT=16）

综合配置：2026-06-03 使用当前 RTL 在临时工作目录重跑 `make small_synth`，即 `TOP=pipeline_cpu_core`，`CLK_PERIOD_NS=10.0`，`COMPILE_MODE=quick`，`BTB_ENTRIES=16 BHT_ENTRIES=16`，Nangate45；主工程 `syn/reports` 未被覆盖。

- 规模：15460 cells，12638 combinational，2786 sequential，macro/black box 为 0。
- 面积：cell area 28723.744323；`u_regfile` 占 33.7%（9676.5482），`u_btb` 占 19.9%（5725.9159），`u_mul_div` 占 15.7%（4511.0941），`u_bht` 占 1.2%（340.7460）。
- 时序：critical path 6.31 ns，setup slack 3.66 ns，TNS 0，violating paths 0；报告推算 Fmax 同为约 157.7 MHz。
- 面积收益：相对 BTB/BHT=256 的当前 core quick 基线，cell area 从 110936.895427 降到 28723.744323，减少约 74.1%；cell count 从 52945 降到 15460，减少约 70.8%。其中 `u_btb` 面积减少约 93.1%，`u_bht` 面积减少约 93.2%。
- 功耗趋势：total dynamic power 2.2693 mW，cell leakage power 576.4267 uW（未标注真实 switching activity，仅作趋势参考）。
- 约束：DRC clean。

### 2026-06-04 Core PPA 优化闭环（默认 baseline 配置）

本轮以 `pipeline_cpu_core` 为正式 PPA top，不映射 `datamem`。优化目标是先把 baseline 变成面积可控、频率有报告支撑的 core-only 配置，后续再接 SRAM adapter/wrapper。

RTL/脚本优化：

- 默认预测器配置从 BTB/BHT=256 改为 BTB/BHT=16；`btb` 默认 `BTB_INDEX_BITS=4 TAG_BITS=16`，`bht` 默认 `BHT_INDEX_BITS=4`。
- `syn/Makefile` 和 `syn/run_dc.tcl` 默认综合顶层固化为 `pipeline_cpu_core`，默认 `BTB_ENTRIES=16 BHT_ENTRIES=16`。
- `pc` 新增 `REGISTER_NEXT_PC` 参数；`pipeline_cpu` 和 `pipeline_cpu_core` 中关闭未使用的 `next_pc` 寄存器，避免无连接 debug 寄存器继续成为时序终点。
- DC elaboration 已确认 `pc_REGISTER_NEXT_PC0` 只保留 `curr_pc_reg` 32 个触发器，`next_pc_reg` 不再进入 core 综合。

功能回归和波形位置：

| 测试目标 | 结果摘要 | 日志 | 波形 |
| --- | --- | --- | --- |
| `baseline_a` | PASS，90 cycles，4 次 load-use stall | `sim/pipeline_test_instr/baseline_a/sim.log` | `sim/pipeline_test_instr/baseline_a/wave.fsdb` |
| `btb_bht` | PASS，200 cycles，13 次 mispredict | `sim/pipeline_test_instr/btb_bht/sim.log` | `sim/pipeline_test_instr/btb_bht/wave.fsdb` |
| `jump_predict` | PASS，150 cycles，2 次总 mispredict，JAL/JALR 首次 BTB miss 2 次 | `sim/pipeline_test_instr/jump_predict/sim.log` | `sim/pipeline_test_instr/jump_predict/wave.fsdb` |
| `all_tests` | PASS，120 cycles，3 次 mispredict | `sim/pipeline_test_instr/all_tests/sim.log` | `sim/pipeline_test_instr/all_tests/wave.fsdb` |
| `m_type` | 28 PASS / 0 FAIL | `sim/pipeline_test_instr/m_type/sim.log` | `sim/pipeline_test_instr/m_type/wave.fsdb` |

DC 检查和最终报告位置：

- `make -C syn check`：通过。
- `make -C syn synth CLK_PERIOD_NS=5.2`：通过，`syn/reports/pipeline_cpu_core.constraints.rpt` 显示 `This design has no violated constraints.`。
- 最终标准报告：`syn/reports/pipeline_cpu_core.timing.rpt`、`syn/reports/pipeline_cpu_core.area.rpt`、`syn/reports/pipeline_cpu_core.power.rpt`、`syn/reports/pipeline_cpu_core.qor.rpt`、`syn/reports/pipeline_cpu_core.constraints.rpt`。
- 最终输出：`syn/outputs/pipeline_cpu_core_mapped.v`、`syn/outputs/pipeline_cpu_core.ddc`、`syn/outputs/pipeline_cpu_core.sdc`、`syn/outputs/pipeline_cpu_core.sdf`。
- Fmax sweep 归档：`syn/reports/ppa_opt_6p0ns/`、`ppa_opt_5p9ns/`、`ppa_opt_5p8ns/`、`ppa_opt_5p7ns/`、`ppa_opt_5p6ns/`、`ppa_opt_5p5ns/`、`ppa_opt_5p4ns/`、`ppa_opt_5p3ns/`、`ppa_opt_5p2ns/`。

Fmax sweep 结果：

| CLK period | 约束状态 | QoR critical path | QoR slack | cell area | dynamic power |
| ---: | --- | ---: | ---: | ---: | ---: |
| 6.0 ns | clean | 5.96 ns | 0.01 ns | 28239.358314 | 3.7356 mW |
| 5.9 ns | clean | 5.82 ns | 0.04 ns | 28321.818308 | 3.7990 mW |
| 5.8 ns | clean | 5.75 ns | 0.01 ns | 28347.886307 | 3.8645 mW |
| 5.7 ns | clean | 5.63 ns | 0.03 ns | 28418.110303 | 3.9323 mW |
| 5.6 ns | clean | 5.55 ns | 0.01 ns | 28463.330302 | 4.0025 mW |
| 5.5 ns | clean | 5.46 ns | 0.00 ns | 28516.530297 | 4.0753 mW |
| 5.4 ns | clean | 5.34 ns | 0.02 ns | 28581.966296 | 4.1508 mW |
| 5.3 ns | clean | 5.25 ns | 0.01 ns | 28638.092297 | 4.2291 mW |
| 5.2 ns | clean | 5.16 ns | 0.00 ns | 28670.810297 | 4.3106 mW |

最终选定 baseline PPA：

- 配置：`TOP=pipeline_cpu_core`，`CLK_PERIOD_NS=5.2`，`COMPILE_MODE=quick`，`BTB_ENTRIES=16 BHT_ENTRIES=16`，Nangate45。
- 频率：5.2 ns clean target 保守支持 `1000/5.2 = 192.3 MHz`；按 QoR critical path 5.16 ns 推算，报告派生 Fmax 约 193.8 MHz。
- 规模：15878 cells，13093 combinational，2752 sequential，macro/black box 为 0；QoR leaf cell count 15818。
- 面积：cell area 28670.810297；主要层级为 `u_regfile` 33.8%、`u_btb` 20.0%、`u_mul_div` 17.3%、`u_id_ex` 7.0%、`u_alu` 6.1%。
- 时序：TNS 0，violating paths 0，critical path 位于 `u_mul_div`，主要是 `multiplicand/product/multiplier` 到 `res/product` 寄存器的乘法迭代路径；PC redirect/`next_pc` 不再是最坏路径。
- 功耗趋势：total dynamic power 4.3106 mW，cell leakage power 584.2822 uW。该功耗未读入应用级 SAIF/VCD switching activity，只用于同一 DC flow 下的趋势对比。

量化收益：

- 相对 BTB/BHT=256 的 RV32M core quick 基线：保守 clean Fmax 从约 157.7 MHz 提升到 192.3 MHz，提升约 21.9%；cell area 从 110936.895427 降到 28670.810297，减少约 74.2%；cell count 从 52945 降到 15878，减少约 70.0%；dynamic power 从 10.6420 mW 降到 4.3106 mW，减少约 59.5%；leakage 从 2.3379 mW 降到 0.5843 mW，减少约 75.0%。
- 相对旧的 BTB/BHT=16、10 ns 临时对照，最终高频档面积基本持平（28723.744323 -> 28670.810297，约 -0.18%），但 Fmax 从约 157.7 MHz 提升到 192.3 MHz。代价是 DC 为压频换用了更快单元，dynamic power 从 2.2693 mW 增至 4.3106 mW。
- 若只追求低面积/低功耗，可使用 10 ns 优化档：BTB/BHT=16 + `REGISTER_NEXT_PC=0` 下 cell area 28201.852317，dynamic power 2.2414 mW，critical path 6.29 ns；若追求性能，采用本轮 5.2 ns 高频档。

### PPA 对比总表

这里 PPA 的 P 按性能记录，用综合报告推算的 Fmax 表示；power 仅在各小节中作为低精度趋势备注。

| 指标 | 初版 quick (fpga wrapper) | DRC 闭环 quick (fpga wrapper) | core quick (256) | core quick (16, 10 ns) | 优化后 core quick (16, 5.2 ns) |
| --- | ---: | ---: | ---: | ---: | ---: |
| max trans violations | 24610 | 0 | 0 | 0 | 0 |
| max cap violations | 35 | 0 | 0 | 0 | 0 |
| max fanout violations | 36 | 0 | 0 | 0 | 0 |
| cell count | 122583 | 85251 | 52945 | 15460 | 15878 |
| cell area | 248272.70 | 169530.31 | 110936.90 | 28723.74 | 28670.81 |
| critical path | 6.32 ns | 6.23 ns | 6.31 ns | 6.31 ns | 5.16 ns |
| setup slack | 3.63 ns | 3.73 ns | 3.66 ns | 3.66 ns | 0.00 ns |
| report-derived Fmax | 158.0 MHz | 159.5 MHz | 157.7 MHz | 157.7 MHz | 193.8 MHz |
| clean target Fmax | 100.0 MHz | 100.0 MHz | 100.0 MHz | 100.0 MHz | 192.3 MHz |

### Core 顶层 PPA 结论

- 当前 core-only 边界已经符合后续接 SRAM 的方向：`pipeline_cpu_core` 不映射 `datamem`，后续应由 SRAM wrapper/adapter 负责 raw SRAM 读写、byte-enable、load sign/zero extension，并与 `dmem_mode` 语义对齐。
- 面积优化已经验证：BTB=256 时 `u_btb` 占 core area 75.1%；默认缩到 16 项后，最终高频档 core area 仍比 256 项基线低约 74.2%。因此“缩小 BTB/BHT 表项数、index 位宽、target/tag 位宽”仍是最确定的面积优化方向。
- 频率瓶颈已经迁移：旧基线最坏路径经过 forwarding/ALU/redirect/PC/`next_pc_reg`；关闭未使用 `next_pc` 寄存器后，5.2 ns 最终报告的 critical path 位于 `u_mul_div` 内部乘法迭代路径。
- 当前高频档保守支持 192.3 MHz，报告派生 Fmax 约 193.8 MHz；若继续提升频率，应优先重构 MDU，而不是继续只调预测器容量。
- `regfile` 当前仍是面积最大层级（33.8%）；不是 5.2 ns 最坏路径，但后续接 2R1W macro 或正沿 write-first/bypass regfile 可以继续优化面积和时序稳定性。
- 功耗数字尚未读入真实 switching activity；最终提交前应从 baseline(A) 或应用级程序导出 SAIF/VCD 后重跑 `report_power`。

### Core PPA/SRAM 优化建议

1. 预测器容量参数化分档：baseline 提交先使用 BTB/BHT=16 或 32，bonus/performance 配置保留 128/256，并用 branch counter 证明 IPC/命中率收益是否值得面积成本。
2. BTB 位宽继续压缩：若指令 SRAM 地址空间有限，可只保存 word-aligned target 低位或 PC-relative offset，而不是完整 32-bit target；tag 位宽也按实际 PC 空间收敛。
3. BHT reset 降扇出：当前 BHT reset 初始化所有 2-bit counter。可改为 valid/default-not-taken 或 lazy init，只 reset valid/epoch，减少复位网络和触发器控制复杂度。
4. SRAM adapter 明确接口：建议新增 `dmem_wmask[3:0]`、raw `sram_rdata` 到 load 扩展 adapter，避免把 load/store 格式逻辑混在 SRAM macro wrapper 的时序假设里。
5. MDU 高频优化：当前 5.2 ns critical path 位于 `u_mul_div` 乘法迭代 datapath；可评估拆分 product/res 更新路径、使用 carry-save 累加、减少单周期 64-bit add/inc 链，或把乘法和除法状态机进一步分离。
6. Fmax sweep 自动化：本轮已手动归档 6.0 ns 到 5.2 ns clean 报告；后续建议增加 `make fmax_sweep`，自动输出每个配置的 WNS/TNS、area、power，并保存到带配置后缀的目录。
7. 报告文件加配置后缀：当前不同 `BTB_ENTRIES/BHT_ENTRIES/COMPILE_MODE` 会覆盖同名 `pipeline_cpu_core.*.rpt`，建议输出到 `reports/<top>_btb*_bht*_<mode>_<clk>ns/`，便于保留 PPA sweep 证据。

## 第一阶段实现路线与解决方案

第一阶段不再只追求“DC 能跑完”，而是分成三个可验收层级：

| 层级 | 目标 | 当前状态 | 验收口径 |
| --- | --- | --- | --- |
| 1A: RTL 可综合性 | DC 能 analyze/elaborate/link/check，且无 latch、组合环、多驱动、端口方向冲突 | 已完成 | `make -C syn check` 通过，`check.rpt` 仅保留可解释 lint |
| 1B: 标准单元快速映射 | 生成 mapped netlist、DDC、SDC、SDF 和初版 PPA | 已完成 | 当前默认 `make -C syn synth` 生成 `pipeline_cpu_core_mapped.v`；历史 wrapper 报告保留 `pipeline_cpu_fpga_mapped.v` |
| 1C: DRC/PPA 可交付基线 | max transition/cap/fanout 闭环，PPA 能作为后续优化基准 | 已完成历史 wrapper DRC clean + 当前 5.2 ns core quick PPA；final ultra 移入第六阶段 | `constraints.rpt` 无 all_violators，归档当前 core quick（256/16）和选定配置的 Fmax 报告 |

历史 fpga-wrapper quick synth 说明架构本身能满足 10 ns setup/hold，但把 `datamem` 用标准单元映射会严重污染最终 PPA：`u_datamem` 和 `u_btb` 曾合计占总面积 80% 以上。当前 `pipeline_cpu_core` 已把数据存储器移出综合边界，面积主导项转为 BTB；后续 PPA 优化应继续围绕 SRAM wrapper、预测器容量/位宽和 PC redirect 关键路径展开，而不是盲目调高 DC effort。

### 问题拆解

| 问题 | 证据 | 根因判断 | 优先级 |
| --- | --- | --- | --- |
| `datamem` 面积和 transition 违例巨大 | 历史 fpga-wrapper quick synth 中 `u_datamem` 约 131670.53 area；当前 core-only 已不映射 `datamem` | 初版 `mem` 是 1024x8 触发器阵列，后续应由 SRAM wrapper/adapter 承担真实存储器实现 | P0 已缓解，SRAM 接入待做 |
| BTB 面积过大 | 当前 core quick 中 `u_btb` 83283.5349 area，占 75.1%；BTB=16 后降到 5725.9159 | 256 项 valid/tag/target 全部由触发器实现，查找路径为多路选择 + tag compare | P0 |
| 全局 reset 高扇出 | QoR 报告 35 条 high-fanout nets，constraints 存在 fanout/cap 违例 | 大量流水寄存器、regfile、BTB、BHT 同用异步 reset；脚本中 `set_dont_touch_network reset` 会限制 DC 自动插 buffer | P1 |
| `compile_ultra` 耗时长 | 历史 wrapper quick compile 曾耗时较长；当前 256 项预测器 core quick 约 516s wall time | 优化空间主要不在 mapper effort，而在综合边界、预测器容量和寄存器阵列实现方式 | P1 |
| power 估计可信度有限 | power 报告未标注实际 activity | 缺少应用级 SAIF/VCD 活动文件 | P2 |

### 推荐实现路线

1. 短期固化 core-only 为正式 PPA top。

   - 默认综合 `pipeline_cpu_core`，用于正式 core PPA；`pipeline_cpu_fpga` 作为 wrapper/历史对照，不再代表最终面积。
   - 归档 `syn/reports/pipeline_cpu_core.{check,area,timing,power,qor,constraints}.rpt` 和 `syn/outputs/pipeline_cpu_core_mapped.v`。
   - 在提交说明中明确：core-only PPA 不含数据 SRAM；最终报告应补 `core + SRAM macro/adapter` 估算。

2. 第一优先级完成 SRAM wrapper/adapter。

   当前 `pipeline_cpu_core` 已具备综合友好的外部数据存储器接口：

   - CPU core 输出 `dmem_addr`、`dmem_wdata`、`dmem_mode`、`dmem_we`，输入 `dmem_rdata`。
   - 仿真 wrapper 继续实例化现有行为级 `datamem`，保证测试不用大改。
   - SRAM wrapper 需要补 byte write mask、load sign/zero extension 和 SRAM read latency 对齐；若后续改为 raw SRAM 接口，建议显式增加 `dmem_wmask[3:0]`。

   已完成的 wrapper 侧备选实现：

   - `reg [31:0] mem_word [0:255]`，`word_addr = address[9:2]`。
   - store 用 `wmask[3:0]` 只更新目标 byte lane，避免 read-modify-write 的 `data_in_buff` 大扇出。
   - load 根据 `address[1:0]` 选择 byte/half/word 并符号扩展。
   - baseline(A) 当前测试以对齐访问为主，先保 aligned 语义；若要支持非对齐，再单独列为功能扩展。

3. 第二优先级处理 BTB/BHT 综合形态。

   - 给 `BTB_ENTRIES`、`BHT_ENTRIES` 增加综合配置入口。baseline(A) 综合可先用 16/32 项，bonus 性能版再恢复 256 项。
   - BTB reset 只清 `valid`，`tag_array` 和 `target_array` 不需要全量异步清零；无效项由 `valid` 屏蔽。
   - BHT 可改为 valid + 默认 not-taken，或用小状态机分多周期初始化，避免 reset 同时驱动全部计数器。
   - 保留 256 项版本作为 bonus 配置，并分别记录“baseline synthesis config”和“bonus performance config”。

4. 第三优先级优化 reset 策略和 DC 约束。

   - RTL 侧减少大阵列异步 reset，只 reset 控制有效位和流水线 architectural state。
   - DC 脚本中不要长期 `set_dont_touch_network [get_ports reset]`；DRC 收敛阶段应允许 DC 插入 reset buffer，或显式建立 reset buffer tree。
   - 增加独立 high-fanout/DRC report：用 `all_fanout`/`sizeof_collection` 或 `report_net` 脚本列出 fanout > 16 的 nets，并保留 `report_constraint -all_violators`、`report_timing -transition_time -capacitance`，每轮比较违例数量。
   - quick 版本继续用 `compile`，最终版本在 memory/predictor 结构收敛后再跑 `compile_ultra`，否则 ultra 的时间主要消耗在不合理的大阵列映射上。

5. 功耗和最终 PPA 记录。

   - baseline(A) 或应用级程序仿真导出 VCD/SAIF。
   - DC 中读入 switching activity 后重新 `report_power`。
   - 最终表格至少区分三列：`standard-cell prototype`、`core-only`、`core + memory macro estimate`。

### 第一阶段下一步清单

- [x] 新增综合友好的 data memory interface 顶层，默认 DC top 切到 core-only。
- [x] 保留现有 `pipeline_cpu_fpga`/`datamem` 作为仿真和 FPGA wrapper，不破坏 baseline(A) 回归。
- [x] 将 `datamem` 改为 word-array + byte-enable，作为不接 macro 时的备选实现。
- [x] 参数化 BTB/BHT 表项数，新增 `SYNTH_SMALL_PREDICTOR` 或 Makefile 变量控制综合配置。
- [x] 去掉 BTB 大数组全量异步 reset，只 reset valid；BHT reset 本轮未改，因 quick synth DRC 已 clean 暂不处理。
- [x] 调整 DC reset 约束，允许 reset 网络缓冲或显式插 buffer tree。
- [x] 每完成一项结构优化后运行 `baseline_a`、`all_tests`、`make -C syn check`、`make -C syn synth`。
- [x] 以 `constraints.rpt` 中 max transition/cap/fanout 违例归零作为 1C 完成标准。
- [x] RV32M 后对选定 core 配置完成 quick Fmax sweep，最终标准报告为 `pipeline_cpu_core`、BTB/BHT=16、5.2 ns clean。
- [ ] 对最终选定 core 配置补跑 `make -C syn ultra`，并与 quick 高频档对照。

## Baseline(A) 验证记录

2026-06-01 baseline(A) 回归目标：

```sh
make -C sim/pipeline_test_instr baseline_a
make -C sim/pipeline_test_instr hazard_forward
make -C sim/pipeline_test_instr branch
make -C sim/pipeline_test_instr jump
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr jump_predict
make -C sim/pipeline_test_instr all_tests
```

本轮回归结果：除 `jump` 外的上述目标均输出 `[PASS]` 且无 `[FAIL]`；`jump` 目标按既有 testbench 判据，以无 `[FAIL]`、无仿真错误并正常结束作为通过依据，后续可补充显式 `[PASS]` 标记。

`baseline_a` 覆盖：

- forwarding：rd=x0 过滤、EX/MEM 优先级、MEM/WB 回退。
- load-use：load 后接 ALU、branch、store、JALR。
- control hazard：branch/JALR 重定向后错误路径寄存器写入和内存写入不提交。

## 第二阶段：RV32M 硬性补齐

目标：满足赛题指令集硬要求。

- [x] 扩展 `decoder`，识别 opcode `0110011` 且 funct7=`0000001` 的 RV32M 指令。
- [x] 扩展 ALU opcode 编码，避免与 RV32I 操作冲突。aluop 0x0b-0x12 对应 8 条 M-type 指令。
- [x] 实现乘法：`MUL`、`MULH`、`MULHSU`、`MULHU`。
- [x] 实现除法/取余：`DIV`、`DIVU`、`REM`、`REMU`。
- [x] 明确除零和溢出行为，按 RISC-V spec 处理。DIV/DIVU 除零→全1；REM/REMU 除零→被除数；0x80000000/-1 溢出→自身/0。
- [x] 选择执行策略：迭代式多周期 MDU，避免 DC 将组合 `/`、`%` 和宽乘法映射成超大 DesignWare 组合除法器。
- [x] 新增 MDU `start/busy/done` 握手；M-type 指令在 EX 阶段执行期间 hold ID/EX、stall PC/IF_ID，并向 EX/MEM 插入 bubble，完成后复用 `ex_alu_out` 写回和 forwarding 路径。
- [x] 新增 `sim/pipeline_test_instr/m_type/`，逐条测试 RV32M（28 项全 PASS，含除零、溢出和大数乘法边界测试）。
- [x] 将 RV32M 合入 `all_tests` 依赖文件列表，确保现有流水线测试可链接 `mul_div`。
- [x] 迭代式 MDU 版本已通过 `make -C sim/pipeline_test_instr m_type`、`baseline_a`、`r_type`、`all_tests`、`btb_bht`、`jump_predict`，以及 `make -C syn check`、`make -C syn synth`。
- [x] 记录 RV32M 后 core-only quick synth PPA：52945 cells，cell area 110936.895427，critical path 6.31 ns，setup slack 3.66 ns，dynamic power 10.6420 mW，leakage power 2.3379 mW，constraints clean。

## 第三阶段：性能量化与 bonus 证明

目标：把已经实现的 BTB+BHT 变成可展示、可评分的数据。

- [ ] 增加全局 cycle counter。
- [ ] 增加 retired instruction counter。
- [ ] 增加 branch/jump 总数、BTB hit、BHT taken、mispredict counter。
- [ ] 增加编译开关或参数，支持关闭 BTB/BHT 作为 baseline。
- [ ] 对循环、排序、矩阵、卷积分别统计 cycle 和 mispredict。
- [ ] 输出 IPC、预测命中率、相对无预测版本的 cycle 降幅。
- [ ] 在设计文档中解释 EX 阶段重定向、2-bit 饱和计数器、BTB tag/index 的设计取舍。

## 第四阶段：应用级验证与覆盖率

目标：达到提交材料对验证完整性的要求。

- [ ] 排序程序：准备输入数据、运行程序、检查排序结果。
- [ ] 矩阵运算程序：准备矩阵乘/加 golden result。
- [ ] 卷积程序：准备小尺寸 1D/2D convolution golden result。
- [ ] 增加自动化脚本，将汇编或机器码生成 `.hex`。
- [ ] VCS 开启覆盖率收集：line、branch、condition、toggle。
- [ ] 使用 URG 生成覆盖率报告。
- [ ] 对未覆盖分支补测试，目标总覆盖率不低于 95%。

## 第五阶段：工程提交材料

目标：形成赛题交付包。

- [ ] RTL 源码：`src/`。
- [ ] 仿真激励和测试程序：`sim/`、`scripts/`。
- [ ] 波形截图：关键指令、冒险、预测命中/误预测、应用程序结束点。
- [ ] 覆盖率报告：URG 或 UDA 导出报告。
- [ ] 综合报告：area、timing、power、qor、constraints。
- [ ] 时序分析报告：关键路径和优化说明。
- [ ] 架构图：五级流水图、forwarding 路径、load-use stall、BTB/BHT 更新路径。
- [ ] UDA 使用记录：对话导出、录屏、AI 辅助定位/优化过程。
- [ ] 性能对比表：baseline vs branch prediction，cycle/PPA/critical path。

## 第六阶段：Core PPA 与 SRAM 集成

目标：把当前 core-only 综合结果转成可提交、可对比、可接 SRAM 的 PPA 闭环。

- [x] 固化综合边界：正式 PPA 默认 `TOP=pipeline_cpu_core`，`pipeline_cpu_fpga`/`pipeline_cpu` 仅作为 wrapper 或仿真入口。
- [ ] 新增 SRAM adapter/wrapper，保持 core 不映射 `datamem`，但 wrapper 完成 byte write mask、load sign/zero extension 和 SRAM read latency 对齐。
- [ ] 增加 BTB/BHT 配置矩阵：已完成 16/256 项对照和 16 项 Fmax sweep；32/64 项、预测性能计数和应用级 IPC 仍待补。
- [x] 先选 baseline 面积配置：默认使用 16 项预测器，256 项保留为 bonus/性能配置候选。
- [x] 清理 `pc.next_pc` 未连接寄存器或改成可选 debug 输出，重新跑 `baseline_a/all_tests` 和 core synth，critical path 已从 PC 更新链路移到 MDU。
- [ ] 评估 regfile 正沿写入 + write-first/bypass 或 2R1W macro 接入，避免未来高频目标下半周期路径成为瓶颈。
- [x] 跑 Fmax sweep，记录最高 clean period，而不是只用 10 ns slack 反推；本轮 0.1 ns 手动 sweep 归档 6.0 ns 到 5.2 ns，最终 5.2 ns clean。
- [ ] 最终用 `compile_ultra` 对选定配置复跑，并归档带配置后缀的 area/timing/qor/constraints/power 报告。

## 当前风险

- RV32M 已实现并采用迭代式 MDU；后续风险主要是多周期 EX stall 与更多复杂程序、随机依赖序列的交叉覆盖仍需扩展。
- 当前综合默认可选择 core-only 边界；仿真顶层 `pipeline_cpu` 内含 `$readmemh` 指令存储器，更适合仿真。
- 默认 core-only 综合已不映射 `datamem`；若综合 `pipeline_cpu_fpga` wrapper，`datamem` 仍会作为寄存器阵列进入面积报告，仅适合作为历史/原型对照。
- 256 项 core 基线面积主要由 BTB/BHT 触发器阵列主导；优化后 16 项高频档的主要面积项转为 `u_regfile`、`u_btb`、`u_mul_div`。若继续追求面积 PPA，应同时考虑预测表位宽、regfile macro 和 MDU 数据通路。
- `make -C syn ultra` 对 256 项预测器仍可能耗时较长；若只做 RTL 可综合性检查，优先用 `make -C syn check`。
- `make -C syn check` 会生成 elaborated netlist，不等同于最终 mapped netlist；最终 PPA 仍需跑 `make -C syn synth` 或 `make -C syn ultra`。
- 正式参赛要求 UDA/UVS/UVSYN 平台材料；本地 DC 报告适合早期自检，但最终提交要按赛事平台复现。
- baseline(A) 功能回归已通过；quick synth DRC 和 5.2 ns Fmax sweep 已闭环并同步 PPA 记录，后续风险转为 SRAM adapter 尚未接入、power 未标注 activity、32/64 项 predictor 性能矩阵和 final `compile_ultra` 尚未完成。

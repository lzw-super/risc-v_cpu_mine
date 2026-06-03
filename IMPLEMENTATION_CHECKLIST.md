# RISC-V CPU 赛题实现清单

本文档基于当前仓库代码和「合见工软企业命题-第九届中国研究生创'芯'大赛」赛题要求整理。赛题页面发布时间为 2026-03-23，核心目标是完成一款高性能、可综合、可验证的 32 位 RISC-V 处理器核，并提交仿真、综合、覆盖率、时序和设计文档。

参考赛题页：https://cpipc.acge.org.cn/cw/contestNews/detail/10/2c9080159d18295c019d19b4e714034b?page=1

## 当前项目基线

当前 RTL 已实现经典 5 级流水线：

- IF：`pc`、指令输入、BTB/BHT 查询。
- ID：`decoder`、`regfile`、立即数生成和控制信号生成。
- EX：`alu`、`branch`、数据转发选择、分支/跳转实际目标计算。
- MEM：`datamem` 访存。
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
| 独立指令存储器与数据存储器 | 仿真顶层有 `pipeline_imem` 和 `datamem`；综合顶层默认外部指令输入 + 内部数据存储 | 明确综合边界，必要时补一个纯 core + memory wrapper |
| PC、寄存器可见 | `pipeline_cpu_fpga` 已输出 PC、写回 rd/data/valid 等观测信号 | 扩展寄存器 dump 或调试 CSR/trace 机制 |
| 复杂程序：排序、矩阵、卷积等 | 未见完整应用级测试 | 至少补 3 个完整程序和 golden check |
| RTL 可综合、无 latch、无组合环 | 已新增 DC 综合流程 | 跑通 DC，修复 check/timing 报告中的问题 |
| 覆盖率不低于 95% | 未建立覆盖率目标 | 在 VCS 中加入 line/branch/condition/toggle 覆盖率收集和 URG 报告 |
| 综合资源/频率报告 | 已新增 `syn/` 流程 | 归档 area/timing/power/qor/constraints 报告 |
| UDA 平台使用记录 | 本地仓库未包含 | 若正式参赛，需在 UDA/UVS/UVSYN 上复现并导出对话、仿真、综合、覆盖率记录 |

## 第一阶段：综合基线

目标：先得到可重复的 DC 综合结果，作为后续 PPA 优化基准。

- [x] 新增 `syn/filelist.f`，排除 testbench 和仿真专用 `pipeline_imem`。
- [x] 新增 `syn/run_dc.tcl`，默认顶层为 `pipeline_cpu_fpga`。
- [x] 新增 `syn/Makefile`，支持一条命令运行综合。
- [x] 跑通 `make -C syn check`，确认 analyze/elaborate/link/check 可重复。
- [x] 跑通 `make -C syn synth`，得到快速映射结果；2026-06-01 使用 `pipeline_cpu_fpga`、10 ns、quick compile 生成 mapped netlist 和 PPA 报告。
- [x] 跑通 `make -C syn ultra`，得到最终 PPA 报告。2026-06-02 core-only ultra 已完成（BTB=256/BHT=256 和 BTB=16/BHT=16 两种配置均跑通）。
- [x] 检查 `reports/pipeline_cpu_fpga.check.rpt`，当前已无 latch、多驱动、组合环和端口方向冲突；剩余 lint 主要是未使用高位索引、monitor 直通和常量控制位。
- [x] 检查 `reports/pipeline_cpu_fpga.constraints.rpt`；2026-06-01 DRC 闭环后 10 ns setup/hold 时序满足，报告显示 `This design has no violated constraints.`。
- [x] 闭环 `reports/pipeline_cpu_fpga.constraints.rpt` 中的设计规则违例；2026-06-01 本轮 DRC 闭环后 max_transition/max_capacitance/max_fanout 违例均为 0。
- [x] 检查 `outputs/pipeline_cpu_fpga_mapped.v`，已确认映射到 Nangate45 标准单元。
- [x] 记录初版 PPA：122583 cells，cell area 248272.699964，critical path 6.32 ns，slack 3.63 ns，dynamic power 16.1542 mW，leakage power 4.9368 mW。
- [x] 记录 DRC 闭环后 PPA：85251 cells，cell area 169530.310568，critical path 6.23 ns，slack 3.73 ns，dynamic power 16.0826 mW，leakage power 3.4746 mW。

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

### Core-Only compile_ultra（BTB=256, BHT=256）

综合配置：`TOP=pipeline_cpu_core`，`CLK_PERIOD_NS=10.0`，`COMPILE_MODE=ultra`，Nangate45。

- 输出文件：`syn/outputs/pipeline_cpu_core_mapped.v`、`pipeline_cpu_core.ddc`、`pipeline_cpu_core.sdc`、`pipeline_cpu_core.sdf`。
- 规模：56509 cells，42930 combinational，13566 sequential。
- 面积：cell area 106729.573524；u_btb 占 81.1%（86577.68），u_regfile 占 8.7%（9302.02），u_bht 占 4.4%（4655.53）。
- 时序：10 ns 约束下 critical path 0.72 ns，setup slack 4.24 ns，TNS 0，violating paths 0。
- 功耗：total dynamic power 9.8427 mW，cell leakage power 1.8008 mW（低精度趋势估算）。
- 约束：DRC clean，`This design has no violated constraints.`

### Core-Only compile_ultra（BTB=16, BHT=16）

综合配置：`TOP=pipeline_cpu_core`，`CLK_PERIOD_NS=10.0`，`COMPILE_MODE=ultra`，`BTB_ENTRIES=16 BHT_ENTRIES=16`，Nangate45。

- 规模：11877 cells，9514 combinational，2350 sequential。
- 面积：cell area 21747.096322；u_btb 占 27.2%（5915.84），u_regfile 占 42.8%（9302.02），u_bht 占 1.5%（319.47）。
- 时序：critical path 0.72 ns，setup slack 4.24 ns，TNS 0，violating paths 0。
- 功耗：total dynamic power 1.9284 mW，cell leakage power 365.88 uW（低精度趋势估算）。
- 约束：DRC clean。

### PPA 对比总表

| 指标 | 初版 quick (fpga) | DRC 闭环 quick (fpga) | core ultra (256) | core ultra (16) |
| --- | ---: | ---: | ---: | ---: |
| max trans violations | 24610 | 0 | 0 | 0 |
| max cap violations | 35 | 0 | 0 | 0 |
| max fanout violations | 36 | 0 | 0 | 0 |
| cell count | 122583 | 85251 | 56509 | 11877 |
| cell area | 248272.70 | 169530.31 | 106729.57 | 21747.10 |
| critical path | 6.32 ns | 6.23 ns | 0.72 ns | 0.72 ns |
| setup slack | 3.63 ns | 3.73 ns | 4.24 ns | 4.24 ns |
| dynamic power | 16.15 mW | 16.08 mW | 9.84 mW | 1.93 mW |
| leakage power | 4.94 mW | 3.47 mW | 1.80 mW | 0.37 mW |

## 第一阶段实现路线与解决方案

第一阶段不再只追求“DC 能跑完”，而是分成三个可验收层级：

| 层级 | 目标 | 当前状态 | 验收口径 |
| --- | --- | --- | --- |
| 1A: RTL 可综合性 | DC 能 analyze/elaborate/link/check，且无 latch、组合环、多驱动、端口方向冲突 | 已完成 | `make -C syn check` 通过，`check.rpt` 仅保留可解释 lint |
| 1B: 标准单元快速映射 | 生成 mapped netlist、DDC、SDC、SDF 和初版 PPA | 已完成 | `make -C syn synth` 生成 `pipeline_cpu_fpga_mapped.v`，setup/hold 无违例 |
| 1C: DRC/PPA 可交付基线 | max transition/cap/fanout 闭环，PPA 能作为后续优化基准 | 已完成（quick synth DRC clean + core-only ultra 归档） | `constraints.rpt` 无 all_violators，归档 DRC 闭环后 quick synth 与 core-only ultra（256/16）area/timing/power/qor |

初版 quick synth 说明架构本身能满足 10 ns setup/hold，但实现方式还不适合作为最终 PPA：`u_datamem` 占总面积约 53.0%，`u_btb` 占约 37.4%，两者合计超过 90%；最坏路径也落在 `u_ex_mem/alu_out_out_reg[0]` 到 `u_datamem/mem_mine/mem_reg[*][*]` 的 store 写内存路径。2026-06-01 本轮 DRC 已清零，但面积仍由 standard-cell 原型中的 `u_btb`（49.1%）和 `u_datamem`（37.4%）主导，后续 PPA 优化应继续处理 memory/predictor 结构，而不是盲目调高 DC effort。

### 问题拆解

| 问题 | 证据 | 根因判断 | 优先级 |
| --- | --- | --- | --- |
| `datamem` 面积和 transition 违例巨大 | 初版 quick synth 中 `u_datamem` 约 131670.53 area；`data_in_buff[*]` transition 约 4.41 ns | 初版 `mem` 是 1024x8 触发器阵列，读为四个 1024:1 大 mux，store 又通过 read-modify-write 生成 `data_in_buff`，导致大扇出和大负载 | P0 |
| BTB 面积过大 | `u_btb` 约 92844.64 area | 256 项 valid/tag/target 全部由触发器实现，异步 reset 清零所有表项，查找路径为大 mux + tag compare | P0 |
| 全局 reset 高扇出 | QoR 报告 35 条 high-fanout nets，constraints 存在 fanout/cap 违例 | 大量流水寄存器、regfile、BTB、BHT 同用异步 reset；脚本中 `set_dont_touch_network reset` 会限制 DC 自动插 buffer | P1 |
| `compile_ultra` 耗时长 | quick compile 已耗时约 1232s，ultra 预期更慢 | 标准单元硬映射大存储阵列，优化空间主要不在 mapper effort，而在 RTL/综合边界 | P1 |
| power 估计可信度有限 | power 报告未标注实际 activity | 缺少应用级 SAIF/VCD 活动文件 | P2 |

### 推荐实现路线

1. 短期保持当前 top，先形成“可复现初版报告”。

   - 保留 `pipeline_cpu_fpga` 作为当前综合顶层，用于证明现有 RTL 可被 DC 完整映射。
   - 归档 `syn/reports/pipeline_cpu_fpga.{check,area,timing,power,qor,constraints}.rpt` 和 `syn/outputs/pipeline_cpu_fpga_mapped.v`。
   - 在提交说明中明确：该版本是 standard-cell memory 原型，PPA 被 `datamem`/BTB 寄存器阵列主导，不代表最终物理实现。

2. 第一优先级重构数据存储器综合边界。

   推荐新增一个综合友好的 core 顶层，例如 `pipeline_cpu_core` 或 `pipeline_cpu_sram_if`：

   - CPU core 输出 `dmem_addr`、`dmem_wdata`、`dmem_wmask`、`dmem_we`，输入 `dmem_rdata`。
   - 仿真 wrapper 继续实例化现有行为级 `datamem`，保证测试不用大改。
   - DC 默认综合 core，不再把 1KB 数据存储器用标准单元硬映射；最终报告同时给出 core-only PPA 和 memory macro 说明。

   若短期不想改接口，可先把 `datamem` 从 byte-array 改成 word-array + byte-enable：

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
- [x] 跑通 `make -C syn ultra`，得到最终 PPA 报告。

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

## 当前风险

- RV32M 已实现并采用迭代式 MDU；后续风险主要是多周期 EX stall 与更多复杂程序、随机依赖序列的交叉覆盖仍需扩展。
- 当前综合默认可选择 core-only 边界；仿真顶层 `pipeline_cpu` 内含 `$readmemh` 指令存储器，更适合仿真。
- `datamem`、BTB、BHT 当前会在 DC 中综合为寄存器阵列/多路选择逻辑，面积和时序可能偏大；后续若追求 PPA，应考虑 SRAM macro 或更小预测表。
- `make -C syn ultra` 可能在映射 `datamem` 大寄存器阵列时耗时较长；若只做 RTL 可综合性检查，优先用 `make -C syn check`。
- `make -C syn check` 会生成 elaborated netlist，不等同于最终 mapped netlist；最终 PPA 仍需跑 `make -C syn synth` 或 `make -C syn ultra`。
- 正式参赛要求 UDA/UVS/UVSYN 平台材料；本地 DC 报告适合早期自检，但最终提交要按赛事平台复现。
- baseline(A) 功能回归已在隔离 worktree 通过；quick synth DRC 已闭环并同步 PPA 记录，后续风险转为 standard-cell memory/predictor 面积仍偏大、power 未标注 activity、final ultra 尚未完成。

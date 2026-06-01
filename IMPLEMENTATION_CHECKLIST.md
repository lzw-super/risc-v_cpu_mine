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
| RV32M 乘除法扩展全部指令 | 未实现 | 增加 `MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU` 解码、执行单元、流水线 stall/前递策略和测试 |
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
- [ ] 跑通 `make -C syn ultra`，得到最终 PPA 报告。
- [x] 检查 `reports/pipeline_cpu_fpga.check.rpt`，当前已无 latch、多驱动、组合环和端口方向冲突；剩余 lint 主要是未使用高位索引、monitor 直通和常量控制位。
- [x] 检查 `reports/pipeline_cpu_fpga.constraints.rpt`；10 ns setup/hold 时序已满足，但仍有 max_transition、max_capacitance、max_fanout 设计规则违例。
- [ ] 闭环 `reports/pipeline_cpu_fpga.constraints.rpt` 中的设计规则违例，重点处理 `datamem`、BTB reset 和全局 reset 等高扇出/大负载网络。
- [x] 检查 `outputs/pipeline_cpu_fpga_mapped.v`，已确认映射到 Nangate45 标准单元。
- [x] 记录初版 PPA：122583 cells，cell area 248272.699964，critical path 6.32 ns，slack 3.63 ns，dynamic power 16.1542 mW，leakage power 4.9368 mW。

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

- [ ] 扩展 `decoder`，识别 opcode `0110011` 且 funct7=`0000001` 的 RV32M 指令。
- [ ] 扩展 ALU opcode 编码，避免与 RV32I 操作冲突。
- [ ] 实现乘法：`MUL`、`MULH`、`MULHSU`、`MULHU`。
- [ ] 实现除法/取余：`DIV`、`DIVU`、`REM`、`REMU`。
- [ ] 明确除零和溢出行为，按 RISC-V spec 处理。
- [ ] 选择执行策略：单周期组合乘除、迭代多周期 MDU、或乘法单周期/除法多周期。
- [ ] 若采用多周期 MDU，增加 EX 阶段 busy/stall，并确认 forwarding/load-use/flush 的优先级。
- [ ] 新增 `sim/pipeline_test_instr/m_type/`，逐条测试 RV32M。
- [ ] 将 RV32M 合入 `all_tests`。

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

- RV32M 尚未实现，这是赛题硬性要求，优先级高于 bonus。
- 当前综合顶层选择 `pipeline_cpu_fpga`，它更适合作为 core 综合边界；仿真顶层 `pipeline_cpu` 内含 `$readmemh` 指令存储器，更适合仿真。
- `datamem`、BTB、BHT 当前会在 DC 中综合为寄存器阵列/多路选择逻辑，面积和时序可能偏大；后续若追求 PPA，应考虑 SRAM macro 或更小预测表。
- `make -C syn ultra` 可能在映射 `datamem` 大寄存器阵列时耗时较长；若只做 RTL 可综合性检查，优先用 `make -C syn check`。
- `make -C syn check` 会生成 elaborated netlist，不等同于最终 mapped netlist；最终 PPA 仍需跑 `make -C syn synth` 或 `make -C syn ultra`。
- 正式参赛要求 UDA/UVS/UVSYN 平台材料；本地 DC 报告适合早期自检，但最终提交要按赛事平台复现。
- baseline(A) 功能回归已在隔离 worktree 和主分支合并后通过；快速综合/PPA 报告已生成，但 max_transition、max_capacitance、max_fanout 设计规则违例仍需后续优化闭环。

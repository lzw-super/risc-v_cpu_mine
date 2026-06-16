# 1GHz 频率优化设计文档

本文档用于记录当前 RISC-V 五级流水线 CPU 从约 190MHz baseline 向 1GHz 目标优化的设计方案、实现清单、验证步骤和综合闭环方法。当前优化优先级以最高频率为主，暂不把面积作为主要约束。
暂时不考虑面积，尽可能将最高频率拉高到1ghz，可以按照以下设置：时钟 CLK_in 频率为 1/TclkHz，transition设置为5%*Tclk，uncertainty 设置为 10%*Tclk，input_delay 和 output_delay 均设置为 10%*Tclkns，要求有最差路径的 setup 时序路径分析 。同时每优化并验证一项就更新这个设计文档的内容并适当补充说明添加的代码内容。
## 1. 当前基线

### 1.1 综合配置

当前正式 PPA baseline 使用 core-only 综合边界：

| 项目 | 当前值 |
| --- | --- |
| Top | `pipeline_cpu_core` |
| 工艺库 | Nangate45 |
| 时钟约束 | 5.2 ns |
| 保守频率 | 192.3 MHz |
| 报告派生 Fmax | 约 193.8 MHz |
| BTB/BHT | 16 entries / 16 entries |
| 综合模式 | quick compile |
| 数据存储器 | 不进入 core PPA，走外部 `dmem_*` 接口 |

对应报告：

- `syn/reports/pipeline_cpu_core.qor.rpt`
- `syn/reports/pipeline_cpu_core.timing.rpt`
- `syn/reports/pipeline_cpu_core.area.rpt`
- `syn/reports/pipeline_cpu_core.constraints.rpt`

### 1.2 当前时序瓶颈

QoR 报告显示：

| 指标 | 当前值 |
| --- | ---: |
| Critical Path Length | 5.16 ns |
| Critical Path Slack | 0.00 ns |
| Levels of Logic | 125 |
| TNS | 0.00 |
| Violating Paths | 0 |

当前最坏路径位于 `u_mul_div`：

```text
u_mul_div/multiplicand_reg[0]
  -> 64-bit add_70
  -> 64-bit add_71/inc/sign correction
  -> result mux/control
  -> u_mul_div/res_reg[31]
```

这说明当前频率瓶颈已经不是 BTB/BHT 容量，也不是旧版 PC redirect/`next_pc` 链路，而是 RV32M 乘法迭代 datapath 内部的 64-bit 进位传播路径和最终结果修正路径。

### 1.3 当前面积热点

面积报告中的主要模块占比：

| 模块 | 面积占比 | 说明 |
| --- | ---: | --- |
| `u_regfile` | 33.8% | 当前仍是标准单元寄存器堆形态 |
| `u_btb` | 20.0% | 16-entry BTB，含 valid/tag/target |
| `u_mul_div` | 17.3% | 当前最高频瓶颈 |
| `u_id_ex` | 7.0% | 流水寄存器和控制信号 |
| `u_alu` | 6.1% | 组合 ALU |

本轮目标暂不考虑面积，因此允许为关键路径使用更多寄存器、更快加法结构、复制控制逻辑和更强旁路网络。

## 2. 优化目标

### 2.1 主目标

在 Nangate45 综合环境下，把 core-only 设计逐步推进到 1GHz 目标，即：

```text
CLK_PERIOD_NS = 1.0
WNS >= 0
TNS = 0
No. of violating paths = 0
```

### 2.2 阶段性目标

| 阶段 | 目标周期 | 目标频率 | 重点 |
| --- | ---: | ---: | --- |
| P0 | 5.2 ns | 192 MHz | 当前 baseline 归档 |
| P1 | 3.0 ns | 333 MHz | MDU 拆路径，移除当前最坏路径 |
| P2 | 2.0 ns | 500 MHz | EX/ALU/branch 关键路径拆分 |
| P3 | 1.5 ns | 667 MHz | IF/ID/MEM 边界重构，旁路网络分层 |
| P4 | 1.0 ns | 1GHz | 全链路高频收敛，后端友好约束闭环 |

### 2.3 非目标

- 不以最小面积为目标。
- 不以最低功耗为目标。
- 不在第一轮改变 RV32I/RV32M 指令语义。
- 不把仿真用 `instr_mem`/`datamem` 标准单元阵列作为最终 PPA 的内存实现。

## 3. 总体优化策略

当前 5.16 ns 到 1.0 ns 需要约 5 倍时序压缩，不能只依赖综合选项完成。总体策略是：

1. 先消除 `u_mul_div` 64-bit ripple/add/inc 的单周期长路径。
2. 再把 EX 阶段拆成更细粒度流水，避免 forwarding、ALU、branch、target add、redirect 在同一周期闭合。
3. 把 IF/ID/MEM 也改成适合 1GHz 的同步边界。
4. 最后用 DC `compile_ultra`、retiming、约束细化和 Fmax sweep 做收敛。

推荐架构方向是从当前 5 级流水线演进到 8-10 级左右的高频流水线。

## 4. 详细设计方案

### 4.1 MDU 高频化

#### 当前问题

`src/mul_div.v` 当前乘法路径每轮最多经过：

- `multiplier[0]` 选择 addend。
- `product + multiplicand` 64-bit 加法。
- 最后一轮同时做符号修正 `~mul_next + 1`。
- 根据 `op_reg` 选择 `MUL/MULH/MULHSU/MULHU` 结果。
- 写入 `res_reg`。

这导致最后一轮乘法同时包含两个 64-bit 进位传播结构，无法接近 1ns。

#### 目标设计

把 MDU 拆成独立的 multiply pipeline 和 divide pipeline：

```text
EX dispatch
  -> mdu_issue_reg
  -> mul_pipe 或 div_pipe
  -> mdu_result_reg
  -> EX/MEM 或 WB result select
```

乘法推荐两种实现路径：

| 方案 | 描述 | 频率潜力 | 延迟 | 面积 |
| --- | --- | --- | --- | --- |
| A: 多周期 CSA 迭代 | 每轮用 carry-save 保存 sum/carry，最终单独一拍 carry-propagate | 中 | 33-35 cycles | 中 |
| B: Booth + Wallace/Dadda + pipeline | Booth 编码、压缩树、prefix final adder，插 2-4 级流水 | 高 | 3-5 cycles | 高 |
| C: 调用 DesignWare 乘法器并 pipeline | 用综合库乘法器实现，再用寄存器切分 | 中高 | 2-5 cycles | 中高 |

推荐优先实现 B 或 C，因为目标是 1GHz 且暂不考虑面积。

除法推荐保留多周期 non-restoring/restoring divider，但拆掉和乘法共享的长结果选择路径：

- `div_remainder_shift >= divisor` 比较和减法可以保留一 bit/周期。
- 最后一轮符号修正单独进入 `div_finish` 状态。
- `DIV/REM` 的结果 mux 写入 `mdu_result_reg`，不要和迭代减法在同一拍完成。

#### MDU 接口变化

当前接口：

```verilog
start, data1, data2, op -> res, busy, done
```

目标接口建议扩展为：

```verilog
issue_valid, issue_ready, issue_rs1, issue_rs2, issue_op
result_valid, result_ready, result_data
```

若暂不做乱序/非阻塞执行，可以保持流水线整体在 MDU busy 时停住，但内部 MDU 仍使用 result register 隔离时序。

### 4.2 EX 阶段拆分

#### 当前问题

当前 EX 阶段组合逻辑包含：

- forwarding compare 和 mux。
- ALU operand mux。
- ALU add/sub/shift/compare。
- branch compare。
- branch target/JALR target 计算。
- mispredict 判断。
- redirect PC 选择。

MDU 优化后，这条 EX 链路大概率会成为新的最坏路径。

#### 目标设计

把 EX 拆成至少两级：

```text
EX0: operand select / forwarding / immediate select
EX1: ALU or branch compare / target calculation
EX2: redirect decision / result register
```

推荐第一轮实现为：

| 新阶段 | 职责 |
| --- | --- |
| EX0 | 接收 ID/EX 寄存器，完成 forwarding 选择并寄存 operand |
| EX1 | 执行 ALU、branch compare、target add、JALR target 计算 |
| EX2 | 完成 branch/jump redirect 判断，寄存结果到 EX/MEM |

这样会增加 branch mispredict penalty，但可以显著缩短单周期组合路径。后续可通过更好的 BTB/BHT 或提前 branch compare 抵消性能损失。

### 4.3 ALU 和加法器高速化

#### 当前问题

资源报告中多个 `DW01_add`/`DW01_sub` 使用 `rpl` 实现。1GHz 目标下，32-bit/64-bit ripple-style adder 容易成为瓶颈。

#### 目标设计

对以下加法器优先改成高速实现或单独 pipeline：

- ALU add/sub。
- PC + 4。
- branch target `ex_pc + ex_imm`。
- JALR target。
- MDU final carry-propagate adder。
- load/store address adder。

可选实现：

- 显式 prefix adder 模块。
- 使用 DesignWare 并指定高速 implementation。
- 结构上拆分：低位/高位 carry-select，或提前计算两路高位结果。

第一轮建议先从 MDU final adder 和 EX branch target adder 入手。

### 4.4 IF/ID 高频化

#### 当前问题

当前 IF 阶段同时包含：

- 当前 PC 寄存。
- BTB/BHT 组合查询。
- predicted PC 选择。
- PC + 4。
- redirect 优先级选择。

在 1GHz 下，预测器查询和 PC 选择最好拆开。

#### 目标设计

把 IF 拆成：

| 阶段 | 职责 |
| --- | --- |
| IF0 | PC register、redirect select、next fetch address |
| IF1 | BTB/BHT/tag read、instruction memory request |
| IF2 | instruction return、prediction metadata register |

如果接同步 SRAM，IF2 必须存在。仿真用 `instr_mem` 可以保留给 testbench，但正式 PPA top 应继续使用外部 `instr_in` 或 SRAM wrapper。

### 4.5 MEM 和存储边界

#### 当前问题

正式 `pipeline_cpu_core` 已经把 data memory 放在外部，但 load data 仍按单周期 `dmem_rdata` 进入 MEM/WB。若后续使用同步 SRAM，load latency 需要显式建模。

#### 目标设计

定义统一的数据存储接口：

```text
dmem_req_valid
dmem_req_ready
dmem_req_we
dmem_req_addr
dmem_req_wdata
dmem_req_be
dmem_resp_valid
dmem_resp_rdata
```

第一阶段可以保持单周期 ready/valid 恒定，先完成接口解耦；第二阶段接 SRAM wrapper 后再引入 1-cycle 或 2-cycle load latency。

### 4.6 Forwarding 与 hazard 重构

#### 当前问题

当前 forwarding 网络只适配 5 级流水线。加深流水后，可能出现更多 bypass 来源：

- EX1/EX2 result。
- MEM1/MEM2 result。
- WB result。
- MDU result。

如果全部用一个大 mux 回 EX，会重新形成长路径。

#### 目标设计

采用分层旁路：

1. EX0 只做最近一级 ALU result bypass。
2. MEM/WB 远距离结果可以提前寄存成 `bypass_bus`。
3. MDU result 使用独立 valid/result register。
4. 对 load-use、MDU-use 等难以旁路的情况优先 stall。

hazard unit 需要从“固定 5 级判断”改成“按 producer latency 判断”：

| Producer 类型 | 可用阶段 | Consumer 策略 |
| --- | --- | --- |
| ALU | EX2 | 可旁路或 stall 1 cycle |
| Load | MEM2/WB | load-use stall |
| MDU | result_valid | 等待 result |
| CSR/未来扩展 | WB | 保守 stall |

### 4.7 控制冒险和分支预测

加深流水后，branch resolved 更晚，mispredict penalty 会增加。频率优化阶段可以先接受 CPI 损失，但需要保证 flush 精确。

建议：

- 第一轮保持 BTB/BHT=16，减少变量。
- EX2 统一产生 `redirect_valid/redirect_pc/flush_mask`。
- IF/ID/EX 各级寄存预测元数据，确保 mispredict 比较使用同一条指令的预测信息。
- 后续再评估增大 BTB/BHT、加入 return stack 或更强局部分支历史。

## 5. 实现清单

### 5.1 P0: 基线冻结

- [x] 确认 `pipeline_cpu_core` 5.2 ns quick synth clean。
- [x] 归档 `pipeline_cpu_core.{qor,timing,area,power,constraints}.rpt`。
- [x] 确认最坏路径位于 `u_mul_div`。
- [x] 建立 `make fmax_sweep` 自动化目标。
- [x] 建立每轮优化结果表，记录 period、WNS、TNS、area、critical path、测试结果。

### 5.2 P1: MDU 优化

- [x] 拆分 `src/mul_div.v` 为乘法状态机、除法状态机和最终结果寄存路径。
- [x] 乘法路径移除最后一轮 `mul_next` 与符号修正在同一拍完成的问题。
- [x] 为乘法结果增加 `final_product` 分块结果寄存。
- [x] 为除法最后一轮商/余数符号修正增加 finish stage。
- [x] 保持 RV32M 边界语义：除零、`0x80000000 / -1`、有符号高位乘法。
- [x] 保持 `pipeline_cpu_core` 中 MDU `start/busy/done/res` 接口不变。
- [x] 跑 `make -C sim/pipeline_test_instr m_type`。
- [x] 跑 `baseline_a`、`all_tests`、`hazard_forward`。
- [x] 跑 `make -C syn synth CLK_PERIOD_NS=3.0`。
- [x] 跑 `make -C syn ultra CLK_PERIOD_NS=3.0`，3.0 ns clean。
- [ ] 若继续推进，下一轮 sweep 2.8/2.6/2.4 ns，并进入 P2 EX 深流水。

### 5.3 P2: EX 深流水

- [x] 新增轻量 EX2 redirect 寄存边界，先切断 `forwarding/ALU/branch-target -> flush -> ID/EX` 长组合路径。
- [x] 若继续压到 1.5 ns 以下，再新增完整 EX0/EX1/EX2 流水寄存器，或重构现有 `id_ex_reg`、`ex_mem_reg`。
- [x] EX0 完成 operand select 和 forwarding mux，并寄存 operand。
- [x] EX1 完成 ALU、branch compare、target add。
- [x] EX2 完成 redirect/flush 寄存输出，flush 延后一拍并同步 kill 错误路径 EX/MEM。
- [x] 更新 branch/jump flush 逻辑和预测元数据传递。
- [x] 更新 forwarding 策略：不做 EX1 组合旁路回 EX0；通过 `hazard_unit` 插入 producer latency，再使用 EX/MEM 与 MEM/WB 分层前递。
- [x] 更新 hazard unit，支持 EX0/EX1 producer latency。
- [x] 跑控制冒险测试：`branch`、`jump`、`jump_predict`、`all_tests`。
- [x] 跑数据冒险测试：`baseline_a`、`hazard_forward`、`load_store`。
- [x] 跑 `make -C syn ultra CLK_PERIOD_NS=2.0`。

### 5.4 P3: IF/ID/MEM 边界优化

- [x] 以 1.5 ns 为目标，对 P2 最差路径做 RED 验证，确认 `redirect_pc_q` 路径不满足 1.5 ns。
- [x] 将 branch/jump redirect target 与 BTB target compare 继续后移到轻量 EX2 eval 寄存边界。
- [x] 将 BTB/BHT update 从 EX 组合结果改为使用 EX2 eval 寄存后的 `redirect_eval_*` 信号。
- [x] 将 `monitor_alu_out` 观测输出打一拍，隔离 debug output delay 对 EX/ALU 真实数据通路的时序压力。
- [x] 跑 load/store、branch、jump、all_tests 相关回归子集。
- [x] 跑 1.5 ns `compile_ultra` sweep，WNS/TNS clean。
- [x] 将 IF 的 PC select 与 prediction read 自反馈切开；完整 instruction capture/同步 SRAM IF2 仍作为后续 wrapper 工作。
- [x] 明确 `instr_in` 的时序假设：当前 core PPA 仍按外部组合指令输入约束，未来同步 SRAM 需增加 IF2 capture/wrapper。
- [x] 保留仿真用 `instr_mem`，但正式 PPA 不把 `src/imem.v` 的 `$readmemh` memory 纳入 core。
- [ ] 将 data memory 接口升级为 request/response 或显式 latency 接口。
- [ ] 更新 load-use hazard，支持 1-cycle/2-cycle load response。

说明：P3 本轮优先完成 1.5 ns 时序闭环；完整 IF/MEM request-response 化仍保留为后续 1GHz 前的结构性工作。

### 5.5 P4: 1GHz 综合闭环

- [ ] 将 `syn/run_dc.tcl` 增加 high-performance mode。
- [ ] 增加 `COMPILE_MODE=ultra` 的归档目录和报告后缀。
- [ ] 尝试 retiming，并记录是否改变可调试层级。
- [ ] 对高扇出 reset/stall/flush 网络做 buffer 或局部复制。
- [ ] 对关键模块尝试 ungroup/boundary optimization。
- [ ] 设置更真实的 clock uncertainty 和 input/output delay 后重新评估。
- [x] 跑 1.2 ns、1.0 ns sweep，记录当前 clean 点和 1GHz 剩余瓶颈。
- [x] 完成 1.0 ns/P4 RTL 收敛：ID0/ID1、ALU one-hot、predictor update register、IF delayed prediction self-loop cut。
- [ ] 对 1.0 ns netlist 跑 GLS smoke test。

## 6. 推荐实施顺序

### Step 1: 建立自动化 sweep

先补一个自动化脚本，避免每次手动改周期和搬报告。

输出建议：

```text
syn/reports/fmax_<config>_<period>ns/
  pipeline_cpu_core.qor.rpt
  pipeline_cpu_core.timing.rpt
  pipeline_cpu_core.area.rpt
  pipeline_cpu_core.constraints.rpt
```

汇总表建议记录：

| 字段 | 来源 |
| --- | --- |
| period | make 参数 |
| WNS/TNS | QoR/constraints report |
| critical path | timing report |
| logic levels | QoR report |
| area | area report |
| top hotspot | area hierarchy |
| regression status | sim log |

### Step 2: 先改 MDU

这是当前最确定的最高收益点。目标不是一次到 1GHz，而是先让最坏路径离开 MDU 的 64-bit add/inc 链。

通过标准：

- `m_type` 28 PASS / 0 FAIL。
- 3.0 ns 综合无 setup violation。
- 新 critical path 不再是 `multiplicand/product -> res_reg` 的最后一轮乘法路径。

### Step 3: 拆 EX

MDU 不再最坏后，EX 组合链大概率暴露出来。此阶段重构会影响 flush/stall/forwarding，是功能风险最高的一步。

通过标准：

- forwarding、load-use、branch/jump 回归全部通过。
- 2.0 ns 综合接近 clean 或 violation 集中在少数可拆路径。
- branch mispredict flush 不提交错误路径写回。

### Step 4: 拆 IF/MEM

为同步 SRAM 和 1GHz 后端实现做准备。此阶段重点是接口和 latency 显式化。

通过标准：

- 指令输入路径没有把大 memory 组合读纳入 core critical path。
- load 数据返回时序明确。
- 1.5 ns sweep 有可收敛趋势。

### Step 5: 1GHz 收敛

在 RTL pipeline 已经足够细后，再使用高强度综合选项。

通过标准：

- 1.0 ns `compile_ultra` 或 high-performance mode WNS >= 0。
- `report_constraint -all_violators` 无 setup/hold/transition/cap/fanout 违例。
- gate-level smoke test 通过。

## 7. 验证计划

### 7.1 功能回归

每一阶段至少运行：

```sh
make -C sim/pipeline_test_instr baseline_a
make -C sim/pipeline_test_instr hazard_forward
make -C sim/pipeline_test_instr load_store
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr jump_predict
make -C sim/pipeline_test_instr all_tests
make -C sim/pipeline_test_instr m_type
```

### 7.2 MDU 专项

重点覆盖：

- `MUL/MULH/MULHSU/MULHU`
- `DIV/DIVU/REM/REMU`
- 正负数组合。
- 0、1、-1、最大正数、最小负数。
- 除零。
- `0x80000000 / -1`。
- MDU 后紧跟消费结果的 RAW hazard。

### 7.3 深流水专项

新增或扩展场景：

- ALU result 被下一条指令消费。
- load result 被下一条指令消费。
- branch 依赖前一条 ALU 结果。
- JALR 依赖前一条 ALU/load 结果。
- mispredict 后错误路径包含 store/寄存器写回。
- MDU busy 期间遇到 branch redirect。
- 连续 MDU 指令。

### 7.4 GLS

每个主要里程碑至少跑一个 gate-level smoke test：

```sh
make -C sim/gls timing_check CLK_NS=<period>
```

如果 1.0 ns GLS 失败，需要区分：

- 功能 bug。
- SDF timing violation。
- testbench 对同步 memory latency 的假设错误。

## 8. 综合和约束计划

### 8.1 DC 脚本增强

建议在 `syn/run_dc.tcl` 增加：

- `COMPILE_MODE=ultra_high_perf`
- `compile_ultra`
- 可选 retiming 开关。
- 可选 ungroup/boundary optimization 开关。
- 带配置名的 report/output 目录。
- 自动生成 summary CSV/Markdown。

### 8.2 约束检查

每轮必须检查：

- WNS/TNS。
- setup/hold violation 数量。
- max transition/max capacitance/max fanout。
- high fanout nets。
- critical path 是否符合预期。
- 是否出现 latch、multiple driver、combinational loop。

### 8.3 1GHz 现实性检查

当前报告使用 wire-load model 和 ideal clock。后续如果进入物理实现，需要额外考虑：

- clock tree insertion delay 和 skew。
- placement 后 wire delay。
- SRAM macro setup/hold。
- reset/stall/flush 高扇出布线。
- scan/DFT 对时序的影响。

因此 DC 1.0 ns clean 只能作为前端 RTL 高频潜力证明，不等同于最终后端 signoff。

## 9. 风险和应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| MDU 改动破坏 RV32M 边界语义 | 功能错误 | 先补 MDU golden/random 测试，再改 RTL |
| 深流水 flush/stall 复杂度上升 | 错误路径提交 | 给每级 valid bit 和 kill bit，回归观察 writeback/store |
| bypass mux 变成新关键路径 | 频率无法继续提升 | 分层 bypass，远距离结果寄存化，必要时 stall |
| branch penalty 增大 | IPC 下降 | 高频目标先接受，后续增强预测器 |
| 同步 SRAM latency 改变 load-use 行为 | 程序错误 | 显式 memory response valid，hazard 按 latency 判断 |
| retiming 破坏调试层级 | 难以定位问题 | retiming 只在功能稳定后启用，并保留非 retiming 对照报告 |

## 10. 每轮记录模板

### 10.1 2026-06-15 P0 自动化与约束闭环

#### 改动摘要

- `syn/run_dc.tcl` 增加按目标周期自动派生的约束：
  - `set_clock_transition = 5% * CLK_PERIOD_NS`
  - `set_clock_uncertainty -setup = 10% * CLK_PERIOD_NS`
  - `set_input_delay/set_output_delay = 10% * CLK_PERIOD_NS`
- `syn/run_dc.tcl` 增加专用最差 setup 路径报告：
  - `reports/pipeline_cpu_core.timing.setup.worst.rpt`
  - 报告包含 `-path full -input_pins -nets -transition_time -capacitance`
- `syn/Makefile` 增加 `fmax_sweep` 目标，并启用 `pipefail`，避免 `dc_shell | tee` 隐藏失败。
- `scripts/summarize_dc_reports.py` 增加 DC 报告 CSV 摘要。
- `scripts/check_timing_reports.py` 增加约束比例、最差 setup 路径、critical path 上限和 MDU 旧最坏路径检查。

#### 验证命令

```sh
make -C syn fmax_sweep FMAX_CONFIG=p0_check FMAX_PERIODS="5.2" COMPILE_MODE=quick
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports \
  --output-dir syn/outputs \
  --design pipeline_cpu_core \
  --period 5.2 \
  --require-proportional-constraints \
  --require-setup-path
```

#### 验证结果

| 项目 | 结果 |
| --- | --- |
| 归档目录 | `syn/reports/fmax_p0_check_5p2ns/` |
| Summary CSV | `syn/reports/fmax_p0_check_summary.csv` |
| Period | 5.2 ns |
| Clock transition | 0.26 ns |
| Clock uncertainty | 0.52 ns |
| Input/output delay | 0.52 ns |
| Critical Path Length | 4.62 ns |
| WNS / TNS | 0.00 / 0.00 |
| Violating Paths | 0 |
| Levels of Logic | 67 |
| Cell Area | 29618.302325 |
| 最差 setup path | `u_ex_mem/rd_addr_out_reg[0]` -> `u_id_ex/pc_out_reg[22]` |
| 约束检查 | `This design has no violated constraints.` |

说明：此 P0 sweep 是在当前 P1 RTL 上回扫 5.2 ns，用于验证自动化流程、比例约束和最差 setup 报告生成。原始 190 MHz baseline 的 MDU 最坏路径记录保留在第 1 节。

### 10.2 2026-06-15 P1 MDU 高频化

#### 改动摘要

- `src/mul_div.v` 保持原有 `start/data1/data2/op -> res/busy/done` 接口，避免本轮扩大流水线控制风险。
- 乘法从单轮 64-bit carry-propagate 累加改为 carry-save 迭代：
  - `mul_sum`
  - `mul_carry`
  - `multiplicand`
  - `multiplier`
- 乘法最终 carry-propagate addition 拆成 4 个 16-bit 状态：
  - `ST_MUL_ADD0`
  - `ST_MUL_ADD1`
  - `ST_MUL_ADD2`
  - `ST_MUL_ADD3`
- 有符号乘法最终 two's-complement 修正拆成 4 个 16-bit 状态：
  - `ST_MUL_NEG0`
  - `ST_MUL_NEG1`
  - `ST_MUL_NEG2`
  - `ST_MUL_NEG3`
- 除法保留一 bit/cycle 迭代，但最终商/余数符号修正拆成：
  - `ST_DIV_NEG0`
  - `ST_DIV_NEG1`
- `res` 只在 `ST_MUL_DONE` 或 `ST_DIV_DONE` 写回，避免把最终大加法和结果选择放在同一拍。

#### 功能验证

| 命令 | 结果 |
| --- | --- |
| `make -C sim/pipeline_test_instr m_type` | 28 PASS / 0 FAIL |
| `make -C sim/pipeline_test_instr baseline_a` | PASS，Errors: 0 |
| `make -C sim/pipeline_test_instr hazard_forward` | PASS |
| `make -C sim/pipeline_test_instr all_tests` | PASS |

#### 综合验证

| 配置 | Period | Critical Path | WNS | TNS | Violating Paths | 结论 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| quick | 3.0 ns | 3.07 ns | -0.39 | -152.57 | 440 | MDU 旧路径已消除，但 quick 未收敛 |
| ultra | 3.0 ns | 2.66 ns | 0.00 | 0.00 | 0 | clean |

P1 ultra 归档目录：

```text
syn/reports/p1_mdu_3p0ns_ultra/
```

P1 ultra 约束：

| 项目 | 值 |
| --- | ---: |
| Clock period | 3.0 ns |
| Clock transition | 0.15 ns |
| Clock uncertainty | 0.30 ns |
| Input/output delay | 0.30 ns |

P1 ultra QoR：

| 项目 | 值 |
| --- | ---: |
| Levels of Logic | 39 |
| Critical Path Length | 2.66 ns |
| Critical Path Slack | 0.00 ns |
| Total Negative Slack | 0.00 |
| Violating Paths | 0 |
| Hold Violations | 0 |
| Max transition/cap violations | 0 |
| Cell Area | 27996.766417 |

P1 ultra 最差 setup 路径：

```text
Startpoint: u_mem_wb/rd_addr_out_reg[1]
Endpoint:   u_id_ex/pc_next_out_reg[1]
Path:       WB rd_addr -> forwarding compare/mux -> ALU/branch-target/flush logic -> ID/EX pc_next register
Arrival:    2.66 ns
Required:   2.66 ns
Slack:      0.00 ns
```

该路径说明 MDU 的 final multiply add/sign-correction 已经不再是最坏路径。新的瓶颈转移到 forwarding、ALU/branch target、flush 和 `id_ex_reg` 控制/数据寄存路径，这正是 P2 EX 深流水需要处理的方向。

#### 检查脚本

P1 ultra 使用以下命令通过 artifact 检查：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p1_mdu_3p0ns_ultra \
  --output-dir syn/reports/p1_mdu_3p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 3.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 3.0
```

注意：`compile_ultra` 日志提示启用了 sequential output inversion。若后续要做 formal equivalence 或严格 GLS 对照，应保留对应 SVF，并用同一份约束和 netlist 做检查。

### 10.3 2026-06-15 P2 轻量 EX2 Redirect Stage

#### RED 验证

P2 开始前，用 P1 归档报告验证 2.4 ns 目标未满足：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p1_mdu_3p0ns_ultra \
  --output-dir syn/reports/p1_mdu_3p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 3.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 2.4
```

结果：

```text
critical path too long: expected <= 2.400 ns, found 2.660 ns
```

#### 改动摘要

- `src/pipeline_cpu_core.v` 增加 `redirect_valid_q` 和 `redirect_pc_q`，把 EX 阶段组合产生的 redirect request 寄存一拍后再驱动 PC redirect 和 flush。
- `src/pipeline_cpu.v` 同步相同修改，保证 VCS 仿真模型和综合 top 的流水行为一致。
- `if_id_flush/id_ex_flush` 改为由 `redirect_valid_q` 触发，mispredict penalty 增加一拍。
- redirect flush 期间同步 flush `ex_mem_reg`，杀掉已经进入 EX 的错误路径指令，避免错误路径写回或 store。
- redirect flush 期间禁止错误路径 branch/jump 更新 BTB/BHT，并屏蔽错误路径产生新的 `ex_mispredict`。
- redirect flush 期间禁止错误路径 MDU 启动或继续拉住 PC：
  - `ex_mdu_start = ex_is_m_type && !redirect_flush && ...`
  - `ex_mdu_stall = ex_is_m_type && !redirect_flush && ...`
- PC stall 增加 redirect 优先级：
  - `pc_stall = (stall_pc || ex_mdu_stall) && !redirect_flush`

该实现不是完整 EX0/EX1/EX2 数据通路拆分，而是 P2 的第一刀：先切断 P1 最差路径中的 `forwarding -> ALU/JALR target -> redirect/flush -> ID/EX D` 组合链。

#### 功能验证

| 命令 | 结果 |
| --- | --- |
| `make -C sim/pipeline_test_instr branch jump jump_predict` | PASS；`jump_predict` 中 flush 从 mispredict 下一拍出现 |
| `make -C sim/pipeline_test_instr hazard_forward load_store all_tests m_type baseline_a` | PASS |
| `m_type` | 28 PASS / 0 FAIL |
| `baseline_a` | PASS，Errors: 0，load-use stall count = 4 |
| `all_tests` | PASS，mispredict = 3，stall = 1 |

#### 综合验证

| 配置 | Period | Critical Path | WNS | TNS | Violating Paths | Levels | Area | 结论 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| ultra | 2.0 ns | 1.78 ns | 0.00 | 0.00 | 0 | 33 | 29006.236409 | clean |

P2 归档目录：

```text
syn/reports/p2_redirect_2p0ns_ultra/
```

P2 2.0 ns 约束：

| 项目 | 值 |
| --- | ---: |
| Clock period | 2.0 ns |
| Clock transition | 0.10 ns |
| Clock uncertainty | 0.20 ns |
| Input/output delay | 0.20 ns |

P2 2.0 ns 最差 setup 路径：

```text
Startpoint: u_id_ex/rs1_addr_out_reg[0]
Endpoint:   redirect_pc_q_reg[3]
Path:       EX operand/forwarding/ALU-JALR target/correct-target calculation -> redirect_pc_q
Arrival:    1.78 ns
Required:   1.78 ns
Slack:      0.00 ns
```

#### 检查脚本

P2 2.0 ns 使用以下命令通过 artifact 检查：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p2_redirect_2p0ns_ultra \
  --output-dir syn/reports/p2_redirect_2p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 2.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 2.0
```

注意：P2 能 clean 到 2.0 ns，但 2.0 ns 最差路径已经贴近 required time。若下一阶段目标为 1.5 ns，优先需要把 EX operand/forwarding、JALR target/correct-target calculation 和 redirect register 之间继续切开；若 MDU final carry path 重新暴露，再把 P1 的 16-bit final carry path 进一步拆成 8-bit 分块或 carry-select 分块。

### 10.4 2026-06-15 P3 EX2 Redirect Eval 与观测输出隔离

#### RED 验证

P3 开始前，用 P2 归档报告验证 1.5 ns 目标未满足：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p2_redirect_2p0ns_ultra \
  --output-dir syn/reports/p2_redirect_2p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 2.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.5
```

结果：

```text
critical path too long: expected <= 1.500 ns, found 1.780 ns
```

P2 最差路径为：

```text
u_id_ex/rs1_addr_out_reg[0]
  -> forwarding / JALR target / correct-target calculation
  -> redirect_pc_q_reg[3]
```

该路径说明 P2 只把 redirect/flush 寄存了一拍，但 JALR target 计算和 redirect PC 写寄存器仍在同一拍内完成，无法继续压到 1.5 ns。

#### 改动摘要

- `src/pipeline_cpu_core.v` 与 `src/pipeline_cpu.v` 增加 EX/EX2 redirect eval 寄存边界：
  - `redirect_eval_valid_q`
  - `redirect_eval_is_branch_q`
  - `redirect_eval_is_jump_q`
  - `redirect_eval_branch_mispredict_q`
  - `redirect_eval_branch_taken_q`
  - `redirect_eval_btb_hit_q`
  - `redirect_eval_predict_target_q`
  - `redirect_eval_pc_q`
  - `redirect_eval_base_q`
  - `redirect_eval_imm_q`
- EX 阶段只捕获 branch/jump 的预测元数据、base 和 imm；JAL/JALR target 计算改为 EX2：

```verilog
assign redirect_eval_target = redirect_eval_base_q + redirect_eval_imm_q;
```

- redirect request 改为由 EX2 生成：

```verilog
assign redirect_eval_request = redirect_eval_valid_q &&
    (redirect_eval_branch_mispredict_q ||
     (redirect_eval_is_jump_q &&
      (!redirect_eval_btb_hit_q ||
       (redirect_eval_predict_target_q != redirect_eval_target))));
```

- `redirect_pc_q` 只接收 EX2 计算后的 `redirect_eval_correct_pc`，切断 EX forwarding 到 redirect PC 的长路径。
- BTB/BHT update 输入改为使用 EX2 eval 寄存后的信号：
  - `predictor_update_enable = redirect_eval_valid_q`
  - `predictor_update_pc = redirect_eval_pc_q`
  - `predictor_update_target = redirect_eval_target`
  - `predictor_update_taken = redirect_eval_is_jump_q ? 1'b1 : redirect_eval_branch_taken_q`
- `if_id_flush/id_ex_flush/ex_mem_reg.flush` 改为由 `redirect_eval_request` 和已寄存的 `redirect_flush` 驱动，避免 EX 组合 mispredict 直接打到前级流水寄存器。
- `redirect_block_ex` 改为只响应真实 EX2 redirect request/flush，避免 branch compare 组合链经 MDU stall 或 PC stall 回到 PC。
- 保留 `ex_mispredict` debug wire，兼容现有 testbench 的层次引用；真实 redirect 逻辑使用 EX2 request。
- `pipeline_cpu_core` 增加 `monitor_alu_out_q`，将 `monitor_alu_out` 观测输出打一拍。该端口只用于外部观测/UART debug，不参与核心写回、访存或 forwarding 数据通路；寄存后消除了 output delay 对 EX/ALU 真实关键路径的干扰。

#### 中间时序观察

P3 初版在 1.5 ns 下仍有负 slack，逐步暴露并处理了以下路径：

| 版本 | WNS | TNS | 主要最差路径 | 处理 |
| --- | ---: | ---: | --- | --- |
| P3 初版 | -0.16 ns | -279.40 | forwarding/branch compare -> IF/ID flush | flush 后移到 EX2 request |
| P3b | -0.14 ns | -246.04 | branch compare -> MDU stall/PC stall | `redirect_block_ex` 只使用真实 redirect pending |
| P3c | -0.17 ns | -186.40 | forwarding/branch compare -> BTB tag/target update | predictor update 后移到 EX2 |
| P3d | -0.04 ns | -17.93 | forwarding/ALU -> `monitor_alu_out` output | `monitor_alu_out` 输出寄存 |

#### 功能验证

| 命令 | 结果 |
| --- | --- |
| `make -C sim/pipeline_test_instr branch jump_predict btb_bht all_tests baseline_a` | PASS |
| `branch` | PASS |
| `jump_predict` | PASS，JAL/JALR BTB miss 统计正常 |
| `btb_bht` | PASS，检测到 mispredict |
| `hazard_forward` | PASS |
| `load_store` | PASS，检测到 1 次 load-use stall |
| `m_type` | 28 PASS / 0 FAIL |
| `all_tests` | PASS，mispredict = 3，stall = 1 |
| `baseline_a` | PASS，Errors: 0 |

说明：`btb_bht` 日志中部分寄存器显示值与注释不一致，但 testbench 本身的断言项通过；本轮未修改该测试判定逻辑。

#### 综合验证

综合命令：

```sh
make -C syn ultra CLK_PERIOD_NS=1.5
```

P3 归档目录：

```text
syn/reports/p3_redirect_eval_1p5ns_ultra/
```

P3 1.5 ns 约束：

| 项目 | 值 |
| --- | ---: |
| Clock period | 1.5 ns |
| Clock transition | 0.075 ns |
| Clock uncertainty | 0.15 ns |
| Input/output delay | 0.15 ns |

P3 1.5 ns QoR：

| 项目 | 值 |
| --- | ---: |
| Levels of Logic | 26 |
| Critical Path Length | 1.32 ns |
| Critical Path Slack | 0.00 ns |
| Total Negative Slack | 0.00 |
| Violating Paths | 0 |
| Hold Violations | 0 |
| Max transition/cap/fanout violations | 0 |
| Cell Area | 30572.976416 |
| Sequential Cell Count | 3075 |

P3 1.5 ns 最差 setup 路径：

```text
Startpoint: u_ex_mem/rd_addr_out_reg[3]
Endpoint:   u_ex_mem/alu_out_out_reg[29]
Path:       EX/MEM rd_addr -> forwarding compare/mux -> ALU data2 mux
            -> ALU result bit[29] -> ex_alu_out mux -> EX/MEM alu_out register
Arrival:    1.32 ns
Required:   1.32 ns
Slack:      0.00 ns
```

该路径是当前真实 EX 数据通路：forwarding 选择影响 ALU operand，再写入 EX/MEM `alu_out_out`。P3 已将 redirect PC、flush、BTB/BHT update 和 debug output 从更长的组合链中移走；若继续向 1.0 ns 推进，下一步需要拆完整 EX0/EX1/EX2 operand/ALU/result pipeline，或对 ALU/forwarding mux 做更强的结构化切分。

#### 检查脚本

P3 1.5 ns 使用以下命令通过 artifact 检查：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p3_redirect_eval_1p5ns_ultra \
  --output-dir syn/reports/p3_redirect_eval_1p5ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 1.5 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.5
```

结果：

```text
timing artifact checks passed
```

`report_constraint -all_violators` 结果：

```text
This design has no violated constraints.
```

### 10.5 2026-06-15 P2/P3 补全：EX0/EX1 数据通路、MDU hold operand、regfile 半周期修复

#### RED 验证

用上一轮 P3 1.5 ns 归档报告作为 RED，要求 critical path 小于 1.0 ns：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p3_redirect_eval_1p5ns_ultra \
  --output-dir syn/reports/p3_redirect_eval_1p5ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 1.5 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.0
```

结果：

```text
critical path too long: expected <= 1.000 ns, found 1.320 ns
```

P3 1.5 ns 最差路径仍为 EX 数据通路：

```text
u_ex_mem/rd_addr_out_reg[3]
  -> forwarding compare/mux
  -> ALU operand/result
  -> u_ex_mem/alu_out_out_reg[29]
```

#### 改动摘要

- `src/pipeline_cpu_core.v` 与 `src/pipeline_cpu.v` 增加完整 EX0/EX1 数据通路切分：
  - EX0 保留 forwarding compare/mux 和 operand select。
  - EX1 新增 `ex1_*` 寄存器，寄存 PC、imm、operand、store data、rd、ALU op、branch/jump/predict 元数据。
  - ALU、branch compare、MDU、EX/MEM 输入改为使用 EX1 寄存后的数据。
- branch compare 单独寄存 `ex1_branch_data1`，避免 B-Type 因 `pce=1` 把 PC 当作 rs1 参与比较。
- branch 预测方向判断改为有效预测：

```verilog
assign ex_branch_predicted_taken = ex1_predict_taken && ex1_btb_hit;
```

  这修复了 BHT taken 但 BTB miss 时实际 PC 没有预测跳转、却被旧逻辑当作 predicted taken 的问题。
- JAL/JALR redirect 初次执行时只 flush 更年轻流水级，不再 flush 当前 JAL/JALR 的 EX/MEM 写回，保证 link register 写回。
- `src/hazard_unit.v` 扩展 EX0/EX1 latency 判断：
  - `id_ex_we && id_uses_id_ex_rd`：相邻 ALU producer 停 1 拍。
  - `ex1_mem_read && id_uses_ex1_rd`：load producer 继续多停 1 拍。
- `src/forward_unit.v` 保持 EX/MEM 与 MEM/WB 两级前递，但明确不新增 EX1 组合旁路回 EX0；最近 producer 由 hazard bubble 暴露到 EX/MEM 后再前递，以保护 EX0/EX1 切分后的时序边界。
- 移除 `hazard_unit` 旧的 `id_ex_mem_read` 端口连接，load-use 判断统一由 `id_ex_we` 和 `ex1_mem_read` latency 规则覆盖，减少综合 lint 噪声。
- MDU busy 期间为等待进入 EX1 的 ID/EX 指令增加 operand hold：
  - `ex_operand_hold_valid_q`
  - `ex_operand_hold_data1_q`
  - `ex_operand_hold_data2_q`

  该逻辑在 MDU stall 期间捕获短暂出现的 MEM/WB forwarding 数据，避免连续 MDU 或 MDU 后 consumer 在释放时读到 ID/EX 中的旧 rs 值。
- `src/regfile.v` 从下降沿写改为上升沿写，并在组合读口加入 WB bypass：

```verilog
else if (we && (wd == rs1)) begin
    rs1_value = wdata;
end
```

  这样保持原有同周期 write-first 语义，同时消除 `MEM/WB -> regfile negedge write` 的半周期 setup 瓶颈。
- EX1 redirect 分支只清控制有效性，并让数据寄存器装载无害值，避免 redirect 控制条件扇到 32-bit EX1 数据寄存器 D 端。
- `pipeline_cpu_core` 的正式综合接口继续使用外部 `instr_in` 与 `dmem_*`，`src/imem.v`/`pipeline_imem.v` 只留在仿真或 wrapper 层；当前 `instr_in` 按组合输入约束验证，若后续接同步 SRAM，需要新增 IF2 capture 或 SRAM wrapper。
- `sim/pipeline_test_instr/btb_bht/tb_btb_bht.v` 将等待窗口从 200 cycles 扩到 350 cycles。EX0/EX1 切分后相邻 ALU producer 会多停 1 拍，嵌套循环测试在 200 cycles 时尚未跑完；期望结果未改变。

#### 功能验证

当前 RTL 全量 VCS 回归使用以下目标：

```sh
make -C sim/pipeline_test_instr \
  r_type i_type load_store branch jump lui_auipc hazard_forward \
  btb_bht jump_predict m_type baseline_a all_tests
```

关键结果：

| 测试 | 结果 |
| --- | --- |
| `m_type` | 28 PASS / 0 FAIL |
| `baseline_a` | PASS，Errors: 0，load-use stall count = 13 |
| `branch` | BEQ/BNE/BLT/BGE/BLTU/BGEU PASS |
| `jump_predict` | PASS，JAL/JALR BTB miss 和 target mispredict 均检测到 |
| `btb_bht` | PASS，350 cycles 后外层 x1=10、内层 x4=5 |
| `hazard_forward` | PASS |
| `load_store` | PASS，load-use stall 检测到 3 次 |
| `all_tests` | PASS |

#### 综合验证

1.2 ns `compile_ultra` clean：

```sh
make -C syn ultra CLK_PERIOD_NS=1.2
```

归档目录：

```text
syn/reports/p2p3_final_1p2ns_ultra/
```

QoR：

| 项目 | 值 |
| --- | ---: |
| Clock period | 1.2 ns |
| Clock transition | 0.06 ns |
| Clock uncertainty | 0.12 ns |
| Input/output delay | 0.12 ns |
| Levels of Logic | 19 |
| Critical Path Length | 1.05 ns |
| WNS / TNS | 0.00 / 0.00 |
| Violating Paths | 0 |
| Hold Violations | 0 |
| Max transition/cap/fanout violations | 0 |
| Cell Area | 33886.804480 |

1.2 ns 最差 setup path：

```text
Startpoint: ex1_alu_data1_reg[8]
Endpoint:   u_mul_div/multiplicand_reg[30]
Path:       EX1 operand -> MDU operand absolute-value/prep logic -> multiplicand register
Arrival:    1.05 ns
Required:   1.05 ns
Slack:      0.00 ns
```

检查脚本：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p2p3_final_1p2ns_ultra \
  --output-dir syn/reports/p2p3_final_1p2ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 1.2 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.05
```

结果：

```text
timing artifact checks passed
```

1.0 ns `compile_ultra` 当前未收敛：

```text
归档目录: syn/reports/p2p3_final_1p0ns_ultra/
Critical Path Length: 1.04 ns
WNS / TNS: -0.16 ns / -152.01 ns
Violating Paths: 1445
```

1.0 ns 最差 setup path：

```text
Startpoint: u_if_id/instr_out_reg[3]
Endpoint:   u_id_ex/rs1_val_out_reg[3]
Path:       IF/ID instr -> decoder rs1 -> regfile read mux -> ID/EX rs1 value
Arrival:    1.04 ns
Required:   0.87 ns
Slack:     -0.16 ns
```

1.0 ns artifact 检查命令：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p2p3_final_1p0ns_ultra \
  --output-dir syn/reports/p2p3_final_1p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 1.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.0
```

结果：

```text
critical path too long: expected <= 1.000 ns, found 1.040 ns
```

#### 当前结论

- P2/P3 本轮已把 EX forwarding/ALU/EX-MEM 关键路径从 1.32 ns 推到 1.2 ns clean。
- regfile 下降沿写半周期 setup 已消除。
- 1GHz 目标的下一条真实瓶颈已经转移到 ID 阶段：`IF/ID -> decoder -> regfile read -> ID/EX`。
- 下一轮如果继续冲 1.0 ns，需要做 ID0/ID1 切分：先寄存 decoded rs/rd/control，再在下一拍做 regfile read 和 ID/EX 写入；或重构 regfile 为更浅的读 mux/分 bank 结构。

### 10.6 2026-06-15 P4：ID0/ID1、ALU one-hot、Predictor/IF 高频闭环

#### RED 验证

P4 从上一轮 1.0 ns 未收敛点开始。`p2p3_final_1p0ns_ultra` 的最差路径为：

```text
Startpoint: u_if_id/instr_out_reg[3]
Endpoint:   u_id_ex/rs1_val_out_reg[3]
Path:       IF/ID instr -> decoder rs1 -> regfile read mux -> ID/EX rs1 value
Arrival:    1.04 ns
Required:   0.87 ns
Slack:     -0.16 ns
```

对应 artifact 检查：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p2p3_final_1p0ns_ultra \
  --output-dir syn/reports/p2p3_final_1p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 1.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.0
```

结果：

```text
critical path too long: expected <= 1.000 ns, found 1.040 ns
```

#### 改动摘要

- 新增 `src/id_decode_reg.v`，在 decoder 与 regfile read 之间插入 ID0/ID1 寄存边界：
  - ID0：`IF/ID instr -> decoder -> rs/rd/control/imm/predict metadata`。
  - ID1：使用寄存后的 `id1_rs1_addr/id1_rs2_addr` 读 regfile，再写入 `id_ex_reg`。
  - flush 时插入 NOP，stall 时保持寄存输出。
- `src/pipeline_cpu_core.v` 与 `src/pipeline_cpu.v` 均接入 `id_decode_reg`：
  - regfile read 地址和读使能改为 `id1_*`。
  - `id_ex_reg` 输入改为 `id1_*` 控制、立即数、预测元数据和 regfile raw data。
  - `hazard_unit` consumer 输入改为 ID1 位置。
- 更新 MDU stall/flush 交互：
  - `id_decode_stall = stall_if_id || ex_mdu_stall_raw`
  - `if_id_reg.stall = stall_if_id || ex_mdu_stall_raw`
  - `ex_mdu_stall_raw = ex_is_m_type && !ex_mdu_done`
  - `ex_mdu_start = ex_mdu_stall_raw && !redirect_block_ex && !ex_mdu_busy`
  - `ex_mdu_stall = ex_mdu_stall_raw && !redirect_block_ex`
  - `ex_is_m_type` 增加 `ex1_we` 限定，避免 invalid bubble 携带旧 `aluop` 误启动 MDU。
- EX1 数据寄存与控制寄存分开处理：
  - 数据寄存器只受 reset 和 `!ex_mdu_stall` 控制，不再由 redirect 组合条件清空。
  - 控制有效位在 `redirect_flush` 时清空，保证错误路径不写回、不写存储。
  - front-end flush 延后到真实 `redirect_flush`，避免 `ex_control_redirect_early` 重新扇入 ID/EX D 端。
- 新增 `src/alu_fast.v`，将 ALU opcode 译码提前到 EX1 寄存边界：
  - EX1 增加 `ex1_alu_add/sub/sll/slt/sltu/xor/srl/sra/or/and` one-hot 寄存器。
  - `alu_fast` 只接收 one-hot select 和两个 operand，移除 `ex1_aluop -> ALU result` 的组合译码路径。
  - MDU 仍使用 `ex1_aluop`，不改变 RV32M 控制语义。
- predictor update 打一拍：
  - 新增 `predictor_update_valid_q/is_jump_q/taken_q/pc_q/target_q`。
  - redirect target 仍在当前 EX2 周期用于真实 PC redirect。
  - BTB/BHT update 延后一拍，切断 `redirect_eval_base_q + imm -> BTB target_array` 写口路径。
- IF prediction 打一拍，切断 PC 自反馈：
  - 新增 `if_predicted_valid_q`、`if_predicted_pc_q`。
  - PC 使用寄存后的 predicted target，不再由 `curr_pc -> BTB/BHT -> PC D` 直接闭合。
  - 新增 `if_prediction_flush`，当 delayed prediction redirect 被应用时，仅 flush 顺序取入的年轻 IF/ID 指令。
  - 原始 `if_predict_taken/target/btb_hit` 仍随当前 IF 指令进入 IF/ID，保证 EX2 mispredict 比较使用同一条指令的预测元数据。
- `syn/filelist.f`、`sim/pipeline/filelist.f` 与所有 `sim/pipeline_test_instr/*/filelist.f` 增加 `id_decode_reg.v` 和 `alu_fast.v`。

#### 1.0 ns 路径迭代记录

| 归档目录 | Slack | Critical Path Length | 最差路径 | 处理 |
| --- | ---: | ---: | --- | --- |
| `p4_idsplit_1p0ns_ultra` | -0.13 ns | 1.00 ns | `ex1_branch_data1_reg -> ex1_alu_data1_reg` | EX1 数据/控制寄存拆分 |
| `p4_idsplit_ex1data_1p0ns_ultra` | -0.14 ns | 1.01 ns | `ex1_pce_reg -> u_id_ex/imm_out_reg` | redirect front flush 延后，MDU raw stall 分离 |
| `p4_idsplit_regflush_1p0ns_ultra` | -0.04 ns | 0.91 ns | `ex1_aluop_reg -> u_ex_mem/alu_out_out_reg` | ALU one-hot 预译码 |
| `p4_alufast_1p0ns_ultra` | -0.04 ns | 0.91 ns | `redirect_eval_base_q_reg -> u_btb/target_array_reg` | predictor update 寄存 |
| `p4_predictor_reg_1p0ns_ultra` | -0.04 ns | 0.91 ns | `u_pc/curr_pc_reg -> u_btb -> u_pc/curr_pc_reg` | IF delayed prediction |
| `p4_ifpred_reg_1p0ns_ultra` | 0.00 ns | 0.87 ns | `ex1_alu_data1_reg -> u_mul_div/multiplicand_reg` | 1.0 ns clean |

说明：中间几轮的 CSV 摘要脚本会把 slack 符号显示得不够直观，本节以原始 `pipeline_cpu_core.qor.rpt` 和 `timing.setup.worst.rpt` 的 slack 为准。

#### 功能验证

最终完整 VCS 回归命令：

```sh
make -C sim/pipeline_test_instr \
  r_type i_type load_store branch jump lui_auipc hazard_forward \
  btb_bht jump_predict m_type baseline_a all_tests
```

日志检查：

```sh
rg -n "\[FAIL\]|Errors: [1-9]|[1-9][0-9]* FAIL|FAIL," \
  /tmp/p4_final_full_regression.log sim/pipeline_test_instr/*/sim.log
```

结果：无匹配项。

关键结果：

| 测试 | 结果 |
| --- | --- |
| `r_type` | ADD/SUB/SHIFT/SLT/LOGIC PASS |
| `i_type` | ADDI/SLLI/SLTI/SLTIU/XORI/SRLI/SRAI/ORI/ANDI PASS |
| `lui_auipc` | LUI/AUIPC PASS |
| `load_store` | PASS，load-use stall 检测到 3 次 |
| `hazard_forward` | PASS |
| `branch` | BEQ/BNE/BLT/BGE/BLTU/BGEU PASS |
| `jump_predict` | PASS，总 mispredict 4；JAL/JALR BTB miss 4；JALR target mispredict 1 |
| `btb_bht` | PASS，外层 x1=10，内层 x4=5 |
| `m_type` | 28 PASS / 0 FAIL |
| `baseline_a` | PASS，Errors: 0，load-use stall count = 14 |
| `all_tests` | PASS，mispredict = 4 |

IF delayed prediction 会让 taken prediction 额外产生前端 flush 气泡，因此部分性能计数相对早期 P3 变化；寄存器结果、store flush、JAL/JALR link 和目标行为均保持正确。

#### 综合验证

最终 1.0 ns 综合命令：

```sh
make -C syn ultra CLK_PERIOD_NS=1.0
```

归档目录：

```text
syn/reports/p4_ifpred_reg_1p0ns_ultra/
```

1.0 ns 约束：

| 项目 | 值 |
| --- | ---: |
| Clock period | 1.0 ns |
| Clock transition | 0.05 ns |
| Clock uncertainty | 0.10 ns |
| Input/output delay | 0.10 ns |

QoR：

| 项目 | 值 |
| --- | ---: |
| Critical Path Length | 0.87 ns |
| Critical Path Slack | 0.00 ns |
| TNS | 0.00 |
| Violating Paths | 0 |
| Levels of Logic | 15 |
| Cell Area | 35615.272551 |

最差 setup path：

```text
Startpoint: ex1_alu_data1_reg[10]
Endpoint:   u_mul_div/multiplicand_reg[30]
Path:       EX1 operand -> MDU operand prep -> multiplicand register
Arrival:    0.87 ns
Required:   0.87 ns
Slack:      MET 0.00 ns
```

artifact 检查命令：

```sh
python3 scripts/check_timing_reports.py \
  --report-dir syn/reports/p4_ifpred_reg_1p0ns_ultra \
  --output-dir syn/reports/p4_ifpred_reg_1p0ns_ultra/outputs \
  --design pipeline_cpu_core \
  --period 1.0 \
  --require-proportional-constraints \
  --require-setup-path \
  --reject-mdu-final-path \
  --max-critical-path 1.0
```

结果：

```text
timing artifact checks passed
```

`report_constraint -all_violators` 结果：

```text
This design has no violated constraints.
```

#### 当前结论

- P4 已在当前 Nangate45 / wire-load / ideal-clock / `compile_ultra` 环境下达到 1.0 ns clean。
- 1GHz clean 是前端 RTL 高频潜力证明；尚不等同于物理实现 signoff。
- 当前剩余边界最紧路径是 EX1 operand 到 MDU operand prep，slack 为 0.00 ns，没有余量。
- IF delayed prediction 用一拍前端气泡换取 PC/BTB 组合自反馈断开，后续若要恢复 IPC，需要更完整的 IF0/IF1/IF2 fetch queue 或 next-line predictor。
- 下一步优先做 GLS smoke、修复 summary 脚本 slack 符号、再评估同步 SRAM/物理综合后的真实余量。

### 10.7 后续记录模板

后续每完成一轮优化，在此追加记录：

```text
日期：
分支/commit：
改动摘要：
目标周期：
综合命令：
功能回归：
QoR:
  WNS:
  TNS:
  Critical Path:
  Levels:
  Cell Area:
  Cell Count:
是否 clean：
下一步：
```

## 11. 当前下一步

P0 自动化、P1 MDU 高频化、P2 EX0/EX1 数据通路切分、P3 redirect eval/monitor 隔离、P4 ID0/ID1 与 IF/predictor 高频闭环已完成。当前 `pipeline_cpu_core` 在 1.0 ns `compile_ultra` 下 clean，约束报告无 violation。

后续建议优先推进：

1. 跑 1.0 ns mapped netlist GLS smoke，确认 SDF/门级功能无回归。
2. 修复 `scripts/summarize_dc_reports.py` 对负 slack 符号的解析问题，避免后续记录误读。
3. 为同步 instruction SRAM 增加完整 IF2 capture 或 fetch wrapper，明确预测气泡和取指返回时序。
4. 将 data memory 接口升级为 request/response 或显式 latency，更新 load-use hazard。
5. 若进入物理实现，加入 clock tree、placement wire delay、SRAM macro 和 reset/stall/flush 高扇出评估；当前 0.00 ns slack 没有物理余量。
6. 若希望在保持 1GHz 的同时改善 IPC，考虑 IF fetch queue、next-line predictor 或更早的 branch target 预计算，减少 IF delayed prediction 的前端气泡。

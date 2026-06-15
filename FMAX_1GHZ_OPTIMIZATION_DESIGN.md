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

- [ ] 新增 EX0/EX1/EX2 流水寄存器，或重构现有 `id_ex_reg`、`ex_mem_reg`。
- [ ] EX0 完成 operand select 和 forwarding mux，并寄存 operand。
- [ ] EX1 完成 ALU、branch compare、target add。
- [ ] EX2 完成 redirect 判断、flush 生成、结果提交到 MEM。
- [ ] 更新 branch/jump flush 逻辑和预测元数据传递。
- [ ] 更新 forwarding unit，区分 EX2/MEM/WB 来源。
- [ ] 更新 hazard unit，支持新流水级 latency。
- [ ] 跑控制冒险测试：`btb_bht`、`jump_predict`、`all_tests`。
- [ ] 跑数据冒险测试：`baseline_a`、`hazard_forward`、`load_store`。
- [ ] 跑 `make -C syn synth CLK_PERIOD_NS=2.0`。

### 5.4 P3: IF/ID/MEM 边界优化

- [ ] 将 IF 拆为 PC select、prediction read、instruction capture。
- [ ] 明确 `instr_in` 的时序假设：组合输入、同步 SRAM wrapper、或 testbench 驱动。
- [ ] 保留仿真用 `instr_mem`，但正式 PPA 不把 `src/imem.v` 的 `$readmemh` memory 纳入 core。
- [ ] 将 data memory 接口升级为 request/response 或显式 latency 接口。
- [ ] 更新 load-use hazard，支持 1-cycle/2-cycle load response。
- [ ] 跑 load/store、branch、jump、all_tests。
- [ ] 跑 1.5 ns sweep。

### 5.5 P4: 1GHz 综合闭环

- [ ] 将 `syn/run_dc.tcl` 增加 high-performance mode。
- [ ] 增加 `COMPILE_MODE=ultra` 的归档目录和报告后缀。
- [ ] 尝试 retiming，并记录是否改变可调试层级。
- [ ] 对高扇出 reset/stall/flush 网络做 buffer 或局部复制。
- [ ] 对关键模块尝试 ungroup/boundary optimization。
- [ ] 设置更真实的 clock uncertainty 和 input/output delay 后重新评估。
- [ ] 跑 1.2 ns、1.1 ns、1.0 ns sweep。
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

### 10.3 后续记录模板

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

P0 自动化和 P1 MDU 高频化已完成，当前 3.0 ns `compile_ultra` 已 clean。下一步进入 P2：

1. 拆 EX/redirect 路径，把 forwarding mux、ALU/branch target、flush/redirect 判断分到更短的流水边界。
2. 优先分析当前 P1 ultra 最差路径 `u_mem_wb/rd_addr_out_reg[1] -> u_id_ex/pc_next_out_reg[1]`。
3. 目标先尝试 2.4 ns/2.0 ns sweep；若 EX 仍集中违例，再增加 EX0/EX1/EX2 寄存边界。
4. 保留 P1 MDU 接口不变，避免 P2 同时引入 MDU 协议风险。

# 从 190MHz 到 1GHz 的频率优化复盘说明

本文用于说明当前 RISC-V 流水线 CPU 在 45nm 工艺库逻辑综合环境下，如何从约 190MHz 的初始工作频率逐步优化到 1GHz。它是对 `FMAX_1GHZ_OPTIMIZATION_DESIGN.md` 的复盘型补充：设计文档记录优化计划、实现清单和验证状态，本文重点解释每一步优化为什么有效、关键路径如何迁移，以及最终 1GHz 结论的适用边界。

## 1. 结论摘要

当前工程已经在 DC 逻辑综合语境下完成 1.0ns 时钟周期的 clean setup 收敛：

| 项目 | 190MHz 基线 | 1GHz 最终版本 |
| --- | ---: | ---: |
| 目标周期 | 5.2ns | 1.0ns |
| 频率 | 192.3MHz 保守口径，报告折算约 193.8MHz | 1000MHz |
| Critical Path Length | 5.16ns | 0.87ns |
| WNS | 0.00ns | 0.00ns |
| TNS | 0.00ns | 0.00ns |
| Violating Paths | 0 | 0 |
| 关键路径逻辑级数 | 125 级 | 15 级 |
| 主要瓶颈 | 乘除法单元长组合链 | EX1 分支判断到 EX2 redirect 评估寄存器 |
| 代表报告目录 | `syn/reports/ppa_opt_5p2ns` | `syn/reports/p5_final_1p0ns_ultra` |

频率提升比例：

```text
5.2ns -> 1.0ns
192.3MHz -> 1000MHz
提升倍数 = 1000 / 192.3 ~= 5.20x
```

关键路径长度缩短比例：

```text
5.16ns -> 0.87ns
缩短比例 = (5.16 - 0.87) / 5.16 ~= 83.1%
```

因此，在当前使用的综合脚本、Nangate45 工艺库、DC 逻辑综合和现有约束模型下，可以认为设计已经达到 1GHz 的 setup 时序目标。需要注意的是，这不是完整物理实现后的 signoff 结论，还没有包含布局布线后真实线延迟、时钟树、拥塞、OCV/AOCV、IR drop、温度电压角等物理签核因素。

## 2. 约束和验证口径

本轮优化使用的核心约束口径如下：

| 约束项 | 公式 | 1.0ns 目标下取值 |
| --- | --- | ---: |
| 时钟周期 | `Tclk` | 1.0ns |
| 时钟频率 | `1 / Tclk` | 1GHz |
| clock transition | `5% * Tclk` | 0.05ns |
| clock uncertainty | `10% * Tclk` | 0.10ns |
| input delay | `10% * Tclk` | 0.10ns |
| output delay | `10% * Tclk` | 0.10ns |

验证分为三类：

1. RTL 功能仿真：用于确认流水线插拍、flush、stall、旁路和 MDU 状态机调整没有破坏指令行为。
2. DC 综合时序：用于确认目标周期下 setup WNS/TNS/violating path 均 clean，并记录最差路径。
3. SDF timing GLS：用于确认 1.0ns netlist 在后仿语境下没有暴露基本时序和功能问题。

最终 1GHz 版本的主要证据：

| 类型 | 结果 |
| --- | --- |
| RTL `all_tests` | PASS |
| RTL `jump_predict` | PASS |
| RTL `m_type` | PASS |
| DC 1.0ns | `Critical Path Length = 0.87ns`，`WNS = 0.00ns`，`TNS = 0.00ns`，`Violating Paths = 0` |
| DC violated constraints | `This design has no violated constraints.` |
| 1.0ns SDF GLS | `[PASS] GLS checks completed with 0 errors` |

## 3. 初始 190MHz 瓶颈分析

初始可收敛频率约为 190MHz，本质原因不是某一个门太慢，而是多个功能块在同一拍内串成了过长的组合路径。最典型的基线路径位于乘除法单元：

```text
u_mul_div/multiplicand_reg
  -> 64-bit add_70
  -> 64-bit add_71 / inc / 符号修正
  -> result mux / control
  -> u_mul_div/res_reg[31]
```

该路径的特征是：

| 特征 | 说明 |
| --- | --- |
| 位宽大 | 乘法中间结果和符号修正涉及 64-bit 数据通路 |
| 进位链长 | 最终加法、加一和取反修正容易形成长 carry propagation |
| 控制和数据混合 | DONE、符号、结果选择等控制信号和数据路径耦合 |
| 逻辑级数高 | 基线最差路径约 125 级逻辑 |
| 单拍承担过多工作 | 部分多周期算法的末端收敛仍压在一个周期内 |

所以，把 5.2ns 直接约束到 1.0ns 不可能只靠 DC 更努力综合来解决。5.2ns 到 1.0ns 等价于要求逻辑深度压缩到原来的约 19.2%，必须改变微结构，把原本一拍完成的长组合链切成多个短阶段。

## 4. 总体优化方法

本轮优化采用的是频率优先策略，暂时不考虑面积代价。核心方法可以概括为五点：

1. 每个阶段只盯住当前最差路径。
   一个阶段 clean 后再进入更紧周期，观察最差路径是否迁移，避免盲目大改。

2. 对真实关键路径插入寄存器边界。
   优先处理 MDU、redirect、ALU、ID decode、predictor 等跨级长链，而不是做局部语法级微调。

3. 把数据路径和控制路径分开收敛。
   数据寄存器、valid 位、flush 位、redirect 位、stall 位分别处理，保证时序被切短后行为仍可解释。

4. 允许增加流水线延迟和气泡。
   本目标是 Fmax，不优先优化 IPC、面积和功耗。因此分支 redirect 可以延后一拍，IF prediction 可以注册化，MDU 可以增加内部状态。

5. 每轮都用报告反推下一步。
   DC 的最差路径从 MDU 迁移到 redirect，再迁移到 ALU、ID、predictor，说明优化没有停在局部，而是在系统性地把长链逐步打断。

## 5. 阶段性优化轨迹

### 5.1 P0：建立可复现基线

P0 的重点不是改 RTL，而是确认 190MHz 左右的初始状态可以被复现，并把约束、报告和统计流程固定下来。

| 项目 | 结果 |
| --- | --- |
| 目标周期 | 5.2ns |
| 频率 | 约 192.3MHz |
| 关键路径 | MDU 乘除法结果路径 |
| Critical Path Length | 5.16ns |
| 逻辑级数 | 125 级 |
| TNS | 0.00ns |
| Violating Paths | 0 |

P0 暴露的问题是：设计在 5.2ns 下已经接近边界，最差路径几乎吃满整个周期。如果目标是 1.0ns，那么必须先处理 MDU 内部的大位宽长组合链。

### 5.2 P1：MDU 多周期化和 carry 链拆分

P1 的目标是把最明显的 64-bit 长组合路径切掉，让频率先从 190MHz 级别提升到 333MHz 级别。

主要实现思路：

| 优化点 | 作用 |
| --- | --- |
| 乘法迭代改为 carry-save 累加 | 避免每个迭代周期都走完整 carry propagate 加法 |
| 最终 64-bit 加法拆成 4 个 16-bit 阶段 | 把长进位链拆成短进位链 |
| 符号修正拆分为独立状态 | 避免取反、加一和结果选择塞进同一拍 |
| 除法结果符号修正拆成独立阶段 | 降低 DONE 前一拍的组合复杂度 |
| `res` 只在 DONE 后更新 | 避免未完成状态的宽 mux 参与主关键路径 |

P1 后的结果：

| 项目 | 结果 |
| --- | --- |
| 目标周期 | 3.0ns |
| 频率 | 333.3MHz |
| Critical Path Length | 2.66ns |
| TNS | 0.00ns |
| Violating Paths | 0 |
| 新最差路径 | WB/forwarding 到 ID/EX 相关路径 |

P1 的意义在于把原先 125 级 MDU 组合路径从系统主瓶颈中移走。此时最差路径迁移到流水线控制和旁路网络，说明优化方向正确：原先最大的结构性长链已经不再主导 Fmax。

### 5.3 P2：redirect 路径寄存器化

P2 针对的是分支和跳转 redirect 路径。原设计中，EX 阶段产生的 redirect 决策会影响 PC、IF/ID flush、ID/EX flush 等多个下游控制点，形成跨级组合长链。

主要实现思路：

| 优化点 | 作用 |
| --- | --- |
| 增加 `redirect_valid_q` | 将 redirect 有效信号注册化 |
| 增加 `redirect_pc_q` | 将 redirect 目标地址注册化 |
| flush 控制延后一拍发出 | 切断 EX 结果到 IF/ID 和 ID/EX 的同拍长链 |
| EX/MEM wrong-path kill | 确保 redirect 延后一拍后错误路径不会提交 |
| MDU start/stall 与 redirect_flush 联动 | 避免错误路径启动长延迟运算 |
| 调整 PC stall 优先级 | 保证 redirect 与 load-use/MDU stall 同时出现时行为确定 |

P2 后的结果：

| 项目 | 结果 |
| --- | --- |
| 目标周期 | 2.0ns |
| 频率 | 500MHz |
| Critical Path Length | 1.78ns |
| TNS | 0.00ns |
| Violating Paths | 0 |
| 新最差路径 | EX operand / JALR target 到 redirect PC 寄存器 |

P2 的代价是分支 redirect 延迟增加，但收益是把最危险的跨级控制组合链注册化。对于频率优先目标，这是非常划算的交换。

### 5.4 P3：EX redirect eval 再切分

P3 继续处理 P2 后暴露出来的 redirect 子路径。P2 已经把 redirect 输出寄存器化，但 EX 内部仍然存在从操作数、立即数、分支比较、目标地址计算到 redirect 判断的一拍组合压力。

主要实现思路：

| 优化点 | 作用 |
| --- | --- |
| 增加 EX/EX2 redirect eval 寄存器 | 把分支判断和 redirect 评估拆成两个阶段 |
| EX2 计算 branch/JAL/JALR target | 减少 EX1 当拍同时承担 ALU 和 redirect 的压力 |
| predictor update 移到 EX2 | 避免预测器写回控制参与 EX1 最差路径 |
| `monitor_alu_out` 注册化 | 避免 debug/monitor 信号拉长主数据路径 |
| 细化 `redirect_block_ex` | 防止新增流水阶段后错误路径穿透 |

P3 后的结果：

| 项目 | 结果 |
| --- | --- |
| 目标周期 | 1.5ns |
| 频率 | 666.7MHz |
| Critical Path Length | 1.32ns |
| TNS | 0.00ns |
| Violating Paths | 0 |
| 新最差路径 | EX/MEM forwarding 到 ALU 结果路径 |

P3 的关键意义是把 redirect 逻辑从一个宽而急的组合决策，变成带 valid 的两级控制流。此后系统最差路径开始迁移到常规执行数据通路，说明控制长链继续被削弱。

### 5.5 P2/P3 补全：EX0/EX1 数据路径切分

在 1.5ns clean 后继续压到 1.2ns 时，最差路径主要来自 EX 数据路径和旁路路径。此时只优化 redirect 已经不够，需要把真正执行数据也切成更短阶段。

主要实现思路：

| 优化点 | 作用 |
| --- | --- |
| 增加 EX0/EX1 数据寄存器 | 把 ID/EX 到 ALU 的长组合链分成两拍 |
| EX1 保存操作数和元数据 | 让 ALU 输入、目的寄存器、控制位保持一致 |
| 扩展 hazard 规则 | 识别新增 EX1 阶段带来的数据相关 |
| MDU operand hold | 防止 MDU stall 时 EX1 操作数被错误覆盖 |
| regfile 改为 posedge write 并保留 WB bypass | 切短写回到读口的组合压力 |

阶段结果：

| 项目 | 结果 |
| --- | --- |
| 目标周期 | 1.2ns |
| 频率 | 833.3MHz |
| Critical Path Length | 1.05ns |
| TNS | 0.00ns |
| Violating Paths | 0 |

此时尝试 1.0ns 仍不 clean：

| 项目 | 1.0ns 尝试结果 |
| --- | ---: |
| Critical Path Length | 1.04ns |
| WNS | -0.16ns |
| TNS | -152.01ns |
| Violating Paths | 1445 |
| 代表最差路径 | `u_if_id/instr_out_reg[3] -> u_id_ex/rs1_val_out_reg[3]` |

这个结果说明新的主瓶颈已经迁移到 ID decode、寄存器读、立即数/控制生成、ID/EX 打拍这一段。要达到 1GHz，必须继续拆 ID 阶段。

### 5.6 P4：ID0/ID1、ALU one-hot 和 IF prediction 注册化

P4 是最终把 1.0ns 推 clean 的核心阶段。它处理的是 1.2ns 到 1.0ns 之间暴露出来的 ID、ALU 控制和 predictor 反馈路径。

主要实现思路：

| 优化点 | 作用 |
| --- | --- |
| 增加 `id_decode_reg` | 将指令译码结果、寄存器索引、立即数、控制信号先打一拍 |
| ID0/ID1 切分 | ID0 做译码，ID1 做读数、旁路选择和进入 EX |
| ALU 控制 one-hot 化 | 减少 ALU 内部大 case/mux 对时序的影响 |
| 增加 `alu_fast` 模块 | 让常用 ALU 操作以更浅逻辑实现 |
| predictor update 注册化 | 切断 redirect eval 到 BTB/BHT 写口的同拍路径 |
| IF delayed prediction | 将 BTB/BHT 预测结果打一拍后再驱动 PC 选择 |

P4 内部经历了多轮迭代，最差路径逐步迁移：

| 迭代 | 结果 | 代表最差路径 |
| --- | --- | --- |
| `p4_idsplit_1p0ns_ultra` | WNS -0.13ns | `ex1_branch_data1_reg -> ex1_alu_data1_reg` |
| `p4_idsplit_ex1data_1p0ns_ultra` | WNS -0.14ns | `ex1_pce_reg -> u_id_ex/imm_out_reg` |
| `p4_idsplit_regflush_1p0ns_ultra` | WNS -0.04ns | `ex1_aluop_reg -> u_ex_mem/alu_out_out_reg` |
| `p4_alufast_1p0ns_ultra` | WNS -0.04ns | `redirect_eval_base_q_reg -> u_btb/target_array_reg` |
| `p4_predictor_reg_1p0ns_ultra` | WNS -0.04ns | `u_pc/curr_pc_reg -> u_btb -> u_pc/curr_pc_reg` |
| `p4_ifpred_reg_1p0ns_ultra` | clean | final 1.0ns clean |

P4 的核心突破点是：不仅切 ID 数据路径，还把预测器读写和 PC 选择也从同拍反馈环里拆出来。1GHz 下任何“当前 PC 读 BTB，然后同拍决定下一 PC”的路径都会非常紧，IF delayed prediction 用一个额外周期换掉了这条组合反馈。

### 5.7 P5：1GHz signoff 硬化和 GLS 收口

P4 已经实现 1.0ns clean，但 P5 继续做了两类工作：一是把脚本和报告统计修正确保结论可靠，二是处理 GLS 和 0.95ns 探索中暴露出的边界问题。

主要实现思路：

| 优化点 | 作用 |
| --- | --- |
| 修正 DC summary 脚本 | 优先读取 `Critical Path Slack`、`TNS` 和 violating path，避免只看单个 WNS |
| GLS Makefile 增加失败门禁 | 对 `[FAIL]`、`[TIMEOUT]`、timing violation 做日志检查 |
| `tb_gls` 增加错误计数和明确 PASS/FAIL | 避免后仿沉默通过 |
| `id_ex_hold = ex_mdu_stall_raw` | 避免 MDU stall 下新增流水寄存器错误推进 |
| BTB target 读出 ungated | 缩短 BTB 目标地址组合路径，valid 仍由 hit 控制 |

P5 最终结果：

| 项目 | 结果 |
| --- | --- |
| 目标周期 | 1.0ns |
| Critical Path Length | 0.87ns |
| WNS | 0.00ns |
| TNS | 0.00ns |
| Violating Paths | 0 |
| 最差 setup 路径 | `ex1_is_branch_reg -> redirect_eval_branch_mispredict_q_reg` |
| SDF GLS | PASS |

P5 还尝试过 0.95ns：

| 项目 | 0.95ns 探索结果 |
| --- | ---: |
| Critical Path Length | 0.83ns |
| TNS | -0.49ns |
| Violating Paths | 319 |
| 结论 | 未达到 clean，不作为当前 Fmax 结论 |

这说明当前设计在 1.0ns 处已经收敛，但 0.95ns 仍有大量边界路径。也就是说，现阶段可以报告最高已验证 clean 频率为 1GHz，但不能报告 1.05GHz。

## 6. 关键路径迁移总结

整个优化过程的关键点不是某一次优化把所有问题都解决，而是每轮把当前最长路径切掉后，最差路径持续向新的真实瓶颈迁移：

| 阶段 | clean 周期 | 频率 | 主瓶颈 |
| --- | ---: | ---: | --- |
| P0 基线 | 5.2ns | 192.3MHz | MDU 64-bit 结果长组合链 |
| P1 | 3.0ns | 333.3MHz | forwarding / ID/EX 控制数据路径 |
| P2 | 2.0ns | 500MHz | redirect PC 和 flush 控制路径 |
| P3 | 1.5ns | 666.7MHz | EX/MEM forwarding 到 ALU |
| P2/P3 补全 | 1.2ns | 833.3MHz | ID decode / regfile / ID/EX |
| P4/P5 | 1.0ns | 1000MHz | EX1 branch 到 EX2 redirect eval |

从这个迁移轨迹可以看到：

1. 最初的 MDU 是最大瓶颈，但不是唯一瓶颈。
2. MDU 解决后，控制流 redirect 成为瓶颈。
3. redirect 解决后，执行数据路径和 ID 路径成为瓶颈。
4. ID 路径解决后，预测器和 PC 反馈路径成为瓶颈。
5. 最终 1GHz 下最差路径已经变成相对短的 EX1 到 EX2 控制判断路径。

这就是从 190MHz 推到 1GHz 的本质：不是把一条路径优化 5 倍，而是把多个原本串在一拍里的功能边界重新分配到多拍中。

## 7. 频率提升的主要来源

### 7.1 MDU 拆长链贡献最大

基线最差路径在 MDU，长度 5.16ns，逻辑级数 125 级。P1 后能在 3.0ns clean，说明大位宽加法和符号修正是第一大问题。这里的收益来自结构改变，而不是门级微调。

### 7.2 redirect 注册化降低控制路径扇出

redirect 原本同时影响 PC、flush、predictor、pipeline valid 等控制点。P2/P3 把 redirect 变成多级寄存器化控制流后，时序路径不再需要从 EX 当拍穿透到多个前级寄存器控制端。

### 7.3 ID/EX 切分解决 1.2ns 到 1.0ns 的核心压力

在 1.0ns 未 clean 的尝试里，最差路径已经是 IF/ID 指令寄存器到 ID/EX 操作数寄存器。这说明 decode、regfile、立即数、控制生成和旁路选择不能再同拍完成。P4 的 ID0/ID1 切分直接解决了这个问题。

### 7.4 predictor 和 PC 反馈必须打一拍

1GHz 下，`PC -> BTB/BHT -> next PC select -> PC` 这种路径很难保留为同拍组合反馈。IF delayed prediction 用预测延迟换频率，是 P4 clean 1.0ns 的关键。

### 7.5 one-hot ALU 控制降低数据通路解码成本

ALU 不只是数据加减慢，控制选择也会进入关键路径。将 ALU 控制转换为 one-hot，并使用 `alu_fast` 降低选择深度，有助于缩短 EX 阶段组合逻辑。

## 8. 功能和微结构代价

本次优化明确暂时不考虑面积，因此接受了以下代价：

| 代价 | 说明 |
| --- | --- |
| 寄存器数量增加 | ID、EX、redirect、predictor、MDU 内部都增加了状态 |
| 流水线级数增加 | 部分指令从 decode 到 execute 的延迟增加 |
| 分支恢复延迟增加 | redirect 和 prediction 都经过更多寄存器阶段 |
| hazard 逻辑更复杂 | 新增 EX1、redirect eval、MDU hold 后，stall/flush 优先级更复杂 |
| 面积和功耗上升 | 更多寄存器、mux、valid 位和控制逻辑会增加面积及动态功耗 |
| IPC 可能下降 | 分支、load-use、MDU 等场景可能引入更多气泡 |

这些代价符合本轮目标：优先把最高工作频率从 190MHz 推到 1GHz。后续如果需要综合 PPA 最优，需要重新平衡 Fmax、面积、功耗和 IPC。

## 9. 为什么可以认为当前达到 1GHz

可以报告 1GHz 的原因是：

1. 约束模型明确。
   1.0ns 下使用比例化 transition、uncertainty、input delay 和 output delay，并不是无约束裸跑。

2. DC 报告 clean。
   `p5_final_1p0ns_ultra` 中 setup TNS 为 0.00ns，violating paths 为 0，且 violated constraints 报告无违例。

3. 最差路径有明确记录。
   最终最差 setup 路径为 `ex1_is_branch_reg -> redirect_eval_branch_mispredict_q_reg`，关键路径长度 0.87ns。

4. RTL 功能测试通过。
   常规指令、跳转预测和 M 类型指令测试均通过，说明流水线切分没有破坏主要功能。

5. 1.0ns SDF GLS 通过。
   后仿日志明确给出 0 error PASS，且 Makefile 已经加入失败关键字检查。

不能报告超过 1GHz 的原因是：

1. 0.95ns 尝试仍有 TNS。
   `p5_holdsplit_btb_0p95ns_ultra` 仍有 `TNS = -0.49ns` 和 319 条 violating paths。

2. 当前没有完成物理实现 signoff。
   后端布局布线可能重新引入线延迟、拥塞和时钟不确定性问题。

3. 当前验证主要覆盖已有测试集。
   虽然关键回归通过，但更大规模随机指令、异常场景、CSR/中断场景仍可继续增强。

所以最准确的表述是：

```text
在当前 Nangate45 + DC 逻辑综合 + 现有比例约束 + 已运行 RTL/GLS 验证范围内，
该 CPU core 已经达到 1.0ns clean，也就是最高已验证 clean 工作频率为 1GHz。
```

## 10. 后续建议

如果继续追求更高频率或更可靠的 1GHz signoff，建议按以下方向推进：

| 方向 | 目标 |
| --- | --- |
| 物理实现 | 用布局布线后寄生参数验证 1GHz 是否仍 clean |
| SRAM/存储宏建模 | 将 imem/dmem 从理想模型切换到更真实的 macro 或 memory compiler 模型 |
| 多角多模式 | 增加 slow/fast、不同电压温度角和 hold 检查 |
| 0.95ns RED 路径分析 | 如果要冲击 1.05GHz，继续拆 P5 中 0.95ns 的 319 条 violators |
| IPC 评估 | 量化新增流水线阶段和分支延迟对性能的影响 |
| 面积功耗回收 | 在保持 1GHz 的前提下回收过度插拍和冗余控制 |

当前阶段的主要成果已经完成：从 5.2ns clean 的约 190MHz 基线，优化到 1.0ns clean 的 1GHz 版本，并保留了可复现报告、最差路径分析和 RTL/GLS 验证证据。

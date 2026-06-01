# Baseline(A) 实现与验证设计

## 范围

本轮只推进 `IMPLEMENTATION_CHECKLIST.md` 中与 baseline(A) 直接相关的项目：经典 5 级流水、forwarding、load-use 数据冒险、控制冒险、稳定仿真回归和综合基线现状核验。不实现 RV32M，不新增性能 counter，不做排序、矩阵、卷积等应用级验证。

## 推荐方案

采用“验证补强优先”方案：先补充能够证明 baseline(A) 正确性的边界测试，再根据失败结果做最小 RTL 修复，最后运行关键回归并同步清单文档。

该方案的优点是风险低、目标集中，能把现有 RTL 的 baseline 能力转化为可重复验证的证据。综合报告已有初版产物，本轮只核验并如实记录，不强行进入 PPA 优化。

## 测试结构

新增目录 `sim/pipeline_test_instr/baseline_a/`，保持现有测试目录风格：

- `tb_baseline_a.v`：集中检查 baseline(A) 边界行为，打印明确 `[PASS]` 和 `[FAIL]`。
- `baseline_a.hex`：测试程序机器码，使用现有 little-endian `.hex` 格式。
- `baseline_a.txt`：逐条记录指令意图、依赖关系和预期结果。
- `pipeline_imem.v`：加载 `baseline_a.hex`。
- `filelist.f`：列出 RTL 与 testbench 源文件。

更新 `sim/pipeline_test_instr/Makefile`：

- 增加 `baseline_a` 目标。
- 将 `baseline_a` 加入 `TESTS` 列表。
- 不改变现有 `all: all_tests` 默认行为，避免扩大默认回归范围。

## 验证内容

### Forwarding

覆盖以下场景：

- `EX/MEM -> EX`：连续依赖指令立即使用上一条 ALU 结果。
- `MEM/WB -> EX`：中间隔一条指令后使用写回阶段结果。
- 优先级：同一个源寄存器同时匹配 EX/MEM 和 MEM/WB 时，必须选择较新的 EX/MEM。
- `rd=x0`：前序指令写 x0 时，后续读取 x0 仍必须得到 0，不能触发有效前递。

### Load-use

覆盖以下场景：

- load 后接 ALU，插入 bubble 后结果正确。
- load 后接 branch，branch 比较值来自 load 结果而非旧值。
- load 后接 store，store 地址或 store 数据依赖 load 时写入结果正确。
- load 后接 JALR，跳转目标依赖 load 时先暂停再重定向。

### Control hazard

覆盖以下场景：

- branch/jump 重定向后，错误路径寄存器写入不能提交。
- branch/jump 重定向后，错误路径内存写入不能提交。
- load-use 与重定向交叠时，PC、IF/ID 和 ID/EX 不应产生重复提交或漏提交。

## RTL 修复策略

默认不重构流水线主体。只有新增测试或回归失败并定位到 RTL 缺陷时，才做最小修复：

- `src/forward_unit.v`：仅修 x0 过滤或 EX/MEM、MEM/WB 优先级。
- `src/hazard_unit.v`：仅修 load-use 读寄存器依赖判断。
- `src/pipeline_cpu.v` / `src/pipeline_cpu_fpga.v`：仅修 flush/stall 优先级或控制连接。
- `src/datamem.v`：仅在 store 数据路径暴露问题时修正 MEM 阶段写入相关逻辑。

## 验收标准

单项测试必须通过：

```sh
make -C sim/pipeline_test_instr baseline_a
```

关键回归必须通过：

```sh
make -C sim/pipeline_test_instr hazard_forward
make -C sim/pipeline_test_instr branch
make -C sim/pipeline_test_instr jump
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr jump_predict
make -C sim/pipeline_test_instr all_tests
```

综合侧执行现状核验：

- 读取已有 `syn/reports/pipeline_cpu_fpga.*.rpt`。
- 如本地 DC 环境可用，运行 `make -C syn check`。
- 若 `constraints.rpt` 仍存在 fanout 违例，不勾选“约束无违例”，只记录现状和后续动作。

## 文档同步

更新 `IMPLEMENTATION_CHECKLIST.md` 时只记录已实际验证通过的事实：

- A: 经典 5 级流水线：标注 RTL 结构和仿真观测证据。
- A: forwarding：记录 `baseline_a` 覆盖 x0、优先级和 MEM/WB fallback。
- A: 数据冒险和控制冒险：记录 load-branch、load-store、load-jump 和 flush 错误路径检查。
- A: 稳定运行：记录通过的仿真目标和日期。
- 综合基线：记录已有报告；若 fanout 或其他约束违例存在，保留未完成状态并写明原因。

## 非目标

- 不实现 RV32M。
- 不新增 cycle、retired instruction、mispredict 等性能 counter。
- 不实现关闭 BTB/BHT 的 baseline 参数。
- 不新增排序、矩阵、卷积应用级程序。
- 不追求最终 PPA 优化或修复全部综合 fanout 违例。

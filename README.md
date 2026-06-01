# RISC-V Pipeline CPU

这是一个 32 位 RISC-V 处理器实验项目，当前主线是经典五级流水线 CPU，并已加入基础冒险处理和动态分支预测。项目正在面向「合见工软企业命题-第九届中国研究生创'芯'大赛」整理综合、验证和实现清单。

赛题页：https://cpipc.acge.org.cn/cw/contestNews/detail/10/2c9080159d18295c019d19b4e714034b?page=1

## 当前状态

- 已实现经典 IF/ID/EX/MEM/WB 五级流水线。
- 已实现 RV32I 主要基础整数指令：R/I/load/store/branch/jump/U 型。
- 已实现 RAW forwarding、load-use stall、分支/跳转 flush。
- 已实现 BTB + BHT 动态分支/跳转预测。
- 已提供 VCS + Verdi 仿真测试目录。
- 已新增 Synopsys Design Compiler 综合入口，默认使用 Nangate45 `.db`。
- 待补齐 RV32M 乘除法扩展、应用级测试、覆盖率和性能量化。

详细赛题映射和后续任务见 [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)。

## 目录结构

```text
src/
  pipeline_cpu.v        # 仿真用五级流水 CPU 顶层，内部连接 pipeline_imem
  pipeline_cpu_fpga.v   # 综合/FPGA 友好 CPU 顶层，外部指令输入，带观测端口
  cpu.v                 # 单周期 CPU 顶层
  decoder.v             # RV32I 解码与控制信号
  alu.v                 # RV32I ALU
  branch.v              # 分支条件判断
  regfile.v             # 32 个通用寄存器，x0 恒为 0
  datamem.v             # 数据存储器，支持 byte/half/word load-store
  pc.v                  # PC 更新、stall、预测跳转和重定向
  if_id_reg.v           # IF/ID 流水寄存器
  id_ex_reg.v           # ID/EX 流水寄存器
  ex_mem_reg.v          # EX/MEM 流水寄存器
  mem_wb_reg.v          # MEM/WB 流水寄存器
  forward_unit.v        # 数据前递单元
  hazard_unit.v         # load-use 冒险检测
  btb.v                 # 256 项 Branch Target Buffer
  bht.v                 # 256 项 2-bit 饱和计数器预测表
  fpga_top.v            # UART + 指令 RAM + CPU 的 FPGA 顶层

sim/
  pipeline_test_instr/  # 流水线指令级测试集合
  pipeline/             # 流水线综合测试
  cpu/                  # 单周期 CPU 测试
  decoder/ regfile/ pc/ datamem/

scripts/
  riscv_encoder.py      # 指令编码辅助脚本
  example_generate_test.py
  fpga_uart.py

syn/
  filelist.f            # DC 综合源文件列表
  run_dc.tcl            # DC 综合脚本
  Makefile              # 综合入口
```

## 微架构概览

流水线为五级结构：

```text
IF -> ID -> EX -> MEM -> WB
```

IF 阶段查询 BTB/BHT 得到预测 PC；ID 阶段完成寄存器读和控制信号生成；EX 阶段完成 ALU、分支条件判断、跳转目标计算和误预测检测；MEM 阶段访问数据存储器；WB 阶段选择 load/ALU/LUI/PC+4 写回寄存器。

数据冒险通过 `forward_unit` 从 EX/MEM、MEM/WB 前递到 EX 输入。load-use 冒险由 `hazard_unit` 插入一个气泡。控制冒险使用 256 项 BTB 和 256 项 2-bit BHT 预测，误预测在 EX 阶段重定向 PC 并清空 IF/ID、ID/EX。

## 仿真

环境假设：

- Synopsys VCS
- Verdi
- 本仓库已带 `pthread_yield` 兼容库源码和 Makefile 链接参数

运行流水线全部指令测试：

```sh
make -C sim/pipeline_test_instr all
```

运行单类测试：

```sh
make -C sim/pipeline_test_instr r_type
make -C sim/pipeline_test_instr load_store
make -C sim/pipeline_test_instr hazard_forward
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr jump_predict
```

查看波形：

```sh
make -C sim/pipeline_test_instr view_all
```

清理仿真产物：

```sh
make -C sim/pipeline_test_instr clean
```

## 综合

本地 DC 环境位于：

```text
/home/synopsys/syn
```

默认综合使用：

- DC wrapper：`dc_shell`
- 工艺库：`/home/synopsys/syn/nangate45/db/nangate.db`
- 默认顶层：`pipeline_cpu_fpga`
- 默认时钟周期：`10.0 ns`

快速检查 RTL 是否能被 DC 读入、展开和链接：

```sh
make -C syn check
```

运行快速综合：

```sh
make -C syn synth
```

运行完整 `compile_ultra`，适合最终 PPA 报告：

```sh
make -C syn ultra
```

当前数据存储器、BTB 和 BHT 会按寄存器阵列映射，完整优化可能比较慢；做 RTL 可综合性自检时先用 `check`。

调整时钟周期：

```sh
make -C syn synth CLK_PERIOD_NS=8.0
```

调整顶层：

```sh
make -C syn synth TOP=pipeline_cpu_fpga
```

综合输出默认生成在：

```text
syn/reports/
  pipeline_cpu_fpga.check.rpt
  pipeline_cpu_fpga.area.rpt
  pipeline_cpu_fpga.timing.rpt
  pipeline_cpu_fpga.power.rpt
  pipeline_cpu_fpga.qor.rpt
  pipeline_cpu_fpga.constraints.rpt

syn/outputs/
  pipeline_cpu_fpga_elab.ddc       # check 模式
  pipeline_cpu_fpga_elab.v         # check 模式
  pipeline_cpu_fpga.ddc
  pipeline_cpu_fpga_mapped.v
  pipeline_cpu_fpga.sdc
  pipeline_cpu_fpga.sdf
```

清理综合产物：

```sh
make -C syn clean
```

## 赛题后续重点

1. 补齐 RV32M：实现全部乘、除、取余指令，并补独立测试。
2. 固化综合结果：检查 DC `check_design`、timing、area、power 和 QoR。
3. 做性能量化：增加 cycle、retired instruction、branch hit/mispredict 计数器，对比关闭/开启 BTB+BHT 的收益。
4. 补应用级程序：至少排序、矩阵运算、卷积三个完整程序。
5. 补覆盖率：收集 line、branch、condition、toggle 覆盖率，目标不低于 95%。
6. 若正式参赛，需在 UDA/UVS/UVSYN 平台复现并导出对话记录、仿真、综合、覆盖率和时序报告。

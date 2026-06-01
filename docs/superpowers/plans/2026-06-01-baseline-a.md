# Baseline(A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有 5 级流水线 CPU 补充 baseline(A) 边界验证、按失败结果做最小 RTL 修复，并同步 `IMPLEMENTATION_CHECKLIST.md` 的真实状态。

**Architecture:** 新增一个独立的 `baseline_a` 仿真目录，复用现有 `sim/pipeline_test_instr/*` 的 VCS/Verdi 结构。测试先覆盖 forwarding、load-use、control hazard 的关键边界；只有测试失败并定位到 RTL 缺陷时，才最小修改 `forward_unit`、`hazard_unit`、`pipeline_cpu` 或 `datamem`。

**Tech Stack:** Verilog RTL、VCS、FSDB/Verdi、GNU Make、RISC-V RV32I little-endian `.hex` 测试程序。

---

## 文件结构

创建：

- `sim/pipeline_test_instr/baseline_a/tb_baseline_a.v`：baseline(A) 自检 testbench，统一打印 `[PASS]`/`[FAIL]` 和错误计数。
- `sim/pipeline_test_instr/baseline_a/baseline_a.hex`：测试程序的 little-endian 机器码。
- `sim/pipeline_test_instr/baseline_a/baseline_a.txt`：逐条说明测试程序意图和预期结果。
- `sim/pipeline_test_instr/baseline_a/pipeline_imem.v`：加载 `baseline_a.hex` 的指令存储器。
- `sim/pipeline_test_instr/baseline_a/filelist.f`：VCS 源文件列表。

修改：

- `sim/pipeline_test_instr/Makefile`：增加 `baseline_a` 目标并加入 `TESTS`。
- `IMPLEMENTATION_CHECKLIST.md`：在验证完成后同步 baseline(A) 状态。

可能修改，仅当测试失败且定位到 RTL 缺陷时：

- `src/forward_unit.v`：forwarding 优先级或 `x0` 过滤。
- `src/hazard_unit.v`：load-use 依赖检测。
- `src/pipeline_cpu.v`：flush/stall 优先级或 store 数据前递路径。
- `src/pipeline_cpu_fpga.v`：若 `pipeline_cpu.v` 中的修复也影响综合顶层，保持一致。
- `src/datamem.v`：仅在内存读写语义暴露 baseline 阻塞问题时最小修复。

---

### Task 1: 新增 baseline_a 仿真骨架

**Files:**
- Create: `sim/pipeline_test_instr/baseline_a/filelist.f`
- Create: `sim/pipeline_test_instr/baseline_a/pipeline_imem.v`
- Create: `sim/pipeline_test_instr/baseline_a/baseline_a.hex`
- Create: `sim/pipeline_test_instr/baseline_a/baseline_a.txt`
- Create: `sim/pipeline_test_instr/baseline_a/tb_baseline_a.v`

- [ ] **Step 1: 创建目录**

Run:

```bash
mkdir -p sim/pipeline_test_instr/baseline_a
```

Expected: 命令无输出，目录存在。

- [ ] **Step 2: 写入 `filelist.f`**

Create `sim/pipeline_test_instr/baseline_a/filelist.f` with:

```text
../../../src/pipeline_cpu.v
../../../src/if_id_reg.v
../../../src/id_ex_reg.v
../../../src/ex_mem_reg.v
../../../src/mem_wb_reg.v
../../../src/forward_unit.v
../../../src/hazard_unit.v
../../../src/btb.v
../../../src/bht.v
../../../src/pc.v
../../../src/regfile.v
../../../src/alu.v
../../../src/datamem.v
pipeline_imem.v
../../../src/decoder.v
../../../src/branch.v
../../../src/mul4to1_32.v
tb_baseline_a.v
```

- [ ] **Step 3: 写入 `pipeline_imem.v`**

Create `sim/pipeline_test_instr/baseline_a/pipeline_imem.v` with:

```verilog
module pipeline_imem (
    input  [31:0] address,
    output [31:0] instr
);
    reg [7:0] imem [1023:0];

    initial begin
        $readmemh("baseline_a.hex", imem);
    end

    assign instr = {imem[address+3], imem[address+2], imem[address+1], imem[address]};
endmodule
```

- [ ] **Step 4: 写入 `baseline_a.hex`**

Create `sim/pipeline_test_instr/baseline_a/baseline_a.hex` with:

```text
93
00
40
06
13
01
50
00
13
00
31
06
b3
01
20
00
13
02
10
00
13
02
22
00
93
02
42
00
13
03
80
00
93
0f
00
00
93
03
93
00
13
05
a0
02
23
a0
a0
00
83
a5
00
00
13
86
15
00
83
a6
00
00
63
84
a6
00
13
07
10
00
13
07
20
00
83
a7
00
00
23
a2
f0
00
03
a8
40
00
93
0a
80
06
23
a4
50
01
03
aa
80
00
e7
09
0a
00
13
0b
10
00
13
0b
20
00
63
04
00
00
23
a6
a0
00
83
ab
c0
00
13
00
00
00
13
00
00
00
13
00
00
00
13
00
00
00
13
00
00
00
13
00
00
00
13
00
00
00
13
00
00
00
```

- [ ] **Step 5: 写入 `baseline_a.txt`**

Create `sim/pipeline_test_instr/baseline_a/baseline_a.txt` with:

```text
Baseline(A) pipeline verification program

Hex format: one byte per line, little-endian instruction order.

PC    Instruction              Purpose
0x00  addi x1, x0, 100         Base data memory address.
0x04  addi x2, x0, 5           Source value for x0 forwarding test.
0x08  addi x0, x2, 99          Attempts to write x0; must be ignored.
0x0c  add x3, x0, x2           x3 must be 5, proving x0 was not forwarded as 104.
0x10  addi x4, x0, 1           Producer for EX/MEM priority test.
0x14  addi x4, x4, 2           Newer x4 value is 3.
0x18  addi x5, x4, 4           Must use EX/MEM x4=3, so x5=7.
0x1c  addi x6, x0, 8           Producer for MEM/WB fallback test.
0x20  addi x31, x0, 0          Spacer.
0x24  addi x7, x6, 9           Must use MEM/WB x6=8, so x7=17.
0x28  addi x10, x0, 42         Store/load data value.
0x2c  sw x10, 0(x1)            mem[100] = 42.
0x30  lw x11, 0(x1)            Load value 42.
0x34  addi x12, x11, 1         Load-use ALU result must be 43.
0x38  lw x13, 0(x1)            Load value 42 for branch compare.
0x3c  beq x13, x10, 0x44       Load-use branch must be taken.
0x40  addi x14, x0, 1          Wrong path; must be flushed.
0x44  addi x14, x0, 2          Correct branch target.
0x48  lw x15, 0(x1)            Load value 42 for store data.
0x4c  sw x15, 4(x1)            Store data depends on load.
0x50  lw x16, 4(x1)            x16 must be 42.
0x54  addi x21, x0, 104        JALR target address.
0x58  sw x21, 8(x1)            mem[108] = 104.
0x5c  lw x20, 8(x1)            Load JALR target.
0x60  jalr x19, 0(x20)         Load-use JALR target dependency.
0x64  addi x22, x0, 1          Wrong path; must be flushed.
0x68  addi x22, x0, 2          Correct JALR target.
0x6c  beq x0, x0, 0x74         Taken branch for wrong-path store suppression.
0x70  sw x10, 12(x1)           Wrong path store; must not commit.
0x74  lw x23, 12(x1)           x23 must remain 0.

Expected final values:
x3  = 5
x5  = 7
x7  = 17
x11 = 42
x12 = 43
x14 = 2
x16 = 42
x19 = 100
x20 = 104
x22 = 2
x23 = 0
stall_count >= 4
```

- [ ] **Step 6: 写入先失败的 testbench**

Create `sim/pipeline_test_instr/baseline_a/tb_baseline_a.v` with:

```verilog
module tb_baseline_a;
    reg clk;
    reg reset;
    integer cycle_count;
    integer stall_count;
    integer error_count;

    pipeline_cpu u_cpu (
        .clk(clk),
        .reset(reset),
        .aluout()
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task check_reg;
        input [4:0] reg_index;
        input [31:0] expected;
        input [255:0] label;
        begin
            if (u_cpu.u_regfile.regfile[reg_index] == expected) begin
                $display("[PASS] %0s: x%0d = %h", label, reg_index, expected);
            end
            else begin
                $display("[FAIL] %0s: x%0d = %h, expected %h",
                         label, reg_index, u_cpu.u_regfile.regfile[reg_index], expected);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_baseline_a);

        cycle_count = 0;
        stall_count = 0;
        error_count = 0;

        $display("========================================");
        $display("Baseline(A) pipeline verification start");
        $display("========================================");

        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;

        repeat (90) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (u_cpu.stall_pc) begin
                stall_count = stall_count + 1;
                $display(">>> Cycle %0d: stall_pc asserted", cycle_count);
            end
        end

        $display("========================================");
        $display("Final register checks");
        $display("========================================");

        check_reg(5'd3,  32'd5,   "x0 write suppression and forwarding filter");
        check_reg(5'd5,  32'd7,   "EX/MEM forwarding priority");
        check_reg(5'd7,  32'd17,  "MEM/WB forwarding fallback");
        check_reg(5'd11, 32'd42,  "load value");
        check_reg(5'd12, 32'd43,  "load-use ALU dependency");
        check_reg(5'd14, 32'd2,   "load-use branch and wrong-path register flush");
        check_reg(5'd16, 32'd42,  "load-use store data dependency");
        check_reg(5'd19, 32'd100, "JALR link register");
        check_reg(5'd20, 32'd104, "load-use JALR target source");
        check_reg(5'd22, 32'd2,   "JALR wrong-path register flush");
        check_reg(5'd23, 32'd0,   "branch wrong-path store suppression");

        if (stall_count >= 4) begin
            $display("[PASS] load-use stall count = %0d", stall_count);
        end
        else begin
            $display("[FAIL] load-use stall count = %0d, expected at least 4", stall_count);
            error_count = error_count + 1;
        end

        $display("========================================");
        $display("Cycles: %0d", cycle_count);
        $display("Errors: %0d", error_count);
        $display("========================================");

        if (error_count == 0) begin
            $display("[PASS] Baseline(A) pipeline verification passed");
        end
        else begin
            $display("[FAIL] Baseline(A) pipeline verification failed with %0d errors", error_count);
        end

        $finish;
    end
endmodule
```

- [ ] **Step 7: 不提交，只记录检查点**

Run:

```bash
git status --short
```

Expected: 新增 `sim/pipeline_test_instr/baseline_a/` 文件。不要提交；本项目全局规则要求只有用户明确要求时才 commit。

---

### Task 2: 将 baseline_a 接入 Makefile 并验证 RED

**Files:**
- Modify: `sim/pipeline_test_instr/Makefile:19-79`

- [ ] **Step 1: 修改 `TESTS` 列表**

Change line with `TESTS =` to:

```make
TESTS = r_type i_type load_store branch jump lui_auipc hazard_forward btb_bht jump_predict baseline_a all_tests
```

- [ ] **Step 2: 增加 `baseline_a` 目标**

Insert after `jump_predict` target and before `all_tests`:

```make
baseline_a:
	cd baseline_a && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd baseline_a && $(RUN_ENV) ./simv -l sim.log
	cd baseline_a && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true
```

- [ ] **Step 3: 运行新增测试，验证它能编译执行**

Run:

```bash
make -C sim/pipeline_test_instr baseline_a
```

Expected now: 测试可能 PASS，也可能暴露 `[FAIL]`。若编译失败，先修测试文件路径或端口连接；不要改 RTL。

- [ ] **Step 4: 检查仿真日志**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
log = Path('sim/pipeline_test_instr/baseline_a/sim.log').read_text(errors='ignore')
for line in log.splitlines():
    if '[PASS]' in line or '[FAIL]' in line or 'Error-' in line or 'Error:' in line:
        print(line)
PY
```

Expected: 能看到 `Baseline(A)` 的 PASS/FAIL 摘要。

- [ ] **Step 5: 不提交，只记录检查点**

Run:

```bash
git status --short
```

Expected: `Makefile` 和 `baseline_a` 目录处于未提交状态。

---

### Task 3: 若 baseline_a 失败，做最小 RTL 修复

**Files:**
- Modify if needed: `src/forward_unit.v:24-47`
- Modify if needed: `src/hazard_unit.v:24-37`
- Modify if needed: `src/pipeline_cpu.v:333-420`
- Modify if needed: `src/pipeline_cpu_fpga.v` corresponding forwarding/store path region

- [ ] **Step 1: 根据日志分类失败**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
log = Path('sim/pipeline_test_instr/baseline_a/sim.log').read_text(errors='ignore')
failures = [line for line in log.splitlines() if '[FAIL]' in line]
if not failures:
    print('NO_FAIL')
else:
    for line in failures:
        print(line)
PY
```

Expected: 如果输出 `NO_FAIL`，跳过本任务剩余 RTL 修复步骤，进入 Task 4。

- [ ] **Step 2: 如果 x0 或 forwarding 优先级失败，检查 `forward_unit.v`**

Expected correct implementation in `src/forward_unit.v`:

```verilog
always @(*) begin
    if (ex_mem_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs1_addr)) begin
        forward_a = 2'b01;
    end
    else if (mem_wb_we && (mem_wb_rd != 5'b0) && (mem_wb_rd == rs1_addr)) begin
        forward_a = 2'b10;
    end
    else begin
        forward_a = 2'b00;
    end

    if (ex_mem_we && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs2_addr)) begin
        forward_b = 2'b01;
    end
    else if (mem_wb_we && (mem_wb_rd != 5'b0) && (mem_wb_rd == rs2_addr)) begin
        forward_b = 2'b10;
    end
    else begin
        forward_b = 2'b00;
    end
end
```

If the file already matches this logic, do not change it.

- [ ] **Step 3: 如果 load-use branch/JALR 没有 stall，检查 `hazard_unit.v`**

Expected correct implementation in `src/hazard_unit.v`:

```verilog
always @(*) begin
    if (id_ex_mem_read && (id_ex_rd != 5'b0) &&
        ((id_re1 && (id_ex_rd == id_rs1_addr)) ||
         (id_re2 && (id_ex_rd == id_rs2_addr)))) begin
        stall_pc      = 1'b1;
        stall_if_id   = 1'b1;
        stall_id_ex   = 1'b1;
    end
    else begin
        stall_pc      = 1'b0;
        stall_if_id   = 1'b0;
        stall_id_ex   = 1'b0;
    end
end
```

If the file already matches this logic, do not change it.

- [ ] **Step 4: 如果 load-use store data 失败，修 store 数据前递**

In `src/pipeline_cpu.v`, inspect the EX/MEM register input for rs2/store data. The store data entering `ex_mem_reg` should use forwarded rs2 data, not the raw ID/EX rs2 value.

Expected pattern:

```verilog
.rs2_val_in(ex_data2_forwarded),
```

If current code uses `ex_rs2_val`, change it to `ex_data2_forwarded`.

Apply the same change to `src/pipeline_cpu_fpga.v` if it has the same `ex_mem_reg` connection.

- [ ] **Step 5: 如果 wrong-path register/memory commit 失败，检查 flush 连接**

In `src/pipeline_cpu.v`, the flush controls should flush IF/ID and ID/EX on redirect/mispredict, while preserving load-use stall behavior.

Expected assignments:

```verilog
assign if_id_flush = redirect_en;
assign id_ex_flush = flush_id_ex || redirect_en;
```

If current code already expresses equivalent behavior, do not change it. If it misses `redirect_en`, add it. Apply the same correction to `src/pipeline_cpu_fpga.v` if needed.

- [ ] **Step 6: 重新运行 baseline_a**

Run:

```bash
make -C sim/pipeline_test_instr baseline_a
```

Expected: `sim/pipeline_test_instr/baseline_a/sim.log` contains `[PASS] Baseline(A) pipeline verification passed` and no `[FAIL]` lines.

- [ ] **Step 7: 不提交，只记录检查点**

Run:

```bash
git diff -- src/forward_unit.v src/hazard_unit.v src/pipeline_cpu.v src/pipeline_cpu_fpga.v src/datamem.v
```

Expected: 只包含为通过测试所需的最小 RTL diff。

---

### Task 4: 运行 baseline(A) 关键回归

**Files:**
- Test outputs only: `sim/pipeline_test_instr/*/sim.log`

- [ ] **Step 1: 运行新增 baseline_a 测试**

Run:

```bash
make -C sim/pipeline_test_instr baseline_a
```

Expected: `sim.log` contains `[PASS] Baseline(A) pipeline verification passed` and no `[FAIL]`.

- [ ] **Step 2: 运行 forwarding 既有回归**

Run:

```bash
make -C sim/pipeline_test_instr hazard_forward
```

Expected: `sim/pipeline_test_instr/hazard_forward/sim.log` contains `[PASS]` lines and no `[FAIL]`.

- [ ] **Step 3: 运行 branch 回归**

Run:

```bash
make -C sim/pipeline_test_instr branch
```

Expected: `sim/pipeline_test_instr/branch/sim.log` contains `[PASS]` lines and no `[FAIL]`.

- [ ] **Step 4: 运行 jump 回归**

Run:

```bash
make -C sim/pipeline_test_instr jump
```

Expected: `sim/pipeline_test_instr/jump/sim.log` contains no compile/runtime errors. If the testbench has no PASS/FAIL summary, verify it reaches `$finish` without VCS error.

- [ ] **Step 5: 运行 BTB/BHT 回归**

Run:

```bash
make -C sim/pipeline_test_instr btb_bht
```

Expected: `sim/pipeline_test_instr/btb_bht/sim.log` contains `[PASS]` lines and no `[FAIL]`.

- [ ] **Step 6: 运行 jump_predict 回归**

Run:

```bash
make -C sim/pipeline_test_instr jump_predict
```

Expected: `sim/pipeline_test_instr/jump_predict/sim.log` contains `[PASS]` lines and no `[FAIL]`.

- [ ] **Step 7: 运行综合指令回归**

Run:

```bash
make -C sim/pipeline_test_instr all_tests
```

Expected: `sim/pipeline_test_instr/all_tests/sim.log` contains `[PASS]` lines and no `[FAIL]`.

- [ ] **Step 8: 汇总回归日志**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
for name in ['baseline_a', 'hazard_forward', 'branch', 'jump', 'btb_bht', 'jump_predict', 'all_tests']:
    log_path = Path('sim/pipeline_test_instr') / name / 'sim.log'
    text = log_path.read_text(errors='ignore') if log_path.exists() else ''
    fail_count = text.count('[FAIL]')
    pass_count = text.count('[PASS]')
    errors = [line for line in text.splitlines() if 'Error-' in line or 'Error:' in line]
    print(f'{name}: PASS={pass_count} FAIL={fail_count} ERRORS={len(errors)}')
PY
```

Expected: all listed tests report `FAIL=0` and `ERRORS=0`.

---

### Task 5: 核验综合报告现状

**Files:**
- Read: `syn/reports/pipeline_cpu_fpga.check.rpt`
- Read: `syn/reports/pipeline_cpu_fpga.constraints.rpt`
- Read if present: `syn/reports/pipeline_cpu_fpga.area.rpt`
- Read if present: `syn/reports/pipeline_cpu_fpga.timing.rpt`
- Read if present: `syn/reports/pipeline_cpu_fpga.power.rpt`
- Read if present: `syn/reports/pipeline_cpu_fpga.qor.rpt`

- [ ] **Step 1: 检查报告文件是否存在**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
for path in [
    'syn/reports/pipeline_cpu_fpga.check.rpt',
    'syn/reports/pipeline_cpu_fpga.constraints.rpt',
    'syn/reports/pipeline_cpu_fpga.area.rpt',
    'syn/reports/pipeline_cpu_fpga.timing.rpt',
    'syn/reports/pipeline_cpu_fpga.power.rpt',
    'syn/reports/pipeline_cpu_fpga.qor.rpt',
]:
    print(f'{path}: {Path(path).exists()}')
PY
```

Expected: existing reports print `True`. Missing reports remain unchecked in `IMPLEMENTATION_CHECKLIST.md`.

- [ ] **Step 2: 提取 constraints 违例摘要**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
path = Path('syn/reports/pipeline_cpu_fpga.constraints.rpt')
text = path.read_text(errors='ignore') if path.exists() else ''
violated = [line for line in text.splitlines() if 'VIOLATED' in line]
print(f'constraint_violations={len(violated)}')
for line in violated[:20]:
    print(line)
PY
```

Expected: 如果存在 fanout 违例，保持清单中“constraints 无违例”为未完成，并记录 `max_fanout` 问题。

- [ ] **Step 3: 可选运行 DC check**

Run only if Design Compiler is available in this shell:

```bash
make -C syn check
```

Expected: `syn/reports/pipeline_cpu_fpga.check.rpt` 更新，且无 latch、多驱动、组合环等结构性错误。若命令不可用或许可证不可用，记录为“本轮使用已有报告核验”。

---

### Task 6: 同步 IMPLEMENTATION_CHECKLIST.md

**Files:**
- Modify: `IMPLEMENTATION_CHECKLIST.md:31-63`
- Modify: `IMPLEMENTATION_CHECKLIST.md:131-138`

- [ ] **Step 1: 更新赛题要求映射中的 A 项状态**

Change relevant table rows to reflect verified facts after Task 4:

```markdown
| A: 经典 5 级流水线 | 已完成 IF/ID/EX/MEM/WB，并通过 `baseline_a` 与 `all_tests` 回归观测 | 归档关键波形截图作为提交材料 |
| A: forwarding | 已完成，并通过 `baseline_a` 覆盖 rd=x0、EX/MEM 优先级、MEM/WB 回退 | 后续可继续扩展随机依赖序列 |
| A: 数据冒险和控制冒险处理 | 已完成基础处理，并通过 `baseline_a` 覆盖 load 后接 ALU/branch/store/JALR 与错误路径 flush | 保留交叉用例回归 |
| A: 稳定运行无死循环、无功能错误 | `baseline_a`、`hazard_forward`、`branch`、`jump`、`btb_bht`、`jump_predict`、`all_tests` 已回归通过 | 将 `sim.log` 和通过截图归档到提交材料 |
```

- [ ] **Step 2: 更新第一阶段综合基线状态**

If Task 5 found `constraints.rpt` still has violations, keep the constraints item unchecked and use:

```markdown
- [ ] 检查 `reports/pipeline_cpu_fpga.constraints.rpt`，当前仍存在 `reset`、`datamem` 和 `ex_branch_target` 等 max_fanout 违例，后续综合优化阶段处理。
```

If mapped netlist does not exist, keep mapped netlist item unchecked.

- [ ] **Step 3: 增加 baseline(A) 验证记录小节**

Insert after the default synthesis command block or before “第二阶段”：

```markdown
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

`baseline_a` 覆盖：

- forwarding：rd=x0 过滤、EX/MEM 优先级、MEM/WB 回退。
- load-use：load 后接 ALU、branch、store、JALR。
- control hazard：branch/JALR 重定向后错误路径寄存器写入和内存写入不提交。
```

- [ ] **Step 4: 更新风险描述**

Keep RV32M risk unchanged. Add or keep a synthesis risk statement:

```markdown
- baseline(A) 功能回归通过后，综合侧仍需单独处理 `max_fanout` 约束违例；本轮不将 fanout 优化混入功能验证。
```

- [ ] **Step 5: 检查文档没有超前声明**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('IMPLEMENTATION_CHECKLIST.md').read_text()
for phrase in ['constraints.rpt`，确认无时序约束违例', '跑通 `make -C syn ultra`']:
    print(f'{phrase}:', phrase in text)
PY
```

Expected: 如果 `syn ultra` 未实际通过，相关项仍是 unchecked。如果 constraints 仍有 fanout 违例，文档不能写成“无违例”。

---

### Task 7: 最终验证与交付摘要

**Files:**
- Read: `sim/pipeline_test_instr/baseline_a/sim.log`
- Read: `IMPLEMENTATION_CHECKLIST.md`
- Read: `git diff`

- [ ] **Step 1: 运行最终 baseline_a**

Run:

```bash
make -C sim/pipeline_test_instr baseline_a
```

Expected: no `[FAIL]`, no VCS runtime error.

- [ ] **Step 2: 运行最终 all_tests**

Run:

```bash
make -C sim/pipeline_test_instr all_tests
```

Expected: no `[FAIL]`, no VCS runtime error.

- [ ] **Step 3: 查看最终 diff**

Run:

```bash
git diff -- sim/pipeline_test_instr/Makefile sim/pipeline_test_instr/baseline_a IMPLEMENTATION_CHECKLIST.md src/forward_unit.v src/hazard_unit.v src/pipeline_cpu.v src/pipeline_cpu_fpga.v src/datamem.v
```

Expected: diff 只包含 baseline(A) 测试、必要 RTL 修复和清单更新。

- [ ] **Step 4: 代码审查**

Use code review before reporting completion. Review for:

- 新测试是否有明确 PASS/FAIL。
- 新 `.hex` 是否与 `baseline_a.txt` 一致。
- RTL 修复是否最小且不破坏现有用例。
- `IMPLEMENTATION_CHECKLIST.md` 是否只勾选已验证事实。

- [ ] **Step 5: 汇报结果，不提交**

Return a short summary with:

- 新增测试目录和覆盖内容。
- 实际通过的仿真命令。
- 是否修改 RTL。
- `IMPLEMENTATION_CHECKLIST.md` 更新内容。
- 综合报告中仍未完成的问题。

Do not run `git commit` unless the user explicitly requests it.

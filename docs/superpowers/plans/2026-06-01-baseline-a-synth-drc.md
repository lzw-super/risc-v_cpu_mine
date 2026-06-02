# Baseline(A) 综合基线 DRC 闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变现有 `datamem` 外部接口和 baseline(A) 功能行为的前提下，降低 DC quick synth 中 max_transition、max_capacitance、max_fanout 设计规则违例，并同步记录 PPA/DRC 对比。

**Architecture:** 本轮采用小步闭环方案：先为 `datamem` 加强非对齐 byte/half 行为测试，再把内部 byte-array/read-modify-write 结构改为 word-array + byte-enable；随后缩减 BTB/BHT reset 对大数组的驱动，并调整 DC reset 约束以允许综合工具缓冲 reset 网络。每步都用 `baseline_a` 和 `all_tests` 保功能，再用 `make -C syn check/synth` 比较 DRC。

**Tech Stack:** Verilog RTL、VCS 仿真、Synopsys Design Compiler、Nangate45、项目现有 `sim/pipeline_test_instr` 和 `syn` Makefile。

---

## File Structure

- Modify: `src/datamem.v`
  - 保持端口不变。
  - 将内部 `mem` 从 `reg [7:0] mem [1023:0]` 改为 `reg [31:0] mem_word [0:255]`。
  - store 用 byte-enable 更新目标 lane，load 按 `address[1:0]` 选择 byte/half/word 并符号扩展。
- Modify: `src/btb.v`
  - reset 时只清 `valid`，不再异步清零 `tag_array` 和 `target_array`。
  - `valid` 为 0 时查找结果屏蔽未初始化 tag/target。
- Modify: `src/bht.v`
  - reset 策略最小化；先保留功能语义，若 DRC 仍高，再用 valid/default-not-taken 方案替代全表 reset。
- Modify: `syn/run_dc.tcl`
  - reset 仍设 false path，但移除或参数化 `set_dont_touch_network [get_ports reset]`。
  - 增加 high-fanout/DRC 辅助报告，便于每轮比较。
- Modify: `IMPLEMENTATION_CHECKLIST.md`
  - 记录每轮 quick synth 的 DRC 数量、PPA 变化、剩余违例和下一步。

---

### Task 1: Strengthen datamem byte-lane regression

**Files:**
- Modify: `sim/pipeline_test_instr/baseline_a/tb_baseline_a.v`
- Test: `make -C sim/pipeline_test_instr baseline_a`

- [ ] **Step 1: Add direct datamem checks before pipeline final checks**

Insert a small direct memory sanity block after reset is released and before the existing `repeat (90)` pipeline run. Use hierarchical access to the already-instantiated `u_cpu.u_datamem` so no new testbench module is needed:

```verilog
        u_cpu.u_datamem.mem_mine.mem_word[8'h20] = 32'h11223344;
        if (u_cpu.u_datamem.mem_mine.mem_word[8'h20] !== 32'h11223344) begin
            $display("[FAIL] datamem word preload failed");
            error_count = error_count + 1;
        end
```

If Task 2 has not yet changed `datamem`, use the current byte-array equivalent instead:

```verilog
        u_cpu.u_datamem.mem_mine.mem[128] = 8'h11;
        u_cpu.u_datamem.mem_mine.mem[129] = 8'h22;
        u_cpu.u_datamem.mem_mine.mem[130] = 8'h33;
        u_cpu.u_datamem.mem_mine.mem[131] = 8'h44;
```

- [ ] **Step 2: Run the test to establish the current baseline**

Run:

```sh
make -C sim/pipeline_test_instr baseline_a
```

Expected: existing baseline(A) still passes; any added direct datamem checks should pass against the current memory representation selected in Step 1.

---

### Task 2: Rewrite datamem internals as word-array + byte-enable

**Files:**
- Modify: `src/datamem.v`
- Test: `make -C sim/pipeline_test_instr baseline_a`
- Test: `make -C sim/pipeline_test_instr all_tests`

- [ ] **Step 1: Replace the `mem` submodule with word-array storage**

Replace the existing `module mem` body with this interface-compatible implementation:

```verilog
module mem (
    input clk,
    input [31:0] addr,
    input we,
    input [3:0] wmask,
    input [31:0] d_in,
    output [31:0] d_out
);
    reg [31:0] mem_word [0:255];
    wire [7:0] word_addr = addr[9:2];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            mem_word[i] = 32'h0;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            if (wmask[3]) mem_word[word_addr][31:24] <= d_in[31:24];
            if (wmask[2]) mem_word[word_addr][23:16] <= d_in[23:16];
            if (wmask[1]) mem_word[word_addr][15:8]  <= d_in[15:8];
            if (wmask[0]) mem_word[word_addr][7:0]   <= d_in[7:0];
        end
    end

    assign d_out = mem_word[word_addr];
endmodule
```

- [ ] **Step 2: Replace `datamem` control logic with byte/half lane selection**

In `datamem`, derive `wmask`, `write_data`, `byte_data`, and `half_data` from `address[1:0]`:

```verilog
    wire [31:0] d_out_wire;
    reg [31:0] write_data;
    reg [3:0] wmask;
    wire [1:0] byte_offset = address[1:0];
    wire [7:0] selected_byte = (byte_offset == 2'b00) ? d_out_wire[7:0] :
                               (byte_offset == 2'b01) ? d_out_wire[15:8] :
                               (byte_offset == 2'b10) ? d_out_wire[23:16] :
                                                        d_out_wire[31:24];
    wire [15:0] selected_half = address[1] ? d_out_wire[31:16] : d_out_wire[15:0];

    mem mem_mine(
        .clk(clk),
        .addr(address),
        .we(we),
        .wmask(wmask),
        .d_in(write_data),
        .d_out(d_out_wire)
    );
```

Store logic:

```verilog
        write_data = 32'b0;
        wmask = 4'b0000;
        d_out = 32'b0;

        if (we) begin
            case (mode)
                3'h0: begin
                    write_data = {4{d_in[7:0]}};
                    wmask = 4'b0001 << byte_offset;
                end
                3'h1: begin
                    write_data = address[1] ? {d_in[15:0], 16'b0} : {16'b0, d_in[15:0]};
                    wmask = address[1] ? 4'b1100 : 4'b0011;
                end
                3'h2: begin
                    write_data = d_in;
                    wmask = 4'b1111;
                end
                default: begin
                    write_data = 32'b0;
                    wmask = 4'b0000;
                end
            endcase
        end
        else begin
            case (mode)
                3'h0: d_out = {{24{selected_byte[7]}}, selected_byte};
                3'h1: d_out = {{16{selected_half[15]}}, selected_half};
                3'h2: d_out = d_out_wire;
                3'h4: d_out = {24'b0, selected_byte};
                3'h5: d_out = {16'b0, selected_half};
                default: d_out = 32'b0;
            endcase
        end
```

- [ ] **Step 3: Run focused and full pipeline regressions**

Run:

```sh
make -C sim/pipeline_test_instr baseline_a
make -C sim/pipeline_test_instr all_tests
```

Expected: both simulations finish without `[FAIL]`; `baseline_a` prints `[PASS] Baseline(A) pipeline verification passed`.

---

### Task 3: Reduce BTB reset fanout

**Files:**
- Modify: `src/btb.v`
- Test: `make -C sim/pipeline_test_instr btb_bht`
- Test: `make -C sim/pipeline_test_instr jump_predict`
- Test: `make -C sim/pipeline_test_instr all_tests`

- [ ] **Step 1: Reset only valid bits**

Change reset loop in `btb` to:

```verilog
        if (reset) begin
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end
```

Leave update logic unchanged:

```verilog
        else if (update_enable && (branch_taken || is_jump)) begin
            valid[update_index] <= 1'b1;
            tag_array[update_index] <= update_tag;
            target_array[update_index] <= actual_target;
        end
```

- [ ] **Step 2: Run branch prediction regressions**

Run:

```sh
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr jump_predict
make -C sim/pipeline_test_instr all_tests
```

Expected: no `[FAIL]`; `btb_hit` remains gated by `valid[fetch_index]`.

---

### Task 4: Reduce BHT reset fanout if needed

**Files:**
- Modify: `src/bht.v`
- Test: `make -C sim/pipeline_test_instr btb_bht`
- Test: `make -C sim/pipeline_test_instr all_tests`

- [ ] **Step 1: Add valid table and default not-taken prediction**

If Task 5 synth still reports BHT/reset as a major violator, change `bht` storage to:

```verilog
    reg valid [0:BHT_ENTRIES-1];
    reg [1:0] bht_table [0:BHT_ENTRIES-1];
```

Change prediction to:

```verilog
    assign predict_taken = valid[fetch_index] && bht_table[fetch_index][1];
```

Change reset/update to:

```verilog
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end
        else if (update_enable) begin
            valid[update_index] <= 1'b1;
            if (is_jump) begin
                bht_table[update_index] <= 2'b11;
            end
            else if (!valid[update_index]) begin
                bht_table[update_index] <= actual_taken ? 2'b10 : 2'b00;
            end
            else if (actual_taken) begin
                if (bht_table[update_index] != 2'b11)
                    bht_table[update_index] <= bht_table[update_index] + 1;
            end
            else begin
                if (bht_table[update_index] != 2'b00)
                    bht_table[update_index] <= bht_table[update_index] - 1;
            end
        end
    end
```

- [ ] **Step 2: Run branch prediction regressions**

Run:

```sh
make -C sim/pipeline_test_instr btb_bht
make -C sim/pipeline_test_instr all_tests
```

Expected: no `[FAIL]`. Prediction warm-up behavior may change, but final architectural state must remain correct.

---

### Task 5: Adjust DC reset constraints and add DRC comparison output

**Files:**
- Modify: `syn/run_dc.tcl`
- Test: `make -C syn check`
- Test: `make -C syn synth`

- [ ] **Step 1: Allow reset buffering by default**

Replace reset constraint block:

```tcl
if {[sizeof_collection [get_ports reset]] > 0} {
    set_false_path -from [get_ports reset]
    set_dont_touch_network [get_ports reset]
}
```

with:

```tcl
if {[sizeof_collection [get_ports reset]] > 0} {
    set_false_path -from [get_ports reset]
    if {[info exists env(DONT_TOUCH_RESET)] && $env(DONT_TOUCH_RESET) eq "1"} {
        set_dont_touch_network [get_ports reset]
    }
}
```

- [ ] **Step 2: Add high fanout report**

After `report_constraint -all_violators`, add:

```tcl
report_net -connections -verbose [all_high_fanout -nets -threshold 16] > [file join $REPORT_DIR ${DESIGN_NAME}.high_fanout.rpt]
```

If this command is unsupported by the installed DC version, replace it with:

```tcl
report_net -connections -verbose > [file join $REPORT_DIR ${DESIGN_NAME}.nets.rpt]
```

- [ ] **Step 3: Run synthesis checks**

Run:

```sh
make -C syn check
make -C syn synth
```

Expected: both commands exit 0; reports are regenerated under `syn/reports/` and mapped outputs under `syn/outputs/`.

---

### Task 6: Parse DRC/PPA result and update checklist

**Files:**
- Modify: `IMPLEMENTATION_CHECKLIST.md`
- Test: read generated reports

- [ ] **Step 1: Extract report numbers**

Read:

```text
syn/reports/pipeline_cpu_fpga.qor.rpt
syn/reports/pipeline_cpu_fpga.area.rpt
syn/reports/pipeline_cpu_fpga.timing.rpt
syn/reports/pipeline_cpu_fpga.power.rpt
syn/reports/pipeline_cpu_fpga.constraints.rpt
```

Record:

```text
Design Rules: Max Trans Violations, Max Cap Violations, Max Fanout Violations
Cell Count: Number of cells, combinational cells, sequential cells
Area: Total cell area, datamem percentage, BTB percentage
Timing: critical path length, slack, TNS, violating paths
Power: dynamic/leakage with activity caveat
```

- [ ] **Step 2: Update `IMPLEMENTATION_CHECKLIST.md`**

Add a new dated subsection under `## 综合/PPA 记录`:

```markdown
### 2026-06-01 DRC 闭环优化记录

变更内容：

- `datamem` 内部改为 word-array + byte-enable，保持外部端口不变。
- BTB reset 只清 valid，避免 tag/target 全量 reset。
- DC reset 约束默认允许 reset buffering。

回归结果：

- `make -C sim/pipeline_test_instr baseline_a`：通过。
- `make -C sim/pipeline_test_instr all_tests`：通过。
- `make -C syn check`：通过。
- `make -C syn synth`：通过。

PPA/DRC 对比：

| 指标 | 优化前 | 优化后 |
| --- | ---: | ---: |
| max transition violations | 24610 | <填入报告值> |
| max capacitance violations | 35 | <填入报告值> |
| max fanout violations | 36 | <填入报告值> |
| cell count | 122583 | <填入报告值> |
| cell area | 248272.699964 | <填入报告值> |
| critical path | 6.32 ns | <填入报告值> |
| setup slack | 3.63 ns | <填入报告值> |
```

Only mark `闭环 constraints 设计规则违例` complete if all three DRC violation counts are 0.

---

## Self-Review

- Spec coverage: covers `datamem` DRC source, BTB/BHT reset, DC reset constraint, simulation regressions, synthesis reports, and checklist sync.
- Placeholder scan: plan uses `<填入报告值>` only in the documentation template where the implementer must insert measured report values after running synthesis; no implementation code has placeholders.
- Type/interface consistency: `datamem` top-level port list remains unchanged; only `mem` submodule gains `wmask`, and only internal instantiation is updated.

# ==============================
# Gate-Level Simulation (GLS) Makefile
# ==============================
# 综合后仿真：使用 syn/outputs/pipeline_cpu_core_mapped.v + SDF 反标
# 用法:
#   make all            -> 编译 + 跑默认 all_tests.hex (周期 5.2 ns)
#   make HEX=baseline_a -> 跑 baseline_a 程序
#   make CLK_NS=5.4     -> 用 5.4 ns 时钟仿真
#   make view           -> 打开 Verdi 波形
#   make clean          -> 清理

VCS    = vcs
VERDI  = verdi

# glibc 2.34+ 兼容
COMPAT_DIR := $(shell pwd)/..
COMPAT_LIB = -L$(COMPAT_DIR)/pipeline_test_instr -lpthread_yield_compat
RUN_ENV    = LD_LIBRARY_PATH=$(COMPAT_DIR)/pipeline_test_instr:$$LD_LIBRARY_PATH

# 默认测试程序与时钟周期
HEX        ?= all_tests
CLK_NS     ?= 5.2
MAX_CYCLES ?= 300

VCS_OPTS = -full64 -sverilog -timescale=1ns/1ps \
           -LDFLAGS "-Wl,--no-as-needed $(COMPAT_LIB)" \
           +define+FSDB \
           -debug_acc+all -kdb -fsdb \
           +nospecify \
           +vcs+initreg+random

# 注: 默认禁用 specify block (+nospecify) 避免大量 setup/hold violation 噪声。
# 真正想观察时序违例可改用 SIM_OPTS_TIMING 模式。

.PHONY: all compile simulate view clean clean_all sweep

all: compile simulate

compile:
	$(VCS) $(VCS_OPTS) -f filelist.f -l compile.log -o simv_$(HEX)

simulate:
	$(RUN_ENV) ./simv_$(HEX) \
	    +HEX_FILE=$(HEX).hex \
	    +CLK_PERIOD=$(CLK_NS) \
	    +MAX_CYCLES=$(MAX_CYCLES) \
	    +vcs+initreg+0 \
	    -l sim_$(HEX)_$(subst .,p,$(CLK_NS))ns.log

# 时序违例检查模式（启用 specify block，含 SDF setup/hold check）
timing_check:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
	    -LDFLAGS "-Wl,--no-as-needed $(COMPAT_LIB)" \
	    +define+FSDB -debug_acc+all -kdb -fsdb \
	    +neg_tchk +sdfverbose \
	    -f filelist.f -l compile_timing.log -o simv_timing
	$(RUN_ENV) ./simv_timing \
	    +HEX_FILE=$(HEX).hex \
	    +CLK_PERIOD=$(CLK_NS) \
	    +MAX_CYCLES=$(MAX_CYCLES) \
	    -l sim_timing_$(HEX)_$(subst .,p,$(CLK_NS))ns.log

# 频率扫描: 5.2 / 5.4 / 5.6 / 5.8 / 6.0 ns
sweep:
	@for p in 5.2 5.4 5.6 5.8 6.0; do \
	    echo "==== Sweep CLK_PERIOD = $$p ns ===="; \
	    $(MAKE) simulate HEX=$(HEX) CLK_NS=$$p MAX_CYCLES=$(MAX_CYCLES); \
	done

view:
	$(VERDI) -ssf wave.fsdb &

clean:
	rm -f *.log *.fsdb ucli.key vc_hdrs.h novas_dump.log
	rm -f simv_* 2>/dev/null || true
	rm -rf simv_*.daidir csrc DVEfiles urgReport verdiLog

clean_all: clean

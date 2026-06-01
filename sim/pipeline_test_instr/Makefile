# ==============================
# Pipeline CPU Test Instructions Makefile
# ==============================
# 支持独立测试目标，每种指令类型独立测试
# 使用方法: make -C sim/pipeline_test_instr <test_name>
# 或者: cd sim/pipeline_test_instr && make <test_name>

VCS     = vcs
VERDI   = verdi

# pthread_yield 兼容性库 (glibc 2.34+ 移除了 pthread_yield)
COMPAT_DIR := $(shell pwd)
COMPAT_LIB = -L$(COMPAT_DIR) -lpthread_yield_compat
RUN_ENV = LD_LIBRARY_PATH=$(COMPAT_DIR):$$LD_LIBRARY_PATH

# 通用编译选项
VCS_OPTS = -full64 -sverilog -timescale=1ns/1ps -LDFLAGS "-Wl,--no-as-needed $(COMPAT_LIB)" +define+FSDB -debug_acc+all -kdb -fsdb

# 测试目标列表
TESTS = r_type i_type load_store branch jump lui_auipc hazard_forward btb_bht jump_predict baseline_a all_tests

.PHONY: all clean $(TESTS)

# 默认执行综合测试
all: all_tests

# ==============================
# 独立测试目标 (使用相对路径)
# ==============================

r_type:
	cd r_type && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd r_type && $(RUN_ENV) ./simv -l sim.log
	cd r_type && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

i_type:
	cd i_type && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd i_type && $(RUN_ENV) ./simv -l sim.log
	cd i_type && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

load_store:
	cd load_store && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd load_store && $(RUN_ENV) ./simv -l sim.log
	cd load_store && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

branch:
	cd branch && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd branch && $(RUN_ENV) ./simv -l sim.log
	cd branch && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

jump:
	cd jump && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd jump && $(RUN_ENV) ./simv -l sim.log
	cd jump && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

lui_auipc:
	cd lui_auipc && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd lui_auipc && $(RUN_ENV) ./simv -l sim.log
	cd lui_auipc && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

hazard_forward:
	cd hazard_forward && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd hazard_forward && $(RUN_ENV) ./simv -l sim.log
	cd hazard_forward && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

btb_bht:
	cd btb_bht && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd btb_bht && $(RUN_ENV) ./simv -l sim.log
	cd btb_bht && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

jump_predict:
	cd jump_predict && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd jump_predict && $(RUN_ENV) ./simv -l sim.log
	cd jump_predict && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

baseline_a:
	cd baseline_a && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd baseline_a && $(RUN_ENV) ./simv -l sim.log
	cd baseline_a && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

all_tests:
	cd all_tests && $(VCS) $(VCS_OPTS) -f filelist.f -l compile.log
	cd all_tests && $(RUN_ENV) ./simv -l sim.log
	cd all_tests && mv simv* csrc vc_hdrs.h ucli.key urgReport *.daidir *.vpd DVEfiles . 2>/dev/null || true

# ==============================
# 波形查看
# ==============================
view_r_type:
	$(VERDI) -ssf r_type/wave.fsdb &

view_i_type:
	$(VERDI) -ssf i_type/wave.fsdb &

view_load_store:
	$(VERDI) -ssf load_store/wave.fsdb &

view_branch:
	$(VERDI) -ssf branch/wave.fsdb &

view_jump:
	$(VERDI) -ssf jump/wave.fsdb &

view_lui_auipc:
	$(VERDI) -ssf lui_auipc/wave.fsdb &

view_hazard_forward:
	$(VERDI) -ssf hazard_forward/wave.fsdb &

view_btb_bht:
	$(VERDI) -ssf btb_bht/wave.fsdb &

view_jump_predict:
	$(VERDI) -ssf jump_predict/wave.fsdb &

view_all:
	$(VERDI) -ssf all_tests/wave.fsdb &

# ==============================
# 清理
# ==============================
clean:
	find . -name "*.log" -delete
	find . -name "*.fsdb" -delete
	find . -name "simv*" -delete
	find . -name "csrc" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.daidir" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.vpd" -delete
	find . -name "DVEfiles" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "vc_hdrs.h" -delete
	find . -name "ucli.key" -delete
	find . -name "urgReport" -type d -exec rm -rf {} + 2>/dev/null || true

clean_all: clean

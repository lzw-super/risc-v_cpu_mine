# ==============================
# FPGA仿真Makefile
# ==============================

# VCS仿真工具
VCS = vcs

# pthread_yield 兼容性库
COMPAT_DIR := $(shell cd .. && pwd)
COMPAT_LIB = -L$(COMPAT_DIR) -lpthread_yield_compat
RUN_ENV = LD_LIBRARY_PATH=$(COMPAT_DIR):$$LD_LIBRARY_PATH

# 源文件列表
RTL_DIR = ../../src
FILELIST = filelist.f

# 输出文件
WAVE_FILE = wave.fsdb
LOG_FILE = sim.log

# 目标
all: compile simulate

compile:
	$(VCS) -full64 -fsdb -debug_access+all +v2k -lca \
		-f $(FILELIST) \
		-top tb_fpga_top \
		-o simv \
		-l compile.log \
		-LDFLAGS "-Wl,--no-as-needed $(COMPAT_LIB)"

simulate:
	$(RUN_ENV) ./simv -l $(LOG_FILE)

view:
	verdi -f $(FILELIST) -ssf $(WAVE_FILE)

clean:
	rm -f simv *.fsdb *.log *.key *.vdb DVEfiles verdiLog*_0.logrc

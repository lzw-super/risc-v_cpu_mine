# ==============================
# Regfile模块 VCS + Verdi 联合仿真 Makefile
# ==============================

VCS     = vcs
VERDI   = verdi

SRC_FILES = filelist.f

COMPAT_DIR := $(shell cd .. && pwd)
COMPAT_LIB = -L$(COMPAT_DIR) -lpthread_yield_compat
RUN_ENV = LD_LIBRARY_PATH=$(COMPAT_DIR):$$LD_LIBRARY_PATH

VCS_COMPILE_OPTS = \
	-full64 \
	-sverilog \
	-timescale=1ns/1ps \
	-LDFLAGS "-Wl,--no-as-needed $(COMPAT_LIB)" \
	+define+FSDB \
	-debug_acc+all \
	-kdb \
	-fsdb \
	-l compile.log

VCS_RUN_OPTS = \
	-l sim.log

.PHONY: all compile simulate view clean

all: compile simulate

compile:
	$(VCS) $(VCS_COMPILE_OPTS) -f $(SRC_FILES)

simulate: compile
	$(RUN_ENV) ./simv $(VCS_RUN_OPTS)

view:
	$(VERDI) -ssf wave.fsdb &

clean:
	rm -rf simv* csrc/ vc_hdrs.h ucli.key urgReport/ *.log *.fsdb *.daidir *.vpd DVEfiles/
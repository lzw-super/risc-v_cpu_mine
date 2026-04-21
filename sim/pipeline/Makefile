# ==============================
# Pipeline CPU VCS + Verdi Makefile
# ==============================

VCS     = vcs
VERDI   = verdi

SRC_FILES = filelist.f

VCS_COMPILE_OPTS = -full64 -sverilog -timescale=1ns/1ps -LDFLAGS -Wl,--no-as-needed +define+FSDB -debug_acc+all -kdb -fsdb -l compile.log

VCS_RUN_OPTS = -l sim.log

.PHONY: all compile simulate view clean

all: compile simulate

compile:
	$(VCS) $(VCS_COMPILE_OPTS) -f $(SRC_FILES)

simulate: compile
	./simv $(VCS_RUN_OPTS)

view:
	$(VERDI) -ssf pipeline_debug_wave.fsdb &

clean:
	rm -rf simv* csrc/ vc_hdrs.h ucli.key urgReport/ *.log *.fsdb *.daidir *.vpd DVEfiles/
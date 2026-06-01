# Synopsys Design Compiler synthesis flow.

DC ?= dc_shell
TOP ?= pipeline_cpu_fpga
CLK_PERIOD_NS ?= 10.0
COMPILE_MODE ?= quick

LOG = dc_$(TOP).log

.PHONY: all check synth ultra clean

all: synth

check:
	TOP=$(TOP) CLK_PERIOD_NS=$(CLK_PERIOD_NS) COMPILE_MODE=check $(DC) -f run_dc.tcl | tee $(LOG)

synth:
	TOP=$(TOP) CLK_PERIOD_NS=$(CLK_PERIOD_NS) COMPILE_MODE=$(COMPILE_MODE) $(DC) -f run_dc.tcl | tee $(LOG)

ultra:
	TOP=$(TOP) CLK_PERIOD_NS=$(CLK_PERIOD_NS) COMPILE_MODE=ultra $(DC) -f run_dc.tcl | tee $(LOG)

clean:
	rm -rf work reports outputs *.log *.svf *.mr *.pvl *.syn alib-52

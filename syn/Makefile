# Synopsys Design Compiler synthesis flow.

DC ?= dc_shell
TOP ?= pipeline_cpu_core
CLK_PERIOD_NS ?= 10.0
COMPILE_MODE ?= quick
BTB_ENTRIES ?= 256
BHT_ENTRIES ?= 256

LOG = dc_$(TOP).log

.PHONY: all check synth ultra small_synth small_ultra fpga_synth fpga_ultra clean

all: synth

check:
	TOP=$(TOP) CLK_PERIOD_NS=$(CLK_PERIOD_NS) COMPILE_MODE=check \
	BTB_ENTRIES=$(BTB_ENTRIES) BHT_ENTRIES=$(BHT_ENTRIES) \
	$(DC) -f run_dc.tcl | tee $(LOG)

synth:
	TOP=$(TOP) CLK_PERIOD_NS=$(CLK_PERIOD_NS) COMPILE_MODE=$(COMPILE_MODE) \
	BTB_ENTRIES=$(BTB_ENTRIES) BHT_ENTRIES=$(BHT_ENTRIES) \
	$(DC) -f run_dc.tcl | tee $(LOG)

ultra:
	TOP=$(TOP) CLK_PERIOD_NS=$(CLK_PERIOD_NS) COMPILE_MODE=ultra \
	BTB_ENTRIES=$(BTB_ENTRIES) BHT_ENTRIES=$(BHT_ENTRIES) \
	$(DC) -f run_dc.tcl | tee $(LOG)

small_synth:
	$(MAKE) synth TOP=pipeline_cpu_core BTB_ENTRIES=16 BHT_ENTRIES=16

small_ultra:
	$(MAKE) ultra TOP=pipeline_cpu_core BTB_ENTRIES=16 BHT_ENTRIES=16

fpga_synth:
	$(MAKE) synth TOP=pipeline_cpu_fpga

fpga_ultra:
	$(MAKE) ultra TOP=pipeline_cpu_fpga

clean:
	rm -rf work reports outputs *.log *.svf *.mr *.pvl *.syn alib-52

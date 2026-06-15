# Synopsys Design Compiler synthesis flow.

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

DC ?= dc_shell
TOP ?= pipeline_cpu_core
CLK_PERIOD_NS ?= 10.0
COMPILE_MODE ?= quick
BTB_ENTRIES ?= 16
BHT_ENTRIES ?= 16
FMAX_CONFIG ?= core
FMAX_PERIODS ?= 5.2 4.0 3.0 2.0 1.5 1.2 1.1 1.0

LOG = dc_$(TOP).log

.PHONY: all check synth ultra small_synth small_ultra fpga_synth fpga_ultra fmax_sweep clean

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

fmax_sweep:
	@summary=reports/fmax_$(FMAX_CONFIG)_summary.csv; \
	mkdir -p reports; \
	printf "period_ns,archive_dir,wns,tns,critical_path_ns,levels,cell_area,violating_paths\n" > $$summary; \
	for period in $(FMAX_PERIODS); do \
		tag=$$(printf "%s" $$period | tr . p); \
		archive=reports/fmax_$(FMAX_CONFIG)_$${tag}ns; \
		echo "[FMAX] Running $(TOP) at $${period} ns -> $${archive}"; \
		$(MAKE) synth TOP=$(TOP) CLK_PERIOD_NS=$$period COMPILE_MODE=$(COMPILE_MODE) BTB_ENTRIES=$(BTB_ENTRIES) BHT_ENTRIES=$(BHT_ENTRIES) || exit $$?; \
		rm -rf $$archive; \
		mkdir -p $$archive/outputs; \
		cp reports/$(TOP).* $$archive/ 2>/dev/null || true; \
		cp outputs/$(TOP).* $$archive/outputs/ 2>/dev/null || true; \
		cp outputs/$(TOP)_*.v $$archive/outputs/ 2>/dev/null || true; \
		python3 ../scripts/summarize_dc_reports.py --period $$period --archive-dir $$archive --design $(TOP) >> $$summary; \
	done; \
	echo "[FMAX] Summary: $$summary"

clean:
	rm -rf work reports outputs *.log *.svf *.mr *.pvl *.syn alib-52

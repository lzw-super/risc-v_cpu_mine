# Design Compiler synthesis script for the RISC-V pipeline CPU.
#
# Default target:
#   TOP=pipeline_cpu_fpga CLK_PERIOD_NS=10.0 dc_shell -f run_dc.tcl

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set REPO_ROOT  [file normalize [file join $SCRIPT_DIR ..]]

if {[info exists env(TOP)]} {
    set DESIGN_NAME $env(TOP)
} else {
    set DESIGN_NAME pipeline_cpu_fpga
}

if {[info exists env(CLK_PERIOD_NS)]} {
    set CLK_PERIOD_NS $env(CLK_PERIOD_NS)
} else {
    set CLK_PERIOD_NS 10.0
}

if {[info exists env(COMPILE_MODE)]} {
    set COMPILE_MODE $env(COMPILE_MODE)
} else {
    set COMPILE_MODE quick
}

if {[info exists env(NANGATE45_HOME)]} {
    set NANGATE45_HOME $env(NANGATE45_HOME)
} else {
    set NANGATE45_HOME /home/synopsys/syn/nangate45
}

if {[info exists env(DC_HOME)]} {
    set DC_HOME_LOCAL $env(DC_HOME)
} else {
    set DC_HOME_LOCAL /home/synopsys/syn/O-2018.06-SP1
}

set WORK_DIR    [file join $SCRIPT_DIR work]
set REPORT_DIR  [file join $SCRIPT_DIR reports]
set OUTPUT_DIR  [file join $SCRIPT_DIR outputs]
set FILELIST    [file join $SCRIPT_DIR filelist.f]

file mkdir $WORK_DIR
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

define_design_lib WORK -path $WORK_DIR

set_app_var search_path [list \
    $SCRIPT_DIR \
    [file join $REPO_ROOT src] \
    [file join $NANGATE45_HOME db] \
    [file join $DC_HOME_LOCAL libraries syn] \
]

set_app_var target_library [list nangate.db]
set_app_var synthetic_library [list dw_foundation.sldb]
set_app_var link_library [list * nangate.db standard.sldb dw_foundation.sldb]

set_host_options -max_cores 4

set rtl_files {}
set fp [open $FILELIST r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq ""} {
        continue
    }
    if {[string match "#*" $line] || [string match "//*" $line]} {
        continue
    }
    lappend rtl_files [file normalize [file join $SCRIPT_DIR $line]]
}
close $fp

analyze -format verilog $rtl_files
elaborate $DESIGN_NAME
current_design $DESIGN_NAME
link
uniquify

if {[sizeof_collection [get_ports clk]] > 0} {
    create_clock -name clk -period $CLK_PERIOD_NS [get_ports clk]
    set non_clock_inputs [remove_from_collection [all_inputs] [get_ports clk]]
    if {[sizeof_collection $non_clock_inputs] > 0} {
        set_input_delay 0.2 -clock clk $non_clock_inputs
    }
    if {[sizeof_collection [all_outputs]] > 0} {
        set_output_delay 0.2 -clock clk [all_outputs]
    }
}

if {[sizeof_collection [get_ports reset]] > 0} {
    set_false_path -from [get_ports reset]
    set_dont_touch_network [get_ports reset]
}

set_max_fanout 16 [current_design]

check_design > [file join $REPORT_DIR ${DESIGN_NAME}.check.pre_compile.rpt]

if {$COMPILE_MODE eq "check"} {
    puts "COMPILE_MODE=check: skip compile and only run analyze/elaborate/link/check."
} elseif {$COMPILE_MODE eq "ultra"} {
    compile_ultra -no_autoungroup
} else {
    compile -map_effort low -area_effort low
}

check_design > [file join $REPORT_DIR ${DESIGN_NAME}.check.rpt]
report_qor > [file join $REPORT_DIR ${DESIGN_NAME}.qor.rpt]
report_area -hierarchy > [file join $REPORT_DIR ${DESIGN_NAME}.area.rpt]
report_timing -delay max -max_paths 20 -nworst 5 > [file join $REPORT_DIR ${DESIGN_NAME}.timing.rpt]
report_power > [file join $REPORT_DIR ${DESIGN_NAME}.power.rpt]
report_resources -hierarchy > [file join $REPORT_DIR ${DESIGN_NAME}.resources.rpt]
report_reference -hierarchy > [file join $REPORT_DIR ${DESIGN_NAME}.reference.rpt]
report_constraint -all_violators > [file join $REPORT_DIR ${DESIGN_NAME}.constraints.rpt]

if {$COMPILE_MODE eq "check"} {
    set VERILOG_OUT [file join $OUTPUT_DIR ${DESIGN_NAME}_elab.v]
    set DDC_OUT [file join $OUTPUT_DIR ${DESIGN_NAME}_elab.ddc]
} else {
    set VERILOG_OUT [file join $OUTPUT_DIR ${DESIGN_NAME}_mapped.v]
    set DDC_OUT [file join $OUTPUT_DIR ${DESIGN_NAME}.ddc]
}

write -format ddc -hierarchy -output $DDC_OUT
write -format verilog -hierarchy -output $VERILOG_OUT
write_sdc [file join $OUTPUT_DIR ${DESIGN_NAME}.sdc]

if {$COMPILE_MODE ne "check"} {
    write_sdf [file join $OUTPUT_DIR ${DESIGN_NAME}.sdf]
}

puts "Synthesis finished for $DESIGN_NAME."
puts "Clock period: $CLK_PERIOD_NS ns"
puts "Compile mode: $COMPILE_MODE"
puts "Reports: $REPORT_DIR"
puts "Outputs: $OUTPUT_DIR"

exit

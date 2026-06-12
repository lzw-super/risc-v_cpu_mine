// Filelist for GLS - post-synthesis gate-level simulation
// (1) Synthesized netlist
../../syn/outputs/pipeline_cpu_core_mapped.v
// (2) External memory models
gls_imem.v
../../src/datamem.v
// (3) Testbench
tb_gls.v
// (4) Standard cell library Verilog model
+incdir+/home/lzw-super/Desktop/mine/flash-attention-hardware/hardware/sim/lib/nangate45
-v /home/lzw-super/Desktop/mine/flash-attention-hardware/hardware/sim/lib/nangate45/NangateOpenCellLibrary.v

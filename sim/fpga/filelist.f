// ==============================
// FPGA仿真文件列表
// ==============================

// 测试bench
tb_fpga_top.v

// FPGA新增模块
../../src/uart_rx.v
../../src/uart_tx.v
../../src/uart_ctrl.v
../../src/instr_ram.v
../../src/pipeline_cpu_fpga.v
../../src/fpga_top.v

// CPU原有模块
../../src/pc.v
../../src/regfile.v
../../src/alu.v
../../src/decoder.v
../../src/branch.v
../../src/datamem.v
../../src/if_id_reg.v
../../src/id_ex_reg.v
../../src/ex_mem_reg.v
../../src/mem_wb_reg.v
../../src/forward_unit.v
../../src/hazard_unit.v
../../src/btb.v
../../src/bht.v
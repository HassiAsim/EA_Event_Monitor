if {[file exists work]} {vdel -lib work -all}
vlib work

vlog -sv ../tb/common/simple_bus_if.sv \
  ../rtl/sync_fifo.sv \
  ../rtl/trigger_unit.sv \
  ../rtl/event_monitor_core.sv \
  ../rtl/reg_block_simple.sv \
  ../rtl/event_monitor_top.sv \
  ../tb/uvm/bus_lite_pkg.sv \
  ../tb/tests/tb_top_bus_uvm_lite.sv

vopt tb_top_bus_uvm_lite -o tb_uvm_opt

vsim -c tb_uvm_opt +TEST=LEVEL_BASIC -do "run -all; quit"

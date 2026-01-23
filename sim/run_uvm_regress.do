if {[file exists work]} {vdel -lib work -all}
vlib work

# 1. COMPILE
vlog -sv ../tb/common/simple_bus_if.sv \
  ../rtl/sync_fifo.sv \
  ../rtl/trigger_unit.sv \
  ../rtl/event_monitor_core.sv \
  ../rtl/reg_block_simple.sv \
  ../rtl/event_monitor_top.sv \
  ../tb/uvm/bus_lite_pkg.sv \
  ../tb/tests/tb_top_bus_uvm_lite.sv

set optname tb_uvm_reg_opt_[clock seconds]
vopt tb_top_bus_uvm_lite -o $optname


set tests {LEVEL_BASIC RISE_BASIC EVENT_MULTIWORD OVERFLOW_STICKY}

foreach t $tests {
  puts "================================="
  puts "RUNNING TEST: $t"
  puts "================================="

  vsim -onfinish stop $optname +TEST=$t
  
  run -all

  quit -sim
  
  puts "TEST DONE: $t"
}

puts "ALL UVM-LITE TESTS DONE"


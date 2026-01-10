vlib work

vlog -sv ../rtl/sync_fifo.sv ../rtl/trigger_unit.sv ../rtl/event_monitor_core.sv ../rtl/reg_block_simple.sv ../rtl/event_monitor_top.sv ../tb/tests/tb_top_bus_regress.sv

set optname "tb_reg_opt_[clock seconds]"
vopt tb_top_bus_regress -o $optname

proc run_one {opt testname} {
  puts ""
  puts "==============================="
  puts "RUNNING TEST: $testname"
  puts "==============================="

  if {[catch {vsim -c $opt +TEST=$testname -do "run -all; quit"} msg]} {
    puts "TEST FAILED: $testname"
    puts $msg
    quit
  }

  puts "TEST PASSED: $testname"
}

run_one $optname LEVEL_BASIC
run_one $optname RISE_BASIC
run_one $optname EVENT_MULTIWORD
run_one $optname OVERFLOW_STICKY

puts ""
puts "ALL REGRESSION TESTS PASSED"
quit


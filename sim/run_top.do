vlib work

vlog -sv ../rtl/sync_fifo.sv ../rtl/trigger_unit.sv ../rtl/event_monitor_core.sv ../rtl/reg_block_simple.sv ../rtl/event_monitor_top.sv ../tb/tests/tb_top_bus_smoke.sv

set optname tb_top_opt_[clock seconds]
vopt tb_top_bus_smoke -o $optname
vsim $optname
run -all


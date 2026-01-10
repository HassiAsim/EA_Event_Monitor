catch {quit -sim}
catch {vdel -lib work -all}

vlib work
vlog -sv ../rtl/sync_fifo.sv ../rtl/trigger_unit.sv ../rtl/event_monitor_core.sv ../tb/tests/tb_core_smoke.sv

set snap "tb_core_opt_[clock seconds]"
vopt tb_core_smoke -o $snap
vsim $snap
run -all
quit 

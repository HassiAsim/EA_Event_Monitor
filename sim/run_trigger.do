# Try to end any running sim
catch {quit -sim}

# Try to delete work library 
catch {vdel -lib work -all}

# Recreate library + compile
vlib work
vlog -sv ../rtl/trigger_unit.sv ../tb/tests/tb_trigger.sv

# Create unique snapshot name 
set snap "tb_trigger_opt_[clock seconds]"
vopt tb_trigger -o $snap

# Simulate snapshot
vsim $snap
run -all
quit 

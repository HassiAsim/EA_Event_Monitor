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

# 2. OPTIMIZE FOR DEBUGGING (+acc)
# +acc enables read/write access to all signals for the waveform viewer
vopt tb_top_bus_uvm_lite -o tb_debug_opt +acc

# 3. LOAD SIMULATION (No -c flag!)
# We select one specific test case to view (e.g., LEVEL_BASIC)
vsim tb_debug_opt +TEST=LEVEL_BASIC

# 4. SETUP WAVEFORM WINDOW
# Turn off 'numeric std' warnings if any
set StdArithNoWarnings 1
set NumericStdNoWarnings 1

# Add ALL signals recursively (-r) to the wave window
add wave -r /*

# Zoom out to see the whole simulation
configure wave -signalnamewidth 1

# 5. RUN
run -all
wave zoom full
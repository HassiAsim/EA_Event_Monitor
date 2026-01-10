vlib work
vlog -sv ../rtl/sync_fifo.sv ../tb/tests/tb_fifo.sv
vsim tb_fifo
run -all
quit

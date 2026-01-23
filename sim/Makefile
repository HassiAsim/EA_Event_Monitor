# Event Monitor Automation
# Description: Makefile to automate compile, simulation, and regression testing.
# Author: Hassan Asim



# 1. Variables (Configuration)

# Tools
VLIB = vlib
VLOG = vlog
VSIM = vsim

# Directories 
RTL_DIR = ../rtl
TB_DIR  = ../tb
WORK    = work

# Source Files
# (Order matters: Packages first, then Interfaces, then RTL, then TB)
RTL_SRC = $(RTL_DIR)/sync_fifo.sv \
          $(RTL_DIR)/trigger_unit.sv \
          $(RTL_DIR)/event_monitor_core.sv \
          $(RTL_DIR)/reg_block_simple.sv \
          $(RTL_DIR)/event_monitor_top.sv

TB_SRC  = $(TB_DIR)/common/simple_bus_if.sv \
          $(TB_DIR)/uvm/bus_lite_pkg.sv \
          $(TB_DIR)/tests/tb_top_bus_uvm_lite.sv



# 2. Main Targets

# Default target: Run the full UVM regression
all: clean lib compile uvm

# Create the library directory if it doesn't exist
lib:
	@echo "--- Creating Work Library ---"
	$(VLIB) $(WORK)

# Compile all SystemVerilog files
compile:
	@echo "--- Compiling RTL and Testbench ---"
	$(VLOG) -work $(WORK) +incdir+$(RTL_DIR) $(RTL_SRC) $(TB_SRC)



# 3. Simulation Targets

# Run UVM-Lite Regression (Runs all tests + Code Coverage)
# This validates your resume point about "Automating Simulation"
uvm: compile
	@echo "--- Running UVM-Lite Regression ---"
	$(VSIM) -c -do "do run_uvm_regress.do; quit -f" | tee uvm_regression.log

# Run Code Coverage Report (Generates HTML)
# This validates your resume point about "Coverage Collection"
coverage: uvm
	@echo "--- Generating Coverage Report ---"
	vcover report -html final_coverage.ucdb -output cov_report -details
	@echo "Report generated at: cov_report/index.html"

# Run Core Smoke Test (Isolated unit test)
core: compile
	@echo "--- Running Core Smoke Test ---"
	$(VSIM) -c -do "do run_core.do; quit -f" | tee core_smoke.log



# 4. Utilities

# Clean up generated files (logs, waves, work dir)
clean:
	@echo "--- Cleaning Up ---"
	rm -rf $(WORK) transcript *.log *.wlf cov_report *.ucdb

# Help menu
help:
	@echo "Available targets:"
	@echo "  make uvm      : Run full UVM regression suite"
	@echo "  make coverage : Run regression AND generate HTML coverage report"
	@echo "  make core     : Run Core-only unit test"
	@echo "  make clean    : Remove build artifacts"

.PHONY: all lib compile uvm coverage core clean help
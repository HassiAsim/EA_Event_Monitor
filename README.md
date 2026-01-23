# Embedded Analytics Event Monitor (EA-EM)

**A configurable hardware IP block for real-time silicon debug and logic analysis.**

The EA-EM monitors internal hardware signals ("probes") and captures timestamped events when specific trigger conditions are met. Designed for SoC debugging, it features an APB-style register interface and an automated UVM Lite verification suite.

## Key Features
- **Configurable Triggering:** Supports Level-Sensitive and Rising-Edge detection.
- **On-Chip Storage:** Captures Timestamp, Probe ID, and Data into a configurable FIFO.
- **Robust Verification:**
  - **UVM Lite Testbench:** Automated self-checking regression suite.
  - **SVA (SystemVerilog Assertions):** Integrated checks for FIFO overflow and protocol violations.
  - **Coverage Model:** Functional coverage hooks (implemented but disabled for Starter Edition compatibility).
- **Automation:** Tcl-based simulation flow compatible with Siemens Questa/ModelSim.

## Project Structure
```text
EA_Event_Monitor/
├── rtl/            # SystemVerilog Design (RTL)
├── tb/             # UVM Lite Testbench & Tests
├── sim/            # Simulation Scripts (Makefile, Tcl)
└── docs/           # Detailed Specifications
```

## How to Run

### 1. Automated Regression (Recommended)
Run the full UVM-Lite regression suite (compiles design, runs all 4 tests, checks SVA).

**Requires:** GNU Make

```bash
cd sim
make uvm
```

### 2. Manual Regression (No Make)
If you do not have `make` installed, you can run the simulator command directly:

```bash
cd sim
vsim -c -do "do run_uvm_regress.do; quit -f"
```

### 3. Visual Debug (Waveforms)
To open the GUI, load the design, and view signals in the waveform viewer:

```bash
cd sim
vsim -do run_debug.do
```

## Requirements

- ModelSim or Questa Simulator
- SystemVerilog (IEEE 1800)

## Documentation

See [docs/spec.md](docs/spec.md) for detailed specifications.

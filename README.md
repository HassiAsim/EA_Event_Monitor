# Embedded Analytics Event Monitor (EA-EM)

> **Note**: This project is a work in progress. Features and enhancements are still being added.

A hardware IP block that monitors internal signals and records timestamped events when trigger conditions occur. Events are stored in an on-chip FIFO for software analysis.

## Overview

The EA-EM monitors probe signals and captures events based on configurable trigger conditions:
- **Signal Monitoring** - Watch probe data with configurable IDs
- **Trigger Detection** - Level compare or rising edge detection
- **Event Storage** - FIFO stores timestamped events (timestamp + probe_id + probe_data)
- **Register Interface** - Software-accessible control and status registers
- **Interrupt Support** - Optional IRQ generation

## Project Structure

EA_Event_Monitor/
├── docs/          # Specification document
├── rtl/           # RTL design files
├── tb/            # Testbench files
├── sim/           # Simulation scripts
└── sva/           # SystemVerilog assertions

## Key Parameters

- `PROBE_W`: Probe data width (default: 32 bits)
- `ID_W`: Probe ID width (default: 8 bits)
- `TS_W`: Timestamp width (default: 32 bits)
- `FIFO_DEPTH`: Number of events stored (default: 16)

## Trigger Modes

- **Mode 0**: Level compare - trigger when probe matches trigger value
- **Mode 1**: Rising edge - trigger on 0→non-zero transition

## Register Map

| Address | Name        | Description                    |
|---------|-------------|--------------------------------|
| 0x00    | CTRL        | Control (enable, arm, mode)    |
| 0x04    | TRIG_VALUE  | Trigger comparison value       |
| 0x08    | TRIG_MASK   | Trigger mask bits              |
| 0x0C    | IRQ_MASK    | Interrupt enable mask          |
| 0x10    | STATUS      | Status flags and FIFO count    |
| 0x14    | STATUS_W1C  | Clear sticky flags             |
| 0x20-0x28| DATA_POP   | Read event data (3 registers)  |

## Running Simulations

Using ModelSim/Questa Simulator:

```bash
cd sim
vsim -do run_core.do      # Core module test
vsim -do run_top.do       # Top-level test
vsim -do run_regress.do   # Regression suite
```

## Basic Usage

1. Configure trigger value and mask
2. Set trigger mode (0=level, 1=rising)
3. Enable and arm: `CTRL.en = 1`, `CTRL.arm = 1`
4. Monitor `STATUS` register for captured events
5. Read events via `DATA_POP` registers (3 consecutive reads)

## Requirements

- ModelSim or Questa Simulator
- SystemVerilog (IEEE 1800)

## Documentation

See [docs/spec.md](docs/spec.md) for detailed specifications.

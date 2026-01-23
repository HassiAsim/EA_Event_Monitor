# Embedded Analytics Event Monitor Specification

| **Version** | **Date** | **Description** |
| ----------- | -------- | --------------- |
| 1.0         | Jan 2026 | Initial Release |

---

## 1. Overview

The **EA-EM** (Embedded Analytics Event Monitor) is a configurable hardware IP block designed for real-time silicon debug. It passively monitors an internal signal bus ("probe"), detects configurable trigger conditions, and captures timestamped event data into an on-chip FIFO for software analysis.

### 1.1 Features

* **Configurable Triggering:** Supports Level-Sensitive and Rising-Edge detection logic.
* **Timestamping:** 32-bit internal counter stamps every event relative to system reset.
* **Deep Visibility:** Captures Source ID, Payload Data, and Timestamp in every packet.
* **APB-Style Interface:** Simple 32-bit read/write bus for configuration and data retrieval.
* **Interrupt Support:** Level-sensitive IRQ output for Trigger Hit or FIFO Overflow events.

---

## 2. Hardware Architecture

### 2.1 Configurable Parameters

The IP is parameterized at synthesis time to fit specific SoC requirements.

| Parameter    | Default | Description                                |
| ------------ | ------- | ------------------------------------------ |
| `PROBE_W`    | 32      | Width of the monitored data signal.        |
| `ID_W`       | 8       | Width of the Probe ID (source identifier). |
| `TS_W`       | 32      | Width of the internal timestamp counter.   |
| `FIFO_DEPTH` | 16      | Depth of the internal Trace FIFO.          |

### 2.2 Signal Interface

| Group               | Signal       | Width     | Direction | Description                                                            |
| ------------------- | ------------ | --------- | --------- | ---------------------------------------------------------------------- |
| **Clock/Reset**     | `clk`        | 1         | Input     | System Clock.                                                          |
|                     | `rst_n`      | 1         | Input     | Active-low asynchronous reset. Resets all registers and FIFO.          |
| **Probe Interface** | `probe_data` | `PROBE_W` | Input     | The live data signal being monitored.                                  |
|                     | `probe_id`   | `ID_W`    | Input     | Static identifier for the probe source (e.g., 0x01 = CPU, 0x02 = DMA). |
| **Register Bus**    | `bus_addr`   | 8         | Input     | Byte-aligned register address.                                         |
|                     | `bus_wr`     | 1         | Input     | Write Enable (1 = Write).                                              |
|                     | `bus_rd`     | 1         | Input     | Read Enable (1 = Read).                                                |
|                     | `bus_wdata`  | 32        | Input     | Write Data payload.                                                    |
|                     | `bus_rdata`  | 32        | Output    | Read Data payload.                                                     |
| **Interrupts**      | `irq`        | 1         | Output    | Level-sensitive interrupt line.                                        |

---

## 3. Register Map

All registers are 32-bit wide. Access must be word-aligned.

| Offset | Name           | Type | Description                                               |
| ------ | -------------- | ---- | --------------------------------------------------------- |
| `0x00` | **CTRL**       | RW   | Main Control Register (Enable/Arm/Mode).                  |
| `0x04` | **TRIG_VALUE** | RW   | Value to compare against the probe data.                  |
| `0x08` | **TRIG_MASK**  | RW   | Bitmask for trigger comparison (1 = Compare, 0 = Ignore). |
| `0x0C` | **IRQ_MASK**   | RW   | Interrupt Enable Mask.                                    |
| `0x10` | **STATUS**     | RO   | Status flags (Sticky bits and FIFO levels).               |
| `0x14` | **STATUS_W1C** | WO   | Write-1-to-Clear register for sticky flags.               |
| `0x20` | **DATA_POP_0** | RO   | FIFO Pop Register (Word 0: Data).                         |
| `0x24` | **DATA_POP_1** | RO   | FIFO Pop Register (Word 1: ID + Partial TS).              |
| `0x28` | **DATA_POP_2** | RO   | FIFO Pop Register (Word 2: Remaining TS).                 |

### 3.1 CTRL (0x00)

| Bit | Name   | Description                                                                                                                                                                    |
| --- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0   | `EN`   | **Global Enable.**<br><br>0: Block disabled. Counters reset.<br><br>1: Block enabled. Timestamp counter runs.                                                                  |
| 1   | `ARM`  | **Trigger Arm.**<br><br>1: Armed. Ready to capture events.<br><br>0: Disarmed. Triggers are ignored. Hardware clears this bit automatically after a single-shot trigger fires. |
| 3:2 | `MODE` | **Trigger Mode.**<br><br>`00`: Level Sensitive (Match `VAL` & `MASK`).<br><br>`01`: Rising Edge (0 to Non-Zero transition).<br><br>`10-11`: Reserved.                          |

### 3.2 STATUS (0x10)

| Bit  | Name          | Description                                                               |
| ---- | ------------- | ------------------------------------------------------------------------- |
| 0    | `TRIG_STICKY` | Set to 1 when a trigger occurs. Remains 1 until cleared via `STATUS_W1C`. |
| 1    | `OVF_STICKY`  | Set to 1 if an event is dropped because the FIFO was full.                |
| 2    | `EMPTY`       | 1 if FIFO is empty.                                                       |
| 3    | `FULL`        | 1 if FIFO is full.                                                        |
| 15:8 | `COUNT`       | Current number of events in the FIFO.                                     |

### 3.3 Interrupts (IRQ_MASK & Output)

The `irq` output signal is a logical OR of enabled sticky flags:

```verilog
irq = (IRQ_MASK[0] & TRIG_STICKY) | (IRQ_MASK[1] & OVF_STICKY);
```

To clear the interrupt, software must write `1` to the corresponding bit in `STATUS_W1C` (0x14).

---

## 4. Functional Description

### 4.1 Trigger Logic

* **Mode 0 (Level):** Fires when `(probe_data & TRIG_MASK) == (TRIG_VALUE & TRIG_MASK)`.
* **Mode 1 (Rising Edge):** Fires when the masked data transitions from `0` to any non-zero value.
* **Capture Rule:** An event is only captured if `EN=1`, `ARM=1`, and `FIFO_FULL=0`.

### 4.2 Data Packet Format

Each event is a 72-bit packet stored in the FIFO. Since the bus is only 32-bits wide, software must perform **three consecutive reads** from the `DATA_POP` region to retrieve one full event.

**Event Structure:**
`{ timestamp[31:0], probe_id[7:0], probe_data[31:0] }`

**Software Read Sequence:**

1. **Read 0x20:** Returns `probe_data[31:0]` (the raw data).
2. **Read 0x24:** Returns `timestamp[15:8]` merged with `probe_id[7:0]`.
3. **Read 0x28:** Returns `timestamp[31:16]`.

Note: Reading address `0x20` triggers the FIFO **POP**. Addresses `0x24` and `0x28` are shadow registers holding the data from that pop.

---

## 5. Verification Strategy

This IP has been verified using a **UVM Lite** simulation environment.

* **Testbench Architecture:** SystemVerilog testbench with constrained-random stimulus and self-checking scoreboards.

* **Regression Suite:**

  1. `LEVEL_BASIC`: Verifies data matching and simple timestamp capture.
  2. `RISE_BASIC`: Verifies edge detection logic.
  3. `EVENT_MULTIWORD`: Verifies the 3-word pack/unpack data integrity.
  4. `OVERFLOW_STICKY`: Stresses the FIFO to validate overflow flags and data protection.

* **SVA (Assertions):** Inline assertions monitor critical illegal states:

  * **FIFO Overflow:** Ensures no push occurs when `full=1`.
  * **FIFO Underflow:** Ensures no pop occurs when `empty=1`.
  * **Unknowns:** Checks for `X` states on the bus during valid transactions.

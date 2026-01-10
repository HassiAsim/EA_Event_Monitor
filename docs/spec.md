# Embedded Analytics Event Monitor (EA-EM) - Specification

## 1. Purpose 
EA-EM is a small hardware IP block that records internal "events" into a trace buffer.
An event is captured when a configurable trigger condition occurs on a monitored signal ("probe").
Captured events are stored in an on-chip FIFO so software can read them later.

This IP is meant to simulate a common "embedded analytics/debug" feature inside chips:
- Watch internal signals
- Detect interesting conditions (trigger)
- Record timestamped data
- Let software read the trace
- Optionally raise an interrupt (IRQ)

## 2. High-level block diagram 
Inputs:
- clk, rst_n
- probe_data[PROBE_W-1:0]
- probe_id[7:0] (which probe/source this data corresponds to)

Main blocks:
1) Timestamp Counter
2) Trigger Unit (level / rising-edge)
3) Event Packer (formats {timestamp, probe_id, probe_data})
4) Trace FIFO (stores event words)
5) Register Block (config + status + data pop)
6) IRQ logic (optional interrupt to CPU)

Outputs:
- irq
- register read data (via internal bus or via AXI-Lite wrapper)

## 3. Interfaces
### 3.1 Core ports (signals this IP has)
- clk: clock
- rst_n: active-low synchronous reset (all regs reset when rst_n=0)
- probe_data[PROBE_W-1:0]: monitored value
- probe_id[7:0]: identifier for the probe source
- irq: interrupt output (level)

### 3.2 Register access (two-stage approach)
The design is split into:
A) A simple internal register bus used by the core:
- reg_wr, reg_rd, reg_addr, reg_wdata, reg_rdata

B) An optional AXI4-Lite wrapper that converts AXI-Lite transactions into the simple internal bus.
This keeps the core simple while still supporting an industry-standard bus externally.

## 4. Parameterization
- PROBE_W: width of probe_data (default 32)
- TS_W: timestamp width (default 32)
- FIFO_DEPTH: number of events stored (default 16)
- EVENT_W: event width = TS_W + 8 + PROBE_W

Default event format width (32 + 8 + 32) = 72 bits.

## 5. Event definition
### 5.1 Event word format
An event word is packed as:

event[EVENT_W-1:0] = { timestamp[TS_W-1:0], probe_id[7:0], probe_data[PROBE_W-1:0] }

This means software can reconstruct:
- when it happened (timestamp)
- which probe (probe_id)
- what value was observed (probe_data)

### 5.2 When an event is captured
An event is pushed into the FIFO when ALL are true:
- CTRL.en == 1
- CTRL.arm == 1
- trigger_hit == 1
- FIFO is not full

If FIFO is full when capture is attempted:
- an overflow flag is set (sticky)
- the event is dropped

Note: In the first version, we capture exactly "one event per trigger hit".
Later versions may support "capture N events after trigger", but that is out of scope for v1.

## 6. Timestamp counter behavior
- timestamp increments by 1 each clock cycle when not in reset
- timestamp resets to 0 when rst_n=0
- timestamp is included in every recorded event

## 7. Trigger behavior
### 7.1 Trigger inputs
- trig_value[PROBE_W-1:0]
- trig_mask[PROBE_W-1:0]
- trig_mode[1:0]

Masking rule:
Only masked bits are compared. A bit is "active" if trig_mask bit = 1.

masked_probe = probe_data & trig_mask
masked_value = trig_value & trig_mask

### 7.2 Trigger modes
Mode 0: LEVEL compare
- trigger_hit = (masked_probe == masked_value)

Mode 1: RISING edge detect (masked)
- trigger_hit when masked_probe goes from 0 to non-zero
- implementation uses a 1-cycle delayed sample of masked_probe

Modes 2/3: reserved (treated as no trigger)

## 8. FIFO / trace buffer behavior
- FIFO stores event words in order captured
- FIFO status:
  - empty when count==0
  - full when count==FIFO_DEPTH
- pop behavior:
  - reading DATA_POP pops exactly one event word from FIFO (if not empty)

If DATA_POP is read while empty:
- underflow flag may be raised internally (debug)
- returned data is undefined (software should check STATUS.empty first)

## 9. Register map (32-bit, byte addresses)
All registers are 32-bit. reg_addr is byte-based.

### 9.1 CTRL (0x00) — RW
bit0  en: enables the block (0=off)
bit1  arm: arms trigger capture (1=armed)
bit3:2 trig_mode:
  0 = level
  1 = rising
  others reserved

Reset value: 0x00000000

### 9.2 TRIG_VALUE (0x04) — RW
Lower PROBE_W bits used.
Reset: 0x00000000

### 9.3 TRIG_MASK (0x08) — RW
Lower PROBE_W bits used.
Reset: all 1s in lower PROBE_W bits (compare all bits by default)

### 9.4 IRQ_MASK (0x0C) — RW
bit0 trigger_irq_en
bit1 overflow_irq_en
Reset: 0x00000000 (IRQs disabled by default)

### 9.5 STATUS (0x10) — RO
bit0 triggered_sticky (set when trigger_hit occurs while armed)
bit1 overflow_sticky  (set when capture attempted while FIFO full)
bit2 fifo_empty
bit3 fifo_full
bits15:8 fifo_count (zero-extended)

Reset: 0x0000000? (flags cleared, fifo_empty=1)

### 9.6 STATUS_W1C (0x14) — WO (write-1-to-clear)
bit0 clear triggered_sticky
bit1 clear overflow_sticky

Writing 1 clears the corresponding sticky flag.
Writing 0 has no effect.

### 9.7 DATA_POP (0x20) — RO (read pops)
Reading this register pops one FIFO entry and returns the event.
Because the event is 72 bits and the bus is 32 bits, the event is returned over 3 reads:

Read 0x20 (POP_LO): returns event[31:0]      (probe_data[31:0] for default widths)
Read 0x24 (POP_MID): returns event[63:32]    (probe_id and part of timestamp)
Read 0x28 (POP_HI): returns event[71:64]     (remaining timestamp bits, zero-extended)

Note: If PROBE_W or TS_W change, the split may be adjusted; v1 targets TS_W=32 and PROBE_W=32.

## 10. Interrupt behavior (irq output)
irq is level-high when enabled conditions occur:

irq = (IRQ_MASK.trigger_irq_en  & triggered_sticky)
   |  (IRQ_MASK.overflow_irq_en & overflow_sticky)

IRQ remains asserted until the sticky flag is cleared using STATUS_W1C.

## 11. Reset behavior
When rst_n=0:
- CTRL resets to 0 (disabled)
- trigger config resets (TRIG_VALUE=0, TRIG_MASK=all 1s)
- sticky flags cleared
- FIFO cleared (count=0, empty=1)
- timestamp resets to 0
- irq deasserted

## 12. Out-of-scope (v1)
- Multi-probe selection and probe routing inside the IP
- Capturing "N cycles after trigger"
- Compression or filtering of events
- DMA or streaming trace output
- Full AXI-Lite performance features (multiple outstanding transactions)

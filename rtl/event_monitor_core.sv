`timescale 1ns/1ps

module event_monitor_core #(
  parameter int PROBE_W = 32,
  parameter int ID_W = 8,
  parameter int TS_W = 32,
  parameter int FIFO_DEPTH = 16
)(
  input logic clk,
  input logic rst_n,

  input logic en,
  input logic arm,
  input logic [1:0] trig_mode,
  input logic [PROBE_W-1:0] trig_value,
  input logic [PROBE_W-1:0] trig_mask,

  input logic [ID_W-1:0] probe_id,
  input logic [PROBE_W-1:0] probe_data,

  input logic evt_pop,
  output logic [TS_W + ID_W + PROBE_W - 1:0] evt_data,
  output logic evt_valid,

  output logic triggered_sticky,
  output logic fifo_overflow_sticky,

  output logic fifo_empty,
  output logic fifo_full,
  output logic [$clog2(FIFO_DEPTH + 1)-1:0] fifo_count
);

  localparam int EVT_W = TS_W + ID_W + PROBE_W;

  logic [TS_W-1:0] ts;
  logic [PROBE_W-1:0] masked_probe;
  logic [PROBE_W-1:0] masked_value;
  logic [PROBE_W-1:0] masked_probe_d;
  logic trig_hit_now;

  logic push_pending;
  logic [EVT_W-1:0] pending_event;

  logic [EVT_W-1:0] fifo_pop_data;
  logic [EVT_W-1:0] fifo_peek_data;

  logic [EVT_W-1:0] last_popped;
  logic last_popped_valid;

  logic fifo_overflow;
  logic fifo_underflow;

  assign masked_probe = probe_data & trig_mask;
  assign masked_value = trig_value & trig_mask;

  always_comb begin
    trig_hit_now = 1'b0;
    unique case (trig_mode)
      2'd0: trig_hit_now = (masked_probe == masked_value);
      2'd1: trig_hit_now = ((masked_probe_d == '0) && (masked_probe != '0));
      default: trig_hit_now = 1'b0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      ts <= '0;
      masked_probe_d <= '0;
    end else begin
      if (en) ts <= ts + 1'b1;
      masked_probe_d <= masked_probe;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      push_pending <= 1'b0;
      pending_event <= '0;
      triggered_sticky <= 1'b0;
      fifo_overflow_sticky <= 1'b0;
    end else begin
      push_pending <= 1'b0;

      if (en && arm && trig_hit_now) begin
        triggered_sticky <= 1'b1;
        pending_event <= {ts, probe_id, probe_data};
        push_pending <= 1'b1;
      end

      if (fifo_overflow) fifo_overflow_sticky <= 1'b1;
    end
  end

  sync_fifo #(.W(EVT_W), .DEPTH(FIFO_DEPTH)) u_fifo (
    .clk(clk),
    .rst_n(rst_n),
    .push(push_pending),
    .push_data(pending_event),
    .pop(evt_pop && !fifo_empty),
    .pop_data(fifo_pop_data),
    .peek_data(fifo_peek_data),
    .empty(fifo_empty),
    .full(fifo_full),
    .count(fifo_count),
    .overflow(fifo_overflow),
    .underflow(fifo_underflow)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      last_popped <= '0;
      last_popped_valid <= 1'b0;
    end else begin
      last_popped_valid <= 1'b0;
      if (evt_pop && !fifo_empty) begin
        last_popped <= fifo_peek_data;
        last_popped_valid <= 1'b1;
      end
    end
  end

  assign evt_data = last_popped_valid ? last_popped : fifo_peek_data;
  assign evt_valid = !fifo_empty;

endmodule


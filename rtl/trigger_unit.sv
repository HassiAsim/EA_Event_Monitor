`timescale 1ns/1ps

module trigger_unit #(
  parameter int PROBE_W = 32
)(
  input logic clk,
  input logic rst_n,
  input logic en,
  input logic arm,
  input logic [PROBE_W-1:0] probe_data,
  input logic [PROBE_W-1:0] trig_value,
  input logic [PROBE_W-1:0] trig_mask,
  input logic [1:0] trig_mode,
  output logic trigger_hit
);

  logic [PROBE_W-1:0] masked_probe;
  logic [PROBE_W-1:0] masked_value;
  logic [PROBE_W-1:0] masked_probe_d;
  logic raw_hit;

  assign masked_probe = probe_data & trig_mask;
  assign masked_value = trig_value & trig_mask;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      masked_probe_d <= '0;
    end else if (en) begin
      masked_probe_d <= masked_probe;
    end
  end

  always_comb begin
    raw_hit = 1'b0;
    unique case (trig_mode)
      2'b00: raw_hit = (masked_probe == masked_value);
      2'b01: raw_hit = ((masked_probe_d != masked_value) && (masked_probe == masked_value));
      default: raw_hit = 1'b0;
    endcase
  end

  always_comb begin
    trigger_hit = en && arm && raw_hit;
  end

  // SYSTEMVERILOG ASSERTIONS (SVA)

  // 1. Safety: Trigger output implies Enabled and Armed were high
  // Logic: If trigger_hit is high, then EN and ARM *must* have been high.
  property p_trigger_safety;
    @(posedge clk) disable iff (!rst_n)
    trigger_hit |-> (en && arm);
  endproperty

  a_trigger_safety: assert property (p_trigger_safety)
    else $error("SVA ERROR: Trigger fired while unit was disabled or disarmed!");

  // 2. Unknown Check: Output should never be X/Z
  a_valid_out_check: assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(trigger_hit));

endmodule


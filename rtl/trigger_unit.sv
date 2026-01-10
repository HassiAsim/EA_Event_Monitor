`timescale 1ns/1ps

module trigger_unit #(
  parameter int PROBE_W = 32
)(
  input  logic                 clk,
  input  logic                 rst_n,

  input  logic [PROBE_W-1:0]   probe_data,
  input  logic [PROBE_W-1:0]   trig_value,
  input  logic [PROBE_W-1:0]   trig_mask,
  input  logic [1:0]           trig_mode,

  output logic                 trigger_hit
);

  logic [PROBE_W-1:0] masked_probe;
  logic [PROBE_W-1:0] masked_value;
  logic [PROBE_W-1:0] masked_probe_d; // previous masked_probe

  assign masked_probe = probe_data & trig_mask;
  assign masked_value = trig_value & trig_mask;

  // Register trigger_hit so we can use the OLD masked_probe_d value
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      masked_probe_d <= '0;
      trigger_hit    <= 1'b0;
    end else begin
      // default pulse low
      trigger_hit <= 1'b0;

      unique case (trig_mode)
        2'd0: begin
          // LEVEL compare (combinational condition, registered output)
          trigger_hit <= (masked_probe == masked_value);
        end

        2'd1: begin
          // RISING edge: previous 0 -> current nonzero
          trigger_hit <= ((masked_probe_d == '0) && (masked_probe != '0));
        end

        default: begin
          trigger_hit <= 1'b0;
        end
      endcase

      // update delayed value AFTER using it
      masked_probe_d <= masked_probe;
    end
  end

endmodule


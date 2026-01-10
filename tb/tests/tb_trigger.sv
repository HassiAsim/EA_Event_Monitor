`timescale 1ns/1ps

module tb_trigger;

  localparam int W = 8;

  logic clk, rst_n;
  logic [W-1:0] probe_data;
  logic [W-1:0] trig_value;
  logic [W-1:0] trig_mask;
  logic [1:0]   trig_mode;
  logic         trigger_hit;

  trigger_unit #(.PROBE_W(W)) dut (
    .clk(clk), .rst_n(rst_n),
    .probe_data(probe_data),
    .trig_value(trig_value),
    .trig_mask(trig_mask),
    .trig_mode(trig_mode),
    .trigger_hit(trigger_hit)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk); #1ps;
  endtask

  initial begin
    // init
    probe_data = 0;
    trig_value = 0;
    trig_mask  = 8'hFF;
    trig_mode  = 0;

    // reset
    rst_n = 0;
    repeat (2) tick();
    rst_n = 1;
    tick();

    // -------------------------
    // Test 1: LEVEL compare
    // -------------------------
    trig_mode  = 2'd0;
    trig_mask  = 8'hFF;
    trig_value = 8'hA5;

    probe_data = 8'h00; tick();
    if (trigger_hit) $fatal(1, "LEVEL: should not hit");

    probe_data = 8'hA5; tick();
    if (!trigger_hit) $fatal(1, "LEVEL: should hit");

    // Mask test: compare only upper nibble
    trig_mask  = 8'hF0;
    trig_value = 8'hA0;

    probe_data = 8'hAF; tick(); // upper nibble A matches
    if (!trigger_hit) $fatal(1, "LEVEL+MASK: should hit");

    probe_data = 8'hBF; tick(); // upper nibble B != A
    if (trigger_hit) $fatal(1, "LEVEL+MASK: should not hit");

    // -------------------------
    // Test 2: RISING edge
    // "0 -> nonzero" on masked_probe
    // -------------------------
    trig_mode  = 2'd1;
    trig_mask  = 8'h0F; // watch lower nibble

    probe_data = 8'h00; tick();
    if (trigger_hit) $fatal(1, "RISE: should not hit at 0");

    probe_data = 8'h01; tick(); // 0 -> nonzero => hit
    if (!trigger_hit) $fatal(1, "RISE: should hit on rising");

    probe_data = 8'h03; tick(); // nonzero -> nonzero => no hit
    if (trigger_hit) $fatal(1, "RISE: should not hit staying nonzero");

    probe_data = 8'h00; tick(); // back to 0 => no hit
    if (trigger_hit) $fatal(1, "RISE: should not hit on falling");

    probe_data = 8'h08; tick(); // 0 -> nonzero => hit again
    if (!trigger_hit) $fatal(1, "RISE: should hit again");

    // Reserved mode => never hit
    trig_mode = 2'd2;
    probe_data = 8'hFF; tick();
    if (trigger_hit) $fatal(1, "RESERVED: should never hit");

    $display("TRIGGER test PASSED");
    $finish;
  end

endmodule

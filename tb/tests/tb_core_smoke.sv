`timescale 1ns/1ps

module tb_core_smoke;

  localparam int PROBE_W = 32;
  localparam int ID_W = 8;
  localparam int TS_W = 32;
  localparam int FIFO_DEPTH = 16;

  logic clk;
  logic rst_n;

  logic en;
  logic arm;
  logic [1:0] trig_mode;
  logic [PROBE_W-1:0] trig_value;
  logic [PROBE_W-1:0] trig_mask;

  logic [ID_W-1:0] probe_id;
  logic [PROBE_W-1:0] probe_data;

  logic evt_pop;
  logic [TS_W + ID_W + PROBE_W - 1:0] evt_data;
  logic evt_valid;

  logic triggered_sticky;
  logic fifo_overflow_sticky;

  logic fifo_empty;
  logic fifo_full;
  logic [$clog2(FIFO_DEPTH + 1)-1:0] fifo_count;

  event_monitor_core #(
    .PROBE_W(PROBE_W),
    .ID_W(ID_W),
    .TS_W(TS_W),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),

    .en(en),
    .arm(arm),
    .trig_mode(trig_mode),
    .trig_value(trig_value),
    .trig_mask(trig_mask),

    .probe_id(probe_id),
    .probe_data(probe_data),

    .evt_pop(evt_pop),
    .evt_data(evt_data),
    .evt_valid(evt_valid),

    .triggered_sticky(triggered_sticky),
    .fifo_overflow_sticky(fifo_overflow_sticky),

    .fifo_empty(fifo_empty),
    .fifo_full(fifo_full),
    .fifo_count(fifo_count)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic wait_cycles(input int n);
    int i;
    begin
      for (i = 0; i < n; i = i + 1) begin
        @(posedge clk);
      end
    end
  endtask

  task automatic pulse_level_match_one_cycle(input logic [PROBE_W-1:0] v);
    begin
      @(negedge clk);
      probe_data = v;
      @(posedge clk);
      @(negedge clk);
      probe_data = '0;
    end
  endtask

  task automatic wait_for_evt_valid(input int max_cycles);
    int i;
    begin
      for (i = 0; i < max_cycles; i = i + 1) begin
        if (evt_valid) return;
        @(posedge clk);
      end
      $fatal(1, "Timeout waiting for evt_valid to assert");
    end
  endtask

  task automatic do_pop_check(input logic [PROBE_W-1:0] exp_probe,
                              input logic [ID_W-1:0] exp_id);
    logic [TS_W + ID_W + PROBE_W - 1:0] e;
    begin
      if (!evt_valid) $fatal(1, "Expected evt_valid before pop");

      @(negedge clk);
      evt_pop = 1'b1;

      @(posedge clk);
      #1ps;
      evt_pop = 1'b0;

      e = evt_data;

      if (e[PROBE_W-1:0] !== exp_probe)
        $fatal(1, "Event probe_data mismatch exp=%h got=%h", exp_probe, e[PROBE_W-1:0]);

      if (e[PROBE_W + ID_W - 1:PROBE_W] !== exp_id)
        $fatal(1, "Event probe_id mismatch exp=%h got=%h", exp_id, e[PROBE_W + ID_W - 1:PROBE_W]);
    end
  endtask

  initial begin
    en = 1'b0;
    arm = 1'b0;
    trig_mode = 2'd0;
    trig_value = '0;
    trig_mask = '0;
    probe_id = '0;
    probe_data = '0;
    evt_pop = 1'b0;

    rst_n = 1'b0;
    wait_cycles(3);
    rst_n = 1'b1;

    trig_mask = 32'hFFFF_FFFF;
    trig_mode = 2'd0; // LEVEL
    trig_value = 32'h0000_1234;
    probe_id = 8'h5A;

    en = 1'b1;
    arm = 1'b1;

    wait_cycles(2);

    if (evt_valid !== 1'b0) $fatal(1, "Expected evt_valid=0 before trigger");
    if (fifo_count !== '0) $fatal(1, "Expected fifo_count=0 after reset");

    pulse_level_match_one_cycle(trig_value);

    if (triggered_sticky !== 1'b1)
      $fatal(1, "Expected triggered_sticky=1 after trigger");

    wait_for_evt_valid(20);

    if (fifo_empty !== 1'b0) $fatal(1, "Expected fifo_empty=0 after event");
    if (fifo_count < 1) $fatal(1, "Expected fifo_count>=1 after event got=%0d", fifo_count);

    do_pop_check(trig_value, probe_id);

    wait_cycles(1);

    if (fifo_count !== 0) $fatal(1, "Expected fifo_count=0 after pop got=%0d", fifo_count);
    if (fifo_empty !== 1'b1) $fatal(1, "Expected fifo_empty=1 after pop");

    $display("CORE smoke test PASSED");
    $finish;
  end

endmodule




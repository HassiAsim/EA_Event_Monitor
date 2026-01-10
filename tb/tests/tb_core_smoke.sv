`timescale 1ns/1ps

module tb_core_smoke;

  localparam int PROBE_W = 8;
  localparam int ID_W = 4;
  localparam int TS_W = 16;
  localparam int DEPTH = 4;
  localparam int EVT_W = TS_W + ID_W + PROBE_W;

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
  logic [EVT_W-1:0] evt_data;
  logic evt_valid;

  logic triggered_sticky;
  logic fifo_overflow_sticky;

  event_monitor_core #(
    .PROBE_W(PROBE_W),
    .ID_W(ID_W),
    .TS_W(TS_W),
    .FIFO_DEPTH(DEPTH)
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
    .fifo_overflow_sticky(fifo_overflow_sticky)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk);
    #1ps;
  endtask

  function automatic [TS_W-1:0] get_ts(input [EVT_W-1:0] e);
    return e[EVT_W-1 -: TS_W];
  endfunction

  function automatic [ID_W-1:0] get_id(input [EVT_W-1:0] e);
    return e[PROBE_W + ID_W - 1 -: ID_W];
  endfunction

  function automatic [PROBE_W-1:0] get_data(input [EVT_W-1:0] e);
    return e[PROBE_W-1:0];
  endfunction

  initial begin
    en = 0;
    arm = 0;
    trig_mode = 0;
    trig_value = 0;
    trig_mask = '1;
    probe_id = 0;
    probe_data = 0;
    evt_pop = 0;

    rst_n = 0;
    repeat (3) tick();
    rst_n = 1;

    en = 1;
    arm = 1;

    trig_mode = 2'd0;
    trig_mask = 8'hFF;
    trig_value = 8'hA5;

    probe_id = 4'h3;

    probe_data = 8'h00;
    tick();

    if (triggered_sticky) $fatal(1, "Should not be triggered yet");

    probe_data = 8'hA5;
    tick();

    if (!triggered_sticky) $fatal(1, "triggered_sticky not set");

    // wait one more cycle because core pushes event into FIFO 1 cycle later
    tick();

    if (!evt_valid) $fatal(1, "evt_valid should be 1 after trigger (1-cycle later)");

    evt_pop = 1;
    tick();
    evt_pop = 0;
    tick();

    if (get_id(evt_data) != 4'h3) $fatal(1, "probe_id mismatch got=%0h", get_id(evt_data));
    if (get_data(evt_data) != 8'hA5) $fatal(1, "probe_data mismatch got=%0h", get_data(evt_data));

    $display("CORE smoke test PASSED");
    $finish;
  end

endmodule


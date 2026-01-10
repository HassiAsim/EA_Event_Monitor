`timescale 1ns/1ps

`include "../common/bus_bfm.sv"
`include "../common/scoreboard_simple.sv"

module tb_top_bus_regress;

  localparam int PROBE_W = 32;
  localparam int ID_W = 8;
  localparam int TS_W = 32;
  localparam int FIFO_DEPTH = 16;

  localparam logic [7:0] ADDR_CONTROL = 8'h00;
  localparam logic [7:0] ADDR_TRIG_VALUE = 8'h04;
  localparam logic [7:0] ADDR_TRIG_MASK = 8'h08;

  logic clk;
  logic rst_n;

  logic [ID_W-1:0] probe_id;
  logic [PROBE_W-1:0] probe_data;

  logic [31:0] bus_rdata;
  simple_bus_if bus(clk);

  event_monitor_top #(
    .PROBE_W(PROBE_W),
    .ID_W(ID_W),
    .TS_W(TS_W),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .probe_id(probe_id),
    .probe_data(probe_data),
    .bus_wr(bus.wr),
    .bus_rd(bus.rd),
    .bus_addr(bus.addr),
    .bus_wdata(bus.wdata),
    .bus_rdata(bus.rdata)
  );

  event_scoreboard sb;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic wait_cycles(input int n);
    int i;
    for (i = 0; i < n; i++) @(posedge clk);
  endtask

  task automatic do_reset();
    bus.idle();
    probe_id = '0;
    probe_data = '0;

    rst_n = 1'b0;
    wait_cycles(3);
    rst_n = 1'b1;
    wait_cycles(2);
  endtask

  task automatic cfg_level_trigger(input logic [31:0] value, input logic [31:0] mask);
    bus.write(ADDR_TRIG_MASK, mask);
    bus.write(ADDR_TRIG_VALUE, value);
    // en=1, arm=1, trig_mode=0 (LEVEL)
    bus.write(ADDR_CONTROL, 32'h0000_0003);
  endtask

  task automatic cfg_rise_trigger(input logic [31:0] mask);
    bus.write(ADDR_TRIG_MASK, mask);
    bus.write(ADDR_TRIG_VALUE, 32'h0);
    // en=1, arm=1, trig_mode=1 (RISE)
    bus.write(ADDR_CONTROL, 32'h0000_0007);
  endtask

  task automatic pulse_probe_onecycle(input logic [31:0] v);
    @(negedge clk);
    probe_data = v;
    @(posedge clk);
    @(negedge clk);
    probe_data = 32'h0;
  endtask

  task automatic hold_probe_cycles(input logic [31:0] v, input int n);
    int i;
    @(negedge clk);
    probe_data = v;
    for (i = 0; i < n; i++) @(posedge clk);
    @(negedge clk);
    probe_data = 32'h0;
  endtask

  task automatic test_level_basic();
    probe_id = 8'h5A;

    cfg_level_trigger(32'h0000_1234, 32'hFFFF_FFFF);
    wait_cycles(2);

    sb.expect_event(8'h5A, 32'h0000_1234);
    pulse_probe_onecycle(32'h0000_1234);

    wait_cycles(5);

    sb.check_status_expect_triggered();
    sb.check_next_event();

    $display("TEST LEVEL_BASIC PASSED");
  endtask

  task automatic test_rise_basic();
    probe_id = 8'hA6;

    cfg_rise_trigger(32'hFFFF_FFFF);
    wait_cycles(2);

    // Create a 0 -> nonzero transition
    @(negedge clk);
    probe_data = 32'h0;
    @(posedge clk);

    sb.expect_event(8'hA6, 32'h0000_0001);
    pulse_probe_onecycle(32'h0000_0001);

    wait_cycles(5);

    sb.check_status_expect_triggered();
    sb.check_next_event();

    $display("TEST RISE_BASIC PASSED");
  endtask

  task automatic test_overflow_sticky();
    probe_id = 8'h3C;

    cfg_level_trigger(32'hDEAD_BEEF, 32'hFFFF_FFFF);
    wait_cycles(2);

    hold_probe_cycles(32'hDEAD_BEEF, FIFO_DEPTH + 6);

    wait_cycles(5);

    sb.check_overflow_sticky_is_set();

    $display("TEST OVERFLOW_STICKY PASSED");
  endtask

  task automatic test_event_multiword();
    probe_id = 8'h11;

    cfg_level_trigger(32'hCAF0_0001, 32'hFFFF_FFFF);
    wait_cycles(2);

    sb.expect_event(8'h11, 32'hCAF0_0001);
    pulse_probe_onecycle(32'hCAF0_0001);

    wait_cycles(5);

    sb.check_next_event();

    $display("TEST EVENT_MULTIWORD PASSED");
  endtask

  initial begin
    string t;
    sb = new(bus);

    do_reset();

    if (!$value$plusargs("TEST=%s", t)) t = "LEVEL_BASIC";

    if (t == "LEVEL_BASIC") begin
      test_level_basic();
    end else if (t == "RISE_BASIC") begin
      test_rise_basic();
    end else if (t == "OVERFLOW_STICKY") begin
      test_overflow_sticky();
    end else if (t == "EVENT_MULTIWORD") begin
      test_event_multiword();
    end else begin
      $fatal(1, "Unknown +TEST=%s", t);
    end

    $display("tb_top_bus_regress DONE");
    $finish;
  end

endmodule

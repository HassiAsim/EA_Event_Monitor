`timescale 1ns/1ps

class event_scoreboard;
  typedef struct packed {
    logic [31:0] probe_data;
    logic [7:0] probe_id;
  } exp_evt_t;

  exp_evt_t exp_q[$];
  virtual simple_bus_if.tb bus;

  localparam logic [7:0] ADDR_STATUS = 8'h0C;
  localparam logic [7:0] ADDR_EVENT_BASE = 8'h10;

  function new(virtual simple_bus_if.tb bus_if);
    bus = bus_if;
  endfunction

  task automatic expect_event(input logic [7:0] id, input logic [31:0] data);
    exp_evt_t e;
    e.probe_id = id;
    e.probe_data = data;
    exp_q.push_back(e);
  endtask

  task automatic check_status_expect_triggered();
    logic [31:0] rd;
    bus.read(ADDR_STATUS, rd);

    if (rd[16] !== 1'b1) $fatal(1, "STATUS triggered_sticky exp=1 got=%0d", rd[16]);
    if (rd[15:8] == 8'h00) $fatal(1, "STATUS fifo_count exp>=1 got=%0d", rd[15:8]);
  endtask

  // Reads full event vector from bus event window.
  // Note: word0 needs 3 reads because pop/capture is pipelined.
  task automatic read_event72(output logic [71:0] ev);
    logic [31:0] w;
    ev = '0;

    bus.read(ADDR_EVENT_BASE, w);
    bus.read(ADDR_EVENT_BASE, w);
    bus.read(ADDR_EVENT_BASE, w);
    ev[31:0] = w;

    bus.read(ADDR_EVENT_BASE + 8'h04, w);
    ev[63:32] = w;

    bus.read(ADDR_EVENT_BASE + 8'h08, w);
    ev[71:64] = w[7:0];
  endtask

  task automatic check_next_event();
    logic [71:0] ev;
    exp_evt_t exp;
    logic [31:0] got_data;
    logic [7:0] got_id;
    logic [31:0] got_ts;

    if (exp_q.size() == 0) $fatal(1, "Scoreboard: no expected events queued");

    exp = exp_q.pop_front();

    read_event72(ev);

    got_data = ev[31:0];
    got_id = ev[39:32];
    got_ts = ev[71:40];

    if (got_data !== exp.probe_data)
      $fatal(1, "EVENT probe_data mismatch exp=%h got=%h", exp.probe_data, got_data);

    if (got_id !== exp.probe_id)
      $fatal(1, "EVENT probe_id mismatch exp=%h got=%h", exp.probe_id, got_id);

    if (got_ts == 32'h0)
      $fatal(1, "EVENT timestamp exp!=0 got=0");
  endtask

  task automatic check_overflow_sticky_is_set();
    logic [31:0] rd;
    bus.read(ADDR_STATUS, rd);

    if (rd[17] !== 1'b1) $fatal(1, "STATUS fifo_overflow_sticky exp=1 got=%0d", rd[17]);
  endtask
endclass

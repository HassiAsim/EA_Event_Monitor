`timescale 1ns/1ps

module tb_top_bus_smoke;

  localparam int PROBE_W = 32;
  localparam int ID_W = 8;
  localparam int TS_W = 32;
  localparam int FIFO_DEPTH = 16;

  localparam logic [7:0] ADDR_CONTROL = 8'h00;
  localparam logic [7:0] ADDR_TRIG_VALUE = 8'h04;
  localparam logic [7:0] ADDR_TRIG_MASK = 8'h08;
  localparam logic [7:0] ADDR_STATUS = 8'h0C;
  localparam logic [7:0] ADDR_EVENT_BASE = 8'h10;

  logic clk;
  logic rst_n;

  logic [ID_W-1:0] probe_id;
  logic [PROBE_W-1:0] probe_data;

  logic bus_wr;
  logic bus_rd;
  logic [7:0] bus_addr;
  logic [31:0] bus_wdata;
  logic [31:0] bus_rdata;

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
    .bus_wr(bus_wr),
    .bus_rd(bus_rd),
    .bus_addr(bus_addr),
    .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  task automatic wait_cycles(input int n);
    int i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task automatic bus_write(input logic [7:0] a, input logic [31:0] d);
    begin
      @(negedge clk);
      bus_addr = a;
      bus_wdata = d;
      bus_wr = 1'b1;
      bus_rd = 1'b0;

      @(posedge clk);
      #1ps;
      bus_wr = 1'b0;
    end
  endtask

  task automatic bus_read(input logic [7:0] a, output logic [31:0] d);
    begin
      @(negedge clk);
      bus_addr = a;
      bus_wr = 1'b0;
      bus_rd = 1'b1;

      @(posedge clk);
      #1ps;
      d = bus_rdata;

      @(negedge clk);
      bus_rd = 1'b0;
    end
  endtask

  initial begin
    logic [31:0] rd;
    logic [31:0] w0;
    logic [31:0] w1;
    logic [31:0] w2;

    bus_wr = 1'b0;
    bus_rd = 1'b0;
    bus_addr = 8'h0;
    bus_wdata = 32'h0;

    probe_id = 8'h00;
    probe_data = 32'h0;

    rst_n = 1'b0;
    wait_cycles(3);
    rst_n = 1'b1;

    probe_id = 8'h5A;

    bus_write(ADDR_TRIG_MASK, 32'hFFFF_FFFF);
    bus_write(ADDR_TRIG_VALUE, 32'h0000_1234);

    bus_write(ADDR_CONTROL, 32'h0000_0003);

    wait_cycles(2);

    @(negedge clk);
    probe_data = 32'h0000_1234;
    @(posedge clk);
    @(negedge clk);
    probe_data = 32'h0;

    wait_cycles(5);

    bus_read(ADDR_STATUS, rd);
    if (rd[16] !== 1'b1) $fatal(1, "STATUS triggered_sticky exp=1 got=%0d", rd[16]);
    if (rd[15:8] == 8'h00) $fatal(1, "STATUS fifo_count exp>=1 got=%0d", rd[15:8]);

    bus_read(ADDR_EVENT_BASE, w0);

    bus_read(ADDR_EVENT_BASE, w0);

    bus_read(ADDR_EVENT_BASE, w0);
    if (w0 !== 32'h0000_1234) $fatal(1, "EVENT word0 exp=00001234 got=%h", w0);

    bus_read(ADDR_EVENT_BASE + 8'h04, w1);
    bus_read(ADDR_EVENT_BASE + 8'h08, w2);

    if (w1[7:0] !== 8'h5A) $fatal(1, "EVENT probe_id exp=5A got=%h", w1[7:0]);

    $display("TOP bus smoke test PASSED");
    $finish;
  end

endmodule


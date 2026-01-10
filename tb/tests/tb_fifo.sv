`timescale 1ns/1ps

module tb_fifo;

  localparam int W     = 72;
  localparam int DEPTH = 4;

  logic clk, rst_n;

  logic         push;
  logic [W-1:0] push_data;
  logic         pop;
  logic [W-1:0] pop_data;

  logic empty, full;
  logic [$clog2(DEPTH+1)-1:0] count;
  logic overflow, underflow;

  // DUT
  sync_fifo #(.W(W), .DEPTH(DEPTH)) dut (
    .clk(clk), .rst_n(rst_n),
    .push(push), .push_data(push_data),
    .pop(pop), .pop_data(pop_data),
    .empty(empty), .full(full), .count(count),
    .overflow(overflow), .underflow(underflow)
  );

  // clock: 10ns period
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // reference queue
  logic [W-1:0] q[$];

  task automatic do_push(input logic [W-1:0] v);
    bit should_overflow;

    should_overflow = (q.size() >= DEPTH);

    // drive push for 1 cycle
    @(negedge clk);
    push      = 1'b1;
    push_data = v;
    pop       = 1'b0;

    // wait for DUT to evaluate at posedge, then wait 1ps for NBA updates
    @(posedge clk);
    #1ps;

    if (overflow !== should_overflow)
      $fatal(1, "Overflow mismatch. expected=%0d got=%0d time=%0t count=%0d full=%0d",
             should_overflow, overflow, $time, count, full);

    if (!should_overflow)
      q.push_back(v);

    // deassert push
    @(negedge clk);
    push = 1'b0;
  endtask

  task automatic do_pop();
    bit should_underflow;
    logic [W-1:0] exp;

    should_underflow = (q.size() == 0);

    @(negedge clk);
    pop  = 1'b1;
    push = 1'b0;

    @(posedge clk);
    #1ps;

    if (underflow !== should_underflow)
      $fatal(1, "Underflow mismatch. expected=%0d got=%0d time=%0t count=%0d empty=%0d",
             should_underflow, underflow, $time, count, empty);

    if (!should_underflow) begin
      exp = q.pop_front();
      if (pop_data !== exp)
        $fatal(1, "POP mismatch exp=%h got=%h time=%0t", exp, pop_data, $time);
    end

    @(negedge clk);
    pop = 1'b0;
  endtask

  initial begin
    push = 0; pop = 0; push_data = '0;

    // reset
    rst_n = 0;
    repeat (3) @(negedge clk);
    rst_n = 1;

    // fill fifo (DEPTH=4)
    do_push(72'h0001);
    do_push(72'h0002);
    do_push(72'h0003);
    do_push(72'h0004);

    // overflow attempt
    do_push(72'h0005);

    // pop all
    do_pop();
    do_pop();
    do_pop();
    do_pop();

    // underflow attempt
    do_pop();

    $display("FIFO test PASSED");
    $finish;
  end

endmodule


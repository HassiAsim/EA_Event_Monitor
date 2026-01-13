`timescale 1ns/1ps

module tb_fifo;

  localparam int W = 72;
  localparam int DEPTH = 4;

  logic clk;
  logic rst_n;

  logic push;
  logic [W-1:0] push_data;
  logic pop;
  logic [W-1:0] pop_data;

  logic [W-1:0] peek_data;

  logic empty;
  logic full;
  logic [$clog2(DEPTH+1)-1:0] count;
  logic overflow;
  logic underflow;

  sync_fifo #(.W(W), .DEPTH(DEPTH)) dut (
    .clk(clk),
    .rst_n(rst_n),

    .push(push),
    .push_data(push_data),

    .pop(pop),
    .pop_data(pop_data),

    .peek_data(peek_data),

    .empty(empty),
    .full(full),
    .count(count),

    .overflow(overflow),
    .underflow(underflow)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  // reference queue
  logic [W-1:0] q[$];

  task automatic do_push(input logic [W-1:0] v);
    bit should_overflow;
    logic [W-1:0] exp_peek;

    should_overflow = (q.size() >= DEPTH);

    // expected peek AFTER a successful push:
    // - if queue was empty, new head becomes v
    // - else head stays the same
    if (!should_overflow) begin
      if (q.size() == 0) exp_peek = v;
      else               exp_peek = q[0];
    end else begin
      exp_peek = (q.size() > 0) ? q[0] : '0;
    end

    @(negedge clk);
    push = 1'b1;
    push_data = v;
    pop = 1'b0;

    @(posedge clk);
    #1ps;

    if (overflow !== should_overflow) begin
      $fatal(1,
        "Overflow mismatch. expected=%0d got=%0d time=%0t count=%0d full=%0d",
        should_overflow, overflow, $time, count, full
      );
    end

    if (!should_overflow) begin
      q.push_back(v);
    end

    // peek should reflect current head whenever not empty
    if (q.size() > 0) begin
      if (peek_data !== exp_peek) begin
        $fatal(1, "PEEK mismatch exp=%h got=%h time=%0t", exp_peek, peek_data, $time);
      end
    end

    @(negedge clk);
    push = 1'b0;
  endtask

  task automatic do_pop();
    bit should_underflow;
    logic [W-1:0] exp;

    should_underflow = (q.size() == 0);

    @(negedge clk);
    pop = 1'b1;
    push = 1'b0;

    @(posedge clk);
    #1ps;

    if (underflow !== should_underflow) begin
      $fatal(1,
        "Underflow mismatch. expected=%0d got=%0d time=%0t count=%0d empty=%0d",
        should_underflow, underflow, $time, count, empty
      );
    end

    if (!should_underflow) begin
      exp = q.pop_front();
      if (pop_data !== exp) begin
        $fatal(1, "POP mismatch exp=%h got=%h time=%0t", exp, pop_data, $time);
      end

      // after pop, if still not empty, peek should show new head
      if (q.size() > 0) begin
        if (peek_data !== q[0]) begin
          $fatal(1, "PEEK(after pop) mismatch exp=%h got=%h time=%0t", q[0], peek_data, $time);
        end
      end
    end

    @(negedge clk);
    pop = 1'b0;
  endtask

  initial begin
    push = 0;
    pop = 0;
    push_data = '0;

    rst_n = 0;
    repeat (3) @(negedge clk);
    rst_n = 1;

    do_push(72'h0001);
    do_push(72'h0002);
    do_push(72'h0003);
    do_push(72'h0004);

    // overflow attempt
    do_push(72'h0005);

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

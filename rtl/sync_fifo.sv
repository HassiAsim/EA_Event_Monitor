`timescale 1ns/1ps

module sync_fifo #(
  parameter int W = 72,
  parameter int DEPTH = 16
) (
  input  logic clk,
  input  logic rst_n,

  input  logic        push,
  input  logic [W-1:0] push_data,

  input  logic        pop,
  output logic [W-1:0] pop_data,

  output logic [W-1:0] peek_data,   

  output logic empty,
  output logic full,
  output logic [$clog2(DEPTH+1)-1:0] count,

  output logic overflow,
  output logic underflow
);

  localparam int AW = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

  logic [W-1:0] mem [0:DEPTH-1];
  logic [AW-1:0] wptr;
  logic [AW-1:0] rptr;

  function automatic [AW-1:0] inc_ptr(input [AW-1:0] ptr);
    if (ptr == DEPTH-1) inc_ptr = '0;
    else inc_ptr = ptr + 1'b1;
  endfunction

  always_comb begin
    empty = (count == 0);
    full  = (count == DEPTH);
  end

  assign peek_data = empty ? '0 : mem[rptr];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      wptr      <= '0;
      rptr      <= '0;
      count     <= '0;
      pop_data  <= '0;
      overflow  <= 1'b0;
      underflow <= 1'b0;
    end else begin
      logic do_pop;
      logic do_push;

      overflow  <= 1'b0;
      underflow <= 1'b0;

      do_pop  = pop && !empty;

      do_push = push && (!full || do_pop);

      if (pop && empty) underflow <= 1'b1;
      if (push && full && !do_pop) overflow <= 1'b1;

      if (do_pop) begin
        pop_data <= mem[rptr];
        rptr <= inc_ptr(rptr);
      end

      if (do_push) begin
        mem[wptr] <= push_data;
        wptr <= inc_ptr(wptr);
      end

      unique case ({do_push, do_pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

endmodule

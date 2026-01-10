`timescale 1ns/1ps

module sync_fifo #(
  parameter int W = 72,
  parameter int DEPTH = 16
) (
  input  logic         clk,
  input  logic         rst_n,

  input  logic         push,
  input  logic [W-1:0] push_data,

  input  logic         pop,
  output logic [W-1:0] pop_data,

  output logic         empty,
  output logic         full,
  output logic [$clog2(DEPTH+1)-1:0] count,

  output logic         overflow,
  output logic         underflow
);

  localparam int AW = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

  logic [W-1:0] mem [0:DEPTH-1];
  logic [AW-1:0] wptr, rptr;

  // status from current count
  always_comb begin
    empty = (count == 0);
    full  = (count == DEPTH);
  end

  function automatic [AW-1:0] inc_ptr(input [AW-1:0] ptr);
    if (ptr == DEPTH-1) inc_ptr = '0;
    else                inc_ptr = ptr + 1'b1;
  endfunction

  // Main sequential logic
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      wptr      <= '0;
      rptr      <= '0;
      count     <= '0;
      pop_data  <= '0;
      overflow  <= 1'b0;
      underflow <= 1'b0;
    end else begin
      // default: pulses low unless an error occurs
      overflow  <= 1'b0;
      underflow <= 1'b0;

      unique case ({push, pop})
        2'b00: begin
          // do nothing
        end

        2'b01: begin : POP_ONLY
          if (!empty) begin
            pop_data <= mem[rptr];
            rptr     <= inc_ptr(rptr);
            count    <= count - 1'b1;
          end else begin
            underflow <= 1'b1;
          end
        end

        2'b10: begin : PUSH_ONLY
          if (!full) begin
            mem[wptr] <= push_data;
            wptr      <= inc_ptr(wptr);
            count     <= count + 1'b1;
          end else begin
            overflow <= 1'b1;
          end
        end

        2'b11: begin : PUSH_AND_POP
          // If both happen, normally count stays the same.
          // But if empty or full, we must be careful.
          if (empty && full) begin
            // impossible state if count is correct; ignore
          end else if (empty) begin
            // pop would underflow, push can succeed
            underflow <= 1'b1;
            if (!full) begin
              mem[wptr] <= push_data;
              wptr      <= inc_ptr(wptr);
              count     <= count + 1'b1;
            end else begin
              overflow <= 1'b1;
            end
          end else if (full) begin
            // push would overflow, pop can succeed
            overflow <= 1'b1;
            pop_data <= mem[rptr];
            rptr     <= inc_ptr(rptr);
            count    <= count - 1'b1;
          end else begin
            // normal case: do both, count unchanged
            pop_data <= mem[rptr];
            rptr     <= inc_ptr(rptr);

            mem[wptr] <= push_data;
            wptr      <= inc_ptr(wptr);

            count <= count; // explicit
          end
        end
      endcase
    end
  end

endmodule


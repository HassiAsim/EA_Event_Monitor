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

  // FIX: Added 'or negedge rst_n' for Asynchronous Reset
  always_ff @(posedge clk or negedge rst_n) begin
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


  // SYSTEMVERILOG ASSERTIONS 
  // Note: 'disable iff (!rst_n)' ensures we don't check during reset.
  
  // 1. Safety: Never Push to a Full FIFO (unless we are also Popping)
  // Logic: If (push is high) AND (fifo is full), THEN (pop must also be high)
  property p_no_overflow_loss;
    @(posedge clk) disable iff (!rst_n)
    (push && full) |-> pop;
  endproperty
  
  a_no_overflow_loss: assert property (p_no_overflow_loss)
    else $error("SVA ERROR: Attempted to push to full FIFO without popping!");

  // 2. Safety: Never Pop from an Empty FIFO
  // Logic: It is illegal to assert 'pop' if 'empty' is true.
  property p_no_underflow;
    @(posedge clk) disable iff (!rst_n)
    (pop) |-> !empty; 
  endproperty

  a_no_underflow: assert property (p_no_underflow)
    else $error("SVA ERROR: Attempted to pop from empty FIFO!");

  // 3. Liveness: If we push (and not full), count must increase next cycle
  // Logic: If (push && !pop && !full), next cycle count == count + 1
  property p_count_inc;
    @(posedge clk) disable iff (!rst_n)
    (push && !pop && !full) |=> (count == $past(count) + 1'b1);
  endproperty

  a_count_inc: assert property (p_count_inc)
    else $error("SVA ERROR: FIFO count did not increment after push!");
endmodule

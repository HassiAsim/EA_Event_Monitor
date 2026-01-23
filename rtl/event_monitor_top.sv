module event_monitor_top #(
  parameter int PROBE_W = 32,
  parameter int ID_W = 8,
  parameter int TS_W = 32,
  parameter int FIFO_DEPTH = 16
)(
  input logic clk,
  input logic rst_n,

  input logic [ID_W-1:0] probe_id,
  input logic [PROBE_W-1:0] probe_data,

  input logic bus_wr,
  input logic bus_rd,
  input logic [7:0] bus_addr,
  input logic [31:0] bus_wdata,
  output logic [31:0] bus_rdata
);

  logic en;
  logic arm;
  logic [1:0] trig_mode;
  logic [PROBE_W-1:0] trig_value;
  logic [PROBE_W-1:0] trig_mask;
  
  // FIX 1: New Wire
  logic clear_sticky;

  logic evt_pop;
  logic [TS_W + ID_W + PROBE_W - 1:0] evt_data;
  logic evt_valid;

  logic fifo_empty;
  logic fifo_full;
  logic [$clog2(FIFO_DEPTH + 1)-1:0] fifo_count;

  logic triggered_sticky;
  logic fifo_overflow_sticky;

  event_monitor_core #(
    .PROBE_W(PROBE_W),
    .ID_W(ID_W),
    .TS_W(TS_W),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) u_core (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .arm(arm),
    
    // FIX 2: Connect Core Input
    .clear_sticky(clear_sticky),
    
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

  reg_block_simple #(
    .PROBE_W(PROBE_W),
    .ID_W(ID_W),
    .TS_W(TS_W),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) u_regs (
    .clk(clk),
    .rst_n(rst_n),
    .bus_wr(bus_wr),
    .bus_rd(bus_rd),
    .bus_addr(bus_addr),
    .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata),
    .en(en),
    .arm(arm),
    .trig_mode(trig_mode),
    .trig_value(trig_value),
    .trig_mask(trig_mask),
    
    // FIX 3: Connect Reg Output
    .clear_sticky(clear_sticky),
    
    .evt_pop(evt_pop),
    .evt_data(evt_data),
    .evt_valid(evt_valid),
    .fifo_empty(fifo_empty),
    .fifo_full(fifo_full),
    .fifo_count(fifo_count),
    .triggered_sticky(triggered_sticky),
    .fifo_overflow_sticky(fifo_overflow_sticky)
  );

endmodule


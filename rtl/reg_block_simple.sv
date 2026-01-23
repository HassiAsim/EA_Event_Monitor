module reg_block_simple #(
  parameter int PROBE_W = 32,
  parameter int ID_W = 8,
  parameter int TS_W = 32,
  parameter int FIFO_DEPTH = 16
) (
  input logic clk,
  input logic rst_n,

  input logic bus_wr,
  input logic bus_rd,
  input logic [7:0] bus_addr,
  input logic [31:0] bus_wdata,
  output logic [31:0] bus_rdata,

  output logic en,
  output logic arm,
  output logic [1:0] trig_mode,
  output logic [PROBE_W-1:0] trig_value,
  output logic [PROBE_W-1:0] trig_mask,
  output logic clear_sticky,

  output logic evt_pop,
  input logic [TS_W+ID_W+PROBE_W-1:0] evt_data,
  input logic evt_valid,

  input logic fifo_empty,
  input logic fifo_full,
  
  // FIX 1: Dynamic Width to match Core
  input logic [$clog2(FIFO_DEPTH + 1)-1:0] fifo_count, 

  input logic triggered_sticky,
  input logic fifo_overflow_sticky
);

  localparam logic [7:0] ADDR_CONTROL    = 8'h00;
  localparam logic [7:0] ADDR_TRIG_VALUE = 8'h04;
  localparam logic [7:0] ADDR_TRIG_MASK  = 8'h08;
  localparam logic [7:0] ADDR_STATUS     = 8'h0C;
  localparam logic [7:0] ADDR_EVENT_BASE = 8'h10;

  logic [31:0] control_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      control_reg <= 32'h0;
      trig_value <= '0;
      trig_mask <= '0;
    end else begin
      if (bus_wr) begin
        unique case (bus_addr)
          ADDR_CONTROL:    control_reg <= bus_wdata;
          ADDR_TRIG_VALUE: trig_value <= bus_wdata[PROBE_W-1:0];
          ADDR_TRIG_MASK:  trig_mask <= bus_wdata[PROBE_W-1:0];
          default: begin end
        endcase
      end
    end
  end

  always_comb begin
    en = control_reg[0];
    arm = control_reg[1];
    trig_mode = {1'b0, control_reg[2]};
    
    // FIX 2: This signal creates a 1-cycle pulse when writing bit 3 to addr 0x00
    clear_sticky = bus_wr && (bus_addr == ADDR_CONTROL) && bus_wdata[3];

    evt_pop = bus_rd && evt_valid && (bus_addr == (ADDR_EVENT_BASE + 8'h08));

    bus_rdata = 32'h0;
    unique case (bus_addr)
      ADDR_CONTROL:    bus_rdata = control_reg;
      ADDR_TRIG_VALUE: bus_rdata = trig_value;
      ADDR_TRIG_MASK:  bus_rdata = trig_mask;
      ADDR_STATUS: begin
        bus_rdata[0] = fifo_empty;
        bus_rdata[1] = fifo_full;
        // The count will fit because we expanded the logic, or we zero-pad if small
        bus_rdata[15:8] = fifo_count; 
        bus_rdata[16] = triggered_sticky;
        bus_rdata[17] = fifo_overflow_sticky;
      end
      ADDR_EVENT_BASE: begin
        if (evt_valid) bus_rdata = evt_data[PROBE_W-1:0];
      end
      (ADDR_EVENT_BASE + 8'h04): begin
        if (evt_valid) begin
          bus_rdata[7:0] = evt_data[PROBE_W +: ID_W];
          bus_rdata[31:8] = evt_data[PROBE_W + ID_W +: 24];
        end
      end
      (ADDR_EVENT_BASE + 8'h08): begin
        if (evt_valid) bus_rdata[7:0] = evt_data[PROBE_W + ID_W + 24 +: 8];
      end
      default: begin end
    endcase
  end
endmodule

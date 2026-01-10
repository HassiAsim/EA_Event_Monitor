`timescale 1ns/1ps

module reg_block_simple #(
  parameter int PROBE_W = 32,
  parameter int ID_W = 8,
  parameter int TS_W = 32,
  parameter int FIFO_DEPTH = 16
)(
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

  output logic evt_pop,
  input logic [TS_W + ID_W + PROBE_W - 1:0] evt_data,
  input logic evt_valid,

  input logic fifo_empty,
  input logic fifo_full,
  input logic [$clog2(FIFO_DEPTH + 1)-1:0] fifo_count,

  input logic triggered_sticky,
  input logic fifo_overflow_sticky
);

  localparam int EVT_W = TS_W + ID_W + PROBE_W;
  localparam int EVT_WORDS = (EVT_W + 31) / 32;

  localparam logic [7:0] ADDR_CONTROL = 8'h00;
  localparam logic [7:0] ADDR_TRIG_VALUE = 8'h04;
  localparam logic [7:0] ADDR_TRIG_MASK = 8'h08;
  localparam logic [7:0] ADDR_STATUS = 8'h0C;
  localparam logic [7:0] ADDR_EVENT_BASE = 8'h10;

  logic [EVT_W-1:0] evt_shadow;
  logic evt_shadow_valid;

  int unsigned word_idx;

  function automatic [31:0] evt_word_at(input int unsigned idx);
    int unsigned lo;
    int unsigned rem;
    begin
      evt_word_at = 32'h0;
      lo = idx * 32;

      if (lo < EVT_W) begin
        rem = EVT_W - lo;
        if (rem >= 32) begin
          evt_word_at = evt_shadow[lo +: 32];
        end else begin
          evt_word_at[rem-1:0] = evt_shadow[lo +: rem];
        end
      end
    end
  endfunction

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      en <= 1'b0;
      arm <= 1'b0;
      trig_mode <= 2'b00;
      trig_value <= '0;
      trig_mask <= '0;

      bus_rdata <= 32'h0;

      evt_pop <= 1'b0;
      evt_shadow <= '0;
      evt_shadow_valid <= 1'b0;
    end else begin
      evt_pop <= 1'b0;

      if (bus_wr) begin
        unique case (bus_addr)
          ADDR_CONTROL: begin
            en <= bus_wdata[0];
            arm <= bus_wdata[1];
            trig_mode <= bus_wdata[3:2];
          end

          ADDR_TRIG_VALUE: begin
            trig_value[31:0] <= bus_wdata;
          end

          ADDR_TRIG_MASK: begin
            trig_mask[31:0] <= bus_wdata;
          end

          default: begin
          end
        endcase
      end

      if (bus_rd) begin
        unique case (bus_addr)
          ADDR_CONTROL: begin
            bus_rdata <= 32'h0;
            bus_rdata[0] <= en;
            bus_rdata[1] <= arm;
            bus_rdata[3:2] <= trig_mode;
          end

          ADDR_TRIG_VALUE: begin
            bus_rdata <= trig_value[31:0];
          end

          ADDR_TRIG_MASK: begin
            bus_rdata <= trig_mask[31:0];
          end

          ADDR_STATUS: begin
            bus_rdata <= 32'h0;
            bus_rdata[0] <= fifo_empty;
            bus_rdata[1] <= fifo_full;
            bus_rdata[15:8] <= fifo_count[7:0];
            bus_rdata[16] <= triggered_sticky;
            bus_rdata[17] <= fifo_overflow_sticky;
          end

          default: begin
            if (bus_addr >= ADDR_EVENT_BASE && bus_addr < (ADDR_EVENT_BASE + EVT_WORDS * 4)) begin
              word_idx = (bus_addr - ADDR_EVENT_BASE) >> 2;

              if (word_idx == 0) begin
                if (evt_valid) begin
                  evt_pop <= 1'b1;
                  evt_shadow <= evt_data;
                  evt_shadow_valid <= 1'b1;
                  bus_rdata <= evt_data[31:0];
                end else begin
                  bus_rdata <= 32'h0;
                end
              end else begin
                if (evt_shadow_valid) begin
                  bus_rdata <= evt_word_at(word_idx);
                end else begin
                  bus_rdata <= 32'h0;
                end
              end
            end else begin
              bus_rdata <= 32'h0;
            end
          end
        endcase
      end
    end
  end

endmodule


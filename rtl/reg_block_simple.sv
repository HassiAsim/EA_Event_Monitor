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
  localparam int FC_W = $clog2(FIFO_DEPTH + 1);

  localparam logic [7:0] ADDR_CONTROL = 8'h00;
  localparam logic [7:0] ADDR_TRIG_VALUE = 8'h04;
  localparam logic [7:0] ADDR_TRIG_MASK = 8'h08;
  localparam logic [7:0] ADDR_STATUS = 8'h0C;
  localparam logic [7:0] ADDR_EVENT_BASE = 8'h10;

  logic [EVT_W-1:0] evt_shadow;
  logic evt_shadow_valid;

  logic [1:0] cap_cnt;

  function automatic [7:0] pack_count8(input logic [FC_W-1:0] fc);
    int i;
    begin
      pack_count8 = 8'h0;
      for (i = 0; i < 8; i = i + 1) begin
        if (i < FC_W) pack_count8[i] = fc[i];
      end
    end
  endfunction

  function automatic [31:0] word_from_vec(input logic [EVT_W-1:0] v, input int unsigned idx);
    int unsigned lo;
    int b;
    begin
      word_from_vec = 32'h0;
      lo = idx * 32;
      for (b = 0; b < 32; b = b + 1) begin
        if ((lo + b) < EVT_W) begin
          word_from_vec[b] = v[lo + b];
        end
      end
    end
  endfunction

  int unsigned word_idx;
  logic have_event;
  logic [EVT_W-1:0] event_vec;
  logic [31:0] r;

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
      cap_cnt <= 2'd0;
    end else begin
      evt_pop <= 1'b0;

      if (cap_cnt != 2'd0) begin
        cap_cnt <= cap_cnt - 2'd1;

        if (cap_cnt == 2'd1) begin
          evt_shadow <= evt_data;
          evt_shadow_valid <= 1'b1;
        end
      end

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
        r = 32'h0;

        unique case (bus_addr)
          ADDR_CONTROL: begin
            r[0] = en;
            r[1] = arm;
            r[3:2] = trig_mode;
            bus_rdata <= r;
          end

          ADDR_TRIG_VALUE: begin
            bus_rdata <= trig_value[31:0];
          end

          ADDR_TRIG_MASK: begin
            bus_rdata <= trig_mask[31:0];
          end

          ADDR_STATUS: begin
            r[0] = fifo_empty;
            r[1] = fifo_full;
            r[15:8] = pack_count8(fifo_count);
            r[16] = triggered_sticky;
            r[17] = fifo_overflow_sticky;
            bus_rdata <= r;
          end

          default: begin
            if (bus_addr >= ADDR_EVENT_BASE && bus_addr < (ADDR_EVENT_BASE + EVT_WORDS * 4)) begin
              word_idx = (bus_addr - ADDR_EVENT_BASE) >> 2;

              have_event = evt_shadow_valid || (cap_cnt == 2'd1);
              event_vec = evt_shadow_valid ? evt_shadow : evt_data;

              if (word_idx == 0) begin
                if (have_event) begin
                  bus_rdata <= word_from_vec(event_vec, 0);
                end else if (evt_valid && (cap_cnt == 2'd0)) begin
                  evt_pop <= 1'b1;
                  cap_cnt <= 2'd2;
                  bus_rdata <= 32'h0;
                end else begin
                  bus_rdata <= 32'h0;
                end
              end else begin
                if (have_event) begin
                  bus_rdata <= word_from_vec(event_vec, word_idx);

                  if (word_idx == (EVT_WORDS - 1)) begin
                    evt_shadow_valid <= 1'b0;
                  end
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





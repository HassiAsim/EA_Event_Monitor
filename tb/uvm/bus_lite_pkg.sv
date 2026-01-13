`timescale 1ns/1ps

package bus_lite_pkg;

  typedef enum int {BUS_READ = 0, BUS_WRITE = 1} bus_op_e;

  typedef struct packed {
    logic [31:0] word0;
    logic [7:0]  pid;
  } exp_event_t;

  class bus_txn;
    bus_op_e op;
    logic [7:0]  addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    function new(bus_op_e op = BUS_READ, logic [7:0] addr = '0, logic [31:0] wdata = '0);
      this.op    = op;
      this.addr  = addr;
      this.wdata = wdata;
      this.rdata = '0;
    endfunction
  endclass

  class bus_driver;
    virtual simple_bus_if.tb vif;
    mailbox #(bus_txn) req_mbx;
    mailbox #(bus_txn) rsp_mbx;

    function new(virtual simple_bus_if.tb vif, mailbox #(bus_txn) req_mbx, mailbox #(bus_txn) rsp_mbx);
      this.vif     = vif;
      this.req_mbx = req_mbx;
      this.rsp_mbx = rsp_mbx;
    endfunction

    task run();
      bus_txn tr;
      forever begin
        req_mbx.get(tr);
        if (tr.op == BUS_WRITE) begin
          vif.write32(tr.addr, tr.wdata);
        end else begin
          vif.read32(tr.addr, tr.rdata);
        end
        rsp_mbx.put(tr);
      end
    endtask
  endclass

  class bus_monitor;
    virtual simple_bus_if.tb vif;
    mailbox #(bus_txn) mon_mbx;

    bit        pend_rd;
    logic [7:0] pend_addr;

    function new(virtual simple_bus_if.tb vif, mailbox #(bus_txn) mon_mbx);
      this.vif     = vif;
      this.mon_mbx = mon_mbx;
      pend_rd      = 0;
      pend_addr    = '0;
    endfunction

    task run();
      bus_txn tr;
      forever begin
        @(posedge vif.clk);
        #1ps;

        if (pend_rd) begin
          tr = new(BUS_READ, pend_addr, 32'h0);
          tr.rdata = vif.rdata;
          mon_mbx.put(tr);
          pend_rd = 0;
        end

        if (vif.wr) begin
          tr = new(BUS_WRITE, vif.addr, vif.wdata);
          mon_mbx.put(tr);
        end

        if (vif.rd) begin
          pend_rd   = 1;
          pend_addr = vif.addr;
        end
      end
    endtask
  endclass

  class scoreboard_lite;
    mailbox #(bus_txn) mon_mbx;
    mailbox #(exp_event_t) exp_evt_mbx;

    localparam logic [7:0] ADDR_CONTROL    = 8'h00;
    localparam logic [7:0] ADDR_TRIG_VALUE = 8'h04;
    localparam logic [7:0] ADDR_TRIG_MASK  = 8'h08;
    localparam logic [7:0] ADDR_STATUS     = 8'h0C;
    localparam logic [7:0] ADDR_EVENT_BASE = 8'h10;

    bit        exp_en;
    bit        exp_arm;
    logic [1:0] exp_trig_mode;
    logic [31:0] exp_trig_value32;
    logic [31:0] exp_trig_mask32;

    bit saw_triggered_sticky;
    bit saw_overflow_sticky;

    bit        have_evt_hold;
    logic [7:0] evt_pid_hold;

    function new(mailbox #(bus_txn) mon_mbx, mailbox #(exp_event_t) exp_evt_mbx);
      this.mon_mbx     = mon_mbx;
      this.exp_evt_mbx = exp_evt_mbx;

      exp_en           = 0;
      exp_arm          = 0;
      exp_trig_mode    = 2'b00;
      exp_trig_value32 = 32'h0;
      exp_trig_mask32  = 32'h0;

      saw_triggered_sticky = 0;
      saw_overflow_sticky  = 0;

      have_evt_hold = 0;
      evt_pid_hold  = '0;
    endfunction

    task run();
      bus_txn tr;
      forever begin
        mon_mbx.get(tr);

        if (tr.op == BUS_WRITE) begin
          if (tr.addr == ADDR_CONTROL) begin
            exp_en        = tr.wdata[0];
            exp_arm       = tr.wdata[1];
            exp_trig_mode = tr.wdata[3:2];
          end else if (tr.addr == ADDR_TRIG_VALUE) begin
            exp_trig_value32 = tr.wdata;
          end else if (tr.addr == ADDR_TRIG_MASK) begin
            exp_trig_mask32 = tr.wdata;
          end
        end

        if (tr.op == BUS_READ) begin
          if (tr.addr == ADDR_CONTROL) begin
            if (tr.rdata[0]   !== exp_en)        $fatal(1, "CONTROL.en readback mismatch exp=%0d got=%0d", exp_en, tr.rdata[0]);
            if (tr.rdata[1]   !== exp_arm)       $fatal(1, "CONTROL.arm readback mismatch exp=%0d got=%0d", exp_arm, tr.rdata[1]);
            if (tr.rdata[3:2] !== exp_trig_mode) $fatal(1, "CONTROL.mode readback mismatch exp=%0d got=%0d", exp_trig_mode, tr.rdata[3:2]);

          end else if (tr.addr == ADDR_TRIG_VALUE) begin
            if (tr.rdata !== exp_trig_value32) $fatal(1, "TRIG_VALUE readback mismatch exp=%h got=%h", exp_trig_value32, tr.rdata);

          end else if (tr.addr == ADDR_TRIG_MASK) begin
            if (tr.rdata !== exp_trig_mask32) $fatal(1, "TRIG_MASK readback mismatch exp=%h got=%h", exp_trig_mask32, tr.rdata);

          end else if (tr.addr == ADDR_STATUS) begin
            if (tr.rdata[16]) saw_triggered_sticky = 1;
            if (tr.rdata[17]) saw_overflow_sticky  = 1;

            if (saw_triggered_sticky && (tr.rdata[16] !== 1'b1)) $fatal(1, "triggered_sticky cleared unexpectedly");
            if (saw_overflow_sticky  && (tr.rdata[17] !== 1'b1)) $fatal(1, "fifo_overflow_sticky cleared unexpectedly");

          end else if (tr.addr == ADDR_EVENT_BASE) begin
            exp_event_t exp;
            if (exp_evt_mbx.try_get(exp)) begin
              if (tr.rdata !== exp.word0) $fatal(1, "EVENT word0 mismatch exp=%h got=%h", exp.word0, tr.rdata);
              evt_pid_hold  = exp.pid;
              have_evt_hold = 1;
            end else begin
              $fatal(1, "EVENT word0 read but no expected event queued");
            end

          end else if (tr.addr == (ADDR_EVENT_BASE + 8'h04)) begin
            if (have_evt_hold) begin
              if (tr.rdata[7:0] !== evt_pid_hold) $fatal(1, "EVENT word1 pid mismatch exp=%h got=%h", evt_pid_hold, tr.rdata[7:0]);
              have_evt_hold = 0;
            end
          end
        end
      end
    endtask
  endclass

  class env_lite;
    virtual simple_bus_if.tb vif;

    mailbox #(bus_txn) req_mbx;
    mailbox #(bus_txn) rsp_mbx;
    mailbox #(bus_txn) mon_mbx;
    mailbox #(exp_event_t) exp_evt_mbx;

    bus_driver      drv;
    bus_monitor     mon;
    scoreboard_lite sb;

    function new(virtual simple_bus_if.tb vif, mailbox #(exp_event_t) exp_evt_mbx);
      this.vif         = vif;
      this.exp_evt_mbx = exp_evt_mbx;

      req_mbx = new();
      rsp_mbx = new();
      mon_mbx = new();

      drv = new(vif, req_mbx, rsp_mbx);
      mon = new(vif, mon_mbx);
      sb  = new(mon_mbx, exp_evt_mbx);
    endfunction

    task start();
      fork
        drv.run();
        mon.run();
        sb.run();
      join_none
    endtask

    task write32(input logic [7:0] a, input logic [31:0] d);
      bus_txn tr;
      tr = new(BUS_WRITE, a, d);
      req_mbx.put(tr);
      rsp_mbx.get(tr);
    endtask

    task read32(input logic [7:0] a, output logic [31:0] d);
      bus_txn tr;
      tr = new(BUS_READ, a, 32'h0);
      req_mbx.put(tr);
      rsp_mbx.get(tr);
      d = tr.rdata;
    endtask
  endclass

endpackage

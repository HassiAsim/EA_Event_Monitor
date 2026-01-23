`timescale 1ns/1ps

module tb_top_bus_uvm_lite;

  import bus_lite_pkg::*;

  // coverage_collector cov;

  localparam int PROBE_W = 32;
  localparam int ID_W = 8;
  localparam int TS_W = 32;
  localparam int FIFO_DEPTH = 4;

  localparam logic [7:0] ADDR_CONTROL    = 8'h00;
  localparam logic [7:0] ADDR_TRIG_VALUE  = 8'h04;
  localparam logic [7:0] ADDR_TRIG_MASK   = 8'h08;
  localparam logic [7:0] ADDR_STATUS      = 8'h0C;
  localparam logic [7:0] ADDR_EVENT_BASE  = 8'h10;

  logic clk;
  logic rst_n;

  logic [ID_W-1:0] probe_id;
  logic [PROBE_W-1:0] probe_data;

  simple_bus_if bus_if(.clk(clk));

  event_monitor_top #(
    .PROBE_W(PROBE_W),
    .ID_W(ID_W),
    .TS_W(TS_W),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .probe_id(probe_id),
    .probe_data(probe_data),
    .bus_wr(bus_if.wr),
    .bus_rd(bus_if.rd),
    .bus_addr(bus_if.addr),
    .bus_wdata(bus_if.wdata),
    .bus_rdata(bus_if.rdata)
  );

  mailbox #(exp_event_t) exp_evt_mbx;
  env_lite env;

  bit sh_en;
  bit sh_arm;
  logic [1:0] sh_trig_mode;
  logic [PROBE_W-1:0] sh_trig_value;
  logic [PROBE_W-1:0] sh_trig_mask;

  logic [PROBE_W-1:0] sh_masked_probe_d;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic bus_write(input logic [7:0] a, input logic [31:0] d);
    env.write32(a, d);

    if (a == ADDR_CONTROL) begin
      sh_en = d[0];
      sh_arm = d[1];
      sh_trig_mode = d[3:2];
    end else if (a == ADDR_TRIG_VALUE) begin
      sh_trig_value[31:0] = d;
    end else if (a == ADDR_TRIG_MASK) begin
      sh_trig_mask[31:0] = d;
    end
  endtask

  task automatic bus_read(input logic [7:0] a, output logic [31:0] d);
    env.read32(a, d);
  endtask

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      sh_masked_probe_d <= '0;
    end else begin
      logic [PROBE_W-1:0] mp;
      logic [PROBE_W-1:0] mv;
      bit hit;

      mp = probe_data & sh_trig_mask;
      mv = sh_trig_value & sh_trig_mask;

      hit = 0;
      if (sh_trig_mode == 2'd0) begin
        hit = (mp == mv);
      end else if (sh_trig_mode == 2'd1) begin
        hit = ((sh_masked_probe_d == '0) && (mp != '0));
      end

      if (sh_en && sh_arm && hit) begin
        exp_event_t e;
        e.word0 = probe_data[31:0];
        e.pid = probe_id;
        exp_evt_mbx.put(e);
      end

      sh_masked_probe_d <= mp;
    end
  end

  task automatic test_level_basic();
    logic [31:0] r;

    probe_id = 8'hA5;
    probe_data = 32'h0;

    bus_write(ADDR_TRIG_MASK, 32'hFFFF_FFFF);
    bus_write(ADDR_TRIG_VALUE, 32'h0000_1234);
    bus_write(ADDR_CONTROL, 32'h0000_0003);

    @(negedge clk);
    probe_data = 32'h0000_1234; // Trigger High
    @(negedge clk);
    probe_data = 32'h0000_0000; // Trigger Low (Stop filling the FIFO!)

    repeat (2) @(posedge clk);;

    bus_read(ADDR_STATUS, r);
    if (r[16] !== 1'b1) $fatal(1, "Expected triggered_sticky=1");

    bus_read(ADDR_EVENT_BASE, r);
    if (r !== 32'h0000_1234) $fatal(1, "EVENT word0 exp=00001234 got=%h", r);

    bus_read(ADDR_EVENT_BASE + 8'h04, r);
    if (r[7:0] !== 8'hA5) $fatal(1, "EVENT word1 pid mismatch exp=A5 got=%h", r[7:0]);

    $display("TEST LEVEL_BASIC PASSED");
  endtask

  task automatic test_rise_basic();
    logic [31:0] r;

    probe_id = 8'h3C;
    probe_data = 32'h0;

    bus_write(ADDR_TRIG_MASK, 32'hFFFF_FFFF);
    bus_write(ADDR_TRIG_VALUE, 32'h0);
    bus_write(ADDR_CONTROL, 32'h0000_0007);

    @(negedge clk);
    probe_data = 32'h0000_0000;
    @(negedge clk);
    probe_data = 32'h0000_0001;

    repeat (2) @(posedge clk);

    bus_read(ADDR_STATUS, r);
    if (r[16] !== 1'b1) $fatal(1, "Expected triggered_sticky=1 in rise test");

    bus_read(ADDR_EVENT_BASE, r);
    if (r !== 32'h0000_0001) $fatal(1, "EVENT word0 exp=00000001 got=%h", r);

    bus_read(ADDR_EVENT_BASE + 8'h04, r);
    if (r[7:0] !== 8'h3C) $fatal(1, "EVENT word1 pid mismatch exp=3C got=%h", r[7:0]);

    $display("TEST RISE_BASIC PASSED");
  endtask

  task automatic test_overflow_sticky();
    logic [31:0] r;
    int i;

    probe_id = 8'h11;
    probe_data = 32'h0; // Start clean

    bus_write(ADDR_TRIG_MASK, 32'hFFFF_FFFF);
    bus_write(ADDR_TRIG_VALUE, 32'h0000_1234);
    bus_write(ADDR_CONTROL, 32'h0000_0003);

    // 1. TURN OFF SVA ALARM
    // We target the specific instance: dut -> u_core -> u_fifo -> a_no_overflow_loss
    $assertoff(0, tb_top_bus_uvm_lite.dut.u_core.u_fifo.a_no_overflow_loss);

    // 2. FILL THE FIFO UNTIL IT BURSTS
    for (i = 0; i < (FIFO_DEPTH + 2); i++) begin
      @(negedge clk);
      probe_data = 32'h0000_1234;
      @(negedge clk);
      probe_data = 32'h0; // Pulse it to create distinct events
    end
    
    // Wait for the chaos to settle
    repeat(2) @(posedge clk);

    // 3. TURN ALARM BACK ON
    $asserton(0, tb_top_bus_uvm_lite.dut.u_core.u_fifo.a_no_overflow_loss);

    bus_read(ADDR_STATUS, r);
    if (r[17] !== 1'b1) $fatal(1, "Expected fifo_overflow_sticky=1");

    $display("TEST OVERFLOW_STICKY PASSED");
  endtask

  task automatic test_event_multiword();
    logic [31:0] w0;
    logic [31:0] w1;
    logic [31:0] w2;

    probe_id = 8'h7E;
    probe_data = 32'h0; // Start clean!

    bus_write(ADDR_TRIG_MASK, 32'hFFFF_FFFF);
    bus_write(ADDR_TRIG_VALUE, 32'hDEAD_BEEF);
    bus_write(ADDR_CONTROL, 32'h0000_0003);

    // Pulse the data ONCE
    @(negedge clk);
    probe_data = 32'hDEAD_BEEF;
    @(negedge clk);
    probe_data = 32'h0; // Clear it so we don't fill the FIFO

    repeat (4) @(posedge clk);

    bus_read(ADDR_EVENT_BASE, w0);
    bus_read(ADDR_EVENT_BASE + 8'h04, w1);
    bus_read(ADDR_EVENT_BASE + 8'h08, w2);

    if (w0 !== 32'hDEAD_BEEF) $fatal(1, "word0 exp=DEADBEEF got=%h", w0);
    if (w1[7:0] !== 8'h7E) $fatal(1, "word1 pid exp=7E got=%h", w1[7:0]);
    if (^w2 === 1'bx) $fatal(1, "word2 has X");

    $display("TEST EVENT_MULTIWORD PASSED");
  endtask

  task automatic run_selected_test(input string name);
    if (name == "LEVEL_BASIC") begin
      test_level_basic();
    end else if (name == "RISE_BASIC") begin
      test_rise_basic();
    end else if (name == "EVENT_MULTIWORD") begin
      test_event_multiword();
    end else if (name == "OVERFLOW_STICKY") begin
      test_overflow_sticky();
    end else begin
      $fatal(1, "Unknown +TEST=%s", name);
    end
  endtask

  initial begin
    string tname;

    exp_evt_mbx = new();

    rst_n = 1'b0;
    probe_id = '0;
    probe_data = '0;

    sh_en = 0;
    sh_arm = 0;
    sh_trig_mode = 2'b00;
    sh_trig_value = '0;
    sh_trig_mask = '0;

    bus_if.reset_signals();

    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    env = new(bus_if, exp_evt_mbx);
    //cov = new();
    env.start();

    if (!$value$plusargs("TEST=%s", tname)) tname = "LEVEL_BASIC";

    $display("===================================");
    $display("RUNNING TEST: %s", tname);
    $display("===================================");

    run_selected_test(tname);

    $display("tb_top_bus_uvm_lite DONE");
    $finish;
  end

  // Coverage Sampling Block
  /*
  always @(posedge clk) begin
    if (cov != null) begin
      // We peek into the DUT signals directly (Whitebox Coverage)
      cov.sample(
        dut.u_regs.trig_mode,
        dut.u_core.fifo_full,
        dut.u_core.fifo_overflow_sticky
      );
    end
  end
  */

endmodule

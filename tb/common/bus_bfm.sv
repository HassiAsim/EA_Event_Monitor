`timescale 1ns/1ps

interface simple_bus_if(input logic clk);
  logic wr;
  logic rd;
  logic [7:0] addr;
  logic [31:0] wdata;
  logic [31:0] rdata;

  task automatic idle();
    wr = 1'b0;
    rd = 1'b0;
    addr = '0;
    wdata = '0;
  endtask

  task automatic write(input logic [7:0] a, input logic [31:0] d);
    @(negedge clk);
    addr = a;
    wdata = d;
    wr = 1'b1;
    rd = 1'b0;

    @(posedge clk);
    #1ps;
    wr = 1'b0;
  endtask

  task automatic read(input logic [7:0] a, output logic [31:0] d);
    @(negedge clk);
    addr = a;
    wr = 1'b0;
    rd = 1'b1;

    @(posedge clk);
    #1ps;
    d = rdata;

    @(negedge clk);
    rd = 1'b0;
  endtask

  modport dut(
    input wr,
    input rd,
    input addr,
    input wdata,
    output rdata
  );

  modport tb(
    output wr,
    output rd,
    output addr,
    output wdata,
    input rdata,
    import idle,
    import write,
    import read
  );
endinterface


`timescale 1ns / 1ps

module mac_tb;

  localparam WIDTH = 32;

  logic clk;
  logic rst_n;
  logic en;
  logic clr;
  logic [WIDTH-1:0] a;
  logic [WIDTH-1:0] b;
  logic [2*WIDTH-1:0] acc_out;

  mac #(.WIDTH(WIDTH)) mac_inst (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .clr(clr),
    .a(a),
    .b(b),
    .acc_out(acc_out)
  );

  // Clock generation
  always #5 clk = ~clk;

  initial begin
    $display("Starting MAC Unit Testbench");

    clk = 0;
    rst_n = 0;
    en = 0;
    clr = 0;
    a = 0;
    b = 0;

    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);
    rst_n = 1;
    #10;

    // First multiply-accumulate
    a = 3;
    b = 4;
    en = 1;
    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);

    // Second accumulate
    a = 2;
    b = 5;
    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);

    // Disable enable
    a = 1;
    b = 5;
    en = 0;
    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);

    // Clear the accumulator
    clr = 1;
    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);
    clr = 0;

    // Another multiply-accumulate
    a = 6;
    b = 7;
    en = 1;
    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);

    en = 0;
    #10;
    $display("a = %0d, b = %0d, acc = %0d, en = %b, clr = %b, rst_n = %b", a, b, acc_out, en, clr, rst_n);

    $display("Final acc_out = %0d", acc_out);
    $finish;
  end

endmodule

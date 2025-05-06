`timescale 1ns / 1ps

module adder_4bit_conv_unsign_tb;

  logic [3:0] x, y;
  logic [4:0] z;

  adder_4bit_conv_unsign aadder_4bit_conv_unsign_inst (
	  x,
	  y,
	  z
  );

  initial begin
    x = 4'b0000;
    y = 4'b0000;
    #10;
    $display("x = %b, y = %b, z = %b", x, y, z);
    x = 4'b0000;
    y = 4'b0001;
    #10;
    $display("x = %b, y = %b, z = %b", x, y, z);
    x = 4'b0001;
    y = 4'b0000;
    #10;
    $display("x = %b, y = %b, z = %b", x, y, z);
    x = 4'b0001;
    y = 4'b0001;
    #10;
    $display("x = %b, y = %b, z = %b", x, y, z);
    #10;
    $finish;
  end

endmodule

// SPDX-License-Identifier: BSD-3-Clause
/*
 * Simple binary to ASCII hexadecimal encoder
 *
 * Copyright (C) 2023 Luís Mendes <luis.p.mendes@gmail.com>
 */
module hexEncoderUnit (nibble, nibbleChar);
//input clk;
input  [3:0] nibble;
output [7:0] nibbleChar;

logic  [7:0] encodedChar;

always @ *
begin
unique case(nibble)
  4'b0000 : encodedChar = "0";
  4'b0001 : encodedChar = "1";
  4'b0010 : encodedChar = "2";
  4'b0011 : encodedChar = "3";
  4'b0100 : encodedChar = "4";
  4'b0101 : encodedChar = "5";
  4'b0110 : encodedChar = "6";
  4'b0111 : encodedChar = "7";
  4'b1000 : encodedChar = "8";
  4'b1001 : encodedChar = "9";
  4'b1010 : encodedChar = "a";
  4'b1011 : encodedChar = "b";
  4'b1100 : encodedChar = "c";
  4'b1101 : encodedChar = "d";
  4'b1110 : encodedChar = "e";
  default : encodedChar = "f";
endcase;
end;

assign nibbleChar = encodedChar;

endmodule
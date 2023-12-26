// SPDX-License-Identifier: BSD-3-Clause
/*
 * Simple ASCII hexadecimal to binary decoder
 *
 * Copyright (C) 2023 Luís Mendes  <luis.p.mendes@gmail.com>
 */
module hexDecoderUnit(clk, nibbleChar, nibble, error);
input clk;
input [7:0] nibbleChar;
output [3:0] nibble;
output error;

logic [3:0] nibbleValue;
logic valueError;

always @(posedge clk)
begin
valueError = 1'b0;
unique case (nibbleChar)
   "0" : nibbleValue = 4'b0000;
   "1" : nibbleValue = 4'b0001;
   "2" : nibbleValue = 4'b0010;
   "3" : nibbleValue = 4'b0011;
   "4" : nibbleValue = 4'b0100;
   "5" : nibbleValue = 4'b0101;
   "6" : nibbleValue = 4'b0110;
   "7" : nibbleValue = 4'b0111;
   "8" : nibbleValue = 4'b1000;
   "9" : nibbleValue = 4'b1001;
   "a" : nibbleValue = 4'b1010;
   "b" : nibbleValue = 4'b1011;
   "c" : nibbleValue = 4'b1100;
   "d" : nibbleValue = 4'b1101;
   "e" : nibbleValue = 4'b1110;
   "f" : nibbleValue = 4'b1111;
   "A" : nibbleValue = 4'b1010;
   "B" : nibbleValue = 4'b1011;
   "C" : nibbleValue = 4'b1100;
   "D" : nibbleValue = 4'b1101;
   "E" : nibbleValue = 4'b1110;
   "F" : nibbleValue = 4'b1111;
 default : valueError = 1'b1;
endcase;
end;

assign error = valueError;
assign nibble = nibbleValue;

endmodule
// SPDX-License-Identifier: BSD-3-Clause
/*
 * A Test pattern generator
 *
 * Copyright (C) 2023 Luís Mendes
 */
module PatternGenerator (
   input pixelClk,
   input vs,
   input de,
   input [9:0] pixelsX,
   input [9:0] pixelsY,
   output reg [7:0] r,
   output reg [7:0] g,
   output reg [7:0] b
);

reg lastVS;
reg startOfFrame;
always @(posedge pixelClk) begin
   lastVS <= vs;
   if (lastVS == 1'b0 && vs == 1'b1)
      startOfFrame <= 1'b1;
   else
      startOfFrame <= 1'b0;
   

   if (de) begin
      //Assume a default dark gray background 
      r <= 8'h20;
      g <= 8'h20;
      b <= 8'h20;

      //Draw left vertical bar with Red
      if (pixelsX < 20 && (pixelsY >= 20 && pixelsY < 600-20)) begin
         r <= 8'hff;
         g <= 8'h00;
         b <= 8'h00;
      end
      //Draw right vertical bar with Green
      if (pixelsX >= 800 - 20 && (pixelsY >= 20 && pixelsY < 600-20)) begin
         r <= 8'h00;
         g <= 8'hff;
         b <= 8'h00;
      end
      //Draw top and bottom horizontal lines with Blue
      if (pixelsY < 20 || pixelsY >= 600 - 20) begin
         r <= 8'h00;
         g <= 8'h00;
         b <= 8'hff;
      end
      //Draw center box in white
      if (pixelsX >= 400 - 10 && pixelsX <= 400 + 10 &&
          pixelsY >= 300 - 10 && pixelsY <= 300 + 10) begin
         r <= 8'hff;
         g <= 8'hff;
         b <= 8'hff;
      end
   end
end

endmodule

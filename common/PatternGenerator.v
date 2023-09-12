// SPDX-License-Identifier: BSD-3-Clause
/*
 * A Test pattern generator
 *
 * Copyright (C) 2023 Luís Mendes
 */
module PatternGenerator #(
   parameter WIDTH = 800,
   parameter HEIGHT = 600
)
(
   input pixelClk,
   input vs,
   input de,
   input [9:0] pixelsX,
   input [9:0] pixelsY,
   output reg [7:0] r,
   output reg [7:0] g,
   output reg [7:0] b
);

localparam HALF_WIDTH = WIDTH / 2;
localparam HALF_HEIGHT = HEIGHT / 2;

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
      r = 8'h20;
      g = 8'h20;
      b = 8'h20;

      //Draw left vertical bar with Red
      if (pixelsX < 20 && (pixelsY >= 20 && pixelsY < HEIGHT-20)) begin
         r = 8'hff;
         g = 8'h00;
         b = 8'h00;
      end
      //Draw right vertical bar with Green
      if (pixelsX >= WIDTH - 20 && (pixelsY >= 20 && pixelsY < HEIGHT-20)) begin
         r = 8'h00;
         g = 8'hff;
         b = 8'h00;
      end
      //Draw top and bottom horizontal lines with Blue
      if (pixelsY < 20 || pixelsY >= HEIGHT - 20) begin
         r = 8'h00;
         g = 8'h00;
         b = 8'hff;
      end
      //Draw center box in white
      if (pixelsX >= HALF_WIDTH - 10 && pixelsX <= HALF_WIDTH + 10 &&
          pixelsY >= HALF_HEIGHT - 10 && pixelsY <= HALF_HEIGHT + 10) begin
         r = 8'hff;
         g = 8'hff;
         b = 8'hff;
      end         
   end
   else begin
      //It is very important for VGA to work properly, otherwise it won't know when it is blanking      
      r = 8'h00;   
      g = 8'h00;      
      b = 8'h00;     
   end
end

endmodule

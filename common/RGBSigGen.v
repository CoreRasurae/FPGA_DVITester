// SPDX-License-Identifier: BSD-3-Clause
/*
 * A RGB Signal timing Generator
 *
 * Copyright (C) 2023 Luís Mendes
 */
module RGBSigGen #(
parameter VSYNC_COUNT   = 4,
parameter HSYNC_COUNT   = 128,
parameter FRONT_PORCH_V = 1,
parameter BACK_PORCH_V  = 14,
parameter PIXELS_V      = 600,
parameter FRONT_PORCH_H = 32,
parameter BACK_PORCH_H  = 128,
parameter PIXELS_H      = 800,
parameter CLOCK_ADJ     = 38400.0/38100.0
)
(
   input pixelClk,
   output reg hs,
   output reg vs,
   output reg de,
   //----------
   input enable,
   output stopped,
   output reg [9:0] pixelX,
   output reg [9:0] pixelY
);

initial de = 1'b0;
initial vs = 1'b1;
initial hs = 1'b1;
initial pixelX = 10'h000;
initial pixelY = 10'h000;

localparam FRONT_PORCH_H_ADJ = $floor(FRONT_PORCH_H * CLOCK_ADJ);
localparam BACK_PORCH_H_ADJ  = $floor(BACK_PORCH_H * CLOCK_ADJ);
localparam HSYNC_COUNT_ADJ   = $floor(HSYNC_COUNT * CLOCK_ADJ);

localparam MAX_PIXELS_H = HSYNC_COUNT_ADJ + BACK_PORCH_H_ADJ + PIXELS_H + FRONT_PORCH_H_ADJ;
localparam MAX_PIXELS_V = VSYNC_COUNT + BACK_PORCH_V + PIXELS_V + FRONT_PORCH_V;

reg [11:0] counterH = 12'h000;
reg [11:0] counterV = 12'h000;
reg complete = 1'b1;
reg working = 1'b0, lastWorking = 1'b0;

assign stopped = !working;

always @ (posedge pixelClk) begin
   if (enable && complete) begin
      complete <= 1'b0;
      working <= 1'b1;
   end
   else if (!enable && complete) begin
      working <= 1'b0;
   end
      
   lastWorking <= working;
   if (working) begin
      if (counterV < VSYNC_COUNT-1 || (counterV == MAX_PIXELS_V - 1 && counterH == MAX_PIXELS_H - 1)) begin
         vs <= 1'b0;
         complete <= 1'b0;
         pixelX <= 10'h000;
         pixelY <= 10'h000;
      end
      else if (counterV >= VSYNC_COUNT-1 && counterH == MAX_PIXELS_H - 1)
         vs <= 1'b1;

      if (counterH < HSYNC_COUNT_ADJ-1 || counterH == MAX_PIXELS_H - 1)
         hs <= 1'b0;
      else if (counterH >= HSYNC_COUNT_ADJ-1) begin
         hs <= 1'b1;
      end
                  
      if (lastWorking) begin
         if (counterH < MAX_PIXELS_H - 1)
            counterH <= counterH + 1;
         else begin
            if (counterV < MAX_PIXELS_V - 1) begin
               counterV <= counterV + 1;
            end
            else begin
               counterV <= 0;
               complete <= 1;
            end
            counterH <= 12'h000;
         end         
      end

      if (counterH >= (HSYNC_COUNT_ADJ + BACK_PORCH_H_ADJ) && counterH < (HSYNC_COUNT_ADJ + BACK_PORCH_H_ADJ + PIXELS_H) &&
          counterV >= (VSYNC_COUNT + BACK_PORCH_V) && counterV < (VSYNC_COUNT + BACK_PORCH_V + PIXELS_V))
         de <= 1'b1;
      else
         de <= 1'b0;
      

      if (de) begin
         //Data is valid, so lets increment the pixels counters
         if (counterH >= (HSYNC_COUNT_ADJ + BACK_PORCH_H_ADJ) && counterH < (HSYNC_COUNT_ADJ + BACK_PORCH_H_ADJ + PIXELS_H))
            pixelX <= pixelX + 1;
         else begin
            pixelX <= 0;         
            if (pixelY < PIXELS_V-1)
               pixelY <= pixelY + 1;            
            else               
               pixelY <= 10'h000;
         end            
      end
   end
end

endmodule

module top(
  input        sys_clk, //27MHz
  output wire [3:0] vga_r,  
  output wire [3:0] vga_g,  
  output wire [3:0] vga_b,  
  output wire vga_hs,  
  output wire vga_vs
);

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire [9:0] pixelPosX;
wire [9:0] pixelPosY;
wire pixelClk, pixelClkX5;
wire hsync, vsync, dataEn;

wire clk192, clk38_4;
wire locked;

assign pixelClk = clk38_4;
assign pixelClkX5 = clk192;

pll myPLL(
   .refclk(sys_clk),
   .reset(1'b0),
   .extlock(locked),
   .clk0_out(clk192),   
   .clk1_out(clk38_4));


RGBSigGen rgbSigGen (
   .pixelClk(pixelClk),
   .hs(hsync),
   .vs(vsync),
   .de(dataEn),
   .enable(locked),
   .stopped(),
   .pixelX(pixelPosX),
   .pixelY(pixelPosY)
);

PatternGenerator pg (
   .pixelClk(pixelClk),
   .vs(vsync),
   .de(dataEn),
   .pixelsX(pixelPosX),
   .pixelsY(pixelPosY),
   .r(red),
   .g(green),
   .b(blue)
);

assign vga_r  = red[7:4];
assign vga_g  = green[7:4];
assign vga_b  = blue[7:4];
assign vga_hs = hsync;
assign vga_vs = vsync;

endmodule
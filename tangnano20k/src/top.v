// SPDX-License-Identifier: BSD-3-Clause
/*
 * Display HDMI/DVI test pattern on the Tang Nano 20K HDMI conector at 800x600 56Hz resolution
 *
 * Copyright (C) 2023 Luís Mendes
 */

module top(
  input        sys_clk, //27MHz
  input        resetn,
  input        uart_rx_i,
  output       uart_tx_o,
  output [4:0] leds,
  output       tmds_clk_n,
  output       tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
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

Gowin_rPLL pll192(
   .clkout(clk192), //output clkout
   .lock(locked), //output lock
   .clkin(sys_clk) //input clkin
);

Gowin_CLKDIV5 div38_4(
   .clkout(clk38_4), //output clkout
   .hclkin(clk192), //input hclkin
   .resetn(locked) //input resetn
);

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

wire reset;
AsyncMetaReset asyncRstUnit (
   .clk(pixelClk),
   .rstIn(~resetn),
   .rstOut(reset)
);

assign leds[4] = 1'b0;

RGB_Debug #(.hasDELine(1)) rgbDebugUnit (
   .CLK(sys_clk),
   .serialError_n(leds[3]),
   .uart_rx_act_n(leds[1]),
   .uart_tx_act_n(leds[0]),
   .uart_rx_i(uart_rx_i),
   .uart_tx_o(uart_tx_o),
   .VGA_CLK(pixelClk),
   .VGA_HS(hsync),
   .VGA_VS(vsync),
   .VGA_DE(dataEn),
   .VGA_R(red),
   .VGA_G(green),
   .VGA_B(blue)
);

rgb2dvi myDVI (
      .TMDS_Clk_p(tmds_clk_p),
      .TMDS_Clk_n(tmds_clk_n),
      .TMDS_Data_p(tmds_d_p),
      .TMDS_Data_n(tmds_d_n),      
      .aRst(!locked),
      .aRst_n(locked),
      .vid_pData({red, blue, green}),
      .vid_pVDE(dataEn),
      .vid_pHSync(hsync),
      .vid_pVSync(vsync),
      .PixelClk(pixelClk),      
      .SerialClk(pixelClkX5)
);

endmodule

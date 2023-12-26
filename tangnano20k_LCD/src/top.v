// SPDX-License-Identifier: BSD-3-Clause
/*
 * Display test pattern on the Tang Nano 20K with a 5.0" LCD (800x480 resolution)
 *
 * Copyright (C) 2023 Luís Mendes
 */
module top(
  input        sys_clk, //27MHz
  input        resetn,
  input        uart_rx_i,
  output       uart_tx_o,
  output [4:0] leds,
  output       LCD_CLK,
  output       LCD_HS,
  output       LCD_VS,
  output       LCD_DE,
  output       LCD_BL,
  output [4:0] LCD_R,
  output [5:0] LCD_G,
  output [4:0] LCD_B
);

wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire [9:0] pixelPosX;
wire [9:0] pixelPosY;
wire pixelClk, pixelClkX5;
wire hsync, vsync, dataEn;

wire clk33;
wire locked;

assign pixelClk = clk33;

Gowin_rPLL pll33(
   .clkout(clk33), //output clkout
   .lock(locked), //output lock
   .clkin(sys_clk) //input clkin
);

RGBSigGen #(
   .VSYNC_COUNT(3),
   .HSYNC_COUNT(2),
   .FRONT_PORCH_V(22),
   .BACK_PORCH_V(23),
   .PIXELS_V(480),
   .FRONT_PORCH_H(46),
   .BACK_PORCH_H(210),
   .PIXELS_H(800),
   .CLOCK_ADJ(33000.0/33333.0)
) rgbSigGen (
   .pixelClk(pixelClk),
   .hs(hsync),
   .vs(vsync),
   .de(dataEn),
   .enable(locked),
   .stopped(),
   .pixelX(pixelPosX),
   .pixelY(pixelPosY)
);

PatternGenerator #(
   .WIDTH(800),
   .HEIGHT(480)
) pg (
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

assign LCD_CLK = pixelClk;
assign LCD_HS = hsync;
assign LCD_VS = vsync;
assign LCD_DE = dataEn;
assign LCD_BL = 1;
assign LCD_R = red[7:3];
assign LCD_G = green[7:2];
assign LCD_B = blue[7:3];

endmodule

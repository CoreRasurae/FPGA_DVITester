//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.9 Beta-1
//Created Time: 2023-09-12 12:26:35
create_clock -name sys_clk -period 37 -waveform {0 18} [get_ports {sys_clk}]
create_clock -name clk33 -period 30 -waveform {0 15} [get_ports {LCD_CLK}]

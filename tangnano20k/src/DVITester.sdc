//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.9 Beta-1
//Created Time: 2023-08-28 15:15:09
create_clock -name sys_clk -period 37 -waveform {0 18} [get_ports {sys_clk}]
create_clock -name clk192 -period 5.208 -waveform {0 2.604} [get_nets {clk192}]
create_clock -name clk38_4 -period 26.042 -waveform {0 13.021} [get_nets {clk38_4}]

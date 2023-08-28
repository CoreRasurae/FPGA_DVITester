create_clock -name sys_clk -period 41.666 -waveform {0 20.833} [get_ports {sys_clk}]
derive_pll_clocks -gen_basic_clock


create_clock -period 27MHz [get_ports CLOCK_27[0]]
derive_pll_clocks
create_generated_clock -name sdclk_pin -source [get_pins {clock|altpll_component|auto_generated|pll1|clk[2]}] [get_ports {SDRAM_CLK}]
derive_clock_uncertainty
set_input_delay -clock sdclk_pin -max 6.4 [get_ports SDRAM_DQ*]
set_input_delay -clock sdclk_pin -min 3.2 [get_ports SDRAM_DQ*]
set_output_delay -clock sdclk_pin -max 1.5 [get_ports SDRAM_*]
set_output_delay -clock sdclk_pin -min -0.8 [get_ports SDRAM_*]
set_multicycle_path -from [get_clocks {sdclk_pin}] -to [get_clocks {clock|altpll_component|auto_generated|pll1|clk[0]}] -setup -end 2

onerror {quit -code 1}
if {![file exists work]} {vlib work}
vmap work work
vcom -2008 ascon_pack.vhd
vcom -2008 ASCON_ROUND.vhd
vcom -2008 ASCON_PERMUTATION.vhd
vcom -2008 ASCON_TOP_LEVEL.vhd
vcom -2008 wrapper.vhd
vcom -2008 tb_wrapper_v2_perf.vhd
vsim work.tb_wrapper_v2_perf
run -all

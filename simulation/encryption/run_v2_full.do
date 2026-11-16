
onerror {quit -code 1}

if {![file exists work]} {vlib work}
vmap work work

vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd
vcom -2008 rtl/encryption/ASCON_TOP_LEVEL.vhd
vcom -2008 rtl/interfaces/wrapper_encrypt.vhd
vcom -2008 simulation/encryption/tb_wrapper_v2_full.vhd

vsim work.tb_wrapper_v2
run -all

# ModelSim - ASCON decryption wrapper performance regression (monitor version)
# Run from repository root:
# do simulation/decryption/run_wrapper_decrypt_perf.do
onerror {quit -code 1}
if {![file exists work]} { vlib work }
vmap work work
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd
vcom -2008 rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 rtl/common/ASCON_PERFORMANCE_MONITOR.vhd
vcom -2008 rtl/interfaces/wrapper_decrypt.vhd
vcom -2008 simulation/decryption/tb_wrapper_decrypt_perf.vhd
vsim work.tb_wrapper_decrypt
run -all


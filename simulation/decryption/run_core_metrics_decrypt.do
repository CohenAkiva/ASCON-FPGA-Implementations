# Run from repository root. Encryption and decryption both declare entity wrapper; run separately.
vlib work
vmap work work
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd
vcom -2008 rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 rtl/common/ASCON_PERFORMANCE_MONITOR.vhd
vcom -2008 rtl/interfaces/wrapper_decrypt.vhd
vcom -2008 simulation/decryption/tb_wrapper_decrypt_core_metrics.vhd
vsim work.tb_wrapper_decrypt_core_metrics
run -all

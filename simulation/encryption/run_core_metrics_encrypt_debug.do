# Run from repository root. Encryption and decryption both declare entity wrapper; run separately.
vlib work
vmap work work
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd
vcom -2008 rtl/encryption/ASCON_TOP_LEVEL.vhd
vcom -2008 rtl/common/ASCON_PERFORMANCE_MONITOR.vhd
vcom -2008 rtl/interfaces/wrapper_encrypt.vhd
vcom -2008 simulation/encryption/tb_wrapper_v2_core_metrics.vhd
vsim -voptargs=+acc work.tb_wrapper_v2_core_metrics
run -all

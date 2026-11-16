# Run from the directory containing the unnumbered source files.
# Requires ModelSim/Questa with VHDL-2008 support.
# This script intentionally compiles the decryption-only wrapper.
onerror {quit -code 1}
if {![file exists work]} {vlib work}
vmap work work
vcom -2008 ascon_pack.vhd
vcom -2008 ASCON_ROUND.vhd
vcom -2008 ASCON_PERMUTATION.vhd
vcom -2008 ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 wrapper_decrypt.vhd
vcom -2008 tb_wrapper_decrypt.vhd
vsim -voptargs=+acc work.tb_wrapper_decrypt
add wave -divider {Raspberry Pi interface}
add wave sim:/tb_wrapper_decrypt/clk
add wave sim:/tb_wrapper_decrypt/reset
add wave sim:/tb_wrapper_decrypt/to_write
add wave sim:/tb_wrapper_decrypt/to_read
add wave sim:/tb_wrapper_decrypt/address
add wave sim:/tb_wrapper_decrypt/data_in
add wave sim:/tb_wrapper_decrypt/data_out
add wave -divider {Wrapper internal state}
add wave sim:/tb_wrapper_decrypt/dut/state
add wave sim:/tb_wrapper_decrypt/dut/ascon_start
add wave sim:/tb_wrapper_decrypt/dut/ascon_ready
add wave sim:/tb_wrapper_decrypt/dut/ascon_done
add wave sim:/tb_wrapper_decrypt/dut/ascon_tag_valid
add wave sim:/tb_wrapper_decrypt/dut/auth_valid
add wave sim:/tb_wrapper_decrypt/dut/result_valid
add wave sim:/tb_wrapper_decrypt/dut/transaction_done
add wave sim:/tb_wrapper_decrypt/dut/error_flag
run -all

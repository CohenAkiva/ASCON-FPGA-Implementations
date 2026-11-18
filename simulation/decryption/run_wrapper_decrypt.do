
# ---------------------------------------------------------------------------
# ModelSim DO Script - ASCON Decryption Wrapper Verification
#
# Run from the repository root:
# do simulation/decryption/run_wrapper_decrypt.do
#
# Compiles the decryption-only wrapper.
# ---------------------------------------------------------------------------

onerror {quit -code 1}

if {![file exists work]} {
    vlib work
}
vmap work work

# Shared ASCON components
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd

# Decryption core and wrapper
vcom -2008 rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 rtl/common/ASCON_PERFORMANCE_MONITOR.vhd
vcom -2008 rtl/interfaces/wrapper_decrypt.vhd

# Decryption wrapper testbench
vcom -2008 simulation/decryption/tb_wrapper_decrypt.vhd

# Load simulation
vsim -voptargs=+acc work.tb_wrapper_decrypt

# Raspberry Pi interface
add wave -divider {Raspberry Pi interface}
add wave sim:/tb_wrapper_decrypt/clk
add wave sim:/tb_wrapper_decrypt/reset
add wave sim:/tb_wrapper_decrypt/to_write
add wave sim:/tb_wrapper_decrypt/to_read
add wave sim:/tb_wrapper_decrypt/address
add wave sim:/tb_wrapper_decrypt/data_in
add wave sim:/tb_wrapper_decrypt/data_out

# Wrapper internal state
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


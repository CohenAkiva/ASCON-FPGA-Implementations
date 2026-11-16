
# ---------------------------------------------------------------------------
# ModelSim DO Script - ASCON Encryption Performance Test
#
# Run from the repository root:
# do simulation/encryption/run_v2_perf.do
# ---------------------------------------------------------------------------

onerror {quit -code 1}

# Create and map the simulation library.
if {![file exists work]} {
    vlib work
}
vmap work work

# Compile shared ASCON components.
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd

# Compile the encryption core and FPGA wrapper.
vcom -2008 rtl/encryption/ASCON_TOP_LEVEL.vhd
vcom -2008 rtl/interfaces/wrapper_encrypt.vhd

# Compile the performance testbench.
vcom -2008 simulation/encryption/tb_wrapper_v2_perf.vhd

# Load and run the performance testbench.
vsim work.tb_wrapper_v2_perf
run -all


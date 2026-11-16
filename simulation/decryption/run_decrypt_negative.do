
# ---------------------------------------------------------------------------
# ASCON Decryption - Authentication and Negative KAT Tests
#
# Run from repository root:
# do simulation/decryption/run_decrypt_negative.do
# ---------------------------------------------------------------------------

onerror {quit -code 1}

if {![file exists work]} {
    vlib work
}
vmap work work

# Compile shared components.
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd

# Compile decryption core and negative testbench.
vcom -2008 rtl/decryption/ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 simulation/decryption/tb_ascon_decrypt_negative.vhd

# Run each fault mode independently.
for {set mode 0} {$mode <= 3} {incr mode} {

    echo "=========================================="
    echo "Running FAULT_MODE=$mode"
    echo "=========================================="

    vsim -voptargs=+acc \
         -gFIRST_COUNT=1 \
         -gLAST_COUNT=1089 \
         -gFAULT_MODE=$mode \
         work.tb_ascon_decrypt_negative

    run -all
    quit -sim
}

echo "All four fault-mode simulations finished."

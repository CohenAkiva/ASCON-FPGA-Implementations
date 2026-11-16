# Ascon AEAD128 positive + negative authentication tests.
# Keep all source files and LWC_AEAD_KAT_128_128.txt in the same folder.
# FAULT_MODE: 0=valid, 1=TAG bit flip, 2=ciphertext bit flip, 3=AD bit flip.
# Ciphertext and AD modes skip vectors where that field is empty.

onerror {quit -code 1}
if {![file exists work]} {vlib work}
vmap work work
vcom -2008 ascon_pack.vhd
vcom -2008 ASCON_ROUND.vhd
vcom -2008 ASCON_PERMUTATION.vhd
vcom -2008 ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 tb_ascon_decrypt_negative.vhd

foreach mode {0 1 2 3} {
    puts "\n========== START FAULT_MODE=$mode ==========\n"
    vsim -voptargs=+acc -gFIRST_COUNT=1 -gLAST_COUNT=1089 -gFAULT_MODE=$mode work.tb_ascon_decrypt_negative
    run -all
    quit -sim
    puts "\n========== END FAULT_MODE=$mode ==========\n"
}
puts "ALL FOUR AUTHENTICATION TEST MODES COMPLETED. Review TESTED/PASSED/FAILED for each mode."

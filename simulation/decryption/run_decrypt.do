# ---------------------------------------------------------------------------
# ModelSim DO Script - NIST SP 800-232 Ascon-AEAD128
#
# STAGED TESTING:
#   Stage 1: Count 1 only       -> FIRST_COUNT=1, LAST_COUNT=1
#   Stage 2: Count 17 only      -> FIRST_COUNT=17, LAST_COUNT=17
#   Stage 3: Count 18 only      -> FIRST_COUNT=18, LAST_COUNT=18
#   Stage 4: Count 34 only      -> FIRST_COUNT=34, LAST_COUNT=34
#   Stage 5: All vectors        -> FIRST_COUNT=1, LAST_COUNT=1089
#
# Change ONLY these two variables when moving between stages.
# ---------------------------------------------------------------------------

set FIRST_COUNT 1
set LAST_COUNT  1089

quit -sim

if {![file exists work]} {
    vlib work
}
vmap work work

# Compile in dependency order.
vcom -2008 ascon_pack.vhd
vcom -2008 ASCON_ROUND.vhd
vcom -2008 ASCON_PERMUTATION.vhd
vcom -2008 ASCON_DECRYPT_TOP_LEVEL.vhd
vcom -2008 tb_ascon_decrypt_top_level.vhd

# Load the selected KAT range.
vsim -voptargs="+acc" \
     -gFIRST_COUNT=$FIRST_COUNT \
     -gLAST_COUNT=$LAST_COUNT \
     work.tb_ascon_decrypt_top_level

view wave
delete wave *

add wave -divider "TOP LEVEL INTERFACE"
add wave /tb_ascon_decrypt_top_level/clk
add wave /tb_ascon_decrypt_top_level/reset
add wave /tb_ascon_decrypt_top_level/start
add wave /tb_ascon_decrypt_top_level/process_ad
add wave /tb_ascon_decrypt_top_level/is_last
add wave -radix unsigned /tb_ascon_decrypt_top_level/data_bytes

add wave -radix hex /tb_ascon_decrypt_top_level/key
add wave -radix hex /tb_ascon_decrypt_top_level/nonce
add wave -radix hex /tb_ascon_decrypt_top_level/data_in
add wave -radix hex /tb_ascon_decrypt_top_level/data_out
add wave -radix hex /tb_ascon_decrypt_top_level/tag_in
add wave /tb_ascon_decrypt_top_level/tag_valid
add wave /tb_ascon_decrypt_top_level/ready
add wave /tb_ascon_decrypt_top_level/done

add wave -divider "TOP LEVEL INTERNAL"
add wave /tb_ascon_decrypt_top_level/UUT/current_top_state
add wave -radix hex /tb_ascon_decrypt_top_level/UUT/state_reg
add wave -radix hex /tb_ascon_decrypt_top_level/UUT/key_internal_reg
add wave /tb_ascon_decrypt_top_level/UUT/has_ad_reg
add wave /tb_ascon_decrypt_top_level/UUT/block_last_reg

add wave -divider "PERMUTATION ENGINE"
add wave /tb_ascon_decrypt_top_level/UUT/PERM_INST/state
add wave /tb_ascon_decrypt_top_level/UUT/PERM_INST/round_counter
add wave -radix hex /tb_ascon_decrypt_top_level/UUT/PERM_INST/current_round_const
add wave -radix hex /tb_ascon_decrypt_top_level/UUT/PERM_INST/current_state

# Testbench calls finish(), so run until completion.
run -all

wave zoomfull

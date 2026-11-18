# Run from repository root. Encryption and decryption both declare entity wrapper; run separately.
vlib work
vmap work work
vcom -2008 rtl/common/ascon_pack.vhd
vcom -2008 rtl/common/ASCON_ROUND.vhd
vcom -2008 rtl/common/ASCON_PERMUTATION.vhd
vcom -2008 rtl/encryption/ASCON_TOP_LEVEL.vhd
vcom -2008 rtl/common/ASCON_PERFORMANCE_MONITOR.vhd
vcom -2008 rtl/interfaces/wrapper_encrypt.vhd
vcom -2008 simulation/encryption/tb_wrapper_v2_perf.vhd
vsim work.tb_wrapper_v2_perf
# Observe the original regression testbench; no VHDL external aliases.
view wave
quietly WaveActivateNextPane {} 0
add wave -divider {Core events}
add wave -radix binary sim:/tb_wrapper_v2_perf/dut/core_start_event
add wave -radix binary sim:/tb_wrapper_v2_perf/dut/core_processing
add wave -radix binary sim:/tb_wrapper_v2_perf/dut/core_stop_event
add wave -radix binary sim:/tb_wrapper_v2_perf/dut/mon_transaction_reset
add wave -divider {Core measured cycles}
add wave -radix unsigned sim:/tb_wrapper_v2_perf/dut/core_last_latency
add wave -radix unsigned sim:/tb_wrapper_v2_perf/dut/core_last_active
add wave -radix unsigned sim:/tb_wrapper_v2_perf/dut/core_total_active
add wave -divider {Monitor internal state}
add wave -radix binary sim:/tb_wrapper_v2_perf/dut/u_performance_monitor/core_running
add wave -radix unsigned sim:/tb_wrapper_v2_perf/dut/u_performance_monitor/core_elapsed
add wave -radix unsigned sim:/tb_wrapper_v2_perf/dut/u_performance_monitor/core_active
run -all
wave zoom full

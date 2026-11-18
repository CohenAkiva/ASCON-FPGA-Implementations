vlib work
vmap work work
vcom -2008 rtl/common/ASCON_PERFORMANCE_MONITOR.vhd
vcom -2008 simulation/common/tb_ascon_performance_monitor_core.vhd
vsim work.tb_ascon_performance_monitor_core
run -all

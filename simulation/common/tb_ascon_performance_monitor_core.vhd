library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_ascon_performance_monitor_core is end entity;
architecture sim of tb_ascon_performance_monitor_core is
    signal clk : std_logic := '0';
    signal rst, cmd_start, cmd_active, cmd_stop, transaction_reset : std_logic := '0';
    signal core_start, core_busy, core_stop, core_reset : std_logic := '0';
    signal last_cycles, total_cycles, core_last_latency, core_last_active, core_total_active : std_logic_vector(31 downto 0);
begin
    clk <= not clk after 5 ns;
    dut : entity work.ASCON_PERFORMANCE_MONITOR
        port map (CLK=>clk, RESET=>rst, CMD_START=>cmd_start,
                  CMD_ACTIVE=>cmd_active, CMD_STOP=>cmd_stop,
                  TRANSACTION_RESET=>transaction_reset,
                  LAST_CYCLES=>last_cycles, TOTAL_CYCLES=>total_cycles,
                  CORE_START=>core_start, CORE_BUSY=>core_busy,
                  CORE_STOP=>core_stop, CORE_RESET=>core_reset,
                  CORE_LAST_LATENCY=>core_last_latency,
                  CORE_LAST_ACTIVE=>core_last_active,
                  CORE_TOTAL_ACTIVE=>core_total_active);
    process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;
        procedure check(signal actual : in std_logic_vector(31 downto 0);
                        constant expected : in natural; constant msg : in string) is
        begin
            assert unsigned(actual) = to_unsigned(expected,32)
                report msg severity failure;
        end procedure;
    begin
        rst <= '1'; tick; rst <= '0';
        cmd_start <= '1'; core_start <= '1'; tick;
        cmd_start <= '0'; core_start <= '0';
        cmd_active <= '1'; core_busy <= '1';
        tick; tick; tick;
        core_busy <= '0'; tick; tick;
        cmd_active <= '0'; cmd_stop <= '1'; core_stop <= '1'; tick;
        cmd_stop <= '0'; core_stop <= '0';
        check(last_cycles, 5, "legacy last count");
        check(total_cycles, 5, "legacy total count");
        check(core_last_latency, 5, "core elapsed count");
        check(core_last_active, 3, "core active count");
        check(core_total_active, 3, "core active total");
        core_start <= '1'; tick; core_start <= '0';
        core_busy <= '1'; tick; tick; core_busy <= '0';
        core_stop <= '1'; tick; core_stop <= '0';
        check(core_last_latency, 2, "second interval elapsed");
        check(core_last_active, 2, "second interval active");
        check(core_total_active, 5, "accumulated core active");
        core_reset <= '1'; tick; core_reset <= '0';
        check(core_total_active, 0, "core reset total");
        check(total_cycles, 5, "core reset must not affect legacy total");
        report "TEST PASSED: extended performance monitor" severity note;
        stop;
        wait;
    end process;
end architecture;

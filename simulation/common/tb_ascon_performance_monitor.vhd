library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ascon_performance_monitor is
end entity;

architecture sim of tb_ascon_performance_monitor is
    signal clk               : std_logic := '0';
    signal reset             : std_logic := '0';
    signal cmd_start         : std_logic := '0';
    signal cmd_active        : std_logic := '0';
    signal cmd_stop          : std_logic := '0';
    signal transaction_reset : std_logic := '0';
    signal last_cycles       : std_logic_vector(31 downto 0);
    signal total_cycles      : std_logic_vector(31 downto 0);
begin
    clk <= not clk after 5 ns;

    dut: entity work.ASCON_PERFORMANCE_MONITOR
        port map (
            CLK => clk, RESET => reset,
            CMD_START => cmd_start, CMD_ACTIVE => cmd_active,
            CMD_STOP => cmd_stop, TRANSACTION_RESET => transaction_reset,
            LAST_CYCLES => last_cycles, TOTAL_CYCLES => total_cycles
        );

    stim: process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;
        procedure check_counts(expected_last, expected_total : natural) is
        begin
            assert unsigned(last_cycles) = to_unsigned(expected_last, 32)
                report "LAST_CYCLES mismatch" severity failure;
            assert unsigned(total_cycles) = to_unsigned(expected_total, 32)
                report "TOTAL_CYCLES mismatch" severity failure;
        end procedure;
    begin
        reset <= '1'; tick;
        check_counts(0, 0);
        reset <= '0';

        -- Command 1: start overrides active; stop captures pre-edge count.
        cmd_start <= '1'; cmd_active <= '1'; tick;
        cmd_start <= '0';
        for i in 1 to 3 loop tick; end loop;
        cmd_stop <= '1'; tick;
        cmd_stop <= '0'; cmd_active <= '0';
        check_counts(3, 3);

        -- Command 2: four active cycles before stop; accumulation preserved.
        cmd_start <= '1'; cmd_active <= '1'; tick;
        cmd_start <= '0';
        for i in 1 to 4 loop tick; end loop;
        cmd_stop <= '1'; tick;
        cmd_stop <= '0'; cmd_active <= '0';
        check_counts(4, 7);

        -- New transaction resets total but preserves last-command result.
        transaction_reset <= '1'; tick;
        transaction_reset <= '0';
        check_counts(4, 0);

        -- Global reset clears both output counters.
        reset <= '1'; tick;
        check_counts(0, 0);
        reset <= '0';

        report "TEST PASSED: legacy performance monitor" severity note;
        wait;
    end process;
end architecture sim;

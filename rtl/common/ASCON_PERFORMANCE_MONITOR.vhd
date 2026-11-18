library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Standalone legacy-compatible wrapper activity-cycle monitor.
-- Events are synchronous, active-high, one-clock strobes except CMD_ACTIVE.
entity ASCON_PERFORMANCE_MONITOR is
    port (
        CLK               : in  std_logic;
        RESET             : in  std_logic;
        CMD_START         : in  std_logic;
        CMD_ACTIVE        : in  std_logic;
        CMD_STOP          : in  std_logic;
        TRANSACTION_RESET : in  std_logic;
        LAST_CYCLES       : out std_logic_vector(31 downto 0);
        TOTAL_CYCLES      : out std_logic_vector(31 downto 0)
    );
end entity ASCON_PERFORMANCE_MONITOR;

architecture rtl of ASCON_PERFORMANCE_MONITOR is
    signal active_count : unsigned(31 downto 0) := (others => '0');
    signal last_count   : unsigned(31 downto 0) := (others => '0');
    signal total_count  : unsigned(31 downto 0) := (others => '0');
begin
    process (CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                active_count <= (others => '0');
                last_count   <= (others => '0');
                total_count  <= (others => '0');
            else
                -- Match legacy wrapper signal-assignment priority:
                -- CMD_START overrides CMD_ACTIVE on the same edge.
                if CMD_START = '1' then
                    active_count <= (others => '0');
                elsif CMD_ACTIVE = '1' then
                    active_count <= active_count + 1;
                end if;

                -- CMD_STOP captures the PRE-edge active_count, not active_count+1.
                -- It also overrides an increment of active_count on this edge
                -- only as far as the saved value is concerned.
                if CMD_STOP = '1' then
                    last_count <= active_count;
                end if;

                -- A new transaction clears accumulated cycles; no command
                -- completion is expected on the same edge in the baseline FSM.
                if TRANSACTION_RESET = '1' then
                    total_count <= (others => '0');
                elsif CMD_STOP = '1' then
                    total_count <= total_count + active_count;
                end if;
            end if;
        end if;
    end process;

    LAST_CYCLES  <= std_logic_vector(last_count);
    TOTAL_CYCLES <= std_logic_vector(total_count);
end architecture rtl;

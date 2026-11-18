library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Independent measurement module. All control signals are synchronous to CLK.
-- Legacy counters preserve their original edge semantics.
-- CORE_START / CORE_STOP delimit a core service interval.
-- CORE_BUSY marks clocks spent in actual processing (not input waiting).
entity ASCON_PERFORMANCE_MONITOR is
    port (
        CLK               : in std_logic;
        RESET             : in std_logic;
        CMD_START         : in std_logic;
        CMD_ACTIVE        : in std_logic;
        CMD_STOP          : in std_logic;
        TRANSACTION_RESET : in std_logic;
        LAST_CYCLES       : out std_logic_vector(31 downto 0);
        TOTAL_CYCLES      : out std_logic_vector(31 downto 0);
        CORE_START        : in std_logic := '0';
        CORE_BUSY         : in std_logic := '0';
        CORE_STOP         : in std_logic := '0';
        CORE_RESET        : in std_logic := '0';
        CORE_LAST_LATENCY : out std_logic_vector(31 downto 0);
        CORE_LAST_ACTIVE  : out std_logic_vector(31 downto 0);
        CORE_TOTAL_ACTIVE : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of ASCON_PERFORMANCE_MONITOR is
    signal active_count, last_count, total_count : unsigned(31 downto 0) := (others => '0');
    signal core_running : std_logic := '0';
    signal core_elapsed, core_active, core_last_latency_reg : unsigned(31 downto 0) := (others => '0');
    signal core_last_active_reg, core_total_active_reg : unsigned(31 downto 0) := (others => '0');
begin
    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                active_count <= (others => '0');
                last_count <= (others => '0');
                total_count <= (others => '0');
            else
                if CMD_START = '1' then
                    active_count <= (others => '0');
                elsif CMD_ACTIVE = '1' then
                    active_count <= active_count + 1;
                end if;
                if CMD_STOP = '1' then
                    last_count <= active_count;
                end if;
                if TRANSACTION_RESET = '1' then
                    total_count <= (others => '0');
                elsif CMD_STOP = '1' then
                    total_count <= total_count + active_count;
                end if;
            end if;

            if RESET = '1' then
                core_running <= '0';
                core_elapsed <= (others => '0');
                core_active <= (others => '0');
                core_last_latency_reg <= (others => '0');
                core_last_active_reg <= (others => '0');
                core_total_active_reg <= (others => '0');
            elsif CORE_RESET = '1' then
                core_running <= '0';
                core_elapsed <= (others => '0');
                core_active <= (others => '0');
                core_last_latency_reg <= (others => '0');
                core_last_active_reg <= (others => '0');
                core_total_active_reg <= (others => '0');
            elsif CORE_START = '1' then
                -- Start wins if simultaneous with STOP; caller must not overlap pulses.
                core_running <= '1';
                core_elapsed <= (others => '0');
                core_active <= (others => '0');
            elsif core_running = '1' then
                if CORE_STOP = '1' then
                    -- Stop captures pre-edge counts, consistent with legacy counters.
                    core_last_latency_reg <= core_elapsed;
                    core_last_active_reg <= core_active;
                    core_total_active_reg <= core_total_active_reg + core_active;
                    core_running <= '0';
                else
                    core_elapsed <= core_elapsed + 1;
                    if CORE_BUSY = '1' then
                        core_active <= core_active + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    LAST_CYCLES <= std_logic_vector(last_count);
    TOTAL_CYCLES <= std_logic_vector(total_count);
    CORE_LAST_LATENCY <= std_logic_vector(core_last_latency_reg);
    CORE_LAST_ACTIVE <= std_logic_vector(core_last_active_reg);
    CORE_TOTAL_ACTIVE <= std_logic_vector(core_total_active_reg);
end architecture;

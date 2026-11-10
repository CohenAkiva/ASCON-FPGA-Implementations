
library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

entity ASCON_PERMUTATION is
    port 
	(
        CLK       : in  std_logic;                                                -- System clock.
        RESET     : in  std_logic;                                                -- Active-high reset.
        START     : in  std_logic;                                                -- One-cycle request to start a permutation.
        ROUND_SEL : in  std_logic;                                                -- Select p[8] or p[12]: 0=8 rounds, 1=12 rounds.
        STATE_IN  : in  std_logic_vector(319 downto 0);                           -- 320-bit Ascon state input.
        STATE_OUT : out std_logic_vector(319 downto 0);                           -- 320-bit state after the selected permutation.
        DONE      : out std_logic                                                 -- Pulses high when the permutation result is ready.
    );
end ASCON_PERMUTATION;

architecture MY_ASCON_PERMUTATION of ASCON_PERMUTATION is
    component ASCON_ROUND                                                         -- Reuse one combinational round block over several clock cycles.
        port 
		(
            ROUND_CONST : in std_logic_vector(7 downto 0);
            S0_in, S1_in, S2_in, S3_in, S4_in : in std_logic_vector(63 downto 0);
            S0_out, S1_out, S2_out, S3_out, S4_out : out std_logic_vector(63 downto 0)
        );
    end component;

    type StateType is (IDLE, PROCESS_ROUND, FINISH);                              -- Small control FSM: load, iterate rounds, finish.
    signal state : StateType := IDLE;
    signal current_state : std_logic_vector(319 downto 0) := (others => '0');     -- Registered 320-bit state between rounds.
    signal round_out : std_logic_vector(319 downto 0);                            -- Combinational output of the current ASCON_ROUND.
    signal round_counter : integer range 0 to 11 := 0;                            -- NIST round index; final implemented round is 11.
    signal current_round_const : std_logic_vector(7 downto 0);                    -- 8-bit constant selected from NIST Table 5.
	
begin
    ROUND_INST : ASCON_ROUND
        port map 
		(
            ROUND_CONST => current_round_const,                                   -- Feed the constant for the current round.
            S0_in => current_state(63 downto 0),                                  -- Internal mapping: low 64 bits hold S0.
            S1_in => current_state(127 downto 64),                                -- Next 64 bits hold S1.
            S2_in => current_state(191 downto 128),                               -- Next 64 bits hold S2.
            S3_in => current_state(255 downto 192),                               -- Next 64 bits hold S3.
            S4_in => current_state(319 downto 256),                               -- High 64 bits hold S4.
            S0_out => round_out(63 downto 0),
            S1_out => round_out(127 downto 64),
            S2_out => round_out(191 downto 128),
            S3_out => round_out(255 downto 192),
            S4_out => round_out(319 downto 256)
        );

    process(round_counter)                                         -- ROUND CONSTANT LOOKUP
    begin
        case round_counter is
            when 0 => current_round_const <= x"F0";
            when 1 => current_round_const <= x"E1";
            when 2 => current_round_const <= x"D2";
            when 3 => current_round_const <= x"C3";
            when 4 => current_round_const <= x"B4";
            when 5 => current_round_const <= x"A5";
            when 6 => current_round_const <= x"96";
            when 7 => current_round_const <= x"87";
            when 8 => current_round_const <= x"78";
            when 9 => current_round_const <= x"69";
            when 10 => current_round_const <= x"5A";
            when 11 => current_round_const <= x"4B";
            when others => current_round_const <= x"00";
        end case;
    end process;

    process(CLK, RESET)
    begin
        if RESET = '1' then                                                       -- Return the engine to a known idle state.
            state         <= IDLE;
            current_state <= (others => '0');
            round_counter  <= 0;
            STATE_OUT      <= (others => '0');
            DONE           <= '0';
			
        elsif rising_edge(CLK) then
            case state is
                when IDLE =>                                                      -- Wait for a new permutation request.
                    DONE <= '0';
                    if START = '1' then
                        current_state <= STATE_IN;                                -- Load the 320-bit input state before round processing.
                        if ROUND_SEL = '1' then                                   -- p[12] uses NIST rounds 0..11.
                            round_counter <= 0;                                   -- Start p[12] at constant F0.
                        else
                            round_counter <= 4;                                   -- Start p[8] at constant B4 (rounds 4..11).
                        end if;
                        state <= PROCESS_ROUND;                                   -- Move to iterative round processing.
                    end if;

                when PROCESS_ROUND =>                                             -- One ASCON_ROUND result is registered each clock.
                    current_state <= round_out;                                   -- Save pL output as input state for the next round.
                    if round_counter = 11 then                                    -- Round 11 is the last required round.
                        state <= FINISH;
                    else
                        round_counter <= round_counter + 1;                       -- Select the next NIST round constant.
                    end if;

                when FINISH =>                                                    -- Publish final state and pulse DONE.
                    STATE_OUT <= current_state;                                   -- Return the state after all selected rounds.
                    DONE <= '1';                                                  -- Tell TOP LEVEL that the permutation is complete.
                    state <= IDLE;

                when others =>
                    state <= IDLE;
                    DONE <= '0';
            end case;
        end if;
    end process;
end architecture MY_ASCON_PERMUTATION;



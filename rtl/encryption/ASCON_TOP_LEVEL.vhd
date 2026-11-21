library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;
	use work.ascon_pack.all;

entity ASCON_TOP_LEVEL is
    port 
	(
        CLK        : in  std_logic;                                               -- System clock.
        RESET      : in  std_logic;                                               -- Active-high reset for TOP and permutation engine.
        START      : in  std_logic;                                               -- Accept a new transaction or data block when READY=1.

        KEY        : in  std_logic_vector(127 downto 0);                          -- 128-bit secret key K.
        NONCE      : in  std_logic_vector(127 downto 0);                          -- 128-bit nonce N; must be unique per key in normal use.

        DATA_IN    : in  std_logic_vector(127 downto 0);                          -- Up to one 128-bit AD/PT block in external byte order.
        DATA_BYTES : in  unsigned(4 downto 0);                                    -- Number of valid input bytes, 0..16.
        PROCESS_AD : in  std_logic;                                               -- At transaction start, tells the FSM whether AD is non-empty.
        IS_LAST    : in  std_logic;                                               -- Marks the last real AD/PT block supplied by the caller.

        DATA_OUT   : out std_logic_vector(127 downto 0);                          -- Ciphertext block; valid bytes equal DATA_BYTES.
        TAG        : out std_logic_vector(127 downto 0);                          -- 128-bit authentication tag T.
        READY      : out std_logic;                                               -- High means START may be accepted.
        DONE       : out std_logic                                                -- One-cycle completion indication; TAG is ready.
    );
end ASCON_TOP_LEVEL;

architecture Behavioral of ASCON_TOP_LEVEL is

    component ASCON_PERMUTATION is                                                 -- Ascon permutation component
        port 
		(
            CLK       : in  std_logic;
            RESET     : in  std_logic;
            START     : in  std_logic;
            ROUND_SEL : in  std_logic;
            STATE_IN  : in  std_logic_vector(319 downto 0);
            STATE_OUT : out std_logic_vector(319 downto 0);
            DONE      : out std_logic
        );
    end component;

    type TopStateType is 
	(                                                                               
        IDLE,                                                                     -- Wait for START pulse, convert input byte order, and build initial 320-bit state
        START_INIT_PERM,                                                          -- Start 12-round initial permutation (p[12])
        WAIT_INIT_PERM,                                                           -- Wait for p[12] to finish, then XOR Key into state (S3||S4)

        WAIT_AD_INPUT,                                                            -- Accept AD block, pad if needed, and XOR into state rate (S0||S1)
        WAIT_AD_PERM,                                                             -- Wait for 8-round permutation (p[8]) after an AD block
        START_AD_EMPTY_PAD_PERM,                                                  -- Absorb empty pad block for 16-byte aligned AD
        WAIT_AD_EMPTY_PAD_PERM,                                                   -- Wait for p[8] on the extra AD pad block

        DOMAIN_SEPARATION,                                                        -- Flip 1-bit in state MSB to separate AD from Plaintext phase

        WAIT_PT_INPUT,                                                            -- Accept Plaintext, encrypt to Ciphertext output, and absorb into state
        WAIT_PT_PERM,                                                             -- Wait for 8-round permutation (p[8]) after a full Plaintext block
        APPLY_PT_EMPTY_PAD,                                                       -- Absorb empty pad block for 16-byte aligned Plaintext

        START_FINAL_PERM,                                                         -- XOR Key into state (S2||S3) and start 12-round final permutation (p[12])
        WAIT_FINAL_PERM,                                                          -- Wait for p[12] to finish, compute Tag (T = S3||S4 XOR K), and raise DONE

        FINISH                                                                    -- Clear DONE signal and return to IDLE for next transaction
    );

    signal current_top_state : TopStateType := IDLE;
    signal state_reg : std_logic_vector(319 downto 0) := (others => '0');         -- 320-bit Ascon state; S0 is low 64 bits and S4 is high 64 bits.

    signal key_internal_reg : std_logic_vector(127 downto 0) := (others => '0');  -- Key stored in internal little-endian byte order.
    signal has_ad_reg       : std_logic := '0';                                   -- Remembers whether this transaction has non-empty AD.
    signal block_last_reg   : std_logic := '0';                                   -- Remembers IS_LAST while p[8] is running.

    signal perm_start     : std_logic := '0';                                     -- One-cycle START pulse sent to ASCON_PERMUTATION.
    signal perm_round_sel : std_logic := '0';                                     -- 0=p[8], 1=p[12].
    signal perm_state_in  : std_logic_vector(319 downto 0) := (others => '0');  
    signal perm_state_out : std_logic_vector(319 downto 0);
    signal perm_done      : std_logic;

    constant ASCON_AEAD_IV : std_logic_vector(63 downto 0):= x"00001000808C0001";          -- IV = 0x00001000808c0001.
    constant ZERO128 : std_logic_vector(127 downto 0):= (others => '0');                   -- Reusable all-zero block for empty padding blocks.
        
begin
    PERM_INST : ASCON_PERMUTATION
        port map 
		(
            CLK       => CLK,
            RESET     => RESET,
            START     => perm_start,
            ROUND_SEL => perm_round_sel,
            STATE_IN  => perm_state_in,
            STATE_OUT => perm_state_out,
            DONE      => perm_done
        );

    process(CLK, RESET)
        variable temp_state    : std_logic_vector(319 downto 0);
        variable key_int       : std_logic_vector(127 downto 0);
        variable nonce_int     : std_logic_vector(127 downto 0);
        variable block_int     : std_logic_vector(127 downto 0);
        variable padded_int    : std_logic_vector(127 downto 0);
        variable cipher_int    : std_logic_vector(127 downto 0);
        variable n             : integer;
    begin

        if RESET = '1' then                                                       -- Reset all FSM, state and handshake registers.
            current_top_state <= IDLE;
            state_reg         <= (others => '0');
            key_internal_reg  <= (others => '0');
            has_ad_reg        <= '0';
            block_last_reg    <= '0';

            perm_start        <= '0';
            perm_round_sel    <= '0';
            perm_state_in     <= (others => '0');

            DATA_OUT          <= (others => '0');
            TAG               <= (others => '0');
            READY             <= '1';
            DONE              <= '0';

        elsif rising_edge(CLK) then
		
            perm_start <= '0';                                                    -- Default: permutation START is a one-clock pulse.
            DONE       <= '0';                                                    -- Default: DONE is also a one-clock pulse.

            case current_top_state is
			
            -- =============================================================
            -- INITIALIZATION PHASE
            -- =============================================================
                when IDLE =>                                                      -- Wait for a new AEAD encryption transaction.
                    READY <= '1';

                    if START = '1' then                                           -- Accept input only on a START pulse.
                        READY    <= '0';
                        DATA_OUT <= (others => '0');                              -- Return only the real ciphertext bytes in external order.
                        TAG      <= (others => '0');

                        key_int   := ext128_to_internal(KEY);                     -- Convert external key bytes to NIST little-endian internal order.
                        nonce_int := ext128_to_internal(NONCE);                   -- Convert nonce bytes to the same internal order.

                        key_internal_reg <= key_int;                              -- Save the converted 128-bit key in an internal register for later use in initialization and finalization
                        has_ad_reg       <= PROCESS_AD;                           -- Save whether AD blocks are required to be processed.

                        state_reg(63 downto 0)    <= ASCON_AEAD_IV;               -- Initialization: S0 = IV.
                        state_reg(191 downto 64)  <= key_int;                     -- Initialization: S1||S2 = K.
                        state_reg(319 downto 192) <= nonce_int;                   -- Initialization: S3||S4 = N.

                        current_top_state <= START_INIT_PERM;
                    end if;

                when START_INIT_PERM =>                                           -- NIST initialization step: apply Ascon-p[12].
                    READY          <= '0';
                    perm_state_in  <= state_reg;
                    perm_round_sel <= '1';                                        -- Select p[12] for initialization/finalization.
                    perm_start     <= '1';
                    current_top_state <= WAIT_INIT_PERM;

                when WAIT_INIT_PERM =>                                            -- Wait until the 12-round permutation finishes.
                    READY <= '0';

                    if perm_done = '1' then
                        temp_state := perm_state_out;
                        temp_state(319 downto 192) := perm_state_out(319 downto 192)  xor key_internal_reg;      -- XOR K into S3||S4.     
                        state_reg <= temp_state;                                                                 -- Save the absorbed padded final plaintext state.

                        if has_ad_reg = '1' then                                                                 -- Process AD only when AD is non-empty.
                            READY <= '1';
                            current_top_state <= WAIT_AD_INPUT;
                        else
                            current_top_state <= DOMAIN_SEPARATION;
                        end if;
                    end if;
					
            -- =============================================================
            -- ASSOCIATED DATA (AD) PHASE
            -- =============================================================
                when WAIT_AD_INPUT =>                                             -- Accept the next associated-data block.
                    READY <= '1';                                                 -- Signal to external interface that module is ready for AD block

                    if START = '1' then                                           -- Execute only when external START pulse is received
                        READY <= '0';                                             -- Clear READY signal while processing input
                        n := to_integer(DATA_BYTES);                              -- Convert valid input byte count to integer 'n'

                        assert n >= 0 and n <= 16                                 -- Verify valid byte range (0 to 16 bytes)
                            report "Invalid AD DATA_BYTES"
                            severity failure;

                        assert (n = 16) or (IS_LAST = '1')                                    -- Verify that only the final AD block can be under 16 bytes
                            report "A non-final AD block must contain exactly 16 bytes"
                            severity failure;

                        if n = 16 then                                                         -- Full 16-byte block: convert to Little-Endian without padding
                            block_int := make_internal_block(DATA_IN, DATA_BYTES, false);
                        else                                                                   -- Partial block: convert to Little-Endian and add 0x01 pad
                            block_int := make_internal_block(DATA_IN, DATA_BYTES, true);
                        end if;

                        temp_state := state_reg;
                        temp_state(127 downto 0):= state_reg(127 downto 0) xor block_int;       -- Absorb AD block into state Rate (S0||S1) via XOR
                            
                        block_last_reg <= IS_LAST;                                -- Store IS_LAST flag to remember if this was final AD block
                        perm_state_in  <= temp_state;                             -- Pass updated state to permutation module
                        perm_round_sel <= '0';                                    -- Select 8-round mode (p[8]) for AD processing
                        perm_start     <= '1';                                    -- Trigger 1-cycle START pulse for permutation engine
                        current_top_state <= WAIT_AD_PERM;                        -- Move state machine to wait for p[8] completion
                    end if;

                when WAIT_AD_PERM =>                                              -- Wait for the p[8] required after each AD block.
                    READY <= '0';                                                 -- Keep READY low while the permutation engine is running

                    if perm_done = '1' then                                       -- Wait for permutation engine to complete its 8 rounds
                        state_reg <= perm_state_out;                              -- Save the new state generated by the permutation engine

                        if block_last_reg = '1' then                              -- Check if the processed AD block was marked as the last one

                            if DATA_BYTES = to_unsigned(16, 5) then               -- If last AD block was full (16 bytes), NIST requires an extra empty pad block
                                current_top_state <= START_AD_EMPTY_PAD_PERM;     -- Move to process the extra empty padding block
                            else
                                current_top_state <= DOMAIN_SEPARATION;           -- Partial AD block was already padded, move directly to Domain Separation
                            end if;
                        else
                            READY <= '1';                                         -- More AD blocks remain; raise READY signal
                            current_top_state <= WAIT_AD_INPUT;                   -- Return to wait for the next AD block
                        end if;
                    end if;
					
                when START_AD_EMPTY_PAD_PERM =>                                   -- Absorb pad(empty) because parse(A,128) creates an empty last block.
                    READY <= '0';                                                 -- Keep READY low while constructing and absorbing pad block

                    temp_state := state_reg;                                                    -- Copy current 320-bit state to temporary variable 
                    padded_int := make_internal_block(ZERO128, to_unsigned(0, 5), true);        -- Build empty padded block: input ZERO128 with 0 valid bytes and padding=true (results in 0x01 followed by zeros)
                    temp_state(127 downto 0) := state_reg(127 downto 0) xor padded_int;         -- Absorb empty padded block into state Rate (S0||S1) via XOR operation
                        

                    perm_state_in  <= temp_state;                             -- Pass updated state with absorbed pad to permutation engine
                    perm_round_sel <= '0';                                    -- Select 8-round mode (p[8]) for AD processing
                    perm_start     <= '1';                                    -- Trigger 1-cycle START pulse for permutation engine
                    current_top_state <= WAIT_AD_EMPTY_PAD_PERM;                  -- Move to wait state for permutation to complete


                when WAIT_AD_EMPTY_PAD_PERM =>                                    -- Wait for p[8] on the extra AD padding block.
                    READY <= '0';                                                 -- Keep READY low while waiting for permutation completion

                    if perm_done = '1' then                                       -- Check if 8-round permutation has completed
                        state_reg <= perm_state_out;                              -- Save permutation result into state register
                        current_top_state <= DOMAIN_SEPARATION;                   -- Transition to Domain Separation phase now that AD processing is complete
                    end if;
					
            -- =============================================================
            -- DOMAIN SEPARATION
            -- =============================================================
                when DOMAIN_SEPARATION =>                                         -- Separate AD processing from plaintext processing.
                    READY <= '0';                                                 -- Keep READY low during domain separation step

                    state_reg(319) <= state_reg(319) xor '1';                     -- Append domain bit: Appendix A.2 gives S4 ^= 0x8000000000000000.
                    READY <= '1';                                                 -- Signal readiness to receive Plaintext input
                    current_top_state <= WAIT_PT_INPUT;                           -- Transition to Plaintext input wait state
					
            -- =============================================================
            -- PLAINTEXT (PT) & ENCRYPTION PHASE
            -- =============================================================
                when WAIT_PT_INPUT =>                                             -- Accept the next plaintext block.
                    READY <= '1';                                                 -- Signal readiness to receive a new Plaintext block

                    if START = '1' then                                           -- Process input when START pulse arrives
                        READY <= '0';                                             -- Lower READY signal while processing
                        n := to_integer(DATA_BYTES);                              -- Convert input byte count to integer 'n'

                        assert n >= 0 and n <= 16                                 -- Check valid byte count range (0..16)
                            report "Invalid PT DATA_BYTES"
                            severity failure;

                        assert (n = 16) or (IS_LAST = '1')                        -- Only the final PT block can be shorter than 16 bytes
                            report "A non-final partial PT block is invalid"
                            severity failure;

                        block_int := make_internal_block(DATA_IN, DATA_BYTES, false);            -- Convert Plaintext block to Little-Endian (unpadded)
                        cipher_int := state_reg(127 downto 0) xor block_int;                     -- Encrypt: C = Rate XOR Plaintext
                        DATA_OUT <= internal_to_ext_valid(cipher_int, DATA_BYTES);               -- Send encrypted valid bytes to output DATA_OUT

                        if n < 16 then                                            -- Handle partial or empty final block (< 16 bytes)
                            assert IS_LAST = '1'                                  -- Verify that a partial block is marked as the last block
                                report "Partial PT block must be final"
                                severity failure;

                            padded_int := make_internal_block(DATA_IN, DATA_BYTES, true);        -- Convert and pad final block with 0x01

                            temp_state := state_reg;
                            temp_state(127 downto 0) := state_reg(127 downto 0) xor padded_int;  -- Absorb padded final block into Rate (S0||S1)

                            state_reg <= temp_state;                              -- Update internal state register
                            current_top_state <= START_FINAL_PERM;                -- Skip p[8] per NIST spec and go directly to Finalization
                        else                                                      -- Handle full 16-byte block
                            temp_state := state_reg;
                            temp_state(127 downto 0) := cipher_int;               -- Absorb Ciphertext into Rate (S0||S1)

                            block_last_reg <= IS_LAST;                            -- Store IS_LAST flag
                            perm_state_in  <= temp_state;                         -- Load state to permutation engine
                            perm_round_sel <= '0';                                -- Select 8-round mode (p[8])
                            perm_start     <= '1';                                -- Start permutation
                            current_top_state <= WAIT_PT_PERM;                    -- Transition to wait for p[8] completion
                        end if;
                    end if;

                when WAIT_PT_PERM =>                                              -- Wait for p[8] after a full plaintext/ciphertext block.
                    READY <= '0';                                                 -- Keep READY low while permutation engine is running

                    if perm_done = '1' then                                       -- Wait for 8-round permutation (p[8]) to complete
                        state_reg <= perm_state_out;                              -- Save permutation output into state register

                        if block_last_reg = '1' then                              -- Check if the processed block was the last Plaintext block
                            current_top_state <= APPLY_PT_EMPTY_PAD;              -- Exact 16-byte aligned PT needs an extra empty padded block
                        else
                            READY <= '1';                                         -- More Plaintext blocks remain; signal READY
                            current_top_state <= WAIT_PT_INPUT;                   -- Return to wait for next Plaintext block
                        end if;
                    end if;
					
                when APPLY_PT_EMPTY_PAD =>                                        -- Absorb pad(empty) after PT length exactly multiple of 16 bytes.
                    READY <= '0';                                                 -- Keep READY low while processing empty pad

                    temp_state := state_reg;                                                    -- Copy current state to temporary variable
                    padded_int := make_internal_block(ZERO128, to_unsigned(0, 5), true);        -- Build empty padded block (0x01 followed by zeros)
                    temp_state(127 downto 0) := state_reg(127 downto 0) xor padded_int;         -- Absorb empty padded block into state Rate (S0||S1) via XOR
                        
                    state_reg <= temp_state;                                                    -- Update state register with absorbed pad result
                    current_top_state <= START_FINAL_PERM;                                      -- Transition directly to Finalization phase without p[8]
					
            -- =============================================================
            -- FINALIZATION & TAG GENERATION PHASE
            -- =============================================================	
                when START_FINAL_PERM =>                                                              -- NIST finalization: key injection followed by p[12].
                    READY <= '0';                                                                     -- Keep READY low during finalization phase

                    temp_state := state_reg;                                                          -- Copy current 320-bit state to temporary variable
                    temp_state(255 downto 128) := state_reg(255 downto 128) xor key_internal_reg;     -- Inject secret key into Capacity words S2||S3 via XOR

                    perm_state_in  <= temp_state;                                 -- Pass key-injected state to permutation module
                    perm_round_sel <= '1';                                        -- Select 12-round mode (p[12]) for finalization
                    perm_start     <= '1';                                        -- Trigger 1-cycle START pulse for permutation engine
                    current_top_state <= WAIT_FINAL_PERM;                         -- Move to wait state for p[12] completion
					
                when WAIT_FINAL_PERM =>                                           -- Wait for final Ascon-p[12].
                    READY <= '0';                                                 -- Keep READY low while permutation engine is running

                    if perm_done = '1' then                                                               -- Wait for 12-round permutation to finish
                        TAG <= internal128_to_ext(perm_state_out(319 downto 192) xor key_internal_reg);   -- Calculate Tag: T = (S3||S4) XOR Key, then convert to Big-Endian output order
                        DONE  <= '1';                                                                     -- Raise 1-cycle DONE signal indicating TAG is ready and transaction is complete
                        READY <= '1';                                                                     -- Raise READY signal to accept new transaction
                        current_top_state <= FINISH;                                                      -- Transition to FINISH state
                    end if;
					
                when FINISH =>                                                    -- Return cleanly to IDLE for the next transaction.
                    READY <= '1';                                                 -- Maintain READY high for the next transaction
                    DONE  <= '0';                                                 -- Clear 1-cycle DONE pulse
                    current_top_state <= IDLE;                                    -- Return state machine to IDLE

                when others =>
                    current_top_state <= IDLE;                                    -- Safe fallback recovery state
                    READY <= '1';

            end case;
        end if;
    end process;

end Behavioral;
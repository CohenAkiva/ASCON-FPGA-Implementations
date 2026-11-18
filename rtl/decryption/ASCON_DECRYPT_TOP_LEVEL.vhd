library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.ascon_pack.all;

entity ASCON_DECRYPT_TOP_LEVEL is
    port (
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
        TAG_IN     : in  std_logic_vector(127 downto 0);                          -- Expected 128-bit tag received with ciphertext.
        TAG_VALID  : out std_logic;                                               -- 1 only when the computed tag matches TAG_IN.
        READY      : out std_logic;                                               -- High means START may be accepted.
        DONE       : out std_logic;                                                -- One-cycle completion indication; TAG is ready.
        CORE_PROCESSING : out std_logic
    );
end ASCON_DECRYPT_TOP_LEVEL;

architecture Behavioral of ASCON_DECRYPT_TOP_LEVEL is

    component ASCON_PERMUTATION is                                                -- Shared p[8]/p[12] permutation engine.
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
	(                                                        -- FSM states mirror the four NIST AEAD phases and handshake waits.
        IDLE,
        START_INIT_PERM,
        WAIT_INIT_PERM,

        WAIT_AD_INPUT,
        WAIT_AD_PERM,
        START_AD_EMPTY_PAD_PERM,
        WAIT_AD_EMPTY_PAD_PERM,

        DOMAIN_SEPARATION,

        WAIT_PT_INPUT,
        WAIT_PT_PERM,
        APPLY_PT_EMPTY_PAD,

        START_FINAL_PERM,
        WAIT_FINAL_PERM,

        FINISH
    );

    signal current_top_state : TopStateType := IDLE;
    signal state_reg : std_logic_vector(319 downto 0) := (others => '0');         -- 320-bit Ascon state; S0 is low 64 bits and S4 is high 64 bits.

    signal key_internal_reg : std_logic_vector(127 downto 0) := (others => '0');  -- Key stored in internal little-endian byte order.
    signal has_ad_reg       : std_logic := '0';                                   -- Remembers whether this transaction has non-empty AD.
    signal expected_tag_reg : std_logic_vector(127 downto 0) := (others => '0');  -- Received tag stored at transaction start.
    signal block_last_reg   : std_logic := '0';                                   -- Remembers IS_LAST while p[8] is running.

    signal perm_start     : std_logic := '0';                                     -- One-cycle START pulse sent to ASCON_PERMUTATION.
    signal perm_round_sel : std_logic := '0';                                     -- 0=p[8], 1=p[12].
    signal perm_state_in  : std_logic_vector(319 downto 0) := (others => '0');
    signal perm_state_out : std_logic_vector(319 downto 0);
    signal perm_done      : std_logic;

    constant ASCON_AEAD_IV : std_logic_vector(63 downto 0):= x"00001000808C0001";                        -- NIST Ascon-AEAD128 IV = 0x00001000808c0001.
    constant ZERO128 : std_logic_vector(127 downto 0):= (others => '0');                             -- Reusable all-zero block for empty padding blocks.
        
begin
    -- Active internal processing; excludes waits for external AD/PT blocks.
    CORE_PROCESSING <= '0' when (current_top_state = IDLE or
                                  current_top_state = WAIT_AD_INPUT or
                                  current_top_state = WAIT_PT_INPUT or
                                  current_top_state = FINISH) else '1';


    PERM_INST : ASCON_PERMUTATION
        port map (
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
        variable plain_int     : std_logic_vector(127 downto 0);
        variable new_rate      : std_logic_vector(127 downto 0);
        variable computed_tag  : std_logic_vector(127 downto 0);
        variable n             : integer;
    begin

        if RESET = '1' then                                                       -- Reset all FSM, state and handshake registers.
            current_top_state <= IDLE;
            state_reg         <= (others => '0');
            key_internal_reg  <= (others => '0');
            has_ad_reg        <= '0';
            block_last_reg    <= '0';
            expected_tag_reg  <= (others => '0');

            perm_start        <= '0';
            perm_round_sel    <= '0';
            perm_state_in     <= (others => '0');

            DATA_OUT          <= (others => '0');
            TAG_VALID         <= '0';
            READY             <= '1';
            DONE              <= '0';

        elsif rising_edge(CLK) then

            perm_start <= '0';                                                    -- Default: permutation START is a one-clock pulse.
            DONE       <= '0';                                                    -- Default: DONE is also a one-clock pulse.

            case current_top_state is

                when IDLE =>                                                      -- Wait for a new AEAD encryption transaction.
                    READY <= '1';

                    if START = '1' then                                           -- Accept input only on a START pulse.
                        READY    <= '0';
                        DATA_OUT <= (others => '0');                              -- Return only the real ciphertext bytes in external order.
                        TAG_VALID <= '0';
                        expected_tag_reg <= TAG_IN;                               -- DECRYPT CHANGE: save received tag for final check.

                        key_int   := ext128_to_internal(KEY);                     -- Convert external key bytes to NIST little-endian internal order.
                        nonce_int := ext128_to_internal(NONCE);                   -- Convert nonce bytes to the same internal order.

                        key_internal_reg <= key_int;
                        has_ad_reg       <= PROCESS_AD;                           -- Save whether Algorithm 3 must process AD blocks.

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

                        temp_state(319 downto 192) :=                             -- NIST: S ^= (0^192 || K), so XOR K into S3||S4.
                            perm_state_out(319 downto 192)
                            xor key_internal_reg;

                        state_reg <= temp_state;                                  -- Save the absorbed padded final plaintext state.

                        if has_ad_reg = '1' then                                  -- Process AD only when AD is non-empty.
                            READY <= '1';
                            current_top_state <= WAIT_AD_INPUT;
                        else
                            current_top_state <= DOMAIN_SEPARATION;
                        end if;
                    end if;

                when WAIT_AD_INPUT =>                                             -- Accept the next associated-data block.
                    READY <= '1';

                    if START = '1' then                                           -- Accept input only on a START pulse.
                        READY <= '0';
                        n := to_integer(DATA_BYTES);                              -- Read the real block length in bytes.

                        assert n >= 0 and n <= 16                                 -- Check legal block length 0..16.
                            report "Invalid AD DATA_BYTES"
                            severity failure;

                        assert (n = 16) or (IS_LAST = '1')                        -- Only the final AD block may be shorter than 16 bytes.
                            report "A non-final AD block must contain exactly 16 bytes"
                            severity failure;

                        if n = 16 then                                            -- A full AD block is absorbed without padding here.
                            block_int :=                                          -- Build the unpadded plaintext block in internal byte order.
                                make_internal_block(DATA_IN, DATA_BYTES, false);  -- Convert the full block to internal little-endian order.
                        else
                            block_int :=                                          -- Build the unpadded plaintext block in internal byte order.
                                make_internal_block(DATA_IN, DATA_BYTES, true);   -- Convert and append NIST padding to the partial final block.
                        end if;

                        temp_state := state_reg;
                        temp_state(127 downto 0) :=                               -- Absorb into the 128-bit rate S[0:127] = S0||S1.
                            state_reg(127 downto 0) xor block_int;

                        block_last_reg <= IS_LAST;

                        perm_state_in  <= temp_state;
                        perm_round_sel <= '0';                                    -- Select p[8] for AD and full plaintext blocks.
                        perm_start     <= '1';
                        current_top_state <= WAIT_AD_PERM;
                    end if;

                when WAIT_AD_PERM =>                                              -- Wait for the p[8] required after each AD block.
                    READY <= '0';

                    if perm_done = '1' then
                        state_reg <= perm_state_out;

                        if block_last_reg = '1' then                              -- The real last AD/PT block has finished its required p[8].

                            if DATA_BYTES = to_unsigned(16, 5) then               -- Exact 16-byte AD end needs one extra empty padded block.
                                current_top_state <= START_AD_EMPTY_PAD_PERM;
                            else
                                current_top_state <= DOMAIN_SEPARATION;
                            end if;
                        else
                            READY <= '1';
                            current_top_state <= WAIT_AD_INPUT;
                        end if;
                    end if;

                when START_AD_EMPTY_PAD_PERM =>                                   -- Absorb pad(empty) because parse(A,128) creates an empty last block.
                    READY <= '0';

                    temp_state := state_reg;

                    padded_int :=                                                 -- Build the required empty padded rate block.
                        make_internal_block(
                            ZERO128,
                            to_unsigned(0, 5),
                            true
                        );

                    temp_state(127 downto 0) :=                                   -- Absorb into the 128-bit rate S[0:127] = S0||S1.
                        state_reg(127 downto 0) xor padded_int;

                    perm_state_in  <= temp_state;
                    perm_round_sel <= '0';                                        -- Select p[8] for AD and full plaintext blocks.
                    perm_start     <= '1';
                    current_top_state <= WAIT_AD_EMPTY_PAD_PERM;

                when WAIT_AD_EMPTY_PAD_PERM =>                                    -- Wait for p[8] on the extra AD padding block.
                    READY <= '0';

                    if perm_done = '1' then
                        state_reg <= perm_state_out;
                        current_top_state <= DOMAIN_SEPARATION;
                    end if;

                when DOMAIN_SEPARATION =>                                         -- Separate AD processing from plaintext processing.
                    READY <= '0';

                    state_reg(319) <= state_reg(319) xor '1';                     -- Append domain bit: Appendix A.2 gives S4 ^= 0x8000000000000000.

                    READY <= '1';
                    current_top_state <= WAIT_PT_INPUT;

                when WAIT_PT_INPUT =>                                             -- DECRYPT CHANGE: receive ciphertext, output plaintext.
                    READY <= '1';
                    if START = '1' then
                        READY <= '0';
                        n := to_integer(DATA_BYTES);
                        assert n >= 0 and n <= 16
                            report "Invalid CT DATA_BYTES" severity failure;
                        assert (n = 16) or (IS_LAST = '1')
                            report "A non-final CT block must contain 16 bytes" severity failure;

                        cipher_int := make_internal_block(DATA_IN, DATA_BYTES, false); -- Ciphertext bytes in little-endian order.
                        plain_int  := state_reg(127 downto 0) xor cipher_int;      -- NIST decryption: P = C xor current rate.
                        DATA_OUT   <= internal_to_ext_valid(plain_int, DATA_BYTES); -- Return only the valid plaintext bytes.

                        temp_state := state_reg;
                        if n < 16 then                                            -- DECRYPT CHANGE: final partial ciphertext block.
                            new_rate := state_reg(127 downto 0);                 -- Keep rate bytes beyond ciphertext unchanged.
                            for i in 0 to 15 loop
                                if i < n then
                                    new_rate(8*i+7 downto 8*i) := cipher_int(8*i+7 downto 8*i); -- Replace only valid bytes with C.
                                end if;
                            end loop;
                            new_rate(8*n+7 downto 8*n) := new_rate(8*n+7 downto 8*n) xor x"01"; -- NIST final pad bit.
                            temp_state(127 downto 0) := new_rate;
                            state_reg <= temp_state;
                            current_top_state <= START_FINAL_PERM;                -- No p[8] after final partial block.
                        else
                            temp_state(127 downto 0) := cipher_int;               -- DECRYPT CHANGE: full rate becomes ciphertext.
                            block_last_reg <= IS_LAST;
                            perm_state_in  <= temp_state;
                            perm_round_sel <= '0';                                -- Full ciphertext block is followed by p[8].
                            perm_start     <= '1';
                            current_top_state <= WAIT_PT_PERM;
                        end if;
                    end if;

                when WAIT_PT_PERM =>                                              -- Wait for p[8] after a full ciphertext block.
                    READY <= '0';

                    if perm_done = '1' then
                        state_reg <= perm_state_out;

                        if block_last_reg = '1' then                              -- The real last AD/PT block has finished its required p[8].

                            current_top_state <= APPLY_PT_EMPTY_PAD;              -- Full final ciphertext needs an extra empty padded block.
                        else
                            READY <= '1';
                            current_top_state <= WAIT_PT_INPUT;
                        end if;
                    end if;

                when APPLY_PT_EMPTY_PAD =>                                        -- Absorb pad(empty) after ciphertext length multiple of 16 bytes.
                    READY <= '0';

                    temp_state := state_reg;

                    padded_int :=                                                 -- Build the required empty padded rate block.
                        make_internal_block(
                            ZERO128,
                            to_unsigned(0, 5),
                            true
                        );

                    temp_state(127 downto 0) :=                                   -- Absorb into the 128-bit rate S[0:127] = S0||S1.
                        state_reg(127 downto 0) xor padded_int;

                    state_reg <= temp_state;                                      -- Save the absorbed padded final plaintext state.
                    current_top_state <= START_FINAL_PERM;                        -- No p[8] after the final partial plaintext block (NIST Eq. 27-29).

                when START_FINAL_PERM =>                                          -- NIST finalization: key injection followed by p[12].
                    READY <= '0';

                    temp_state := state_reg;

                    temp_state(255 downto 128) :=                                 -- NIST: S ^= (0^128 || K || 0^64), so XOR K into S2||S3.
                        state_reg(255 downto 128)
                        xor key_internal_reg;

                    perm_state_in  <= temp_state;
                    perm_round_sel <= '1';                                        -- Select p[12] for initialization/finalization.
                    perm_start     <= '1';
                    current_top_state <= WAIT_FINAL_PERM;

                when WAIT_FINAL_PERM =>                                           -- Wait for final Ascon-p[12].
                    READY <= '0';

                    if perm_done = '1' then

                        computed_tag := internal128_to_ext(                      -- DECRYPT CHANGE: compute the expected NIST tag.
                            perm_state_out(319 downto 192) xor key_internal_reg);
                        if computed_tag = expected_tag_reg then                  -- NIST: accept only if tags match.
                            TAG_VALID <= '1';
                        else
                            TAG_VALID <= '0';
                            DATA_OUT <= (others => '0');                          -- Hide last plaintext block on tag failure.
                        end if;

                        DONE  <= '1';                                             -- Signal successful end of encryption; TAG is now valid.
                        READY <= '1';
                        current_top_state <= FINISH;
                    end if;

                when FINISH =>                                                    -- Return cleanly to IDLE for the next transaction.
                    READY <= '1';
                    DONE  <= '0';
                    current_top_state <= IDLE;

                when others =>
                    current_top_state <= IDLE;
                    READY <= '1';

            end case;
        end if;
    end process;

end Behavioral;

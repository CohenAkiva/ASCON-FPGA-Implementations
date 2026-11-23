library IEEE;
		use IEEE.std_logic_1164.all;
		use IEEE.numeric_std.all;

entity wrapper is
    port 
	(
        CLK      : in  std_logic;
        RESET    : in  std_logic;
        TO_READ  : in  std_logic;
        TO_WRITE : in  std_logic;
        ADDRESS  : in  std_logic_vector(5 downto 0);
        DATA_IN  : in  std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0)
    );
end entity;

architecture wrapper_ARC of wrapper is
    signal reg_key, reg_nonce, reg_data_in, reg_data_out, reg_tag : std_logic_vector(127 downto 0) := (others => '0');
    signal key_written, nonce_written, data_written, tag_written : std_logic_vector(15 downto 0) := (others => '0');

    signal write_sync1, write_sync2, write_prev : std_logic := '0';
    signal read_sync1, read_sync2, read_prev : std_logic := '0';
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of write_sync1 : signal is "TRUE";
    attribute ASYNC_REG of write_sync2 : signal is "TRUE";
    attribute ASYNC_REG of read_sync1 : signal is "TRUE";
    attribute ASYNC_REG of read_sync2 : signal is "TRUE";

    signal ascon_start : std_logic := '0';
    signal ascon_ready, ascon_done : std_logic;
    signal ascon_data_out : std_logic_vector(127 downto 0);
    signal ascon_tag_valid : std_logic;
	
    signal tag_bank : std_logic := '0';
    signal auth_valid : std_logic := '0';
    signal saw_done : std_logic := '0';
    signal release_mode, verified, block_valid : std_logic := '0';
    signal block_bytes : unsigned(4 downto 0) := (others => '0');
    signal block_is_ad, block_is_last, init_has_ad : std_logic := '0';
    signal data_bytes_latched : unsigned(4 downto 0) := (others => '0');
    signal is_ad_latched, is_last_latched : std_logic := '0';
    signal result_bytes : unsigned(4 downto 0) := (others => '0');
    signal result_valid, transaction_done, transaction_started, error_flag : std_logic := '0';
    signal reg_output_byte : std_logic_vector(7 downto 0) := (others => '0');



    type WrapperState is (IDLE, START_INIT, WAIT_INIT_LOW, WAIT_INIT_HIGH,
                          START_BLOCK, WAIT_BLOCK_LOW, WAIT_BLOCK_HIGH);
    signal state : WrapperState := IDLE;
begin
    DATA_OUT <= reg_output_byte;
    u_ascon : entity work.ASCON_DECRYPT_TOP_LEVEL
        port map 
		(
            CLK => CLK, RESET => RESET, START => ascon_start,
            KEY => reg_key, NONCE => reg_nonce, DATA_IN => reg_data_in,
            DATA_BYTES => data_bytes_latched,
            PROCESS_AD => init_has_ad, -- Sampled at initialization; ignored for later blocks
            IS_LAST => is_last_latched,
            DATA_OUT => ascon_data_out, TAG_IN => reg_tag,
            TAG_VALID => ascon_tag_valid,
            READY => ascon_ready, DONE => ascon_done
        );

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                write_sync1 <= '0'; write_sync2 <= '0'; write_prev <= '0';
                read_sync1 <= '0'; read_sync2 <= '0'; read_prev <= '0';
            else
                write_sync1 <= TO_WRITE; write_sync2 <= write_sync1; write_prev <= write_sync2;
                read_sync1 <= TO_READ; read_sync2 <= read_sync1; read_prev <= read_sync2;
            end if;
        end if;
    end process;

    process(CLK)
        variable a : integer range 0 to 63;
        variable idx : integer range 0 to 15;
        variable status_byte : std_logic_vector(7 downto 0);
        variable all_bytes_written : boolean;
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                reg_key <= (others => '0'); reg_nonce <= (others => '0');
                reg_data_in <= (others => '0'); reg_data_out <= (others => '0');
                reg_tag <= (others => '0'); tag_bank <= '0'; auth_valid <= '0'; saw_done <= '0';
                release_mode <= '0'; verified <= '0'; block_valid <= '0';
                key_written <= (others => '0'); nonce_written <= (others => '0');
                data_written <= (others => '0'); tag_written <= (others => '0');
                block_bytes <= (others => '0'); data_bytes_latched <= (others => '0');
                block_is_ad <= '0'; block_is_last <= '0'; init_has_ad <= '0';
                is_ad_latched <= '0'; is_last_latched <= '0';
                result_bytes <= (others => '0');
                result_valid <= '0'; transaction_done <= '0';
                transaction_started <= '0'; error_flag <= '0';
                reg_output_byte <= (others => '0');
                ascon_start <= '0'; state <= IDLE;
            else
                ascon_start <= '0';
                a := to_integer(unsigned(ADDRESS));

                -- Read address map: CT=0..15, TAG=16..31, status=49,
                -- Output length at address 53. Addresses 54..61 are reserved.
                if read_sync2 = '1' and read_prev = '0' then
                    if a <= 15 then
                        idx := a;
                        if release_mode = '1' and verified = '1' and block_valid = '1' then
                            reg_output_byte <= reg_data_out(127-8*idx downto 120-8*idx);
                        else
                            reg_output_byte <= (others => '0');
                        end if;
                    elsif a <= 31 then
                        idx := a-16;
                        reg_output_byte <= reg_tag(127-8*idx downto 120-8*idx);
                    elsif a = 49 then
                        status_byte := (others => '0');
                        if state = IDLE and ascon_ready = '1' then 
						    status_byte(0) := '1';
						end if;
                        status_byte(1) := result_valid;
                        status_byte(2) := transaction_done;
                        status_byte(3) := error_flag;
                        status_byte(4) := auth_valid;
                        status_byte(5) := tag_bank;
                        status_byte(6) := verified;
                        status_byte(7) := release_mode;
                        reg_output_byte <= status_byte;
                    elsif a = 62 then
                        reg_output_byte <= "0000000" & tag_bank;
                    elsif a = 53 then
                        reg_output_byte <= "000" & std_logic_vector(result_bytes);
                    else
                        reg_output_byte <= (others => '0');
                    end if;
                end if;


                case state is
                    when IDLE =>
                        if write_sync2 = '1' and write_prev = '0' then
                            if a <= 15 then
                                idx := a;
                                reg_key(127-8*idx downto 120-8*idx) <= DATA_IN;
                                key_written(idx) <= '1';
                            elsif a <= 31 then
                                idx := a-16;
                                reg_nonce(127-8*idx downto 120-8*idx) <= DATA_IN;
                                nonce_written(idx) <= '1';
                            elsif a <= 47 then
                                idx := a-32;
                                if tag_bank = '1' then
                                    reg_tag(127-8*idx downto 120-8*idx) <= DATA_IN;
                                    tag_written(idx) <= '1';
                                else
                                    reg_data_in(127-8*idx downto 120-8*idx) <= DATA_IN;
                                    data_written(idx) <= '1';
                                end if;
                            elsif a = 62 then
                                tag_bank <= DATA_IN(0);
                            elsif a = 50 then
                                if DATA_IN(4 downto 0) <= "10000" then
                                    block_bytes <= unsigned(DATA_IN(4 downto 0));
                                else
                                    error_flag <= '1';
                                end if;
                            elsif a = 51 then
                                block_is_ad <= DATA_IN(0);
                                block_is_last <= DATA_IN(1);
                            elsif a = 52 then
                                init_has_ad <= DATA_IN(0);
                            elsif a = 48 then
                                if DATA_IN = x"01" or DATA_IN = x"03" or DATA_IN = x"04" then
                                    -- 01/03: begin verification pass; 04: begin release pass.
                                    if key_written = x"FFFF" and nonce_written = x"FFFF" and
                                       tag_written = x"FFFF" and ascon_ready = '1' and
                                       (DATA_IN /= x"04" or verified = '1') then
                                        if DATA_IN = x"04" then
                                            release_mode <= '1';
                                        else
                                            release_mode <= '0';
                                        end if;
                                        if DATA_IN /= x"04" then
                                            verified <= '0';
                                            auth_valid <= '0';
                                        end if;
                                        transaction_started <= '1';
                                        transaction_done <= '0';
                                        result_valid <= '0';
                                        block_valid <= '0';
                                        result_bytes <= (others => '0');
                                        reg_data_out <= (others => '0');
                                        error_flag <= '0';
                                        data_written <= (others => '0');
                                        reg_data_in <= (others => '0');
                                        state <= START_INIT;
                                    else
                                        error_flag <= '1';
                                    end if;
                                elsif DATA_IN = x"02" then
                                    all_bytes_written := true;
                                    for i in 0 to 15 loop
                                        if i < to_integer(block_bytes) and data_written(i) = '0' then
                                            all_bytes_written := false;
                                        end if;
                                    end loop;
                                    if transaction_started = '1' and transaction_done = '0' and
                                       ascon_ready = '1' and to_integer(block_bytes) <= 16 and
                                       all_bytes_written and tag_bank = '0' and
                                       (block_bytes = to_unsigned(16,5) or block_is_last = '1') and
                                       (block_is_ad = '0' or init_has_ad = '1') then
                                        data_bytes_latched <= block_bytes;
                                        is_ad_latched <= block_is_ad;
                                        is_last_latched <= block_is_last;
                                        result_valid <= '0';
                                        block_valid <= '0';
                                        state <= START_BLOCK;
                                    else
                                        error_flag <= '1';
                                    end if;
                                else
                                    error_flag <= '1';
                                end if;
                            end if;
                        end if;
                    when START_INIT =>
                        ascon_start <= '1';
                        state <= WAIT_INIT_LOW;
                    when WAIT_INIT_LOW =>
                        if ascon_ready = '0' then
						     state <= WAIT_INIT_HIGH;
					    end if;
                    when WAIT_INIT_HIGH =>
                        if ascon_ready = '1' then
                            state <= IDLE;
                        end if;
                    when START_BLOCK =>
                        saw_done <= '0';
                        ascon_start <= '1';
                        state <= WAIT_BLOCK_LOW;
                    when WAIT_BLOCK_LOW =>
                        if ascon_done = '1' then
						    saw_done <= '1';
						end if;
                        if ascon_ready = '0' then
                            -- TOP accepted START; capture plaintext before finalization.
                            if release_mode = '1' and is_ad_latched = '0' then
                                reg_data_out <= ascon_data_out;
                            end if;
                            state <= WAIT_BLOCK_HIGH;
                        end if;
                    when WAIT_BLOCK_HIGH =>
                        if ascon_done = '1' then
						    saw_done <= '1';
						end if;
                        if ascon_ready = '1' then
                            -- READY rises for intermediate blocks too; DONE only for final block.
                            if is_ad_latched = '0' and release_mode = '1' then
                                result_bytes <= data_bytes_latched;
                                result_valid <= '1';
                                block_valid <= '1';
                            end if;
                            if ascon_done = '1' or saw_done = '1' then
                                transaction_done <= '1';
                                transaction_started <= '0';
                                if release_mode = '0' then
                                    if ascon_tag_valid = '1' then
                                        verified <= '1';
                                        auth_valid <= '1';
                                    else
                                        verified <= '0';
                                        auth_valid <= '0';
                                        error_flag <= '1';
                                    end if;
                                elsif ascon_tag_valid = '0' then
                                    -- Defensive check: the trusted replay should authenticate too.
                                    verified <= '0';
                                    auth_valid <= '0';
                                    block_valid <= '0';
                                    result_valid <= '0';
                                    reg_data_out <= (others => '0');
                                    error_flag <= '1';
                                end if;
                            end if;
                            data_written <= (others => '0');
                            reg_data_in <= (others => '0');
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
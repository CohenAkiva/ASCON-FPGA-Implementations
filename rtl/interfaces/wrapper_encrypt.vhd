library IEEE;                                                                               --Defining Library Usage                                      
		use IEEE.std_logic_1164.all;
		use IEEE.numeric_std.all;

entity wrapper is                                                                           --Definition of the component's external interface (inputs and outputs)
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

architecture wrapper_ARC of wrapper is                                                                   --Definition of Registers, Signals, and FSM States.
    signal reg_key, reg_nonce, reg_data_in : std_logic_vector(127 downto 0) := (others => '0');
    signal reg_data_out, reg_tag : std_logic_vector(127 downto 0) := (others => '0');
    signal key_written, nonce_written, data_written : std_logic_vector(15 downto 0) := (others => '0');  --Write Buffer Fill Check.

    signal write_sync1, write_sync2, write_prev : std_logic := '0';                                      --The Two-Stage Synchronization Mechanism.
    signal read_sync1, read_sync2, read_prev : std_logic := '0';                                         --First sample, second sample, saving the previous value.
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of write_sync1 : signal is "TRUE";                                               --Inform Vivado that these signals are for synchronization.
    attribute ASYNC_REG of write_sync2 : signal is "TRUE";
    attribute ASYNC_REG of read_sync1 : signal is "TRUE";
    attribute ASYNC_REG of read_sync2 : signal is "TRUE";

    signal ascon_start : std_logic := '0';                                                          --When the wrapper wants to invoke the ASCON core
    signal ascon_ready, ascon_done : std_logic;                                                     --ASCON message to Wrapper: Additional block available / End of operation
    signal ascon_data_out, ascon_tag_out : std_logic_vector(127 downto 0);
    signal block_bytes : unsigned(4 downto 0) := (others => '0');                                   --The number of valid houses in the current block.
    signal block_is_ad, block_is_last, init_has_ad : std_logic := '0';                              --`init_has_ad` indicates, during the initialization phase, whether Associated Data is present.
    signal data_bytes_latched : unsigned(4 downto 0) := (others => '0');
    signal is_ad_latched, is_last_latched : std_logic := '0';
    signal result_bytes : unsigned(4 downto 0) := (others => '0');
    signal result_valid, transaction_done, transaction_started, error_flag : std_logic := '0';
    signal reg_output_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal last_cycles, total_cycles : std_logic_vector(31 downto 0);
    signal mon_cmd_start, mon_cmd_active, mon_cmd_stop, mon_transaction_reset : std_logic;

    type WrapperState is 
	    (
		 IDLE,                                          --Waiting for commands from the Raspberry Pi
		 START_INIT,                                    --Sending a reset command to ASCON
		 WAIT_INIT_LOW,                                 --Waiting for READY to drop to 0
		 WAIT_INIT_HIGH,                                --Waiting for READY to return to 1
		 START_BLOCK,
		 WAIT_BLOCK_LOW,
		 WAIT_BLOCK_HIGH
		);
    signal state : WrapperState := IDLE;
begin
    DATA_OUT <= reg_output_byte;

    -- Combinational event decode from the CURRENT wrapper state.
    -- The monitor samples these signals on the same rising edge as the wrapper.
    mon_cmd_start <= '1' when (state = START_INIT or state = START_BLOCK) else '0';
    mon_cmd_active <= '1' when state /= IDLE else '0';
    mon_cmd_stop <= '1' when ((state = WAIT_INIT_HIGH or state = WAIT_BLOCK_HIGH)
                                     and ascon_ready = '1') else '0';
    mon_transaction_reset <= '1' when (state = IDLE and write_sync2 = '1' and write_prev = '0'
                                        and ADDRESS = "110000" and DATA_IN = x"01"
                                        and key_written = x"FFFF" and nonce_written = x"FFFF"
                                        and ascon_ready = '1') else '0';

    u_performance_monitor : entity work.ASCON_PERFORMANCE_MONITOR
        port map (
            CLK => CLK, RESET => RESET,
            CMD_START => mon_cmd_start,
            CMD_ACTIVE => mon_cmd_active,
            CMD_STOP => mon_cmd_stop,
            TRANSACTION_RESET => mon_transaction_reset,
            LAST_CYCLES => last_cycles,
            TOTAL_CYCLES => total_cycles
        );



    u_ascon : entity work.ASCON_TOP_LEVEL
        port map                                       --The physical connection to the ASCON core,
		(
            CLK => CLK,
			RESET => RESET,
			START => ascon_start,
            KEY => reg_key,
			NONCE => reg_nonce,
			DATA_IN => reg_data_in,
            DATA_BYTES => data_bytes_latched,
            PROCESS_AD => init_has_ad,
            IS_LAST => is_last_latched,
            DATA_OUT => ascon_data_out,
			TAG => ascon_tag_out,
            READY => ascon_ready,
			DONE => ascon_done
        );

    process(CLK)
    begin                                                                --Implementation of the two-stage synchronization of control signals originating from the Raspberry Pi.
        if rising_edge(CLK) then
            if RESET = '1' then
                write_sync1 <= '0'; write_sync2 <= '0'; write_prev <= '0';
                read_sync1 <= '0'; read_sync2 <= '0'; read_prev <= '0';
            else
                write_sync1 <= TO_WRITE;
				write_sync2 <= write_sync1;
				write_prev <= write_sync2;
				
                read_sync1 <= TO_READ;
				read_sync2 <= read_sync1;
				read_prev <= read_sync2;
            end if;
        end if;
    end process;

    process(CLK)                                                             --Defining Variables
        variable a : integer range 0 to 63;
        variable idx : integer range 0 to 15;
        variable status_byte : std_logic_vector(7 downto 0);              --An auxiliary variable. Each of its bits represents different information about the system's state.
        variable all_bytes_written : boolean;
		
    begin
        if rising_edge(CLK) then
            if RESET = '1' then                                                                  --System Reset Check
                reg_key <= (others => '0'); reg_nonce <= (others => '0');
                reg_data_in <= (others => '0'); reg_data_out <= (others => '0');
                reg_tag <= (others => '0');
                key_written <= (others => '0'); nonce_written <= (others => '0');
                data_written <= (others => '0');
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

                -- Read address map:
                --CT=0..15, TAG=16..31, status=49, result length=53, last-command cycles=54..57, cumulative active cycles=58..61 (little-endian bytes).
                if read_sync2 = '1' and read_prev = '0' then                                                     --Watch startup following the two-step synchronization
                    if a <= 15 then
                        idx := a;
                        reg_output_byte <= reg_data_out(127-8*idx downto 120-8*idx);                             --Reading a byte from DATA_OUT
                    elsif a <= 31 then
                        idx := a-16;
                        reg_output_byte <= reg_tag(127-8*idx downto 120-8*idx);                                  --Read a byte from reg_data_out
                    elsif a = 49 then                                                                            --Reading the status register
                        status_byte := (others => '0');
                        if state = IDLE and ascon_ready = '1' then
						    status_byte(0) := '1';
						end if;
                        status_byte(1) := result_valid;
                        status_byte(2) := transaction_done;
                        status_byte(3) := error_flag;
                        reg_output_byte <= status_byte;                                                        --Preserving status upon exit
                    elsif a = 53 then                                    
                        reg_output_byte <= "000" & std_logic_vector(result_bytes);                             --Reading the number of valid bytes
                    elsif a >= 54 and a <= 57 then                                                               
                        idx := a-54;
                        reg_output_byte <= last_cycles(8*idx+7 downto 8*idx);                --Clock Meter Reading
                    elsif a >= 58 and a <= 61 then
                        idx := a-58;
                        reg_output_byte <= total_cycles(8*idx+7 downto 8*idx);
                    else
                        reg_output_byte <= (others => '0');                                                     --Handling an undefined read address
                    end if;
                end if;

                -- Count only FPGA processing cycles, not Raspberry Pi idle/transfer time.

                case state is
                    when IDLE =>
                        if write_sync2 = '1' and write_prev = '0' then                                    --Watch startup following the two-step synchronization
                            if a <= 15 then
                                idx := a;
                                reg_key(127-8*idx downto 120-8*idx) <= DATA_IN;                           --Writing a byte to a key
                                key_written(idx) <= '1';
                            elsif a <= 31 then
                                idx := a-16;
                                reg_nonce(127-8*idx downto 120-8*idx) <= DATA_IN;
                                nonce_written(idx) <= '1';                                                --Writing a byte to a nonce
                            elsif a <= 47 then
                                idx := a-32;
                                reg_data_in(127-8*idx downto 120-8*idx) <= DATA_IN;                       --Writing a byte to a DATA_OUT
                                data_written(idx) <= '1';                                                  
                            elsif a = 50 then                                                             --Defining the number of bytes in a block
                                if DATA_IN(4 downto 0) <= "10000" then                                    --If the number of bits is within the range, then it keeps it.
                                    block_bytes <= unsigned(DATA_IN(4 downto 0));
                                else
                                    error_flag <= '1';
                                end if;
                            elsif a = 51 then                                                              --Defining the block type and AD data
                                block_is_ad <= DATA_IN(0);
                                block_is_last <= DATA_IN(1);
                            elsif a = 52 then                                                               --Notification of AD presence as early as the boot stage
                                init_has_ad <= DATA_IN(0);
                            elsif a = 48 then                                                               --ASCON Initialization Command
                                if DATA_IN = x"01" then                                                     --Starting a new transaction
                                    if key_written = x"FFFF" and nonce_written = x"FFFF" and ascon_ready = '1' then
                                        transaction_started <= '1';                                         --Preparing the transaction status
										transaction_done <= '0';
                                        result_valid <= '0';
										error_flag <= '0';
                                        state <= START_INIT;
                                    else
                                        error_flag <= '1';
                                    end if;
                                elsif DATA_IN = x"02" then                                                  --Block processing command
                                    all_bytes_written := true;
                                    for i in 0 to 15 loop
                                        if i < to_integer(block_bytes) and data_written(i) = '0' then
                                            all_bytes_written := false;
                                        end if;
                                    end loop;
                                    if transaction_started = '1' and transaction_done = '0' and ascon_ready = '1' and to_integer(block_bytes) <= 16 and
                                       all_bytes_written and (block_bytes = to_unsigned(16,5) or block_is_last = '1') then
                                        data_bytes_latched <= block_bytes;
                                        is_ad_latched <= block_is_ad;
                                        is_last_latched <= block_is_last;
                                        result_valid <= '0';
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
                        ascon_start <= '1';
                        state <= WAIT_BLOCK_LOW;
                    when WAIT_BLOCK_LOW =>
                        if ascon_ready = '0' then
						    state <= WAIT_BLOCK_HIGH;
					    end if;
                    when WAIT_BLOCK_HIGH =>
                        if ascon_ready = '1' then
                            if is_ad_latched = '0' then
                                reg_data_out <= ascon_data_out;
                                result_bytes <= data_bytes_latched;
                                result_valid <= '1';
                            end if;
                            if ascon_done = '1' then
                                reg_tag <= ascon_tag_out;
                                transaction_done <= '1';
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

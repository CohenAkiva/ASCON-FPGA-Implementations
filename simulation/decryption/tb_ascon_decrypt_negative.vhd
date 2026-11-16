
----------------------------------------------------------------------------------
-- General KAT testbench for NIST SP 800-232 Ascon-AEAD128
--
-- Decrypts the CT prefix and checks it against PT.
-- Checks TAG_VALID against the final 16 bytes of CT.
-- Reads:
--   LWC_AEAD_KAT_128_128.txt
--
-- FAULT_MODE:
--   0 = Valid input
--   1 = Corrupt authentication tag
--   2 = Corrupt ciphertext
--   3 = Corrupt associated data
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_ascon_decrypt_negative is
    generic (
        FIRST_COUNT : integer := 1;
        LAST_COUNT  : integer := 1089;
        FAULT_MODE  : integer := 0
    );
end tb_ascon_decrypt_negative;


architecture sim of tb_ascon_decrypt_negative is

    component ASCON_DECRYPT_TOP_LEVEL is
        port (
            CLK        : in  std_logic;
            RESET      : in  std_logic;
            START      : in  std_logic;
            KEY        : in  std_logic_vector(127 downto 0);
            NONCE      : in  std_logic_vector(127 downto 0);
            DATA_IN    : in  std_logic_vector(127 downto 0);
            DATA_BYTES : in  unsigned(4 downto 0);
            PROCESS_AD : in  std_logic;
            IS_LAST    : in  std_logic;
            DATA_OUT   : out std_logic_vector(127 downto 0);
            TAG_IN     : in  std_logic_vector(127 downto 0);
            TAG_VALID  : out std_logic;
            READY      : out std_logic;
            DONE       : out std_logic
        );
    end component;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal start      : std_logic := '0';

    signal key        : std_logic_vector(127 downto 0) := (others => '0');
    signal nonce      : std_logic_vector(127 downto 0) := (others => '0');

    signal data_in    : std_logic_vector(127 downto 0) := (others => '0');
    signal data_bytes : unsigned(4 downto 0) := to_unsigned(0, 5);
    signal process_ad : std_logic := '0';
    signal is_last    : std_logic := '0';

    signal data_out   : std_logic_vector(127 downto 0);
    signal tag_in     : std_logic_vector(127 downto 0) := (others => '0');
    signal tag_valid  : std_logic;
    signal ready      : std_logic;
    signal done       : std_logic;

    constant CLK_PERIOD : time := 10 ns;
    constant KAT_FILE   : string := "verification/KAT/LWC_AEAD_KAT_128_128.txt";


    function hex_value(c : character) return integer is
    begin
        if c >= '0' and c <= '9' then
            return character'pos(c) - character'pos('0');
        elsif c >= 'A' and c <= 'F' then
            return 10 + character'pos(c) - character'pos('A');
        elsif c >= 'a' and c <= 'f' then
            return 10 + character'pos(c) - character'pos('a');
        else
            return -1;
        end if;
    end function;


    function is_hex_char(c : character) return boolean is
    begin
        return hex_value(c) >= 0;
    end function;


    function hex_byte(
        constant hs       : string;
        constant char_pos : integer
    ) return std_logic_vector is
        variable v : integer;
    begin
        v := 16*hex_value(hs(char_pos)) + hex_value(hs(char_pos+1));
        return std_logic_vector(to_unsigned(v, 8));
    end function;


    function hex_to_ext128(
        constant hs         : string;
        constant start_char : integer;
        constant nbytes     : integer
    ) return std_logic_vector is
        variable r : std_logic_vector(127 downto 0) := (others => '0');
    begin
        for i in 0 to 15 loop
            if i < nbytes then
                r(127-8*i downto 120-8*i) :=
                    hex_byte(hs, start_char + 2*i);
            end if;
        end loop;
        return r;
    end function;


    function parse_decimal_after_equals(
        constant s : string
    ) return integer is
        variable value   : integer := 0;
        variable started : boolean := false;
    begin
        for i in s'range loop
            if s(i) = '=' then
                started := true;
            elsif started and s(i) >= '0' and s(i) <= '9' then
                value := value*10 +
                    character'pos(s(i)) - character'pos('0');
            end if;
        end loop;
        return value;
    end function;


begin

    UUT : ASCON_DECRYPT_TOP_LEVEL
        port map (
            CLK        => clk,
            RESET      => reset,
            START      => start,
            KEY        => key,
            NONCE      => nonce,
            DATA_IN    => data_in,
            DATA_BYTES => data_bytes,
            PROCESS_AD => process_ad,
            IS_LAST    => is_last,
            DATA_OUT   => data_out,
            TAG_IN     => tag_in,
            TAG_VALID  => tag_valid,
            READY      => ready,
            DONE       => done
        );


    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;


    stim_proc : process

        file kat_file : text open read_mode is KAT_FILE;
        variable l : line;

        constant MAX_LINE : integer := 16384;
        constant MAX_HEX  : integer := 8192;

        variable linebuf : string(1 to MAX_LINE) := (others => ' ');
        variable llen    : integer := 0;

        variable key_str   : string(1 to 64) := (others => ' ');
        variable nonce_str : string(1 to 64) := (others => ' ');
        variable pt_str    : string(1 to MAX_HEX) := (others => ' ');
        variable ad_str    : string(1 to MAX_HEX) := (others => ' ');
        variable ct_str    : string(1 to MAX_HEX) := (others => ' ');

        variable key_len   : integer := 0;
        variable nonce_len : integer := 0;
        variable pt_len    : integer := 0;
        variable ad_len    : integer := 0;
        variable ct_len    : integer := 0;

        variable current_count : integer := 0;

        variable got_key   : boolean;
        variable got_nonce : boolean;
        variable got_pt    : boolean;
        variable got_ad    : boolean;
        variable got_ct    : boolean;
        variable got_count : boolean;

        variable pt_bytes  : integer;
        variable ad_bytes  : integer;

        variable offset      : integer;
        variable block_bytes : integer;
        variable block_data  : std_logic_vector(127 downto 0);

        variable expected_byte : std_logic_vector(7 downto 0);
        variable actual_byte   : std_logic_vector(7 downto 0);

        variable vector_ok : boolean;
        variable ct_ok     : boolean;
        variable tag_ok    : boolean;

        variable expected_tag : std_logic_vector(127 downto 0);

        variable tested : integer := 0;
        variable passed : integer := 0;
        variable failed : integer := 0;


        procedure clear_vector_buffers is
        begin
            key_str   := (others => ' ');
            nonce_str := (others => ' ');
            pt_str    := (others => ' ');
            ad_str    := (others => ' ');
            ct_str    := (others => ' ');

            key_len   := 0;
            nonce_len := 0;
            pt_len    := 0;
            ad_len    := 0;
            ct_len    := 0;
        end procedure;


        procedure copy_line_to_buffer is
        begin
            linebuf := (others => ' ');
            llen := 0;

            for i in l.all'range loop
                if llen < linebuf'length then
                    llen := llen + 1;
                    linebuf(llen) := l.all(i);
                end if;
            end loop;
        end procedure;


        procedure read_hex_field(
            variable dest : out string;
            variable dlen : out integer
        ) is
            variable seen_equals : boolean := false;
        begin
            for k in dest'range loop
                dest(k) := ' ';
            end loop;
            dlen := 0;

            for i in 1 to llen loop
                if linebuf(i) = '=' then
                    seen_equals := true;
                elsif seen_equals and is_hex_char(linebuf(i)) then
                    if dlen < dest'length then
                        dlen := dlen + 1;
                        dest(dlen) := linebuf(i);
                    end if;
                end if;
            end loop;
        end procedure;


        procedure pulse_start is
        begin
            -- Put START high with half a cycle of setup before the active edge.
            wait until falling_edge(clk);
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
        end procedure;


        procedure wait_ready_after_accept is
        begin
            -- READY is high before acceptance. Wait for the transaction/block
            -- to make it low and then high again.
            wait until ready = '0';
            wait until ready = '1';
        end procedure;


        procedure build_external_block(
            constant hs          : in string;
            constant byte_offset : in integer;
            constant nbytes      : in integer;
            variable result      : out std_logic_vector(127 downto 0)
        ) is
        begin
            result := (others => '0');

            for j in 0 to 15 loop
                if j < nbytes then
                    result(127-8*j downto 120-8*j) :=
                        hex_byte(hs, 2*(byte_offset+j)+1);
                end if;
            end loop;
        end procedure;


        procedure check_plaintext_block(
            constant byte_offset : in integer;
            constant nbytes      : in integer;
            variable ok          : inout boolean
        ) is
        begin
            for j in 0 to 15 loop
                if j < nbytes then
                    expected_byte :=
                        hex_byte(pt_str, 2*(byte_offset+j)+1);

                    actual_byte :=
                        data_out(127-8*j downto 120-8*j);

                    if actual_byte /= expected_byte then
                        ok := false;
                        report
                            "Plaintext mismatch at Count=" &
                            integer'image(current_count) &
                            ", byte=" &
                            integer'image(byte_offset+j) &
                            ", expected=" &
                            to_hstring(expected_byte) &
                            ", actual=" &
                            to_hstring(actual_byte)
                            severity error;
                    end if;
                end if;
            end loop;
        end procedure;


    begin

        ----------------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------------
        reset <= '1';
        start <= '0';
        wait for 4*CLK_PERIOD;
        wait until falling_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);

        report "============================================================";
        report "NIST SP 800-232 ASCON-AEAD128 DECRYPTION KAT testbench";
        report "Requested Count range: " &
               integer'image(FIRST_COUNT) & " .. " &
               integer'image(LAST_COUNT);
        report "============================================================";


        ----------------------------------------------------------------------
        -- Scan the KAT file
        ----------------------------------------------------------------------
        while not endfile(kat_file) loop

            got_count := false;

            -- Find the next Count line.
            while (not endfile(kat_file)) and (not got_count) loop
                readline(kat_file, l);
                copy_line_to_buffer;

                if llen >= 5 then
                    if linebuf(1)='C' and linebuf(2)='o' and
                       linebuf(3)='u' and linebuf(4)='n' and
                       linebuf(5)='t' then

                        current_count :=
                            parse_decimal_after_equals(linebuf(1 to llen));

                        got_count := true;
                    end if;
                end if;
            end loop;

            exit when not got_count;

            clear_vector_buffers;

            got_key   := false;
            got_nonce := false;
            got_pt    := false;
            got_ad    := false;
            got_ct    := false;

            -- Read fields until all five required fields were found.
            while not (got_key and got_nonce and got_pt and got_ad and got_ct) loop
                exit when endfile(kat_file);

                readline(kat_file, l);
                copy_line_to_buffer;

                if llen >= 3 then

                    if linebuf(1)='K' and linebuf(2)='e' and linebuf(3)='y' then
                        read_hex_field(key_str, key_len);
                        got_key := true;

                    elsif llen >= 5 and
                          linebuf(1)='N' and linebuf(2)='o' and
                          linebuf(3)='n' and linebuf(4)='c' and
                          linebuf(5)='e' then
                        read_hex_field(nonce_str, nonce_len);
                        got_nonce := true;

                    elsif linebuf(1)='P' and linebuf(2)='T' then
                        read_hex_field(pt_str, pt_len);
                        got_pt := true;

                    elsif linebuf(1)='A' and linebuf(2)='D' then
                        read_hex_field(ad_str, ad_len);
                        got_ad := true;

                    elsif linebuf(1)='C' and linebuf(2)='T' then
                        read_hex_field(ct_str, ct_len);
                        got_ct := true;
                    end if;
                end if;
            end loop;


            ------------------------------------------------------------------
            -- Run only the selected count range.
            ------------------------------------------------------------------
            if current_count >= FIRST_COUNT and current_count <= LAST_COUNT then

                if (FAULT_MODE = 2 and pt_len = 0) or
                   (FAULT_MODE = 3 and ad_len = 0) then
                    report "SKIP Count=" &
                           integer'image(current_count) &
                           " (no data to corrupt)";
                    next;
                end if;

                vector_ok := true;
                ct_ok     := true;
                tag_ok    := true;
                tested    := tested + 1;

                pt_bytes := pt_len / 2;
                ad_bytes := ad_len / 2;

                assert key_len = 32
                    report "KAT Key length is not 128 bits"
                    severity failure;

                assert nonce_len = 32
                    report "KAT Nonce length is not 128 bits"
                    severity failure;

                assert ct_len = 2*(pt_bytes + 16)
                    report "KAT CT length is not PT length + 16-byte tag"
                    severity failure;


                --------------------------------------------------------------
                -- Load key / nonce in external KAT byte order.
                --------------------------------------------------------------
                key   <= hex_to_ext128(key_str, 1, 16);
                nonce <= hex_to_ext128(nonce_str, 1, 16);

                expected_tag :=
                    hex_to_ext128(ct_str, 2*pt_bytes + 1, 16);

                if FAULT_MODE = 1 then
                    expected_tag(127) := not expected_tag(127);
                end if;

                tag_in <= expected_tag;
                data_in    <= (others => '0');
                data_bytes <= to_unsigned(0, 5);
                is_last    <= '0';

                if ad_bytes > 0 then
                    process_ad <= '1';
                else
                    process_ad <= '0';
                end if;


                --------------------------------------------------------------
                -- Start transaction / initialization.
                --------------------------------------------------------------
                pulse_start;
                wait_ready_after_accept;


                --------------------------------------------------------------
                -- Associated Data
                --------------------------------------------------------------
                if ad_bytes > 0 then
                    offset := 0;

                    while offset < ad_bytes loop
                        block_bytes := ad_bytes - offset;

                        if block_bytes > 16 then
                            block_bytes := 16;
                        end if;

                        build_external_block(
                            ad_str,
                            offset,
                            block_bytes,
                            block_data
                        );

                        if FAULT_MODE = 3 and offset = 0 then
                            block_data(127) := not block_data(127);
                        end if;

                        data_in    <= block_data;
                        data_bytes <= to_unsigned(block_bytes, 5);
                        process_ad <= '1';

                        if offset + block_bytes = ad_bytes then
                            is_last <= '1';
                        else
                            is_last <= '0';
                        end if;

                        pulse_start;
                        wait_ready_after_accept;

                        offset := offset + block_bytes;
                    end loop;
                end if;


                --------------------------------------------------------------
                -- Ciphertext input -> recovered plaintext output
                --------------------------------------------------------------
                process_ad <= '0';

                if pt_bytes = 0 then
                    -- Empty plaintext is the empty final block.
                    data_in    <= (others => '0');
                    data_bytes <= to_unsigned(0, 5);
                    is_last    <= '1';

                    pulse_start;
                    wait until done = '1';

                else
                    offset := 0;

                    while offset < pt_bytes loop
                        block_bytes := pt_bytes - offset;

                        if block_bytes > 16 then
                            block_bytes := 16;
                        end if;

                        build_external_block(
                            ct_str,
                            offset,
                            block_bytes,
                            block_data
                        );

                        if FAULT_MODE = 2 and offset = 0 then
                            block_data(127) := not block_data(127);
                        end if;

                        data_in    <= block_data;
                        data_bytes <= to_unsigned(block_bytes, 5);

                        if offset + block_bytes = pt_bytes then
                            is_last <= '1';
                        else
                            is_last <= '0';
                        end if;

                        pulse_start;

                        -- DATA_OUT holds recovered plaintext after acceptance.
                        wait for 1 ns;

                        if FAULT_MODE = 0 or FAULT_MODE = 1 then
                            check_plaintext_block(offset, block_bytes, ct_ok);
                        end if;

                        if offset + block_bytes = pt_bytes then
                            wait until done = '1';
                        else
                            wait until ready = '1';
                        end if;

                        offset := offset + block_bytes;
                    end loop;
                end if;


                --------------------------------------------------------------
                -- Authentication: compare the computed tag with TAG_IN.
                --------------------------------------------------------------
                if FAULT_MODE = 0 then
                    if tag_valid /= '1' then
                        tag_ok := false;
                        report "Expected TAG_VALID=1 at Count=" &
                               integer'image(current_count)
                               severity error;
                    end if;
                else
                    if tag_valid /= '0' then
                        tag_ok := false;
                        report "Expected TAG_VALID=0 at Count=" &
                               integer'image(current_count)
                               severity error;
                    end if;
                end if;

                vector_ok := ct_ok and tag_ok;

                if vector_ok then
                    passed := passed + 1;
                    report "PASS Count = " &
                           integer'image(current_count);
                else
                    failed := failed + 1;
                    report "FAIL Count = " &
                           integer'image(current_count)
                           severity error;
                end if;


                -- Let DONE fall and the FSM return fully to IDLE.
                wait until rising_edge(clk);

            end if;

            exit when current_count >= LAST_COUNT;

        end loop;


        ----------------------------------------------------------------------
        -- Summary
        ----------------------------------------------------------------------
        report "============================================================";
        report "AUTHENTICATION TEST SUMMARY - FAULT_MODE=" &
               integer'image(FAULT_MODE);
        report "TESTED = " & integer'image(tested);
        report "PASSED = " & integer'image(passed);
        report "FAILED = " & integer'image(failed);
        report "============================================================";

        if tested = 0 then
            report "No KAT vectors were tested. Check FIRST_COUNT/LAST_COUNT."
                severity failure;
        elsif failed = 0 then
            report "ALL SELECTED TEST VECTORS PASSED.";
            finish(0);
        else
            report "ONE OR MORE SELECTED TEST VECTORS FAILED."
                severity failure;
            finish(1);
        end if;

        wait;
    end process;

end sim;

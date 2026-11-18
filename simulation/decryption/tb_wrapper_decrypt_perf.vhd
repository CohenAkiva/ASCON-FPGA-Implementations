library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_wrapper_decrypt is
end entity;

architecture sim of tb_wrapper_decrypt is
    constant PERIOD : time := 10 ns;
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal to_read, to_write : std_logic := '0';
    signal address : std_logic_vector(5 downto 0) := (others => '0');
    signal data_in : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out : std_logic_vector(7 downto 0);

    constant KEY_HEX : string := "000102030405060708090A0B0C0D0E0F";
    constant NONCE_HEX : string := "101112131415161718191A1B1C1D1E1F";

    function nibble(c : character) return natural is
    begin
        if c >= '0' and c <= '9' then
            return character'pos(c) - character'pos('0');
        elsif c >= 'A' and c <= 'F' then
            return 10 + character'pos(c) - character'pos('A');
        elsif c >= 'a' and c <= 'f' then
            return 10 + character'pos(c) - character'pos('a');
        end if;
        assert false report "Invalid hex character" severity failure;
        return 0;
    end function;

    function hex_byte(s : string; i : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(
            16*nibble(s(s'low+2*i)) + nibble(s(s'low+2*i+1)), 8));
    end function;
begin
    clk <= not clk after PERIOD/2;

    dut : entity work.wrapper
        port map (
            CLK => clk, RESET => reset,
            TO_READ => to_read, TO_WRITE => to_write,
            ADDRESS => address, DATA_IN => data_in, DATA_OUT => data_out
        );

    stimulus : process
        variable status : std_logic_vector(7 downto 0);
        variable value : std_logic_vector(7 downto 0);
        variable tests : natural := 0;
        variable perf_step : natural := 1;

        procedure write_byte(a : natural; b : std_logic_vector(7 downto 0)) is
        begin
            assert a <= 63 severity failure;
            wait until falling_edge(clk);
            address <= std_logic_vector(to_unsigned(a, 6));
            data_in <= b;
            to_write <= '1';
            -- The wrapper synchronizes the strobe over two clock cycles.
            for k in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
            wait until falling_edge(clk);
            to_write <= '0';
            for k in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure write_num(a : natural; b : natural) is
        begin
            write_byte(a, std_logic_vector(to_unsigned(b, 8)));
        end procedure;

        procedure write_hex(base : natural; s : string) is
        begin
            assert s'length mod 2 = 0 severity failure;
            assert s'length <= 32 severity failure;
            for i in 0 to s'length/2-1 loop
                write_byte(base+i, hex_byte(s, i));
            end loop;
        end procedure;

        procedure read_byte(a : natural; variable b : out std_logic_vector(7 downto 0)) is
        begin
            wait until falling_edge(clk);
            address <= std_logic_vector(to_unsigned(a, 6));
            to_read <= '1';
            for k in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
            b := data_out;
            wait until falling_edge(clk);
            to_read <= '0';
            for k in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure wait_status(mask : std_logic_vector(7 downto 0);
                              expected : std_logic_vector(7 downto 0)) is
            variable s : std_logic_vector(7 downto 0);
        begin
            for k in 1 to 500 loop
                read_byte(49, s);
                if (s and mask) = expected then
                    return;
                end if;
            end loop;
            assert false report "TIMEOUT waiting for STATUS mask=" &
                to_hstring(mask) & " expected=" & to_hstring(expected) &
                " last=" & to_hstring(s) severity failure;
        end procedure;

        -- Read a 32-bit counter from four little-endian MMIO bytes.
        procedure read_counter(base : natural; variable result : out unsigned(31 downto 0)) is
            variable b : std_logic_vector(7 downto 0);
        begin
            result := (others => '0');
            for i in 0 to 3 loop
                read_byte(base+i, b);
                result(8*i+7 downto 8*i) := unsigned(b);
            end loop;
        end procedure;

        procedure report_cycles(phase : string) is
            variable last_value  : unsigned(31 downto 0);
            variable total_value : unsigned(31 downto 0);
        begin
            read_counter(54, last_value);
            read_counter(58, total_value);
            report "DECRYPT_PERF,Step=" & integer'image(perf_step) &
                   ",Phase=" & phase &
                   ",LAST=" & integer'image(to_integer(last_value)) &
                   ",TOTAL=" & integer'image(to_integer(total_value));
            perf_step := perf_step + 1;
        end procedure;

        procedure reset_dut is
        begin
            wait until falling_edge(clk);
            reset <= '1';
            to_read <= '0';
            to_write <= '0';
            for k in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
            wait until falling_edge(clk);
            reset <= '0';
            for k in 1 to 3 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure initialize(tag_hex : string; has_ad : boolean) is
        begin
            write_hex(0, KEY_HEX);
            write_hex(16, NONCE_HEX);
            write_num(62, 1);  -- TAG bank
            write_hex(32, tag_hex);
            write_num(62, 0);  -- Input-data bank
            if has_ad then
                write_num(52, 1);
            else
                write_num(52, 0);
            end if;
            write_num(48, 1);  -- Initialize
            wait_status(x"01", x"01"); -- Ready for the first block
            report_cycles("INIT");
        end procedure;

        procedure send_block(s : string; is_ad : boolean) is
            variable flags : natural;
        begin
            if s'length > 0 then
                write_hex(32, s);
            end if;
            write_num(50, s'length/2);
            if is_ad then
                flags := 3;  -- AD, final AD block
            else
                flags := 2;  -- CT, final ciphertext block
            end if;
            write_num(51, flags);
            write_num(48, 2);
            if is_ad then
                wait_status(x"01", x"01");
            else
                wait_status(x"04", x"04"); -- Transaction complete
            end if;
            if is_ad then
                report_cycles("AD");
            else
                report_cycles("CT");
            end if;
        end procedure;

        procedure expect_status(auth_ok : boolean) is
            variable s : std_logic_vector(7 downto 0);
        begin
            read_byte(49, s);
            assert s(2) = '1' report "Transaction DONE not set" severity error;
            assert s(3) = '0' report "Wrapper error flag set" severity error;
            if auth_ok then
                assert s(4) = '1' and s(1) = '1'
                    report "Expected authenticated valid result, STATUS=" &
                    to_hstring(s) severity error;
            else
                assert s(4) = '0' and s(1) = '0'
                    report "Corrupted tag unexpectedly accepted, STATUS=" &
                    to_hstring(s) severity error;
            end if;
        end procedure;

        procedure expect_plaintext(s : string; valid : boolean) is
            variable b : std_logic_vector(7 downto 0);
            variable n : natural;
        begin
            n := s'length/2;
            read_byte(53, b);
            if valid then
                assert to_integer(unsigned(b)) = n
                    report "Wrong plaintext byte count" severity error;
            else
                assert b = x"00" report "Invalid plaintext length not zero" severity error;
            end if;
            for i in 0 to 15 loop
                read_byte(i, b);
                if valid and i < n then
                    assert b = hex_byte(s, i)
                        report "Plaintext mismatch at byte " & integer'image(i) &
                        ": got " & to_hstring(b) severity error;
                else
                    assert b = x"00"
                        report "Plaintext should be hidden/zero at byte " &
                        integer'image(i) severity error;
                end if;
            end loop;
        end procedure;

        procedure check_hidden_before_completion is
            variable b : std_logic_vector(7 downto 0);
        begin
            read_byte(0, b);
            assert b = x"00" report "Plaintext exposed before authentication" severity error;
        end procedure;

    begin
        report "START WRAPPER DECRYPTION INTEGRATION TESTS";

        -- KAT Count 1: empty AD and empty plaintext.
        reset_dut;
        initialize("4F9C278211BEC9316BF68F46EE8B2EC6", false);
        check_hidden_before_completion;
        send_block("", false);
        expect_status(true);
        expect_plaintext("", true);
        tests := tests+1;
        report "PASS Count=1: empty ciphertext, valid tag";

        -- KAT Count 2: 1 byte of AD, empty plaintext.
        reset_dut;
        initialize("CCCB674FE18A09A285D6AB11B35675C0", true);
        send_block("30", true);
        check_hidden_before_completion;
        send_block("", false);
        expect_status(true);
        expect_plaintext("", true);
        tests := tests+1;
        report "PASS Count=2: AD and empty ciphertext";

        -- KAT Count 34: one ciphertext byte E8 -> plaintext 20.
        reset_dut;
        initialize("DD576ABA1CD3E6FC704DE02AEDB79588", false);
        check_hidden_before_completion;
        send_block("E8", false);
        expect_status(true);
        expect_plaintext("20", true);
        tests := tests+1;
        report "PASS Count=34: 1-byte ciphertext";

        -- KAT Count 50: 16-byte AD and 1-byte ciphertext.
        reset_dut;
        initialize("8BBACE2C82A050832E46B3224A9552A0", true);
        send_block("303132333435363738393A3B3C3D3E3F", true);
        send_block("63", false);
        expect_status(true);
        expect_plaintext("20", true);
        tests := tests+1;
        report "PASS Count=50: full AD block, 1-byte ciphertext";

        -- KAT Count 529: exactly 16 bytes of ciphertext.
        reset_dut;
        initialize("9EAA915C9DD3245D77048F24D46D27A7", false);
        send_block("E8C3DEEE246CC5EAE3E872313897A2BB", false);
        expect_status(true);
        expect_plaintext("202122232425262728292A2B2C2D2E2F", true);
        tests := tests+1;
        report "PASS Count=529: full ciphertext block";

        -- Negative: flip first bit of the Count 34 tag.
        reset_dut;
        initialize("5D576ABA1CD3E6FC704DE02AEDB79588", false);
        check_hidden_before_completion;
        send_block("E8", false);
        expect_status(false);
        expect_plaintext("20", false);
        tests := tests+1;
        report "PASS Count=34: corrupted TAG rejected, plaintext hidden";

        -- Negative: corrupt the Count 34 ciphertext but keep the original tag.
        reset_dut;
        initialize("DD576ABA1CD3E6FC704DE02AEDB79588", false);
        send_block("E9", false);
        expect_status(false);
        expect_plaintext("20", false);
        tests := tests+1;
        report "PASS Count=34: corrupted ciphertext rejected";

        -- Negative: corrupt the Count 2 AD but keep the original tag.
        reset_dut;
        initialize("CCCB674FE18A09A285D6AB11B35675C0", true);
        send_block("31", true);
        send_block("", false);
        expect_status(false);
        expect_plaintext("", false);
        tests := tests+1;
        report "PASS Count=2: corrupted AD rejected";

        report "====================================================";
        report "ALL " & integer'image(tests) &
               " WRAPPER DECRYPTION TESTS COMPLETED";
        report "====================================================";
        finish(0);
        wait;
    end process;
end architecture;

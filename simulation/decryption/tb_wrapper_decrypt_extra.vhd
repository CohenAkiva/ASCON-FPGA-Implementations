library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_wrapper_decrypt_extra is
end entity;

architecture sim of tb_wrapper_decrypt_extra is
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

        -- Two-pass protocol: 03=VERIFY, 04=RELEASE, 02=BLOCK.
        -- STATUS: bit0 READY, bit1 RESULT_VALID, bit2 DONE,
        -- bit3 ERROR, bit4 AUTH, bit6 VERIFIED, bit7 RELEASE_MODE.
        procedure prepare(tag_hex : string; has_ad : boolean) is
        begin
            write_hex(0, KEY_HEX);
            write_hex(16, NONCE_HEX);
            write_num(62, 1);
            write_hex(32, tag_hex);
            write_num(62, 0);
            if has_ad then write_num(52, 1);
            else write_num(52, 0); end if;
        end procedure;

        procedure send_block(s : string; is_ad : boolean) is
            variable flags : natural;
            variable status_byte : std_logic_vector(7 downto 0);
        begin
            if s'length > 0 then write_hex(32, s); end if;
            write_num(50, s'length/2);
            if is_ad then flags := 3; else flags := 2; end if;
            write_num(51, flags);
            write_num(48, 2);
            wait_status(x"01", x"01");
            read_byte(49, status_byte);
            assert status_byte(3) = '0' or status_byte(2) = '1'
                report "Unexpected wrapper error during block" severity failure;
        end procedure;

        procedure check_hidden is
            variable b : std_logic_vector(7 downto 0);
        begin
            read_byte(53, b);
            assert b = x"00" report "Result length visible before release" severity failure;
            for i in 0 to 15 loop
                read_byte(i, b);
                assert b = x"00" report "Plaintext exposed before release" severity failure;
            end loop;
        end procedure;

        procedure run_pass(ad_hex : string; ct_hex : string; release_pass : boolean) is
            variable s : std_logic_vector(7 downto 0);
        begin
            if release_pass then write_num(48, 4);
            else write_num(48, 3); end if;
            wait_status(x"01", x"01");
            if ad_hex'length > 0 then send_block(ad_hex, true); end if;
            send_block(ct_hex, false);
            wait_status(x"04", x"04");
            read_byte(49, s);
            if release_pass then
                assert s(7)='1' and s(6)='1' and s(4)='1' and s(3)='0'
                    report "Release pass failed: STATUS=" & to_hstring(s) severity failure;
            else
                assert s(7)='0' report "VERIFY incorrectly entered RELEASE mode" severity failure;
                check_hidden;
            end if;
        end procedure;

        procedure expect_verify(valid : boolean) is
            variable s : std_logic_vector(7 downto 0);
        begin
            read_byte(49, s);
            assert s(2)='1' report "VERIFY did not finish" severity failure;
            if valid then
                assert s(6)='1' and s(4)='1' and s(3)='0'
                    report "Valid message rejected: STATUS=" & to_hstring(s) severity failure;
            else
                assert s(6)='0' and s(4)='0' and s(3)='1'
                    report "Invalid message accepted: STATUS=" & to_hstring(s) severity failure;
            end if;
            check_hidden;
        end procedure;

        procedure expect_plaintext(s : string) is
            variable b : std_logic_vector(7 downto 0);
            variable n : natural;
        begin
            n := s'length/2;
            read_byte(53, b);
            assert to_integer(unsigned(b))=n
                report "Wrong plaintext byte count" severity failure;
            for i in 0 to 15 loop
                read_byte(i, b);
                if i < n then
                    assert b=hex_byte(s,i)
                        report "Plaintext mismatch at byte " & integer'image(i) severity failure;
                else
                    assert b=x"00" report "Nonzero padding/output" severity failure;
                end if;
            end loop;
        end procedure;

        procedure reject_release is
            variable s : std_logic_vector(7 downto 0);
        begin
            write_num(48, 4);
            read_byte(49, s);
            assert s(3)='1' and s(7)='0' and s(6)='0'
                report "Unauthorized RELEASE was not rejected: STATUS=" & to_hstring(s)
                severity failure;
            check_hidden;
        end procedure;

    begin
        report "START TWO-PASS WRAPPER EXTRA REGRESSION";
        reset_dut;
        prepare("4F9C278211BEC9316BF68F46EE8B2EC6", false);
        run_pass("", "", false); expect_verify(true);
        run_pass("", "", true); expect_plaintext("");
        tests:=tests+1; report "PASS 1: empty message";

        -- Consecutive transactions without reset; no stale result may leak.
        prepare("9EAA915C9DD3245D77048F24D46D27A7", false);
        run_pass("", "E8C3DEEE246CC5EAE3E872313897A2BB", false); expect_verify(true);
        run_pass("", "E8C3DEEE246CC5EAE3E872313897A2BB", true);
        expect_plaintext("202122232425262728292A2B2C2D2E2F");
        tests:=tests+1; report "PASS 2: valid transaction without reset";

        prepare("5D576ABA1CD3E6FC704DE02AEDB79588", false);
        run_pass("", "E8", false); expect_verify(false); reject_release;
        tests:=tests+1; report "PASS 3: invalid tag after valid transaction";

        prepare("83AECC1DA0834A52940EC4BFCDDB6404", false);
        run_pass("", "E8C3DEEE246CC5EAE3E872313897A2", false); expect_verify(true);
        run_pass("", "E8C3DEEE246CC5EAE3E872313897A2", true);
        expect_plaintext("202122232425262728292A2B2C2D2E");
        tests:=tests+1; report "PASS 4: valid 15-byte transaction after failure";

        reset_dut;
        read_byte(49,status);
        assert (status and x"DE")=x"00"
            report "Reset did not clear status" severity failure;
        check_hidden;
        tests:=tests+1; report "PASS 5: reset clears status and plaintext";

        prepare("DD576ABA1CD3E6FC704DE02AEDB79588", false);
        write_num(50,17);
        read_byte(49,status);
        assert status(3)='1'
            report "Invalid DATA_BYTES=17 not rejected" severity failure;
        tests:=tests+1; report "PASS 6: invalid block length rejected";

        report "ALL " & integer'image(tests) & " TWO-PASS EXTRA TESTS PASSED";
        finish(0);
        wait;
    end process;
end architecture;

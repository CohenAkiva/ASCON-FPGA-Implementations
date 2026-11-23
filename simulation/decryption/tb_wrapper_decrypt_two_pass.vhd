-- KAT-driven two-pass wrapper testbench (VHDL-2008)
-- Protocol: 0x03 VERIFY, 0x04 RELEASE, 0x02 PROCESS_BLOCK.
-- Assumes trusted Raspberry Pi replays the same data.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_wrapper_decrypt_two_pass is
  generic (
    FIRST_COUNT : integer := 1;
    LAST_COUNT : integer := 1089;
    KAT_FILE : string := "verification/KAT/LWC_AEAD_KAT_128_128.txt"
  );
end entity;

architecture sim of tb_wrapper_decrypt_two_pass is
  constant CLK_PERIOD : time := 10 ns;
  signal clk : std_logic := '0';
  signal reset, to_read, to_write : std_logic := '0';
  signal address : std_logic_vector(5 downto 0) := (others => '0');
  signal data_in, data_out : std_logic_vector(7 downto 0) := (others => '0');
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
  clk <= not clk after CLK_PERIOD/2;
  dut : entity work.wrapper port map (
    CLK => clk, RESET => reset, TO_READ => to_read,
    TO_WRITE => to_write, ADDRESS => address,
    DATA_IN => data_in, DATA_OUT => data_out);
  stimulus : process
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
            -- 'dest' is an unconstrained STRING formal parameter.
            -- ModelSim 2020.1 does not allow (others => ' ') on such a formal,
            -- so clear it explicitly over its actual constrained range.
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



    procedure write_byte(a : natural; b : std_logic_vector(7 downto 0)) is
    begin
      wait until falling_edge(clk);
      address <= std_logic_vector(to_unsigned(a, 6));
      data_in <= b; to_write <= '1';
      for k in 1 to 5 loop wait until rising_edge(clk); end loop;
      wait until falling_edge(clk); to_write <= '0';
      for k in 1 to 5 loop wait until rising_edge(clk); end loop;
    end procedure;

    procedure write_num(a : natural; b : natural) is
    begin
      write_byte(a, std_logic_vector(to_unsigned(b, 8)));
    end procedure;

    procedure read_byte(a : natural; variable b : out std_logic_vector(7 downto 0)) is
    begin
      wait until falling_edge(clk);
      address <= std_logic_vector(to_unsigned(a, 6)); to_read <= '1';
      for k in 1 to 5 loop wait until rising_edge(clk); end loop;
      wait for 1 ns; b := data_out;
      wait until falling_edge(clk); to_read <= '0';
      for k in 1 to 5 loop wait until rising_edge(clk); end loop;
    end procedure;

    procedure wait_status(mask : std_logic_vector(7 downto 0);
                          expected : std_logic_vector(7 downto 0)) is
      variable s : std_logic_vector(7 downto 0);
    begin
      for k in 1 to 3000 loop
        read_byte(49, s);
        if (s and mask) = expected then return; end if;
      end loop;
      assert false report "STATUS timeout Count=" & integer'image(current_count) &
        " mask=" & to_hstring(mask) & " expected=" & to_hstring(expected) &
        " actual=" & to_hstring(s) severity failure;
    end procedure;

    procedure load_hex(base : natural; hs : string; first_byte : integer;
                       count_bytes : integer) is
    begin
      for i in 0 to count_bytes-1 loop
        write_byte(base+i, hex_byte(hs, 2*(first_byte+i)+1));
      end loop;
    end procedure;

    procedure send_block
	(
        hs          : string;
        first_byte  : integer;
        count_bytes : integer;
        is_ad       : boolean;
        is_last     : boolean
    ) is
        variable flags : natural := 0;
    begin
        write_num(62, 0);
        load_hex(32, hs, first_byte, count_bytes);
        write_num(50, count_bytes);

        if is_ad then
            flags := flags + 1;
        end if;

        if is_last then
            flags := flags + 2;
        end if;

        write_num(51, flags);
        write_num(48, 2);

        wait_status(x"01", x"01");

        -- Check the Wrapper error flag.
        read_byte(49, actual_byte);

        assert actual_byte(3) = '0'
            report "Wrapper error Count=" &
                   integer'image(current_count)
            severity failure;
    end procedure;

    procedure run_pass(
        release_pass : boolean;
        variable ok  : inout boolean
    ) is
      variable n : integer;
      variable s : std_logic_vector(7 downto 0);
    begin
      if release_pass then write_num(48, 4);
      else write_num(48, 3); end if;
      wait_status(x"01", x"01");
      if ad_bytes > 0 then
        offset := 0;
        while offset < ad_bytes loop
          n := ad_bytes-offset; if n > 16 then n := 16; end if;
          send_block(ad_str, offset, n, true, offset+n=ad_bytes);
          offset := offset+n;
        end loop;
      end if;
      offset := 0;
      if pt_bytes = 0 then
        send_block(ct_str, 0, 0, false, true);
      else
        while offset < pt_bytes loop
          n := pt_bytes-offset; if n > 16 then n := 16; end if;
          send_block(ct_str, offset, n, false, offset+n=pt_bytes);
          if release_pass then
            wait_status(x"02", x"02");
            read_byte(53, s);
            if to_integer(unsigned(s(4 downto 0))) /= n then
              ok := false;
              report "Length mismatch Count=" & integer'image(current_count) severity error;
            end if;
            for j in 0 to n-1 loop
              read_byte(j, actual_byte);
              expected_byte := hex_byte(pt_str, 2*(offset+j)+1);
              if actual_byte /= expected_byte then
                ok := false;
                report "PT mismatch Count=" & integer'image(current_count) &
                  " byte=" & integer'image(offset+j) &
                  " expected=" & to_hstring(expected_byte) &
                  " actual=" & to_hstring(actual_byte) severity error;
              end if;
            end loop;
          else
            read_byte(0, actual_byte);
            if actual_byte /= x"00" then
              ok := false;
              report "Plaintext leaked in VERIFY Count=" &
                integer'image(current_count) severity error;
            end if;
          end if;
          offset := offset+n;
        end loop;
      end if;
      wait_status(x"04", x"04"); -- final DONE
    end procedure;
  begin
    reset <= '1'; wait for 8*CLK_PERIOD;
    wait until falling_edge(clk); reset <= '0';
    report "Starting two-pass wrapper KAT";
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

                vector_ok := true;
                ct_ok     := true; -- Tracks recovered plaintext bytes.
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


                -- Reload KEY/NONCE/TAG for each KAT case.
                -- Reset avoids stale write masks between vectors.
                wait until falling_edge(clk); reset <= '1';
                wait for 4*CLK_PERIOD;
                wait until falling_edge(clk); reset <= '0';
                load_hex(0, key_str, 0, 16);
                load_hex(16, nonce_str, 0, 16);
                write_num(62, 1);
                load_hex(32, ct_str, pt_bytes, 16);
                write_num(62, 0);
                if ad_bytes > 0 then write_num(52, 1);
                else write_num(52, 0); end if;
                run_pass(false, vector_ok);
                read_byte(49, actual_byte);
                if actual_byte(6) /= '1' or actual_byte(4) /= '1' then
                  vector_ok := false;
                  report "VERIFY failed Count=" & integer'image(current_count) severity error;
                end if;
                if vector_ok then
                  run_pass(true, vector_ok);
                end if;
                if vector_ok then
                  passed := passed + 1;
                  report "PASS Count=" & integer'image(current_count);
                else
                  failed := failed + 1;
                  report "FAIL Count=" & integer'image(current_count) severity error;
                end if;
            end if;
            exit when current_count >= LAST_COUNT;
        end loop;
        report "KAT SUMMARY tested=" & integer'image(tested) &
               " passed=" & integer'image(passed) &
               " failed=" & integer'image(failed);
        if tested = 0 or failed /= 0 then
          assert false report "TWO-PASS KAT FAILED" severity failure;
        else
          report "ALL TWO-PASS KAT VECTORS PASSED";
          finish(0);
        end if;
        wait;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_wrapper_v2 is end entity;
architecture sim of tb_wrapper_v2 is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal to_read, to_write : std_logic := '0';
  signal address : std_logic_vector(5 downto 0) := (others=>'0');
  signal data_in, data_out : std_logic_vector(7 downto 0) := (others=>'0');
  constant KEY_HEX : string := "000102030405060708090A0B0C0D0E0F";
  constant NONCE_HEX : string := "101112131415161718191A1B1C1D1E1F";

  function hex_nibble(c: character) return natural is
  begin
    case c is
      when '0' to '9' => return character'pos(c)-character'pos('0');
      when 'A' to 'F' => return character'pos(c)-character'pos('A')+10;
      when 'a' to 'f' => return character'pos(c)-character'pos('a')+10;
      when others => assert false report "Invalid hex" severity failure; return 0;
    end case;
  end;
  function hex_byte(s: string; i: natural) return std_logic_vector is
    variable v: natural;
  begin
    v:=16*hex_nibble(s(s'low+2*i))+hex_nibble(s(s'low+2*i+1));
    return std_logic_vector(to_unsigned(v,8));
  end;
begin
  clk <= not clk after 5 ns;
  dut: entity work.wrapper port map(
    CLK=>clk, RESET=>reset, TO_READ=>to_read, TO_WRITE=>to_write,
    ADDRESS=>address, DATA_IN=>data_in, DATA_OUT=>data_out);

  stimulus: process
    procedure wr(a: natural; v: std_logic_vector(7 downto 0)) is
    begin
      address <= std_logic_vector(to_unsigned(a,6)); data_in <= v;
      wait for 40 ns;
      to_write <= '1'; wait for 50 ns;
      to_write <= '0'; wait for 40 ns;
    end procedure;
    procedure rd(a: natural; variable v: out std_logic_vector(7 downto 0)) is
    begin
      address <= std_logic_vector(to_unsigned(a,6));
      wait for 40 ns;
      to_read <= '1'; wait for 50 ns;
      v := data_out;
      to_read <= '0'; wait for 40 ns;
    end procedure;
    procedure wait_ready is
      variable v: std_logic_vector(7 downto 0);
      variable ready: boolean := false;
    begin
      for i in 0 to 500 loop
        rd(49,v);
        if v(3)='1' then assert false report "Wrapper error status" severity failure; end if;
        if v(0)='1' then ready:=true; exit; end if;
      end loop;
      assert ready report "Timeout waiting for ready" severity failure;
    end procedure;
    procedure write_hex(base: natural; s: string) is
    begin
      assert s'length mod 2 = 0 severity failure;
      for i in 0 to s'length/2-1 loop wr(base+i,hex_byte(s,i)); end loop;
    end procedure;
    procedure block_send(s: string; start_byte: natural; n: natural; ad: boolean; last: boolean) is
      variable flags: natural:=0;
    begin
      for i in 0 to n-1 loop
        wr(32+i,hex_byte(s,start_byte+i));
      end loop;
      wr(50,std_logic_vector(to_unsigned(n,8)));
      if ad then flags:=flags+1; end if;
      if last then flags:=flags+2; end if;
      wr(51,std_logic_vector(to_unsigned(flags,8)));
      wr(48,x"02");
      wait_ready;
    end procedure;
    procedure run_case(id: natural; ad: string; pt: string; ct_tag: string) is
      variable v: std_logic_vector(7 downto 0);
      variable ptlen,adlen,clen: natural;
      variable off,n: natural;
    begin
      ptlen:=pt'length/2; adlen:=ad'length/2; clen:=ct_tag'length/2-16;
      assert clen=ptlen report "KAT length mismatch" severity failure;
      report "KAT Count=" & integer'image(id) &
        " AD=" & integer'image(adlen) & " PT=" & integer'image(ptlen);
      write_hex(0,KEY_HEX); write_hex(16,NONCE_HEX);
      if adlen=0 then wr(52,x"00"); else wr(52,x"01"); end if;
      wr(48,x"01"); wait_ready;
      off:=0;
      while off<adlen loop
        if (adlen - off) >= 16 then
			n := 16;
		else
			n := adlen - off;
		end if;
        block_send(ad,off,n,true,off+n=adlen);
        off:=off+n;
      end loop;
      off:=0;
      loop
        if (ptlen - off) >= 16 then
			n := 16;
		else
			n := ptlen - off;
		end if;
        block_send(pt,off,n,false,off+n=ptlen);
        rd(53,v);
        assert to_integer(unsigned(v))=n report "Wrong CT valid byte count" severity failure;
        for i in 0 to n-1 loop
          rd(i,v);
          assert v=hex_byte(ct_tag,off+i)
            report "Ciphertext mismatch Count=" & integer'image(id) &
              " byte=" & integer'image(off+i) severity failure;
        end loop;
        off:=off+n;
        exit when off=ptlen;
      end loop;
      rd(49,v);
      assert v(2)='1' report "Transaction done not set" severity failure;
      for i in 0 to 15 loop
        rd(16+i,v);
        assert v=hex_byte(ct_tag,ptlen+i)
          report "Tag mismatch Count=" & integer'image(id) &
          " byte=" & integer'image(i) severity failure;
      end loop;
      report "PASS Count=" & integer'image(id);
    end procedure;
  begin
    wait for 50 ns; reset<='0'; wait for 100 ns;
    run_case(1, "", "", "4F9C278211BEC9316BF68F46EE8B2EC6");
    run_case(2, "30", "", "CCCB674FE18A09A285D6AB11B35675C0");
    run_case(17, "303132333435363738393A3B3C3D3E3F", "", "E4230CDB8330EE9DC0CFD7C7B346E6DC");
    run_case(529, "", "202122232425262728292A2B2C2D2E2F", "E8C3DEEE246CC5EAE3E872313897A2BB9EAA915C9DD3245D77048F24D46D27A7");
    run_case(530, "30", "202122232425262728292A2B2C2D2E2F", "96107D8A29A7529A7941BDC7DF1FE3C6B48691673A22DA04BCC261FEE0FD6A4D");
    run_case(545, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E2F", "6373EBB28BE97C9BAC090CF399C13EF13ABFC0D209E8F4844C90814D13F32C59");
    run_case(578, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E2F30", "6373EBB28BE97C9BAC090CF399C13EF14E97E8B4E670B6AF4CB7DB044B2685F85A");
    run_case(1057, "", "202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F", "E8C3DEEE246CC5EAE3E872313897A2BB6089AA3E15E80307970F2D1F006654C2AAA5FA172CB9F07D07463CEFC7440BC1");
    run_case(1073, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F", "6373EBB28BE97C9BAC090CF399C13EF14EA6C5E519E30A5C6EF44F7CEA881AB7ABEF171657D19C6C1138B7577693E439");
    report "ALL V2 KAT CASES PASSED";
    stop;
    wait;
  end process;
end architecture;

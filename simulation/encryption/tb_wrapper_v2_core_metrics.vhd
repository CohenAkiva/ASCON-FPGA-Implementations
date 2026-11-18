library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_wrapper_v2_core_metrics is end entity;
architecture sim of tb_wrapper_v2_core_metrics is
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal to_read, to_write : std_logic := '0';
  signal address : std_logic_vector(5 downto 0) := (others=>'0');
  signal data_in, data_out : std_logic_vector(7 downto 0) := (others=>'0');
  constant KEY_HEX : string := "000102030405060708090A0B0C0D0E0F";
  constant NONCE_HEX : string := "101112131415161718191A1B1C1D1E1F";

    -- VHDL-2008 external names: simulator must support hierarchical aliases.
    alias mon_core_reset is << signal .tb_wrapper_v2_core_metrics.dut.mon_transaction_reset : std_logic >>;
    alias mon_core_start is << signal .tb_wrapper_v2_core_metrics.dut.core_start_event : std_logic >>;
    alias mon_core_stop is << signal .tb_wrapper_v2_core_metrics.dut.core_stop_event : std_logic >>;
    alias mon_core_busy is << signal .tb_wrapper_v2_core_metrics.dut.core_processing : std_logic >>;
    alias mon_core_latency is << signal .tb_wrapper_v2_core_metrics.dut.core_last_latency : std_logic_vector(31 downto 0) >>;
    alias mon_core_active is << signal .tb_wrapper_v2_core_metrics.dut.core_last_active : std_logic_vector(31 downto 0) >>;
    alias mon_core_total is << signal .tb_wrapper_v2_core_metrics.dut.core_total_active : std_logic_vector(31 downto 0) >>;
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
    procedure read_counter(base_addr: natural; variable result: out unsigned(31 downto 0)) is
      variable b: std_logic_vector(7 downto 0);
    begin
      result := (others=>'0');
      for j in 0 to 3 loop
        rd(base_addr+j,b);
        result(8*j+7 downto 8*j) := unsigned(b);
      end loop;
    end procedure;
    procedure run_case(id: natural; ad: string; pt: string; ct_tag: string) is
      variable v: std_logic_vector(7 downto 0);
      variable ptlen,adlen,clen: natural;
      variable off,n: natural;
      variable cycle_count, last_count, init_count: unsigned(31 downto 0);
      variable ad_count, pt_count: natural;

    begin
      ptlen:=pt'length/2; adlen:=ad'length/2; clen:=ct_tag'length/2-16;
      assert clen=ptlen report "KAT length mismatch" severity failure;
      report "KAT Count=" & integer'image(id) &
        " AD=" & integer'image(adlen) & " PT=" & integer'image(ptlen);
      write_hex(0,KEY_HEX); write_hex(16,NONCE_HEX);
      if adlen=0 then wr(52,x"00"); else wr(52,x"01"); end if;
      wr(48,x"01"); wait_ready;
      read_counter(54,init_count);
      ad_count:=0; pt_count:=0;
      off:=0;
      while off<adlen loop
        if adlen-off >= 16 then n:=16; else n:=adlen-off; end if;
        block_send(ad,off,n,true,off+n=adlen);
        read_counter(54,last_count);
        ad_count:=ad_count+to_integer(last_count);
        off:=off+n;
      end loop;
      off:=0;
      loop
        if ptlen-off >= 16 then n:=16; else n:=ptlen-off; end if;
        block_send(pt,off,n,false,off+n=ptlen);
        read_counter(54,last_count);
        pt_count:=pt_count+to_integer(last_count);
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
      read_counter(58,cycle_count);
      assert cycle_count = init_count + ad_count + pt_count
        report "Counter sum mismatch Count=" & integer'image(id) severity failure;
      report "PERF,Count=" & integer'image(id) &
        ",AD=" & integer'image(adlen) &
        ",PT=" & integer'image(ptlen) &
        ",INIT=" & integer'image(to_integer(init_count)) &
        ",AD_CYC=" & integer'image(ad_count) &
        ",PT_CYC=" & integer'image(pt_count) &
        ",TOTAL=" & integer'image(to_integer(cycle_count));
    end procedure;
  begin
    wait for 50 ns; reset<='0'; wait for 100 ns;
    report "PERF columns: Count,AD,PT,INIT,AD_CYC,PT_CYC,TOTAL";
    run_case(1, "", "", "4F9C278211BEC9316BF68F46EE8B2EC6");
    run_case(2, "30", "", "CCCB674FE18A09A285D6AB11B35675C0");
    run_case(17, "303132333435363738393A3B3C3D3E3F", "", "E4230CDB8330EE9DC0CFD7C7B346E6DC");
    run_case(33, "303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F", "", "EFC3E78B02AD9A80A6F0548C5B0BB5BA");
    run_case(34, "", "20", "E8DD576ABA1CD3E6FC704DE02AEDB79588");
    run_case(35, "30", "20", "962B8016836C75A7D86866588CA245D886");
    run_case(50, "303132333435363738393A3B3C3D3E3F", "20", "638BBACE2C82A050832E46B3224A9552A0");
    run_case(66, "303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F", "20", "CB9963324ED507234028425D0F64BA269C");
    run_case(496, "", "202122232425262728292A2B2C2D2E", "E8C3DEEE246CC5EAE3E872313897A283AECC1DA0834A52940EC4BFCDDB6404");
    run_case(497, "30", "202122232425262728292A2B2C2D2E", "96107D8A29A7529A7941BDC7DF1FE370915182EE42081F9D1622AD33F30BE6");
    run_case(512, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E", "6373EBB28BE97C9BAC090CF399C13E646BE0C80B0404770341EB48D6178948");
    run_case(528, "303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F", "202122232425262728292A2B2C2D2E", "CB34D04660A66DBFBE9C856601F5B8C79104F5675250A98B8EEADC36B8EBBE");
    run_case(529, "", "202122232425262728292A2B2C2D2E2F", "E8C3DEEE246CC5EAE3E872313897A2BB9EAA915C9DD3245D77048F24D46D27A7");
    run_case(530, "30", "202122232425262728292A2B2C2D2E2F", "96107D8A29A7529A7941BDC7DF1FE3C6B48691673A22DA04BCC261FEE0FD6A4D");
    run_case(545, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E2F", "6373EBB28BE97C9BAC090CF399C13EF13ABFC0D209E8F4844C90814D13F32C59");
    run_case(561, "303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F", "202122232425262728292A2B2C2D2E2F", "CB34D04660A66DBFBE9C856601F5B8AA7A81D0A7A37F8A346C0F6FC60093D40B");
    run_case(562, "", "202122232425262728292A2B2C2D2E2F30", "E8C3DEEE246CC5EAE3E872313897A2BB60301002539D456275DD0B0CEAB3B23844");
    run_case(563, "30", "202122232425262728292A2B2C2D2E2F30", "96107D8A29A7529A7941BDC7DF1FE3C6C7EA70D7986E7B59CD0D357239F5D25BF5");
    run_case(578, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E2F30", "6373EBB28BE97C9BAC090CF399C13EF14E97E8B4E670B6AF4CB7DB044B2685F85A");
    run_case(594, "303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F", "202122232425262728292A2B2C2D2E2F30", "CB34D04660A66DBFBE9C856601F5B8AA510D7CAAB912FC145145DF923A2403A85F");
    run_case(1057, "", "202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F", "E8C3DEEE246CC5EAE3E872313897A2BB6089AA3E15E80307970F2D1F006654C2AAA5FA172CB9F07D07463CEFC7440BC1");
    run_case(1058, "30", "202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F", "96107D8A29A7529A7941BDC7DF1FE3C6C7210336AB5B1EB94CFC067CE2248742B9E5DBBB767A4AD97D1949F09022CD66");
    run_case(1073, "303132333435363738393A3B3C3D3E3F", "202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F", "6373EBB28BE97C9BAC090CF399C13EF14EA6C5E519E30A5C6EF44F7CEA881AB7ABEF171657D19C6C1138B7577693E439");
    run_case(1089, "303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F", "202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F", "CB34D04660A66DBFBE9C856601F5B8AA51A499B55AC8F7FBEFBC331A613EE9CDFD191750A47F211C0A15ED28173D7CAA");
    report "ALL 24 PERFORMANCE KAT CASES PASSED";
    stop;
    wait;
  end process;

    core_scoreboard: process
        variable running : boolean := false;
        variable elapsed : natural := 0;
        variable active : natural := 0;
        variable total : natural := 0;
        variable completed : natural := 0;
        variable expect_last_latency : natural := 0;
        variable expect_last_active : natural := 0;
        variable reset_event : boolean;
        variable start_event : boolean;
        variable stop_event : boolean;
        variable busy_event : boolean;
    begin
        loop
            wait until rising_edge(clk);
            reset_event := reset = '1' or mon_core_reset = '1';
            start_event := mon_core_start = '1';
            stop_event := mon_core_stop = '1';
            busy_event := mon_core_busy = '1';
            if reset_event then
                running := false;
                elapsed := 0;
                active := 0;
                total := 0;
                completed := 0;
                expect_last_latency := 0;
                expect_last_active := 0;
            elsif start_event then
                assert not running report "CORE: overlapping START" severity failure;
                running := true;
                elapsed := 0;
                active := 0;
            elsif running then
                if stop_event then
                    expect_last_latency := elapsed;
                    expect_last_active := active;
                    total := total + active;
                    running := false;
                    completed := completed + 1;
                else
                    elapsed := elapsed + 1;
                    if busy_event then active := active + 1; end if;
                end if;
            end if;
            wait for 1 ns;
            if reset_event then
                assert unsigned(mon_core_latency) = 0 and
                       unsigned(mon_core_active) = 0 and
                       unsigned(mon_core_total) = 0
                    report "CORE: reset did not clear counters" severity failure;
            elsif stop_event and completed > 0 then
                assert unsigned(mon_core_latency) = to_unsigned(expect_last_latency,32)
                    report "CORE: LAST_LATENCY mismatch" severity failure;
                assert unsigned(mon_core_active) = to_unsigned(expect_last_active,32)
                    report "CORE: LAST_ACTIVE mismatch" severity failure;
                assert unsigned(mon_core_total) = to_unsigned(total,32)
                    report "CORE: TOTAL_ACTIVE mismatch" severity failure;
                assert expect_last_active <= expect_last_latency
                    report "CORE: ACTIVE exceeds LATENCY" severity failure;
                report "CORE_METRICS,Operation=" & integer'image(completed) &
                       ",LATENCY=" & integer'image(expect_last_latency) &
                       ",ACTIVE=" & integer'image(expect_last_active) &
                       ",TOTAL_ACTIVE=" & integer'image(total);
            end if;
        end loop;
    end process;
end architecture;

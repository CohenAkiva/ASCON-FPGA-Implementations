library IEEE;
	use IEEE.std_logic_1164.all;                                                        
    
entity ASCON_ROUND is
    port 
	(
        ROUND_CONST : in std_logic_vector(7 downto 0);                              -- 8-bit round constant input to differentiate rounds
        S0_in, S1_in, S2_in, S3_in, S4_in : in std_logic_vector(63 downto 0);       -- 64-bit input state words (Total 320 bits)
        S0_out, S1_out, S2_out, S3_out, S4_out : out std_logic_vector(63 downto 0)  -- 64-bit output state words after 1 round
    );
end ASCON_ROUND;

architecture Behavioral of ASCON_ROUND is
    signal S0_pc, S1_pc, S2_pc, S3_pc, S4_pc : std_logic_vector(63 downto 0);       -- State after constant-addition layer pC.
    signal S0_ps, S1_ps, S2_ps, S3_ps, S4_ps : std_logic_vector(63 downto 0);       -- State after substitution layer pS.
	
begin
    ----------------------------------------------------------------------------
    -- 1. CONSTANT ADDITION pC
    ----------------------------------------------------------------------------
    S0_pc <= S0_in;                                                               -- pC does not change S0.
    S1_pc <= S1_in;                                                               -- pC does not change S1.
    S2_pc <= S2_in(63 downto 8) & (S2_in(7 downto 0) xor ROUND_CONST);            --   S2[7:0] <- S2[7:0] XOR round_constant The remaining bits are unchanged.
    S3_pc <= S3_in;                                                               -- pC does not change S3.
    S4_pc <= S4_in;                                                               -- pC does not change S4.
	
    ----------------------------------------------------------------------------
    -- 2. SUBSTITUTION LAYER pS
    ----------------------------------------------------------------------------
    process(S0_pc, S1_pc, S2_pc, S3_pc, S4_pc)                                    -- Combinational bit-sliced S-box, applied to 64 slices in parallel.
        variable x0, x1, x2, x3, x4 : std_logic_vector(63 downto 0);              -- Working vectors for the five S-box bit planes.
        variable t0, t1, t2, t3, t4 : std_logic_vector(63 downto 0);              -- Temporary vectors for the non-linear S-box terms.
    begin

        x0 := S0_pc xor S4_pc;                                                    -- S-box input affine step.
        x1 := S1_pc;                                                              -- S1 enters this step unchanged.
        x2 := S2_pc xor S1_pc;                                                    -- S-box input affine step.
        x3 := S3_pc;                                                              -- S3 enters this step unchanged.
        x4 := S4_pc xor S3_pc;                                                    -- S-box input affine step.

        t0 := x0 xor ((not x1) and x2);                                           -- Non-linear chi term for output plane 0.
        t1 := x1 xor ((not x2) and x3);                                           -- Non-linear chi term for output plane 1.
        t2 := x2 xor ((not x3) and x4);                                           -- Non-linear chi term for output plane 2.
        t3 := x3 xor ((not x4) and x0);                                           -- Non-linear chi term for output plane 3.
        t4 := x4 xor ((not x0) and x1);                                           -- Non-linear chi term for output plane 4.

        t1 := t1 xor t0;                                                          -- Final S-box affine mixing.
        t0 := t0 xor t4;                                                          -- Final S-box affine mixing.
        t3 := t3 xor t2;                                                          -- Final S-box affine mixing.
        t2 := not t2;                                                             -- Final S-box inversion required by Ascon.

        S0_ps <= t0;                                                              -- Store S-box output S0.
        S1_ps <= t1;                                                              -- Store S-box output S1.
        S2_ps <= t2;                                                              -- Store S-box output S2.
        S3_ps <= t3;                                                              -- Store S-box output S3.
        S4_ps <= t4;                                                              -- Store S-box output S4.
    end process;

    ----------------------------------------------------------------------------
    -- 3. LINEAR DIFFUSION LAYER pL
    ----------------------------------------------------------------------------
    S0_out <= S0_ps xor (S0_ps(18 downto 0) & S0_ps(63 downto 19)) xor (S0_ps(27 downto 0) & S0_ps(63 downto 28));    -- S0 = S0 XOR ROTR(S0,19) XOR ROTR(S0,28)
    S1_out <= S1_ps xor (S1_ps(60 downto 0) & S1_ps(63 downto 61)) xor (S1_ps(38 downto 0) & S1_ps(63 downto 39));    -- S1 = S1 XOR ROTR(S1,61) XOR ROTR(S1,39)
    S2_out <= S2_ps xor (S2_ps(0) & S2_ps(63 downto 1)) xor (S2_ps(5 downto 0) & S2_ps(63 downto 6));                 -- S2 = S2 XOR ROTR(S2, 1) XOR ROTR(S2, 6)
    S3_out <= S3_ps xor (S3_ps(9 downto 0) & S3_ps(63 downto 10)) xor (S3_ps(16 downto 0) & S3_ps(63 downto 17));     -- S3 = S3 XOR ROTR(S3,10) XOR ROTR(S3,17)
    S4_out <= S4_ps xor (S4_ps(6 downto 0) & S4_ps(63 downto 7)) xor (S4_ps(40 downto 0) & S4_ps(63 downto 41));      -- S4 = S4 XOR ROTR(S4, 7) XOR ROTR(S4,41)
end architecture Behavioral;

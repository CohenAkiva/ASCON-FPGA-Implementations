library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

package ascon_pack is                                                             -- Statement

    subtype slv128_t is std_logic_vector(127 downto 0);                           -- Convenient 128-bit type for key, nonce, rate blocks and tag.

    function ext128_to_internal(d : slv128_t) return slv128_t;                    -- Convert KAT byte order to Ascon little-endian integer order.

    function internal128_to_ext(d : slv128_t) return slv128_t;                    -- Convert internal little-endian order back to KAT/output byte order.

    function make_internal_block(                                                 -- Build a rate block and optionally add NIST Ascon padding.	                                                                               
        d           : slv128_t;
        n           : unsigned(4 downto 0);
        add_padding : boolean
    ) return slv128_t;

    function internal_to_ext_valid(                                                -- Return only the valid ciphertext bytes in external order.
        d : slv128_t;
        n : unsigned(4 downto 0)
    ) return slv128_t;

end package ascon_pack;

package body ascon_pack is                                                       -- Implementation

-- =========================================================================
    -- FUNCTION: ext128_to_internal
    -- PURPOSE : Converts a 128-bit word from external byte order (Big-Endian)
    --           to Ascon's internal integer byte order (Little-Endian).
    -- ======================================================================
    function ext128_to_internal(d : slv128_t) return slv128_t is
        variable r : slv128_t := (others => '0');                               -- Temporary variable to store the byte-swapped result
    begin
        for i in 0 to 15 loop                                                   -- Loop through all 16 bytes (128 bits total)
            r(8*i+7 downto 8*i) := d(127-8*i downto 120-8*i);                   -- Take byte 'i' from the top end of input (Big-Endian) 
        end loop;                                                               -- and place it into byte 'i' at the bottom end of result (Little-Endian)       
        return r;                                                               -- Return the converted 128-bit block
    end function;

-- =========================================================================
    -- FUNCTION: internal128_to_ext
    -- PURPOSE : Converts a 128-bit word from Ascon's internal integer byte order
    --           (Little-Endian) back to external byte order (Big-Endian).
    -- =========================================================================
    function internal128_to_ext(d : slv128_t) return slv128_t is                  -- Convert internal little-endian order back to KAT/output byte order.
        variable r : slv128_t := (others => '0');                                 -- Temporary result, cleared so unused bytes are zero.
    begin
        for i in 0 to 15 loop                                                     -- Process each byte independently.
            r(127-8*i downto 120-8*i) :=  d(8*i+7 downto 8*i);                    -- Move internal byte i back to normal external display order.              
        end loop;
        return r;                                                                 -- Return the converted/padded 128-bit block.
    end function;
	
-- =========================================================================
    -- FUNCTION: make_internal_block
    -- PURPOSE : Converts an input byte block to internal Little-Endian order
    --           and optionally appends NIST Ascon padding (0x01 bit/byte).
    -- =========================================================================
    function make_internal_block
	(                                                                             -- Build a rate block and optionally add NIST Ascon padding.
        d           : slv128_t;
        n           : unsigned(4 downto 0);
        add_padding : boolean
    )
	return slv128_t is
        variable r  : slv128_t := (others => '0');
        variable ni : integer;
    begin
        ni := to_integer(n);                                                      -- Convert DATA_BYTES to an integer in range 0..16.

        assert ni >= 0 and ni <= 16                                               -- Protect against an invalid block length.
            report "DATA_BYTES must be in range 0..16"
            severity failure;

        for i in 0 to 15 loop                                                     -- Process each byte independently.
            if i < ni then                                                        -- Copy only bytes that are really part of the message.
                r(8*i+7 downto 8*i) := d(127-8*i downto 120-8*i);                 -- Put external byte i at internal byte position i (LSB-first integer form).                    
            end if;
        end loop;

        if add_padding and ni < 16 then                                           -- Partial/empty last block needs the NIST pad bit.
            r(8*ni+7 downto 8*ni) := x"01";                                       -- Append 0x01 in little-endian integer form (Appendix A.2).
        end if;

        return r;                                                                 -- Return the converted/padded 128-bit block.
    end function;

-- =========================================================================
    -- FUNCTION: internal_to_ext_valid
    -- PURPOSE : Extracts only the valid payload bytes from internal order
    --           and converts them back to external byte order (Big-Endian).
    -- =========================================================================
    function internal_to_ext_valid
	(                                                                           -- Return only the valid ciphertext bytes in external order.
        d : slv128_t;
        n : unsigned(4 downto 0)
    )
	return slv128_t is
        variable r  : slv128_t := (others => '0');
        variable ni : integer;
    begin
        ni := to_integer(n);                                                      -- Convert DATA_BYTES to an integer in range 0..16.

        for i in 0 to 15 loop                                                     -- Process each byte independently.
            if i < ni then                                                        -- Copy only bytes that are really part of the message.
                r(127-8*i downto 120-8*i) := d(8*i+7 downto 8*i);                 -- Move internal byte i back to normal external display order.                 
            end if;
        end loop;
		
        return r;                                                                 -- Return the converted/padded 128-bit block.
    end function;

end package body ascon_pack;

----------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- Replacement of TRS-80_MiSTer/rtl/keyboard.sv: keeps the same entity name and
-- ports, so that the unmodified trs80.vhd can be used.
--
-- The MiSTer version converts PS/2 scancodes into the TRS-80 keyboard matrix.
-- On the MEGA65, the keyboard matrix is built directly from the MEGA65 keys
-- (see CORE/vhdl/keyboard.vhd), so the ps2_key port is used as a simple bus
-- that continuously transfers the eight matrix rows, one row per clock cycle:
--
--    ps2_key(10 downto 8) : row number (0 .. 7, i.e. address line A0 .. A7)
--    ps2_key( 7 downto 0) : the keys of this row, high active (bit = column)
--
-- Like the real TRS-80, reading the keyboard at $3800 - $3BFF returns the OR
-- of all rows that are selected by the address lines A0 .. A7.
--
-- kblayout is not used (the layout is defined in CORE/vhdl/keyboard.vhd).
--
-- TRS-80 port 2026, licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keyboard is
   port (
      reset    : in  std_logic;
      clk_sys  : in  std_logic;
      ps2_key  : in  std_logic_vector(10 downto 0);
      addr     : in  std_logic_vector(7 downto 0);
      key_data : out std_logic_vector(7 downto 0);
      kblayout : in  std_logic
   );
end entity keyboard;

architecture synthesis of keyboard is

   type rows_t is array (0 to 7) of std_logic_vector(7 downto 0);
   signal rows : rows_t := (others => (others => '0'));

begin

   rows_proc : process (clk_sys)
   begin
      if rising_edge(clk_sys) then
         rows(to_integer(unsigned(ps2_key(10 downto 8)))) <= ps2_key(7 downto 0);
         if reset = '1' then
            rows <= (others => (others => '0'));
         end if;
      end if;
   end process rows_proc;

   data_proc : process (all)
      variable d : std_logic_vector(7 downto 0);
   begin
      d := (others => '0');
      for i in 0 to 7 loop
         if addr(i) = '1' then
            d := d or rows(i);
         end if;
      end loop;
      key_data <= d;
   end process data_proc;

end architecture synthesis;

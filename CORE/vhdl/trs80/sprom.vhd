----------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- Xilinx replacement of TRS-80_MiSTer/rtl/sprom.vhd (Altera altsyncram ROM).
--
-- The only ROM of the core that uses sprom is the TRS-80 skin in videoctrl.vhd
-- (init_file "rtl/skin4.mif", 64k x 32 bit RGBA). The skin is stored as a
-- 24 bit RGB image in skin4.mem (see CORE/tools/mif2mem.py): the alpha channel
-- is constant 0xFF and not used by the core. Like the unregistered altsyncram,
-- the ROM has one clock cycle of latency (registered address).
--
-- TRS-80 port 2026, licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library xpm;
use xpm.vcomponents.all;

entity sprom is
   generic (
      init_file     : string := "";
      widthad_a     : natural;
      width_a       : natural := 8;
      outdata_reg_a : string := "UNREGISTERED"
   );
   port (
      address : in  std_logic_vector(widthad_a - 1 downto 0);
      clock   : in  std_logic;
      q       : out std_logic_vector(width_a - 1 downto 0)
   );
end entity sprom;

architecture synthesis of sprom is

   signal rgb : std_logic_vector(23 downto 0);

begin

   assert widthad_a = 16 and width_a = 32
      report "sprom: only the TRS-80 skin ROM (64k x 32) is supported"
      severity failure;

   i_skin : xpm_memory_sprom
      generic map (
         ADDR_WIDTH_A        => 16,
         AUTO_SLEEP_TIME     => 0,
         ECC_MODE            => "no_ecc",
         MEMORY_INIT_FILE    => "skin4.mem",
         MEMORY_INIT_PARAM   => "",
         MEMORY_OPTIMIZATION => "true",
         MEMORY_PRIMITIVE    => "block",
         MEMORY_SIZE         => 65536 * 24,
         MESSAGE_CONTROL     => 0,
         READ_DATA_WIDTH_A   => 24,
         READ_LATENCY_A      => 1,
         READ_RESET_VALUE_A  => "0",
         RST_MODE_A          => "SYNC",
         SIM_ASSERT_CHK      => 0,
         USE_MEM_INIT        => 1,
         WAKEUP_TIME         => "disable_sleep"
      )
      port map (
         clka           => clock,
         ena            => '1',
         regcea         => '1',
         rsta           => '0',
         sleep          => '0',
         injectdbiterra => '0',
         injectsbiterra => '0',
         addra          => address,
         douta          => rgb,
         dbiterra       => open,
         sbiterra       => open
      ); -- i_skin

   q <= rgb & x"FF";

end architecture synthesis;

----------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- Simulation-only behavioural models of the Xilinx XPM macros that are used by
-- the TRS-80-specific modules, so that the testbenches run in GHDL.
-- Compile into library "xpm".
--
-- xpm_memory_sprom is only used for the TRS-80 skin ROM: the model returns
-- black pixels (the skin is not simulated).
--
-- Taken from the X68000 port (MegaX68000).
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity xpm_cdc_single is
   generic (
      DEST_SYNC_FF   : integer := 4;
      INIT_SYNC_FF   : integer := 0;
      SIM_ASSERT_CHK : integer := 0;
      SRC_INPUT_REG  : integer := 1
   );
   port (
      src_clk  : in  std_logic;
      src_in   : in  std_logic;
      dest_clk : in  std_logic;
      dest_out : out std_logic
   );
end entity xpm_cdc_single;

architecture sim of xpm_cdc_single is
   signal src_r : std_logic := '0';
   signal sync  : std_logic_vector(DEST_SYNC_FF-1 downto 0) := (others => '0');
begin
   p_src : process (src_clk)
   begin
      if rising_edge(src_clk) then
         src_r <= src_in;
      end if;
   end process p_src;

   p_dest : process (dest_clk)
   begin
      if rising_edge(dest_clk) then
         if SRC_INPUT_REG = 1 then
            sync <= sync(DEST_SYNC_FF-2 downto 0) & src_r;
         else
            sync <= sync(DEST_SYNC_FF-2 downto 0) & src_in;
         end if;
      end if;
   end process p_dest;

   dest_out <= sync(DEST_SYNC_FF-1);
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;

entity xpm_cdc_array_single is
   generic (
      DEST_SYNC_FF   : integer := 4;
      INIT_SYNC_FF   : integer := 0;
      SIM_ASSERT_CHK : integer := 0;
      SRC_INPUT_REG  : integer := 1;
      WIDTH          : integer := 2
   );
   port (
      src_clk  : in  std_logic;
      src_in   : in  std_logic_vector(WIDTH-1 downto 0);
      dest_clk : in  std_logic;
      dest_out : out std_logic_vector(WIDTH-1 downto 0)
   );
end entity xpm_cdc_array_single;

architecture sim of xpm_cdc_array_single is
   type t_sync is array (0 to DEST_SYNC_FF-1) of std_logic_vector(WIDTH-1 downto 0);
   signal src_r : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
   signal sync  : t_sync := (others => (others => '0'));
begin
   p_src : process (src_clk)
   begin
      if rising_edge(src_clk) then
         src_r <= src_in;
      end if;
   end process p_src;

   p_dest : process (dest_clk)
   begin
      if rising_edge(dest_clk) then
         if SRC_INPUT_REG = 1 then
            sync(0) <= src_r;
         else
            sync(0) <= src_in;
         end if;
         for i in 1 to DEST_SYNC_FF-1 loop
            sync(i) <= sync(i-1);
         end loop;
      end if;
   end process p_dest;

   dest_out <= sync(DEST_SYNC_FF-1);
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;

entity xpm_cdc_async_rst is
   generic (
      DEST_SYNC_FF    : integer := 4;
      INIT_SYNC_FF    : integer := 0;
      RST_ACTIVE_HIGH : integer := 0
   );
   port (
      src_arst  : in  std_logic;
      dest_clk  : in  std_logic;
      dest_arst : out std_logic
   );
end entity xpm_cdc_async_rst;

architecture sim of xpm_cdc_async_rst is
   signal sync : std_logic_vector(DEST_SYNC_FF-1 downto 0) := (others => '1');
begin
   p_sync : process (dest_clk, src_arst)
      variable act : std_logic;
   begin
      if RST_ACTIVE_HIGH = 1 then act := '1'; else act := '0'; end if;
      if src_arst = act then
         sync <= (others => act);
      elsif rising_edge(dest_clk) then
         sync <= sync(DEST_SYNC_FF-2 downto 0) & not act;
      end if;
   end process p_sync;
   dest_arst <= sync(DEST_SYNC_FF-1);
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;

entity xpm_memory_sprom is
   generic (
      ADDR_WIDTH_A        : integer := 6;
      AUTO_SLEEP_TIME     : integer := 0;
      ECC_MODE            : string  := "no_ecc";
      MEMORY_INIT_FILE    : string  := "none";
      MEMORY_INIT_PARAM   : string  := "";
      MEMORY_OPTIMIZATION : string  := "true";
      MEMORY_PRIMITIVE    : string  := "auto";
      MEMORY_SIZE         : integer := 2048;
      MESSAGE_CONTROL     : integer := 0;
      READ_DATA_WIDTH_A   : integer := 32;
      READ_LATENCY_A      : integer := 2;
      READ_RESET_VALUE_A  : string  := "0";
      RST_MODE_A          : string  := "SYNC";
      SIM_ASSERT_CHK      : integer := 0;
      USE_MEM_INIT        : integer := 1;
      WAKEUP_TIME         : string  := "disable_sleep"
   );
   port (
      clka           : in  std_logic;
      ena            : in  std_logic;
      regcea         : in  std_logic;
      rsta           : in  std_logic;
      sleep          : in  std_logic;
      injectdbiterra : in  std_logic;
      injectsbiterra : in  std_logic;
      addra          : in  std_logic_vector(ADDR_WIDTH_A - 1 downto 0);
      douta          : out std_logic_vector(READ_DATA_WIDTH_A - 1 downto 0);
      dbiterra       : out std_logic;
      sbiterra       : out std_logic
   );
end entity xpm_memory_sprom;

architecture sim of xpm_memory_sprom is
begin
   douta    <= (others => '0');
   dbiterra <= '0';
   sbiterra <= '0';
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;

package vcomponents is

   component xpm_cdc_single is
      generic (
         DEST_SYNC_FF   : integer := 4;
         INIT_SYNC_FF   : integer := 0;
         SIM_ASSERT_CHK : integer := 0;
         SRC_INPUT_REG  : integer := 1
      );
      port (
         src_clk  : in  std_logic;
         src_in   : in  std_logic;
         dest_clk : in  std_logic;
         dest_out : out std_logic
      );
   end component xpm_cdc_single;

   component xpm_cdc_array_single is
      generic (
         DEST_SYNC_FF   : integer := 4;
         INIT_SYNC_FF   : integer := 0;
         SIM_ASSERT_CHK : integer := 0;
         SRC_INPUT_REG  : integer := 1;
         WIDTH          : integer := 2
      );
      port (
         src_clk  : in  std_logic;
         src_in   : in  std_logic_vector(WIDTH-1 downto 0);
         dest_clk : in  std_logic;
         dest_out : out std_logic_vector(WIDTH-1 downto 0)
      );
   end component xpm_cdc_array_single;

   component xpm_cdc_async_rst is
      generic (
         DEST_SYNC_FF    : integer := 4;
         INIT_SYNC_FF    : integer := 0;
         RST_ACTIVE_HIGH : integer := 0
      );
      port (
         src_arst  : in  std_logic;
         dest_clk  : in  std_logic;
         dest_arst : out std_logic
      );
   end component xpm_cdc_async_rst;

   component xpm_memory_sprom is
      generic (
         ADDR_WIDTH_A        : integer := 6;
         AUTO_SLEEP_TIME     : integer := 0;
         ECC_MODE            : string  := "no_ecc";
         MEMORY_INIT_FILE    : string  := "none";
         MEMORY_INIT_PARAM   : string  := "";
         MEMORY_OPTIMIZATION : string  := "true";
         MEMORY_PRIMITIVE    : string  := "auto";
         MEMORY_SIZE         : integer := 2048;
         MESSAGE_CONTROL     : integer := 0;
         READ_DATA_WIDTH_A   : integer := 32;
         READ_LATENCY_A      : integer := 2;
         READ_RESET_VALUE_A  : string  := "0";
         RST_MODE_A          : string  := "SYNC";
         SIM_ASSERT_CHK      : integer := 0;
         USE_MEM_INIT        : integer := 1;
         WAKEUP_TIME         : string  := "disable_sleep"
      );
      port (
         clka           : in  std_logic;
         ena            : in  std_logic;
         regcea         : in  std_logic;
         rsta           : in  std_logic;
         sleep          : in  std_logic;
         injectdbiterra : in  std_logic;
         injectsbiterra : in  std_logic;
         addra          : in  std_logic_vector(ADDR_WIDTH_A - 1 downto 0);
         douta          : out std_logic_vector(READ_DATA_WIDTH_A - 1 downto 0);
         dbiterra       : out std_logic;
         sbiterra       : out std_logic
      );
   end component xpm_memory_sprom;

   -- declaration only (check_design.sh): the M2M framework's axi_fifo.vhd
   component xpm_fifo_axis is
      generic (
         CASCADE_HEIGHT      : integer := 0;
         CDC_SYNC_STAGES     : integer := 2;
         CLOCKING_MODE       : string  := "common_clock";
         ECC_MODE            : string  := "no_ecc";
         FIFO_DEPTH          : integer := 2048;
         FIFO_MEMORY_TYPE    : string  := "auto";
         PACKET_FIFO         : string  := "false";
         PROG_EMPTY_THRESH   : integer := 10;
         PROG_FULL_THRESH    : integer := 10;
         RD_DATA_COUNT_WIDTH : integer := 1;
         RELATED_CLOCKS      : integer := 0;
         SIM_ASSERT_CHK      : integer := 0;
         TDATA_WIDTH         : integer := 32;
         TDEST_WIDTH         : integer := 1;
         TID_WIDTH           : integer := 1;
         TUSER_WIDTH         : integer := 1;
         USE_ADV_FEATURES    : string  := "1000";
         WR_DATA_COUNT_WIDTH : integer := 1
      );
      port (
         almost_empty_axis  : out std_logic;
         almost_full_axis   : out std_logic;
         dbiterr_axis       : out std_logic;
         m_axis_tdata       : out std_logic_vector(TDATA_WIDTH-1 downto 0);
         m_axis_tdest       : out std_logic_vector(TDEST_WIDTH-1 downto 0);
         m_axis_tid         : out std_logic_vector(TID_WIDTH-1 downto 0);
         m_axis_tkeep       : out std_logic_vector(TDATA_WIDTH/8-1 downto 0);
         m_axis_tlast       : out std_logic;
         m_axis_tstrb       : out std_logic_vector(TDATA_WIDTH/8-1 downto 0);
         m_axis_tuser       : out std_logic_vector(TUSER_WIDTH-1 downto 0);
         m_axis_tvalid      : out std_logic;
         prog_empty_axis    : out std_logic;
         prog_full_axis     : out std_logic;
         rd_data_count_axis : out std_logic_vector(RD_DATA_COUNT_WIDTH-1 downto 0);
         s_axis_tready      : out std_logic;
         sbiterr_axis       : out std_logic;
         wr_data_count_axis : out std_logic_vector(WR_DATA_COUNT_WIDTH-1 downto 0);
         injectdbiterr_axis : in  std_logic;
         injectsbiterr_axis : in  std_logic;
         m_aclk             : in  std_logic;
         m_axis_tready      : in  std_logic;
         s_aclk             : in  std_logic;
         s_aresetn          : in  std_logic;
         s_axis_tdata       : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
         s_axis_tdest       : in  std_logic_vector(TDEST_WIDTH-1 downto 0);
         s_axis_tid         : in  std_logic_vector(TID_WIDTH-1 downto 0);
         s_axis_tkeep       : in  std_logic_vector(TDATA_WIDTH/8-1 downto 0);
         s_axis_tlast       : in  std_logic;
         s_axis_tstrb       : in  std_logic_vector(TDATA_WIDTH/8-1 downto 0);
         s_axis_tuser       : in  std_logic_vector(TUSER_WIDTH-1 downto 0);
         s_axis_tvalid      : in  std_logic
      );
   end component xpm_fifo_axis;

end package vcomponents;

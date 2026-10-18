----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- MEGA65 main file that contains the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
-- TRS-80 port 2026, licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;
use work.vdrives_pkg.all;
use work.trs80_menu_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in  std_logic;
   qnice_rst_i             : in  std_logic;

   -- Video and audio mode control
   qnice_dvi_o             : out std_logic;              -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_video_mode_o      : out video_mode_type;        -- Defined in video_modes_pkg.vhd
   qnice_osm_cfg_scaling_o : out std_logic_vector(8 downto 0);
   qnice_scandoubler_o     : out std_logic;              -- 0 = no scandoubler, 1 = scandoubler
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;
   qnice_retro15kHz_o      : out std_logic;              -- 0 = normal frequency, 1 = retro 15 kHz frequency
   qnice_csync_o           : out std_logic;              -- 0 = normal HS/VS, 1 = Composite Sync  

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   qnice_gp_reg_i          : in  std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in  std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in  std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in  std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in  std_logic;
   qnice_dev_we_i          : in  std_logic;
   qnice_dev_wait_o        : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- HyperRAM Clock Domain
   --------------------------------------------------------------------------------------------------------

   hr_clk_i                : in  std_logic;
   hr_rst_i                : in  std_logic;
   hr_core_write_o         : out std_logic;
   hr_core_read_o          : out std_logic;
   hr_core_address_o       : out std_logic_vector(31 downto 0);
   hr_core_writedata_o     : out std_logic_vector(15 downto 0);
   hr_core_byteenable_o    : out std_logic_vector( 1 downto 0);
   hr_core_burstcount_o    : out std_logic_vector( 7 downto 0);
   hr_core_readdata_i      : in  std_logic_vector(15 downto 0);
   hr_core_readdatavalid_i : in  std_logic;
   hr_core_waitrequest_i   : in  std_logic;
   hr_high_i               : in  std_logic;  -- Core is too fast
   hr_low_i                : in  std_logic;  -- Core is too slow

   --------------------------------------------------------------------------------------------------------
   -- Video Clock Domain
   --------------------------------------------------------------------------------------------------------

   video_clk_o             : out std_logic;
   video_rst_o             : out std_logic;
   video_ce_o              : out std_logic;
   video_ce_ovl_o          : out std_logic;
   video_red_o             : out std_logic_vector(7 downto 0);
   video_green_o           : out std_logic_vector(7 downto 0);
   video_blue_o            : out std_logic_vector(7 downto 0);
   video_vs_o              : out std_logic;
   video_hs_o              : out std_logic;
   video_hblank_o          : out std_logic;
   video_vblank_o          : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   clk_i                   : in  std_logic;              -- 100 MHz clock

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;              -- CORE's 42.578 MHz clock
   main_rst_o              : out std_logic;              -- CORE's reset, synchronized

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in  std_logic;
   main_reset_core_i       : in  std_logic;

   main_pause_core_i       : in  std_logic;

   -- On-Screen-Menu selections
   main_osm_control_i      : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register converted to main clock domain
   main_qnice_gp_reg_i     : in  std_logic_vector(255 downto 0);

   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface (incl. power led and drive led)
   main_kb_key_num_i       : in  integer range 0 to 79;  -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;              -- low active: debounced feedback: is kb_key_num_i pressed right now?
   main_power_led_o        : out std_logic;
   main_power_led_col_o    : out std_logic_vector(23 downto 0);
   main_drive_led_o        : out std_logic;
   main_drive_led_col_o    : out std_logic_vector(23 downto 0);

   -- Joysticks and paddles input
   main_joy_1_up_n_i       : in  std_logic;
   main_joy_1_down_n_i     : in  std_logic;
   main_joy_1_left_n_i     : in  std_logic;
   main_joy_1_right_n_i    : in  std_logic;
   main_joy_1_fire_n_i     : in  std_logic;
   main_joy_1_up_n_o       : out std_logic;
   main_joy_1_down_n_o     : out std_logic;
   main_joy_1_left_n_o     : out std_logic;
   main_joy_1_right_n_o    : out std_logic;
   main_joy_1_fire_n_o     : out std_logic;
   main_joy_2_up_n_i       : in  std_logic;
   main_joy_2_down_n_i     : in  std_logic;
   main_joy_2_left_n_i     : in  std_logic;
   main_joy_2_right_n_i    : in  std_logic;
   main_joy_2_fire_n_i     : in  std_logic;
   main_joy_2_up_n_o       : out std_logic;
   main_joy_2_down_n_o     : out std_logic;
   main_joy_2_left_n_o     : out std_logic;
   main_joy_2_right_n_o    : out std_logic;
   main_joy_2_fire_n_o     : out std_logic;

   main_pot1_x_i           : in  std_logic_vector(7 downto 0);
   main_pot1_y_i           : in  std_logic_vector(7 downto 0);
   main_pot2_x_i           : in  std_logic_vector(7 downto 0);
   main_pot2_y_i           : in  std_logic_vector(7 downto 0);
   main_rtc_i              : in  std_logic_vector(64 downto 0);

   -- CBM-488/IEC serial port
   iec_reset_n_o           : out std_logic;
   iec_atn_n_o             : out std_logic;
   iec_clk_en_o            : out std_logic;
   iec_clk_n_i             : in  std_logic;
   iec_clk_n_o             : out std_logic;
   iec_data_en_o           : out std_logic;
   iec_data_n_i            : in  std_logic;
   iec_data_n_o            : out std_logic;
   iec_srq_en_o            : out std_logic;
   iec_srq_n_i             : in  std_logic;
   iec_srq_n_o             : out std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_en_o               : out std_logic;  -- Enable port, active high
   cart_phi2_o             : out std_logic;
   cart_dotclock_o         : out std_logic;
   cart_dma_i              : in  std_logic;
   cart_reset_oe_o         : out std_logic;
   cart_reset_i            : in  std_logic;
   cart_reset_o            : out std_logic;
   cart_game_oe_o          : out std_logic;
   cart_game_i             : in  std_logic;
   cart_game_o             : out std_logic;
   cart_exrom_oe_o         : out std_logic;
   cart_exrom_i            : in  std_logic;
   cart_exrom_o            : out std_logic;
   cart_nmi_oe_o           : out std_logic;
   cart_nmi_i              : in  std_logic;
   cart_nmi_o              : out std_logic;
   cart_irq_oe_o           : out std_logic;
   cart_irq_i              : in  std_logic;
   cart_irq_o              : out std_logic;
   cart_roml_oe_o          : out std_logic;
   cart_roml_i             : in  std_logic;
   cart_roml_o             : out std_logic;
   cart_romh_oe_o          : out std_logic;
   cart_romh_i             : in  std_logic;
   cart_romh_o             : out std_logic;
   cart_ctrl_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_ba_i               : in  std_logic;
   cart_rw_i               : in  std_logic;
   cart_io1_i              : in  std_logic;
   cart_io2_i              : in  std_logic;
   cart_ba_o               : out std_logic;
   cart_rw_o               : out std_logic;
   cart_io1_o              : out std_logic;
   cart_io2_o              : out std_logic;
   cart_addr_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_a_i                : in  unsigned(15 downto 0);
   cart_a_o                : out unsigned(15 downto 0);
   cart_data_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_d_i                : in  unsigned( 7 downto 0);
   cart_d_o                : out unsigned( 7 downto 0)
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal main_clk               : std_logic;               -- Core main clock (42.578 MHz)
signal main_rst               : std_logic;

---------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

signal main_disp_color        : std_logic_vector(1 downto 0);
signal main_overscan          : std_logic_vector(1 downto 0);
signal main_execute_method    : std_logic_vector(1 downto 0);
signal main_joytype           : std_logic_vector(1 downto 0);
signal main_overclock         : std_logic_vector(1 downto 0);

signal main_ioctl_download    : std_logic;
signal main_ioctl_index       : std_logic_vector(15 downto 0);
signal main_ioctl_wr          : std_logic;
signal main_ioctl_addr        : std_logic_vector(23 downto 0);
signal main_ioctl_data        : std_logic_vector(7 downto 0);
signal main_ioctl_wait        : std_logic;

signal main_img_mounted       : std_logic_vector(C_VDNUM - 1 downto 0);
signal main_img_readonly      : std_logic;
signal main_img_size          : std_logic_vector(31 downto 0);
signal main_sd_lba            : std_logic_vector(31 downto 0);
signal main_sd_rd             : std_logic_vector(C_VDNUM - 1 downto 0);
signal main_sd_wr             : std_logic_vector(C_VDNUM - 1 downto 0);
signal main_sd_ack            : std_logic;
signal main_sd_buff_addr      : std_logic_vector(8 downto 0);
signal main_sd_buff_dout      : std_logic_vector(7 downto 0);
signal main_sd_buff_din       : std_logic_vector(7 downto 0);
signal main_sd_buff_wr        : std_logic;
signal main_floppy_led        : std_logic;
signal main_cache_dirty       : std_logic_vector(C_VDNUM - 1 downto 0);

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

signal qnice_vga_15khz        : std_logic;   -- VGA: 15 kHz RGB instead of 31 kHz

-- ROM, program and cassette loader
signal qnice_rom_ce           : std_logic;
signal qnice_rom1_ce          : std_logic;
signal qnice_prg_ce           : std_logic;
signal qnice_cas_ce           : std_logic;
signal qnice_ldr_wait         : std_logic;
signal qnice_ldr_data         : std_logic_vector(15 downto 0);

-- Virtual drives
signal qnice_vd_data_o        : std_logic_vector(15 downto 0);
signal qnice_vd_ce            : std_logic;
signal qnice_vd_we            : std_logic;
signal qnice_vd_wait          : std_logic;
signal qnice_vd_wait_cnt      : natural range 0 to 31;
signal qnice_sd_lba           : vd_vec_array(C_VDNUM - 1 downto 0)(31 downto 0);
signal qnice_sd_rd            : vd_std_array(C_VDNUM - 1 downto 0);
signal qnice_sd_wr            : vd_std_array(C_VDNUM - 1 downto 0);
signal qnice_sd_ack           : vd_std_array(C_VDNUM - 1 downto 0);
signal qnice_sd_buff_addr     : std_logic_vector(13 downto 0);
signal qnice_sd_buff_dout     : std_logic_vector(7 downto 0);
signal qnice_sd_buff_din      : vd_vec_array(C_VDNUM - 1 downto 0)(7 downto 0);
signal qnice_sd_buff_wr       : std_logic;
signal qnice_sd_buff_wr_acc   : std_logic;

-- QNICE needs to wait this amount of QNICE clock cycles when reading a byte from the
-- FDC's sector buffer (see fdc_bridge.vhd)
constant C_VD_DIN_WAIT        : natural := 24;

-- Disk image buffers in HyperRAM (word addresses, 1 MB per drive)
type vd_base_array is array(0 to 3) of unsigned(31 downto 0);
constant C_VD_BASE            : vd_base_array := (
   shift_left(resize(unsigned(C_HMAP_VD0), 32), 12),
   shift_left(resize(unsigned(C_HMAP_VD1), 32), 12),
   shift_left(resize(unsigned(C_HMAP_VD2), 32), 12),
   shift_left(resize(unsigned(C_HMAP_VD3), 32), 12));
signal qnice_buf_cs           : std_logic;
signal qnice_buf_drive        : natural range 0 to 3;
signal qnice_buf_address      : std_logic_vector(31 downto 0);
signal qnice_buf_writedata    : std_logic_vector(15 downto 0);
signal qnice_buf_byteenable   : std_logic_vector(1 downto 0);
signal qnice_buf_readdata     : std_logic_vector(15 downto 0);
signal qnice_buf_wait         : std_logic;

signal qnice_avm_write        : std_logic;
signal qnice_avm_read         : std_logic;
signal qnice_avm_address      : std_logic_vector(31 downto 0);
signal qnice_avm_writedata    : std_logic_vector(15 downto 0);
signal qnice_avm_byteenable   : std_logic_vector(1 downto 0);
signal qnice_avm_burstcount   : std_logic_vector(7 downto 0);
signal qnice_avm_readdata     : std_logic_vector(15 downto 0);
signal qnice_avm_readdatavalid: std_logic;
signal qnice_avm_waitrequest  : std_logic;

begin

   -- Tristate all expansion port drivers that we can directly control
   -- @TODO: As soon as we support modules that can act as busmaster, we need to become more flexible here
   cart_ctrl_oe_o       <= '0';
   cart_addr_oe_o       <= '0';
   cart_data_oe_o       <= '0';

   -- Due to a bug in the R5/R6 boards, the cartridge port needs to be enabled for joystick port 2 to work
   cart_en_o            <= '1';

   cart_reset_oe_o      <= '0';
   cart_game_oe_o       <= '0';
   cart_exrom_oe_o      <= '0';
   cart_nmi_oe_o        <= '0';
   cart_irq_oe_o        <= '0';
   cart_roml_oe_o       <= '0';
   cart_romh_oe_o       <= '0';

   -- Default values for all signals
   cart_phi2_o          <= '0';
   cart_reset_o         <= '1';
   cart_dotclock_o      <= '0';
   cart_game_o          <= '1';
   cart_exrom_o         <= '1';
   cart_nmi_o           <= '1';
   cart_irq_o           <= '1';
   cart_roml_o          <= '0';
   cart_romh_o          <= '0';
   cart_ba_o            <= '0';
   cart_rw_o            <= '0';
   cart_io1_o           <= '0';
   cart_io2_o           <= '0';
   cart_a_o             <= (others => '0');
   cart_d_o             <= (others => '0');

   main_joy_1_up_n_o    <= '1';
   main_joy_1_down_n_o  <= '1';
   main_joy_1_left_n_o  <= '1';
   main_joy_1_right_n_o <= '1';
   main_joy_1_fire_n_o  <= '1';
   main_joy_2_up_n_o    <= '1';
   main_joy_2_down_n_o  <= '1';
   main_joy_2_left_n_o  <= '1';
   main_joy_2_right_n_o <= '1';
   main_joy_2_fire_n_o  <= '1';

   -- CBM-488/IEC serial port: not used
   iec_reset_n_o        <= '1';
   iec_atn_n_o          <= '1';
   iec_clk_en_o         <= '0';
   iec_clk_n_o          <= '1';
   iec_data_en_o        <= '0';
   iec_data_n_o         <= '1';
   iec_srq_en_o         <= '0';
   iec_srq_n_o          <= '1';

   -- MMCME2_ADV clock generator: TRS-80 42.578 MHz
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => clk_i,           -- expects 100 MHz
         main_clk_o        => main_clk,        -- CORE's 42.578 MHz clock
         main_rst_o        => main_rst         -- CORE's reset, synchronized
      ); -- clk_gen

   main_clk_o  <= main_clk;
   main_rst_o  <= main_rst;
   video_clk_o <= main_clk;
   video_rst_o <= main_rst;

   ---------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- MEGA65's power led: By default, it is on and glows green when the MEGA65 is powered on.
   -- We switch it to blue when a long reset is detected and as long as the user keeps pressing the preset button
   main_power_led_o     <= '1';
   main_power_led_col_o <= x"0000FF" when main_reset_m2m_i else x"00FF00";

   -- Drive led: green while the floppy motor is on, yellow while the write cache of a drive is dirty
   main_drive_led_o     <= main_floppy_led or (or main_cache_dirty);
   main_drive_led_col_o <= x"FFFF00" when (or main_cache_dirty) = '1' else x"00FF00";

   -- On-Screen-Menu selections
   main_disp_color      <= "01" when main_osm_control_i(C_MENU_COLOR_GREEN) = '1' else
                           "10" when main_osm_control_i(C_MENU_COLOR_AMBER) = '1' else
                           "00";
   main_overscan        <= "01" when main_osm_control_i(C_MENU_OVERSCAN_PARTIAL) = '1' else
                           "10" when main_osm_control_i(C_MENU_OVERSCAN_FULL)    = '1' else
                           "00";
   main_execute_method  <= "01" when main_osm_control_i(C_MENU_EXEC_JMP)  = '1' else
                           "10" when main_osm_control_i(C_MENU_EXEC_NONE) = '1' else
                           "00";
   main_joytype         <= "01" when main_osm_control_i(C_MENU_JOY_BIG5)  = '1' else
                           "10" when main_osm_control_i(C_MENU_JOY_ALPHA) = '1' else
                           "00";
   main_overclock       <= "01" when main_osm_control_i(C_MENU_SPEED_2X)  = '1' else
                           "10" when main_osm_control_i(C_MENU_SPEED_3X)  = '1' else
                           "11" when main_osm_control_i(C_MENU_SPEED_12X) = '1' else
                           "00";

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
      )
      port map (
         clk_main_i           => main_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
         pause_i              => main_pause_core_i,

         clk_main_speed_i     => CORE_CLK_SPEED,

         -- TRS-80 configuration
         trs_disp_color_i     => main_disp_color,
         trs_flicker_i        => main_osm_control_i(C_MENU_FLICKER),
         trs_lcasetype_i      => main_osm_control_i(C_MENU_LCASE_SYMBOL),
         trs_overscan_i       => main_overscan,
         trs_debug_i          => main_osm_control_i(C_MENU_DEBUG),
         trs_skin_i           => main_osm_control_i(C_MENU_SKIN),
         trs_execute_method_i => main_execute_method,
         trs_joytype_i        => main_joytype,
         trs_overclock_i      => main_overclock,
         trs_omikron_i        => main_osm_control_i(C_MENU_OMIKRON),
         trs_erase_i          => main_osm_control_i(C_MENU_ERASE),

         -- ioctl downloads
         ioctl_download_i     => main_ioctl_download,
         ioctl_index_i        => main_ioctl_index,
         ioctl_wr_i           => main_ioctl_wr,
         ioctl_addr_i         => main_ioctl_addr,
         ioctl_data_i         => main_ioctl_data,
         ioctl_wait_o         => main_ioctl_wait,

         -- Floppy drives
         img_mounted_i        => main_img_mounted,
         img_readonly_i       => main_img_readonly,
         img_size_i           => main_img_size,
         sd_lba_o             => main_sd_lba,
         sd_rd_o              => main_sd_rd,
         sd_wr_o              => main_sd_wr,
         sd_ack_i             => main_sd_ack,
         sd_buff_addr_i       => main_sd_buff_addr,
         sd_buff_dout_i       => main_sd_buff_dout,
         sd_buff_din_o        => main_sd_buff_din,
         sd_buff_wr_i         => main_sd_buff_wr,
         floppy_led_o         => main_floppy_led,

         -- Video output
         video_ce_o           => video_ce_o,
         video_ce_ovl_o       => video_ce_ovl_o,
         video_red_o          => video_red_o,
         video_green_o        => video_green_o,
         video_blue_o         => video_blue_o,
         video_vs_o           => video_vs_o,
         video_hs_o           => video_hs_o,
         video_hblank_o       => video_hblank_o,
         video_vblank_o       => video_vblank_o,

         -- audio output (pcm format, signed values)
         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         -- M2M Keyboard interface
         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         -- MEGA65 joysticks and paddles/mouse/potentiometers
         joy_1_up_n_i         => main_joy_1_up_n_i,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,

         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i,

         pot1_x_i             => main_pot1_x_i,
         pot1_y_i             => main_pot1_y_i,
         pot2_x_i             => main_pot2_x_i,
         pot2_y_i             => main_pot2_y_i
      ); -- i_main

   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   -- Due to a discussion on the MEGA65 discord (https://discord.com/channels/719326990221574164/794775503818588200/1039457688020586507)
   -- we decided to choose a naming convention for the PAL modes that might be more intuitive for the end users than it is
   -- for the programmers: "4:3" means "meant to be run on a 4:3 monitor", "5:4 on a 5:4 monitor".
   qnice_video_mode_o <= C_VIDEO_SVGA_800_60   when qnice_osm_control_i(C_MENU_SVGA_800_60)    = '1' else
                         C_VIDEO_HDMI_720_5994 when qnice_osm_control_i(C_MENU_HDMI_720_5994)  = '1' else
                         C_VIDEO_HDMI_640_60   when qnice_osm_control_i(C_MENU_HDMI_640_60)    = '1' else
                         C_VIDEO_HDMI_5_4_50   when qnice_osm_control_i(C_MENU_HDMI_5_4_50)    = '1' else
                         C_VIDEO_HDMI_4_3_50   when qnice_osm_control_i(C_MENU_HDMI_4_3_50)    = '1' else
                         C_VIDEO_HDMI_16_9_50  when qnice_osm_control_i(C_MENU_HDMI_16_9_50)   = '1' else
                         C_VIDEO_HDMI_16_9_60;

   -- Use On-Screen-Menu selections to configure several audio and video settings
   -- Video and audio mode control
   qnice_dvi_o                <= '0';                                         -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_vga_15khz            <= qnice_osm_control_i(C_MENU_VGA_15KHZ) or qnice_osm_control_i(C_MENU_VGA_CSYNC);

   -- VGA: the TRS-80 is a 15 kHz machine: 31 kHz needs the scandoubler
   qnice_scandoubler_o        <= not qnice_vga_15khz;
   qnice_audio_mute_o         <= '0';                                         -- audio is not muted
   qnice_audio_filter_o       <= qnice_osm_control_i(C_MENU_IMPROVE_AUDIO);   -- 0 = raw audio, 1 = use filters from globals.vhd
   qnice_zoom_crop_o          <= qnice_osm_control_i(C_MENU_HDMI_ZOOM);       -- 0 = no zoom/crop

   -- These two signals are often used as a pair (i.e. both '1'), particularly when
   -- you want to run old analog cathode ray tube monitors or TVs (via SCART)
   --    "Standard VGA":                     qnice_retro15kHz_o=0 and qnice_csync_o=0
   --    "Retro 15 kHz with HSync and VSync" qnice_retro15kHz_o=1 and qnice_csync_o=0
   --    "Retro 15 kHz with CSync"           qnice_retro15kHz_o=1 and qnice_csync_o=1
   qnice_retro15kHz_o         <= qnice_vga_15khz;
   qnice_csync_o              <= qnice_osm_control_i(C_MENU_VGA_CSYNC);
   qnice_osm_cfg_scaling_o    <= (others => '1');

   -- ascal filters that are applied while processing the input
   -- 00 : Nearest Neighbour
   -- 01 : Bilinear
   -- 10 : Sharp Bilinear
   -- 11 : Bicubic
   qnice_ascal_mode_o         <= "00";

   -- If polyphase is '1' then the ascal filter mode is ignored and polyphase filters are used instead
   -- @TODO: Right now, the filters are hardcoded in the M2M framework, we need to make them changeable inside m2m-rom.asm
   qnice_ascal_polyphase_o    <= qnice_osm_control_i(C_MENU_CRT_EMULATION);

   -- ascal triple-buffering
   -- @TODO: Right now, the M2M framework only supports OFF, so do not touch until the framework is upgraded
   qnice_ascal_triplebuf_o    <= '0';

   -- Flip joystick ports (i.e. the joystick in port 2 is used as joystick 1 and vice versa)
   qnice_flip_joyports_o      <= '0';

   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   core_specific_devices : process(all)
   begin
      -- make sure that this is x"EEEE" by default and avoid a register here by having this default value
      qnice_dev_data_o     <= x"EEEE";
      qnice_dev_wait_o     <= '0';

      qnice_rom_ce         <= '0';
      qnice_rom1_ce        <= '0';
      qnice_prg_ce         <= '0';
      qnice_cas_ce         <= '0';
      qnice_vd_ce          <= '0';
      qnice_vd_we          <= '0';
      qnice_buf_cs         <= '0';
      qnice_buf_drive      <= 0;

      case qnice_dev_id_i is

         -- BOOT.ROM and Omikron ROM loader (write only)
         when C_DEV_TRS_ROM =>
            qnice_rom_ce         <= qnice_dev_ce_i;
            qnice_dev_wait_o     <= qnice_ldr_wait;

         when C_DEV_TRS_ROM1 =>
            qnice_rom1_ce        <= qnice_dev_ce_i;
            qnice_dev_wait_o     <= qnice_ldr_wait;

         -- Program (CMD/BAS) and cassette loader
         when C_DEV_TRS_PRG =>
            qnice_prg_ce         <= qnice_dev_ce_i;
            qnice_dev_data_o     <= qnice_ldr_data;
            qnice_dev_wait_o     <= qnice_ldr_wait;

         when C_DEV_TRS_CAS =>
            qnice_cas_ce         <= qnice_dev_ce_i;
            qnice_dev_data_o     <= qnice_ldr_data;
            qnice_dev_wait_o     <= qnice_ldr_wait;

         -- Virtual drives
         when C_DEV_TRS_VD =>
            qnice_vd_ce          <= qnice_dev_ce_i;
            qnice_vd_we          <= qnice_dev_we_i;
            qnice_dev_data_o     <= qnice_vd_data_o;
            qnice_dev_wait_o     <= qnice_vd_wait;

         -- Disk image buffers in HyperRAM
         when C_DEV_TRS_VD0_BUF | C_DEV_TRS_VD1_BUF | C_DEV_TRS_VD2_BUF | C_DEV_TRS_VD3_BUF =>
            qnice_buf_cs         <= qnice_dev_ce_i;
            qnice_buf_drive      <= to_integer(unsigned(qnice_dev_id_i) - unsigned(C_DEV_TRS_VD0_BUF));
            qnice_dev_wait_o     <= qnice_buf_wait;
            if qnice_dev_addr_i(0) = '0' then
               qnice_dev_data_o  <= x"00" & qnice_buf_readdata(7 downto 0);
            else
               qnice_dev_data_o  <= x"00" & qnice_buf_readdata(15 downto 8);
            end if;

         when others => null;
      end case;
   end process core_specific_devices;

   ---------------------------------------------------------------------------------------
   -- ROM, program and cassette loader (MiSTer ioctl download emulation)
   ---------------------------------------------------------------------------------------

   i_ioctl_loader : entity work.ioctl_loader
      port map (
         qnice_clk_i           => qnice_clk_i,
         qnice_rst_i           => qnice_rst_i,
         qnice_addr_i          => qnice_dev_addr_i,
         qnice_data_i          => qnice_dev_data_i,
         qnice_we_i            => qnice_dev_we_i,
         qnice_rom_ce_i        => qnice_rom_ce,
         qnice_rom1_ce_i       => qnice_rom1_ce,
         qnice_prg_ce_i        => qnice_prg_ce,
         qnice_cas_ce_i        => qnice_cas_ce,
         qnice_wait_o          => qnice_ldr_wait,
         qnice_data_o          => qnice_ldr_data,

         main_clk_i            => main_clk,
         main_rst_i            => main_rst,
         main_ioctl_download_o => main_ioctl_download,
         main_ioctl_index_o    => main_ioctl_index,
         main_ioctl_wr_o       => main_ioctl_wr,
         main_ioctl_addr_o     => main_ioctl_addr,
         main_ioctl_dout_o     => main_ioctl_data,
         main_ioctl_wait_i     => main_ioctl_wait
      ); -- i_ioctl_loader

   ---------------------------------------------------------------------------------------
   -- Disk image buffers: 1 MB per drive in HyperRAM
   --
   -- The firmware stores one byte per QNICE address. Two bytes are stored in one
   -- 16-bit HyperRAM word (even address = low byte).
   ---------------------------------------------------------------------------------------

   qnice_buf_address    <= std_logic_vector(C_VD_BASE(qnice_buf_drive) + resize(unsigned(qnice_dev_addr_i(19 downto 1)), 32));
   qnice_buf_writedata  <= qnice_dev_data_i(7 downto 0) & qnice_dev_data_i(7 downto 0);
   qnice_buf_byteenable <= "10" when qnice_dev_addr_i(0) = '1' else "01";

   i_qnice2hyperram : entity work.qnice2hyperram
      port map (
         clk_i                 => qnice_clk_i,
         rst_i                 => qnice_rst_i,
         s_qnice_wait_o        => qnice_buf_wait,
         s_qnice_address_i     => qnice_buf_address,
         s_qnice_cs_i          => qnice_buf_cs,
         s_qnice_write_i       => qnice_dev_we_i,
         s_qnice_writedata_i   => qnice_buf_writedata,
         s_qnice_byteenable_i  => qnice_buf_byteenable,
         s_qnice_readdata_o    => qnice_buf_readdata,
         m_avm_write_o         => qnice_avm_write,
         m_avm_read_o          => qnice_avm_read,
         m_avm_address_o       => qnice_avm_address,
         m_avm_writedata_o     => qnice_avm_writedata,
         m_avm_byteenable_o    => qnice_avm_byteenable,
         m_avm_burstcount_o    => qnice_avm_burstcount,
         m_avm_readdata_i      => qnice_avm_readdata,
         m_avm_readdatavalid_i => qnice_avm_readdatavalid,
         m_avm_waitrequest_i   => qnice_avm_waitrequest
      ); -- i_qnice2hyperram

   -- Clock domain crossing: QNICE to HyperRAM
   i_avm_fifo : entity work.avm_fifo
      generic map (
         G_WR_DEPTH     => 16,
         G_RD_DEPTH     => 16,
         G_FILL_SIZE    => 1,
         G_ADDRESS_SIZE => 32,
         G_DATA_SIZE    => 16
      )
      port map (
         s_clk_i               => qnice_clk_i,
         s_rst_i               => qnice_rst_i,
         s_avm_waitrequest_o   => qnice_avm_waitrequest,
         s_avm_write_i         => qnice_avm_write,
         s_avm_read_i          => qnice_avm_read,
         s_avm_address_i       => qnice_avm_address,
         s_avm_writedata_i     => qnice_avm_writedata,
         s_avm_byteenable_i    => qnice_avm_byteenable,
         s_avm_burstcount_i    => qnice_avm_burstcount,
         s_avm_readdata_o      => qnice_avm_readdata,
         s_avm_readdatavalid_o => qnice_avm_readdatavalid,
         m_clk_i               => hr_clk_i,
         m_rst_i               => hr_rst_i,
         m_avm_waitrequest_i   => hr_core_waitrequest_i,
         m_avm_write_o         => hr_core_write_o,
         m_avm_read_o          => hr_core_read_o,
         m_avm_address_o       => hr_core_address_o,
         m_avm_writedata_o     => hr_core_writedata_o,
         m_avm_byteenable_o    => hr_core_byteenable_o,
         m_avm_burstcount_o    => hr_core_burstcount_o,
         m_avm_readdata_i      => hr_core_readdata_i,
         m_avm_readdatavalid_i => hr_core_readdatavalid_i
      ); -- i_avm_fifo

   ---------------------------------------------------------------------------------------
   -- Virtual drive handler: floppy drives 0 .. 3
   ---------------------------------------------------------------------------------------

   -- Reading the byte from the FDC's sector buffer (window >= 1, register 0x000B) needs
   -- wait states because the data comes from the core clock domain (see fdc_bridge.vhd)
   vd_wait_proc : process(qnice_clk_i)
   begin
      if rising_edge(qnice_clk_i) then
         if qnice_vd_ce = '1' and qnice_dev_we_i = '0' and
            qnice_dev_addr_i(27 downto 12) /= x"0000" and qnice_dev_addr_i(11 downto 0) = x"00B" then
            if qnice_vd_wait_cnt /= C_VD_DIN_WAIT then
               qnice_vd_wait_cnt <= qnice_vd_wait_cnt + 1;
            end if;
         else
            qnice_vd_wait_cnt <= 0;
         end if;
      end if;
   end process vd_wait_proc;

   qnice_vd_wait <= '1' when qnice_vd_ce = '1' and qnice_dev_we_i = '0' and
                             qnice_dev_addr_i(27 downto 12) /= x"0000" and qnice_dev_addr_i(11 downto 0) = x"00B" and
                             qnice_vd_wait_cnt /= C_VD_DIN_WAIT
                    else '0';

   i_vdrives : entity work.vdrives
      generic map (
         VDNUM       => C_VDNUM
      )
      port map
      (
         clk_qnice_i       => qnice_clk_i,
         clk_core_i        => main_clk,
         reset_core_i      => main_reset_core_i,

         -- Core clock domain
         img_mounted_o     => main_img_mounted,
         img_readonly_o    => main_img_readonly,
         img_size_o        => main_img_size,
         img_type_o        => open,
         drive_mounted_o   => open,

         -- Cache output signals: The dirty flags can be used to enforce data consistency
         -- (for example by ignoring/delaying a reset or delaying a drive unmount/mount, etc.)
         -- The flushing flags can be used to signal the fact that the caches are currently
         -- flushing to the user, for example using a special color/signal for example
         -- at the drive led
         cache_dirty_o     => main_cache_dirty,
         cache_flushing_o  => open,

         -- QNICE clock domain
         sd_lba_i          => qnice_sd_lba,
         sd_blk_cnt_i      => (others => (others => '0')),   -- always one block of 512 bytes
         sd_rd_i           => qnice_sd_rd,
         sd_wr_i           => qnice_sd_wr,
         sd_ack_o          => qnice_sd_ack,

         sd_buff_addr_o    => qnice_sd_buff_addr,
         sd_buff_dout_o    => qnice_sd_buff_dout,
         sd_buff_din_i     => qnice_sd_buff_din,
         sd_buff_wr_o      => qnice_sd_buff_wr,

         -- QNICE interface (MMIO, 4k-segmented)
         -- qnice_addr is 28-bit because we have a 16-bit window selector and a 4k window: 65536*4096 = 268.435.456 = 2^28
         qnice_addr_i      => qnice_dev_addr_i,
         qnice_data_i      => qnice_dev_data_i,
         qnice_data_o      => qnice_vd_data_o,
         qnice_ce_i        => qnice_vd_ce,
         qnice_we_i        => qnice_vd_we
      ); -- i_vdrives

   -- Write strobe for the sector buffer: every QNICE write access that writes '1' to the
   -- sd_buff_wr register (window 0, register 7): see fdc_bridge.vhd
   qnice_sd_buff_wr_acc <= '1' when qnice_vd_ce = '1' and qnice_dev_we_i = '1' and
                                    qnice_dev_addr_i(27 downto 12) = x"0000" and qnice_dev_addr_i(11 downto 0) = x"007" and
                                    qnice_dev_data_i(0) = '1'
                           else '0';

   i_fdc_bridge : entity work.fdc_bridge
      generic map (
         G_VDNUM           => C_VDNUM
      )
      port map (
         qnice_clk_i       => qnice_clk_i,
         qnice_rst_i       => qnice_rst_i,
         qnice_sd_lba_o    => qnice_sd_lba,
         qnice_sd_rd_o     => qnice_sd_rd,
         qnice_sd_wr_o     => qnice_sd_wr,
         qnice_sd_ack_i    => qnice_sd_ack,
         qnice_buff_addr_i => qnice_sd_buff_addr,
         qnice_buff_dout_i => qnice_sd_buff_dout,
         qnice_buff_din_o  => qnice_sd_buff_din,
         qnice_buff_wr_i   => qnice_sd_buff_wr_acc,

         main_clk_i        => main_clk,
         main_sd_lba_i     => main_sd_lba,
         main_sd_rd_i      => main_sd_rd,
         main_sd_wr_i      => main_sd_wr,
         main_sd_ack_o     => main_sd_ack,
         main_buff_addr_o  => main_sd_buff_addr,
         main_buff_dout_o  => main_sd_buff_dout,
         main_buff_din_i   => main_sd_buff_din,
         main_buff_wr_o    => main_sd_buff_wr
      ); -- i_fdc_bridge

end architecture synthesis;

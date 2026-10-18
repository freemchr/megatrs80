----------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domain
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
-- TRS-80 port 2026, licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- TRS-80 configuration (see trs80_top.sv)
      trs_disp_color_i        : in  std_logic_vector(1 downto 0);   -- White, Green, Amber
      trs_flicker_i           : in  std_logic;
      trs_lcasetype_i         : in  std_logic;
      trs_overscan_i          : in  std_logic_vector(1 downto 0);   -- None, Partial, Full
      trs_debug_i             : in  std_logic;
      trs_skin_i              : in  std_logic;
      trs_execute_method_i    : in  std_logic_vector(1 downto 0);   -- CAS, JMP, NONE
      trs_joytype_i           : in  std_logic_vector(1 downto 0);   -- None, BIG5, ALPHA
      trs_overclock_i         : in  std_logic_vector(1 downto 0);   -- 1x, 2x, 3x, 12x
      trs_omikron_i           : in  std_logic;
      trs_erase_i             : in  std_logic;                      -- erase memory and reset (rising edge)

      -- ioctl downloads (see ioctl_loader.vhd)
      ioctl_download_i        : in  std_logic;
      ioctl_index_i           : in  std_logic_vector(15 downto 0);
      ioctl_wr_i              : in  std_logic;
      ioctl_addr_i            : in  std_logic_vector(23 downto 0);
      ioctl_data_i            : in  std_logic_vector(7 downto 0);
      ioctl_wait_o            : out std_logic;

      -- Floppy drives (see fdc_bridge.vhd)
      img_mounted_i           : in  std_logic_vector(G_VDNUM - 1 downto 0);
      img_readonly_i          : in  std_logic;
      img_size_i              : in  std_logic_vector(31 downto 0);
      sd_lba_o                : out std_logic_vector(31 downto 0);
      sd_rd_o                 : out std_logic_vector(G_VDNUM - 1 downto 0);
      sd_wr_o                 : out std_logic_vector(G_VDNUM - 1 downto 0);
      sd_ack_i                : in  std_logic;
      sd_buff_addr_i          : in  std_logic_vector(8 downto 0);
      sd_buff_dout_i          : in  std_logic_vector(7 downto 0);
      sd_buff_din_o           : out std_logic_vector(7 downto 0);
      sd_buff_wr_i            : in  std_logic;
      floppy_led_o            : out std_logic;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

   component trs80_top is
      port (
         clk_sys        : in  std_logic;
         RESET          : in  std_logic;
         disp_color     : in  std_logic_vector(1 downto 0);
         flicker        : in  std_logic;
         lcasetype      : in  std_logic;
         overscan       : in  std_logic_vector(1 downto 0);
         debug          : in  std_logic;
         skin           : in  std_logic;
         execute_method : in  std_logic_vector(1 downto 0);
         joytype        : in  std_logic_vector(1 downto 0);
         overclock      : in  std_logic_vector(1 downto 0);
         omikron        : in  std_logic;
         erase_mem      : in  std_logic;
         ps2_key        : in  std_logic_vector(10 downto 0);
         joystick_0     : in  std_logic_vector(15 downto 0);
         ioctl_download : in  std_logic;
         ioctl_index    : in  std_logic_vector(15 downto 0);
         ioctl_wr       : in  std_logic;
         ioctl_addr     : in  std_logic_vector(23 downto 0);
         ioctl_data     : in  std_logic_vector(7 downto 0);
         ioctl_wait     : out std_logic;
         img_mounted    : in  std_logic_vector(3 downto 0);
         img_readonly   : in  std_logic_vector(3 downto 0);
         img_size       : in  std_logic_vector(31 downto 0);
         sd_lba         : out std_logic_vector(31 downto 0);
         sd_rd          : out std_logic_vector(3 downto 0);
         sd_wr          : out std_logic_vector(3 downto 0);
         sd_ack         : in  std_logic;
         sd_buff_addr   : in  std_logic_vector(8 downto 0);
         sd_buff_dout   : in  std_logic_vector(7 downto 0);
         sd_buff_din    : out std_logic_vector(7 downto 0);
         sd_buff_wr     : in  std_logic;
         ce_pix         : out std_logic;
         RGB            : out std_logic_vector(23 downto 0);
         HSync          : out std_logic;
         VSync          : out std_logic;
         HBlank         : out std_logic;
         VBlank         : out std_logic;
         AUDIO_L        : out std_logic_vector(15 downto 0);
         AUDIO_R        : out std_logic_vector(15 downto 0);
         UART_RXD       : in  std_logic;
         UART_TXD       : out std_logic;
         UART_RTS       : out std_logic;
         UART_CTS       : in  std_logic;
         UART_DTR       : out std_logic;
         UART_DSR       : in  std_logic;
         uart_mode      : in  std_logic_vector(7 downto 0);
         uart_speed     : in  std_logic_vector(31 downto 0);
         LED            : out std_logic
      );
   end component trs80_top;

   signal reset_core       : std_logic;
   signal kbd_matrix       : std_logic_vector(10 downto 0);
   signal joystick_0       : std_logic_vector(15 downto 0);

   -- Erase memory and reset: the MiSTer core expects a pulse
   signal erase_d          : std_logic := '0';
   signal erase_cnt        : natural range 0 to 15 := 0;
   signal erase_mem        : std_logic;

   -- The virtual drives report the write protection when an image is mounted
   signal img_readonly     : std_logic_vector(3 downto 0) := (others => '0');
   signal img_mounted      : std_logic_vector(3 downto 0);

   signal ce_pix           : std_logic;
   signal ce_pix_d         : std_logic_vector(1 downto 0) := (others => '0');
   signal rgb              : std_logic_vector(23 downto 0);
   signal audio_l          : std_logic_vector(15 downto 0);
   signal audio_r          : std_logic_vector(15 downto 0);

begin

   -- long and short press of reset button mean the same
   reset_core <= reset_soft_i or reset_hard_i;

   i_keyboard : entity work.m65_keyboard
      port map (
         clk_main_i           => clk_main_i,
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,
         matrix_o             => kbd_matrix
      ); -- i_keyboard

   -- MiSTer joystick format: bit 0 = right, 1 = left, 2 = down, 3 = up, 4 = fire
   joystick_0 <= x"00" & "000" & not joy_1_fire_n_i & not joy_1_up_n_i & not joy_1_down_n_i &
                 not joy_1_left_n_i & not joy_1_right_n_i;

   erase_proc : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         erase_d <= trs_erase_i;
         if trs_erase_i = '1' and erase_d = '0' then
            erase_cnt <= 15;
         elsif erase_cnt /= 0 then
            erase_cnt <= erase_cnt - 1;
         end if;
      end if;
   end process erase_proc;

   erase_mem <= '1' when erase_cnt /= 0 else '0';

   readonly_proc : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         for i in 0 to 3 loop
            if img_mounted(i) = '1' then
               img_readonly(i) <= img_readonly_i;
            end if;
         end loop;
      end if;
   end process readonly_proc;

   img_mounted <= std_logic_vector(resize(unsigned(img_mounted_i), 4));

   i_trs80 : trs80_top
      port map (
         clk_sys        => clk_main_i,
         RESET          => reset_core,
         disp_color     => trs_disp_color_i,
         flicker        => trs_flicker_i,
         lcasetype      => trs_lcasetype_i,
         overscan       => trs_overscan_i,
         debug          => trs_debug_i,
         skin           => trs_skin_i,
         execute_method => trs_execute_method_i,
         joytype        => trs_joytype_i,
         overclock      => trs_overclock_i,
         omikron        => trs_omikron_i,
         erase_mem      => erase_mem,
         ps2_key        => kbd_matrix,
         joystick_0     => joystick_0,
         ioctl_download => ioctl_download_i,
         ioctl_index    => ioctl_index_i,
         ioctl_wr       => ioctl_wr_i,
         ioctl_addr     => ioctl_addr_i,
         ioctl_data     => ioctl_data_i,
         ioctl_wait     => ioctl_wait_o,
         img_mounted    => img_mounted,
         img_readonly   => img_readonly,
         img_size       => img_size_i,
         sd_lba         => sd_lba_o,
         sd_rd          => sd_rd_o,
         sd_wr          => sd_wr_o,
         sd_ack         => sd_ack_i,
         sd_buff_addr   => sd_buff_addr_i,
         sd_buff_dout   => sd_buff_dout_i,
         sd_buff_din    => sd_buff_din_o,
         sd_buff_wr     => sd_buff_wr_i,
         ce_pix         => ce_pix,
         RGB            => rgb,
         HSync          => video_hs_o,
         VSync          => video_vs_o,
         HBlank         => video_hblank_o,
         VBlank         => video_vblank_o,
         AUDIO_L        => audio_l,
         AUDIO_R        => audio_r,
         -- RS232 / MIDI/80: not connected
         UART_RXD       => '1',
         UART_TXD       => open,
         UART_RTS       => open,
         UART_CTS       => '0',
         UART_DTR       => open,
         UART_DSR       => '0',
         uart_mode      => x"00",
         uart_speed     => std_logic_vector(to_unsigned(9600, 32)),
         LED            => floppy_led_o
      ); -- i_trs80

   video_red_o    <= rgb(7 downto 0);
   video_green_o  <= rgb(15 downto 8);
   video_blue_o   <= rgb(23 downto 16);

   audio_left_o   <= signed(audio_l);
   audio_right_o  <= signed(audio_r);

   -- On video_ce_o and video_ce_ovl_o:
   -- video_ce_o:     The TRS-80's pixel clock is clk_main_i / 4 = 10.64 MHz (see videoctrl.vhd)
   -- video_ce_ovl_o: The OSM overlay and the scandoubler's output are running at twice the pixel clock
   video_ce_o     <= ce_pix;

   ce_ovl_proc : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         ce_pix_d <= ce_pix_d(0) & ce_pix;
      end if;
   end process ce_ovl_proc;

   video_ce_ovl_o <= ce_pix or ce_pix_d(1);

end architecture synthesis;

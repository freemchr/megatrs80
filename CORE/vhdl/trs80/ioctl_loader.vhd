----------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- MiSTer "ioctl" download emulation: QNICE devices that receive files byte by
-- byte from the M2M ROM loader and hand them over to the TRS-80 core using the
-- same interface as MiSTer's hps_io (ioctl_download, ioctl_index, ioctl_wr,
-- ioctl_addr, ioctl_dout and ioctl_wait), so that the loaders of the MiSTer
-- core (TRS-80.sv and cmd_loader.sv) can be used unchanged.
--
-- Devices and the ioctl_index that they are using (like the MiSTer core):
--
--    qnice_rom_ce_i    BOOT.ROM (automatically loaded)            index 0x00
--    qnice_rom1_ce_i   Omikron CP/M mapper ROM (automatically)    index 0x40
--    qnice_prg_ce_i    *.CMD program (manually loaded)            index 0x02
--                      *.BAS program (manually loaded)            index 0x42
--    qnice_cas_ce_i    *.CAS cassette (manually loaded)           index 0x01
--
-- BASIC programs (binary format) start with 0xFF while CMD files start with a
-- block type (0x01 .. 0x1F), so the first byte of the file decides whether
-- the file is loaded as a CMD or as a BAS file.
--
-- The two manually loaded devices implement the M2M CRT/ROM control and status
-- registers (CSR) in the 4k window 0xFFFF (see CRTROM_CSR_* in
-- M2M/rom/sysdef.asm). ioctl_download is high from the first byte of the file
-- until the firmware sets the CSR status from "loading" to "OK" or "error".
-- The automatically loaded ROMs have no CSR: ioctl_download stays high until
-- no byte has been received for about 1.5 ms.
--
-- Each byte is passed to the core clock domain using a toggle handshake. The
-- core clock domain waits until ioctl_wait is low, writes the byte (ioctl_wr)
-- and acknowledges it. While the previous byte has not been acknowledged,
-- QNICE is stalled using the wait signal.
--
-- TRS-80 port 2026, licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity ioctl_loader is
   port (
      -- QNICE clock domain
      qnice_clk_i          : in  std_logic;
      qnice_rst_i          : in  std_logic;
      qnice_addr_i         : in  std_logic_vector(27 downto 0);
      qnice_data_i         : in  std_logic_vector(15 downto 0);
      qnice_we_i           : in  std_logic;
      qnice_rom_ce_i       : in  std_logic;
      qnice_rom1_ce_i      : in  std_logic;
      qnice_prg_ce_i       : in  std_logic;
      qnice_cas_ce_i       : in  std_logic;
      qnice_wait_o         : out std_logic;
      qnice_data_o         : out std_logic_vector(15 downto 0);   -- CSR of the manually loaded devices

      -- Core clock domain
      main_clk_i           : in  std_logic;
      main_rst_i           : in  std_logic;
      main_ioctl_download_o: out std_logic;
      main_ioctl_index_o   : out std_logic_vector(15 downto 0);
      main_ioctl_wr_o      : out std_logic;
      main_ioctl_addr_o    : out std_logic_vector(23 downto 0);
      main_ioctl_dout_o    : out std_logic_vector(7 downto 0);
      main_ioctl_wait_i    : in  std_logic
   );
end entity ioctl_loader;

architecture synthesis of ioctl_loader is

   -- M2M CRT/ROM control and status registers
   constant C_CSR_WIN      : std_logic_vector(15 downto 0) := x"FFFF";
   constant C_CSR_STATUS   : std_logic_vector(11 downto 0) := x"000";
   constant C_CSR_FS_LO    : std_logic_vector(11 downto 0) := x"001";
   constant C_CSR_FS_HI    : std_logic_vector(11 downto 0) := x"002";
   constant C_CSR_PARSEST  : std_logic_vector(11 downto 0) := x"010";
   constant C_ST_IDLE      : std_logic_vector(15 downto 0) := x"0000";
   constant C_ST_LOADING   : std_logic_vector(15 downto 0) := x"0001";
   constant C_ST_OK        : std_logic_vector(15 downto 0) := x"0003";
   constant C_PT_IDLE      : std_logic_vector(15 downto 0) := x"0000";
   constant C_PT_OK        : std_logic_vector(15 downto 0) := x"0002";

   -- ioctl_index values of the MiSTer core
   constant C_IDX_ROM      : std_logic_vector(7 downto 0) := x"00";
   constant C_IDX_CAS      : std_logic_vector(7 downto 0) := x"01";
   constant C_IDX_CMD      : std_logic_vector(7 downto 0) := x"02";
   constant C_IDX_BAS      : std_logic_vector(7 downto 0) := x"42";
   constant C_IDX_ROM1     : std_logic_vector(7 downto 0) := x"40";

   -- ioctl_download of the automatically loaded ROMs: timeout after the last byte
   constant C_AUTO_HOLD    : natural := 65535;

   -- CSR index: 0 = program (CMD/BAS), 1 = cassette
   type csr_status_array is array(0 to 1) of std_logic_vector(15 downto 0);
   type csr_fs_array     is array(0 to 1) of std_logic_vector(31 downto 0);
   signal qnice_csr_status : csr_status_array := (others => C_ST_IDLE);
   signal qnice_csr_fs     : csr_fs_array;
   signal qnice_csr_ce     : std_logic;
   signal qnice_csr_idx    : natural range 0 to 1;
   signal qnice_is_csr     : std_logic;
   signal qnice_data_ce    : std_logic;
   signal qnice_prg_loading: std_logic;
   signal qnice_cas_loading: std_logic;

   signal qnice_addr       : std_logic_vector(23 downto 0);
   signal qnice_byte       : std_logic_vector(7 downto 0);
   signal qnice_index      : std_logic_vector(7 downto 0);
   signal qnice_manual     : std_logic;
   signal qnice_bas        : std_logic := '0';
   signal qnice_req        : std_logic := '0';
   signal qnice_ack        : std_logic;
   signal qnice_delay      : natural range 0 to 3 := 0;
   signal qnice_busy       : std_logic;
   signal qnice_taken      : std_logic := '0';   -- the current write access has been captured

   -- Core clock domain
   signal main_addr        : std_logic_vector(23 downto 0);
   signal main_byte        : std_logic_vector(7 downto 0);
   signal main_index       : std_logic_vector(7 downto 0);
   signal main_manual      : std_logic;
   signal main_prg_loading : std_logic;
   signal main_cas_loading : std_logic;
   signal main_req         : std_logic;
   signal main_ack         : std_logic := '0';

   type main_state_t is (M_IDLE, M_END, M_START, M_WAIT, M_WRITE, M_HOLD);
   signal main_state       : main_state_t := M_IDLE;
   signal main_download    : std_logic := '0';
   signal main_dl_index    : std_logic_vector(7 downto 0) := (others => '0');
   signal main_dl_manual   : std_logic := '0';
   signal main_hold        : natural range 0 to C_AUTO_HOLD := 0;
   signal main_cnt         : natural range 0 to 3 := 0;
   signal main_wr          : std_logic := '0';
   signal main_ioctl_addr  : std_logic_vector(23 downto 0) := (others => '0');
   signal main_ioctl_dout  : std_logic_vector(7 downto 0) := (others => '0');

begin

   ---------------------------------------------------------------------------------------------
   -- QNICE clock domain
   ---------------------------------------------------------------------------------------------

   qnice_is_csr  <= '1' when qnice_addr_i(27 downto 12) = C_CSR_WIN else '0';
   qnice_csr_ce  <= qnice_prg_ce_i or qnice_cas_ce_i;
   qnice_csr_idx <= 1 when qnice_cas_ce_i = '1' else 0;
   qnice_data_ce <= qnice_rom_ce_i or qnice_rom1_ce_i or (qnice_csr_ce and not qnice_is_csr);

   qnice_prg_loading <= '1' when qnice_csr_status(0) = C_ST_LOADING else '0';
   qnice_cas_loading <= '1' when qnice_csr_status(1) = C_ST_LOADING else '0';

   -- A new byte can only be accepted when the previous byte has been written.
   -- The QNICE CPU samples wait at its rising clock edge, while this device captures the
   -- byte at the falling edge before: Once the byte of the current write access has been
   -- captured (qnice_taken), wait must stay low, otherwise the CPU would repeat the access
   -- forever (each capture makes qnice_busy high again).
   qnice_busy    <= '1' when qnice_req /= qnice_ack or qnice_delay /= 0 else '0';
   qnice_wait_o  <= qnice_data_ce and qnice_we_i and qnice_busy and not qnice_taken;

   -- CSR read access
   csr_read : process(all)
   begin
      qnice_data_o <= x"0000";
      if qnice_is_csr = '1' then
         case qnice_addr_i(11 downto 0) is
            when C_CSR_STATUS  => qnice_data_o <= qnice_csr_status(qnice_csr_idx);
            when C_CSR_FS_LO   => qnice_data_o <= qnice_csr_fs(qnice_csr_idx)(15 downto 0);
            when C_CSR_FS_HI   => qnice_data_o <= qnice_csr_fs(qnice_csr_idx)(31 downto 16);
            when C_CSR_PARSEST =>
               -- there is nothing to parse: the file has been handed over to the core while loading
               if qnice_csr_status(qnice_csr_idx) = C_ST_OK then
                  qnice_data_o <= C_PT_OK;
               else
                  qnice_data_o <= C_PT_IDLE;
               end if;
            when others        => qnice_data_o <= x"0000";   -- error code and error string
         end case;
      end if;
   end process csr_read;

   qnice_proc : process(qnice_clk_i)
      variable index : std_logic_vector(7 downto 0);
   begin
      if falling_edge(qnice_clk_i) then
         -- The data needs to be stable in the core clock domain before the request toggles:
         -- Toggle the request three QNICE clock cycles after the data has been updated.
         if qnice_delay /= 0 then
            qnice_delay <= qnice_delay - 1;
            if qnice_delay = 1 then
               qnice_req <= not qnice_req;
            end if;
         end if;

         -- CSR write access
         if qnice_csr_ce = '1' and qnice_we_i = '1' and qnice_is_csr = '1' then
            case qnice_addr_i(11 downto 0) is
               when C_CSR_STATUS => qnice_csr_status(qnice_csr_idx) <= qnice_data_i;
               when C_CSR_FS_LO  => qnice_csr_fs(qnice_csr_idx)(15 downto 0)  <= qnice_data_i;
               when C_CSR_FS_HI  => qnice_csr_fs(qnice_csr_idx)(31 downto 16) <= qnice_data_i;
               when others       => null;
            end case;
         end if;

         -- Data write access
         if qnice_data_ce = '1' and qnice_we_i = '1' and qnice_busy = '0' and qnice_taken = '0' then
            qnice_taken <= '1';
            qnice_byte  <= qnice_data_i(7 downto 0);
            qnice_addr  <= qnice_addr_i(23 downto 0);
            qnice_delay <= 3;

            if qnice_rom_ce_i = '1' then
               index := C_IDX_ROM;
            elsif qnice_rom1_ce_i = '1' then
               index := C_IDX_ROM1;
            elsif qnice_cas_ce_i = '1' then
               index := C_IDX_CAS;
            else
               -- CMD or BAS: decided by the first byte of the file
               if unsigned(qnice_addr_i) = 0 then
                  if qnice_data_i(7 downto 0) = x"FF" then
                     qnice_bas <= '1';
                     index := C_IDX_BAS;
                  else
                     qnice_bas <= '0';
                     index := C_IDX_CMD;
                  end if;
               elsif qnice_bas = '1' then
                  index := C_IDX_BAS;
               else
                  index := C_IDX_CMD;
               end if;
            end if;
            qnice_index  <= index;
            qnice_manual <= qnice_csr_ce;
         end if;

         -- the write access ends as soon as the CPU continues with the next instruction
         if qnice_data_ce = '0' or qnice_we_i = '0' then
            qnice_taken <= '0';
         end if;

         if qnice_rst_i = '1' then
            qnice_taken      <= '0';
            qnice_req        <= '0';
            qnice_delay      <= 0;
            qnice_bas        <= '0';
            qnice_csr_status <= (others => C_ST_IDLE);
         end if;
      end if;
   end process qnice_proc;

   ---------------------------------------------------------------------------------------------
   -- Core clock domain
   ---------------------------------------------------------------------------------------------

   main_ioctl_download_o <= main_download;
   main_ioctl_index_o    <= x"00" & main_dl_index;
   main_ioctl_wr_o       <= main_wr;
   main_ioctl_addr_o     <= main_ioctl_addr;
   main_ioctl_dout_o     <= main_ioctl_dout;

   main_proc : process(main_clk_i)
      variable loading : std_logic;
   begin
      if rising_edge(main_clk_i) then
         main_wr <= '0';

         if main_dl_index = C_IDX_CAS then
            loading := main_cas_loading;
         else
            loading := main_prg_loading;
         end if;

         case main_state is
            when M_IDLE =>
               if main_req /= main_ack then
                  -- a byte of another file: end the current download first
                  if main_download = '1' and main_index /= main_dl_index then
                     main_download <= '0';
                     main_state    <= M_END;
                  elsif main_download = '0' then
                     main_state    <= M_START;
                  else
                     main_state    <= M_WAIT;
                  end if;
               elsif main_download = '1' then
                  -- end of a download
                  if main_dl_manual = '1' then
                     if loading = '0' then
                        main_download <= '0';
                     end if;
                  elsif main_hold /= 0 then
                     main_hold <= main_hold - 1;
                  else
                     main_download <= '0';
                  end if;
               end if;

            -- give the core some time to see the end of the previous download
            when M_END =>
               main_cnt   <= 3;
               main_state <= M_HOLD;

            when M_HOLD =>
               if main_cnt /= 0 then
                  main_cnt <= main_cnt - 1;
               else
                  main_state <= M_START;
               end if;

            -- like hps_io: new download, ioctl_index is valid when ioctl_download goes high
            when M_START =>
               main_download  <= '1';
               main_dl_index  <= main_index;
               main_dl_manual <= main_manual;
               main_state     <= M_WAIT;

            -- like the MiSTer's HPS: do not send the next byte while the core requests to wait
            when M_WAIT =>
               if main_ioctl_wait_i = '0' then
                  main_ioctl_addr <= main_addr;
                  main_ioctl_dout <= main_byte;
                  main_state      <= M_WRITE;
               end if;

            -- like hps_io: ioctl_wr is high one clock cycle after ioctl_addr and ioctl_dout are valid
            when M_WRITE =>
               main_wr    <= '1';
               main_hold  <= C_AUTO_HOLD;
               main_ack   <= main_req;
               main_state <= M_IDLE;
         end case;

         if main_rst_i = '1' then
            main_state    <= M_IDLE;
            main_download <= '0';
            main_wr       <= '0';
            main_ack      <= main_req;
         end if;
      end if;
   end process main_proc;

   ---------------------------------------------------------------------------------------------
   -- Clock domain crossing
   ---------------------------------------------------------------------------------------------

   i_cdc_q2m_data : xpm_cdc_array_single
      generic map (
         DEST_SYNC_FF   => 2,
         INIT_SYNC_FF   => 0,
         SIM_ASSERT_CHK => 0,
         SRC_INPUT_REG  => 0,
         WIDTH          => 43
      )
      port map (
         src_clk                => qnice_clk_i,
         src_in(23 downto 0)    => qnice_addr,
         src_in(31 downto 24)   => qnice_byte,
         src_in(39 downto 32)   => qnice_index,
         src_in(40)             => qnice_manual,
         src_in(41)             => qnice_prg_loading,
         src_in(42)             => qnice_cas_loading,
         dest_clk               => main_clk_i,
         dest_out(23 downto 0)  => main_addr,
         dest_out(31 downto 24) => main_byte,
         dest_out(39 downto 32) => main_index,
         dest_out(40)           => main_manual,
         dest_out(41)           => main_prg_loading,
         dest_out(42)           => main_cas_loading
      ); -- i_cdc_q2m_data

   i_cdc_q2m_req : xpm_cdc_single
      generic map (
         DEST_SYNC_FF   => 2,
         INIT_SYNC_FF   => 0,
         SIM_ASSERT_CHK => 0,
         SRC_INPUT_REG  => 0
      )
      port map (
         src_clk  => qnice_clk_i,
         src_in   => qnice_req,
         dest_clk => main_clk_i,
         dest_out => main_req
      ); -- i_cdc_q2m_req

   i_cdc_m2q_ack : xpm_cdc_single
      generic map (
         DEST_SYNC_FF   => 2,
         INIT_SYNC_FF   => 0,
         SIM_ASSERT_CHK => 0,
         SRC_INPUT_REG  => 0
      )
      port map (
         src_clk  => main_clk_i,
         src_in   => main_ack,
         dest_clk => qnice_clk_i,
         dest_out => qnice_ack
      ); -- i_cdc_m2q_ack

end architecture synthesis;

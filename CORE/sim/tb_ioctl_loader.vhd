----------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- Testbench: ioctl_loader. A QNICE bus model writes files the way the M2M
-- firmware does (one byte per address, waiting for qnice_wait_o; the manually
-- loaded files are framed by the CSR status "loading" and "OK"), a core model
-- receives the ioctl stream and requests wait states after some bytes like
-- the MiSTer core's cmd_loader.sv.
--
-- Checks: data, addresses and ioctl_index of all bytes, ioctl_download (high
-- during the whole file, low after it), CMD/BAS detection, CSR read back.
--
-- Run: CORE/sim/run_tb.sh tb_ioctl_loader
-- TRS-80 port 2026, licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ioctl_loader is
end entity tb_ioctl_loader;

architecture sim of tb_ioctl_loader is

   constant C_MAX       : natural := 400;

   signal qclk          : std_logic := '0';
   signal clk           : std_logic := '0';
   signal done          : boolean := false;

   signal q_addr        : std_logic_vector(27 downto 0) := (others => '0');
   signal q_data        : std_logic_vector(15 downto 0) := (others => '0');
   signal q_we          : std_logic := '0';
   signal q_rom_ce      : std_logic := '0';
   signal q_rom1_ce     : std_logic := '0';
   signal q_prg_ce      : std_logic := '0';
   signal q_cas_ce      : std_logic := '0';
   signal q_wait        : std_logic;
   signal q_dout        : std_logic_vector(15 downto 0);

   signal io_download   : std_logic;
   signal io_index      : std_logic_vector(15 downto 0);
   signal io_wr         : std_logic;
   signal io_addr       : std_logic_vector(23 downto 0);
   signal io_dout       : std_logic_vector(7 downto 0);
   signal io_wait       : std_logic := '0';

   type t_mem is array (0 to C_MAX - 1) of std_logic_vector(7 downto 0);
   signal mem           : t_mem;
   signal writes        : natural := 0;
   signal last_index    : std_logic_vector(15 downto 0);
   signal downloads     : natural := 0;    -- rising edges of ioctl_download

   type t_dev is (DEV_ROM, DEV_ROM1, DEV_PRG, DEV_CAS);

   function file_byte(i : natural; first : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      if i = 0 then
         return first;
      end if;
      return std_logic_vector(to_unsigned((i * 13 + 5) mod 256, 8));
   end function file_byte;

begin

   qclk <= not qclk after 10 ns when not done;       -- 50 MHz
   clk  <= not clk after 11.743 ns when not done;    -- 42.578 MHz

   i_dut : entity work.ioctl_loader
      port map (
         qnice_clk_i           => qclk,
         qnice_rst_i           => '0',
         qnice_addr_i          => q_addr,
         qnice_data_i          => q_data,
         qnice_we_i            => q_we,
         qnice_rom_ce_i        => q_rom_ce,
         qnice_rom1_ce_i       => q_rom1_ce,
         qnice_prg_ce_i        => q_prg_ce,
         qnice_cas_ce_i        => q_cas_ce,
         qnice_wait_o          => q_wait,
         qnice_data_o          => q_dout,
         main_clk_i            => clk,
         main_rst_i            => '0',
         main_ioctl_download_o => io_download,
         main_ioctl_index_o    => io_index,
         main_ioctl_wr_o       => io_wr,
         main_ioctl_addr_o     => io_addr,
         main_ioctl_dout_o     => io_dout,
         main_ioctl_wait_i     => io_wait
      ); -- i_dut

   -- core model: like cmd_loader.sv, ioctl_wait goes high one clock after some of the writes
   p_core : process
      variable n     : natural := 0;
      variable dl_d  : std_logic := '0';
   begin
      wait until rising_edge(clk);
      if io_download = '1' and dl_d = '0' then
         downloads <= downloads + 1;
      end if;
      dl_d := io_download;
      if io_wr = '1' then
         assert io_download = '1' report "ioctl_wr without ioctl_download" severity failure;
         assert io_wait = '0' report "ioctl_wr while ioctl_wait" severity failure;
         mem(to_integer(unsigned(io_addr))) <= io_dout;
         last_index <= io_index;
         writes <= writes + 1;
         n := n + 1;
         if n mod 3 = 0 then
            io_wait <= '1';
            for i in 1 to (n mod 7) * 5 + 1 loop
               wait until rising_edge(clk);
               assert io_wr = '0' report "ioctl_wr while ioctl_wait" severity failure;
            end loop;
            io_wait <= '0';
         end if;
      end if;
   end process p_core;

   p_qnice : process

      procedure qnice_cycle(dev : t_dev; addr : natural; data : std_logic_vector(15 downto 0); we : std_logic) is
      begin
         wait until falling_edge(qclk);
         q_addr    <= std_logic_vector(to_unsigned(addr, 28));
         q_data    <= data;
         q_we      <= we;
         q_rom_ce  <= '1' when dev = DEV_ROM  else '0';
         q_rom1_ce <= '1' when dev = DEV_ROM1 else '0';
         q_prg_ce  <= '1' when dev = DEV_PRG  else '0';
         q_cas_ce  <= '1' when dev = DEV_CAS  else '0';
         wait until rising_edge(qclk);
         while q_wait = '1' loop
            wait until rising_edge(qclk);
         end loop;
         wait until falling_edge(qclk);
         q_rom_ce  <= '0';
         q_rom1_ce <= '0';
         q_prg_ce  <= '0';
         q_cas_ce  <= '0';
         q_we      <= '0';
         for w in 1 to 3 loop
            wait until falling_edge(qclk);
         end loop;
      end procedure qnice_cycle;

      procedure csr_write(dev : t_dev; reg : natural; data : natural) is
      begin
         qnice_cycle(dev, 16#FFFF000# + reg, std_logic_vector(to_unsigned(data, 16)), '1');
      end procedure csr_write;

      procedure send_file(dev : t_dev; size : natural; first : std_logic_vector(7 downto 0)) is
      begin
         for i in 0 to size - 1 loop
            qnice_cycle(dev, i, x"00" & file_byte(i, first), '1');
         end loop;
      end procedure send_file;

      procedure check_file(name : string; size : natural; first : std_logic_vector(7 downto 0);
                           index : std_logic_vector(15 downto 0); writes0 : natural) is
      begin
         assert writes - writes0 = size
            report name & ": number of writes: " & integer'image(writes - writes0) severity failure;
         for i in 0 to size - 1 loop
            assert mem(i) = file_byte(i, first)
               report name & ": byte " & integer'image(i) & " wrong" severity failure;
         end loop;
         assert last_index = index report name & ": wrong ioctl_index" severity failure;
         report name & ": " & integer'image(size) & " bytes OK";
      end procedure check_file;

      procedure manual_file(name : string; dev : t_dev; size : natural; first : std_logic_vector(7 downto 0);
                            index : std_logic_vector(15 downto 0)) is
         variable writes0, downloads0 : natural;
      begin
         writes0    := writes;
         downloads0 := downloads;
         csr_write(dev, 0, 1);                        -- status: loading
         wait for 1 us;
         assert io_download = '0' report name & ": ioctl_download before the first byte" severity failure;
         send_file(dev, size, first);
         wait for 1 us;
         assert io_download = '1' report name & ": ioctl_download low before the end of the file" severity failure;
         assert downloads = downloads0 + 1 report name & ": ioctl_download was not high all the time" severity failure;
         csr_write(dev, 1, size mod 65536);           -- file size
         csr_write(dev, 2, size / 65536);
         csr_write(dev, 0, 3);                        -- status: OK
         wait for 1 us;
         assert io_download = '0' report name & ": ioctl_download still high after status OK" severity failure;
         check_file(name, size, first, index, writes0);
         -- CSR read back: parse status OK, file size
         wait until falling_edge(qclk);
         q_addr    <= x"FFFF010";
         q_we      <= '0';
         q_prg_ce  <= '1' when dev = DEV_PRG else '0';
         q_cas_ce  <= '1' when dev = DEV_CAS else '0';
         wait until rising_edge(qclk);
         assert q_dout = x"0002" report name & ": parse status not OK" severity failure;
         q_addr <= x"FFFF001";
         wait until rising_edge(qclk);
         assert unsigned(q_dout) = size report name & ": file size read back wrong" severity failure;
         q_prg_ce <= '0';
         q_cas_ce <= '0';
      end procedure manual_file;

      variable writes0 : natural;

   begin
      wait for 200 ns;

      -- 1. BOOT.ROM (automatically loaded, index 0)
      writes0 := writes;
      send_file(DEV_ROM, 300, x"F3");
      wait for 1 us;
      assert io_download = '1' report "ROM: ioctl_download low too early" severity failure;
      assert downloads = 1 report "ROM: ioctl_download was not high all the time" severity failure;
      check_file("ROM", 300, x"F3", x"0000", writes0);
      wait for 2 ms;
      assert io_download = '0' report "ROM: ioctl_download still high 2 ms after the last byte" severity failure;

      -- 2. Omikron ROM (automatically loaded, index 0x40) directly followed by BOOT.ROM:
      --    two separate downloads
      writes0 := writes;
      send_file(DEV_ROM1, 50, x"C3");
      wait for 1 us;
      check_file("ROM1", 50, x"C3", x"0040", writes0);
      writes0 := writes;
      send_file(DEV_ROM, 60, x"F3");
      wait for 1 us;
      check_file("ROM after ROM1", 60, x"F3", x"0000", writes0);
      assert downloads = 3 report "ROM1/ROM: expected two downloads" severity failure;
      wait for 2 ms;

      -- 3. CMD program (index 2), BAS program (index 0x42), cassette (index 1)
      manual_file("CMD", DEV_PRG, 350, x"01", x"0002");
      manual_file("BAS", DEV_PRG, 200, x"FF", x"0042");
      manual_file("CAS", DEV_CAS, 250, x"55", x"0001");
      manual_file("CMD again", DEV_PRG, 100, x"05", x"0002");

      report "tb_ioctl_loader: ALL TESTS PASSED";
      done <= true;
      wait;
   end process p_qnice;

end architecture sim;

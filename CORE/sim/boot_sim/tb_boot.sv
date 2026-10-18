// ----------------------------------------------------------------------------
// TRS-80 for MEGA65: boot simulation testbench (Verilator, --timing)
//
// main.vhd (as a GHDL netlist, see boot_sim.sh). The testbench
//   - loads the ROM through main's ioctl interface (index 0), like
//     ioctl_loader.vhd does for the M2M firmware, while the core is in reset
//   - optionally loads a program (+prg=<file>, index 2 = CMD / 0x42 = BAS) or a
//     cassette (+cas=<file>, index 1) at +load_ms=<ms>, honouring ioctl_wait
//   - emulates the M2M keyboard scan (kb_key_num_i / kb_key_pressed_n_i) and
//     types the text of +type=<text> starting at +type_ms=<ms>
//     ("_" = Return, "~" = Break, "|" = pause of 0.5 s, lower case letters = with Shift)
//   - optionally mounts a JV1 disk image as drive 0 (+dsk=<file>) and answers the FDC's
//     sector requests like MiSTer's hps_io; +sd_byte_ns=<ns> slows down the transfer of
//     each byte (the M2M firmware is much slower than the HPS); writes only change the
//     copy of the image in memory
//   - writes the picture of the last completed frame as frame.ppm (and
//     frame_<ms>.ppm for every +snap<n>=<ms>)
//
// Usage: see CORE/sim/boot_sim.sh
// TRS-80 port 2026, licensed under GPL v3
// ----------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_boot;

   // 42.578125 MHz
   logic clk = 1'b0;
   always #11743 clk = ~clk;

   logic        reset = 1'b1;

   logic        ioctl_download = 1'b0;
   logic [15:0] ioctl_index = '0;
   logic        ioctl_wr = 1'b0;
   logic [23:0] ioctl_addr = '0;
   logic [7:0]  ioctl_data = '0;
   wire         ioctl_wait;

   logic [6:0]  kb_key_num = '0;
   logic        kb_key_pressed_n = 1'b1;
   logic [79:0] keys = '0;          // high = pressed

   wire         vid_ce, vid_vs, vid_hs, vid_hb, vid_vb;
   wire [7:0]   vid_r, vid_g, vid_b;
   wire         floppy_led;

   logic [3:0]  img_mounted = '0;
   logic [31:0] img_size = '0;
   wire  [31:0] sd_lba;
   wire  [3:0]  sd_rd, sd_wr;
   logic        sd_ack = 1'b0;
   logic [8:0]  sd_buff_addr = '0;
   logic [7:0]  sd_buff_dout = '0;
   wire  [7:0]  sd_buff_din;
   logic        sd_buff_wr = 1'b0;

   main dut (
      .clk_main_i(clk), .reset_soft_i(reset), .reset_hard_i(1'b0), .pause_i(1'b0),
      .clk_main_speed_i(31'd42578125),
      .trs_disp_color_i(2'd0), .trs_flicker_i(1'b0), .trs_lcasetype_i(1'b0), .trs_overscan_i(2'd0),
      .trs_debug_i(1'b0), .trs_skin_i(1'b0), .trs_execute_method_i(2'd0), .trs_joytype_i(2'd0),
      .trs_overclock_i(2'd0), .trs_omikron_i(1'b0), .trs_erase_i(1'b0),
      .ioctl_download_i(ioctl_download), .ioctl_index_i(ioctl_index), .ioctl_wr_i(ioctl_wr),
      .ioctl_addr_i(ioctl_addr), .ioctl_data_i(ioctl_data), .ioctl_wait_o(ioctl_wait),
      .img_mounted_i(img_mounted), .img_readonly_i(1'b0), .img_size_i(img_size),
      .sd_lba_o(sd_lba), .sd_rd_o(sd_rd), .sd_wr_o(sd_wr), .sd_ack_i(sd_ack), .sd_buff_addr_i(sd_buff_addr),
      .sd_buff_dout_i(sd_buff_dout), .sd_buff_din_o(sd_buff_din), .sd_buff_wr_i(sd_buff_wr),
      .floppy_led_o(floppy_led),
      .video_ce_o(vid_ce), .video_ce_ovl_o(), .video_red_o(vid_r), .video_green_o(vid_g), .video_blue_o(vid_b),
      .video_vs_o(vid_vs), .video_hs_o(vid_hs), .video_hblank_o(vid_hb), .video_vblank_o(vid_vb),
      .audio_left_o(), .audio_right_o(),
      .kb_key_num_i(kb_key_num), .kb_key_pressed_n_i(kb_key_pressed_n),
      .joy_1_up_n_i(1'b1), .joy_1_down_n_i(1'b1), .joy_1_left_n_i(1'b1), .joy_1_right_n_i(1'b1),
      .joy_1_fire_n_i(1'b1), .joy_2_up_n_i(1'b1), .joy_2_down_n_i(1'b1), .joy_2_left_n_i(1'b1),
      .joy_2_right_n_i(1'b1), .joy_2_fire_n_i(1'b1),
      .pot1_x_i(8'hFF), .pot1_y_i(8'hFF), .pot2_x_i(8'hFF), .pot2_y_i(8'hFF)
   );

   // -------------------------------------------------------------------------------------------------
   // M2M keyboard scan (the real one scans all 80 keys 1000 times per second; faster is fine)
   // -------------------------------------------------------------------------------------------------

   always @(posedge clk) begin
      kb_key_num       <= (kb_key_num == 7'd79) ? 7'd0 : kb_key_num + 7'd1;
      kb_key_pressed_n <= ~keys[(kb_key_num == 7'd79) ? 0 : kb_key_num + 1];
   end

   // MEGA65 key numbers (see CORE/vhdl/m65_keyboard.vhd)
   function automatic int m65_key(input byte c);
      case (c)
         "A": return 10; "B": return 28; "C": return 20; "D": return 18; "E": return 14; "F": return 21;
         "G": return 26; "H": return 29; "I": return 33; "J": return 34; "K": return 37; "L": return 42;
         "M": return 36; "N": return 39; "O": return 38; "P": return 41; "Q": return 62; "R": return 17;
         "S": return 13; "T": return 22; "U": return 30; "V": return 31; "W": return 9;  "X": return 23;
         "Y": return 25; "Z": return 12;
         "0": return 35; "1": return 56; "2": return 59; "3": return 8;  "4": return 11; "5": return 16;
         "6": return 19; "7": return 24; "8": return 27; "9": return 32;
         " ": return 60; "_": return 1;  "~": return 63; ".": return 44; ",": return 47; ":": return 45;
         ";": return 50; "-": return 43; "+": return 40; "*": return 49; "=": return 53; "/": return 55;
         "@": return 46; "\"": return -59;   // Shift + 2
         default: return -1;
      endcase
   endfunction

   task automatic press(input byte c);
      int k;
      logic shift;
      shift = 1'b0;
      if (c == "|") begin
         #500ms;
         return;
      end
      if (c >= "a" && c <= "z") begin
         c = c - 8'd32;
         shift = 1'b1;
      end
      k = m65_key(c);
      if (k < -1) begin
         k = -k;
         shift = 1'b1;
      end
      if (k < 0) begin
         $display("tb: cannot type '%c'", c);
         return;
      end
      if (shift) keys[15] = 1'b1;
      #20ms;
      keys[k] = 1'b1;
      #50ms;
      keys[k] = 1'b0;
      keys[15] = 1'b0;
      #50ms;
   endtask

   // -------------------------------------------------------------------------------------------------
   // ioctl download (like hps_io: ioctl_addr/ioctl_dout one clock before ioctl_wr, wait while ioctl_wait)
   // -------------------------------------------------------------------------------------------------

   task automatic download(input string name, input logic [15:0] index, input logic check_first);
      int fd, n, c;
      fd = $fopen(name, "rb");
      if (fd == 0) begin
         $display("tb: cannot open %s", name);
         $finish;
      end
      n = 0;
      c = $fgetc(fd);
      if (check_first && c == 'hFF) index = 16'h0042;   // BAS instead of CMD (see ioctl_loader.vhd)
      @(posedge clk);
      ioctl_index    <= index;
      ioctl_download <= 1'b1;
      while (c >= 0) begin
         @(posedge clk);
         while (ioctl_wait) @(posedge clk);
         ioctl_addr <= n;
         ioctl_data <= c[7:0];
         @(posedge clk);
         ioctl_wr   <= 1'b1;
         @(posedge clk);
         ioctl_wr   <= 1'b0;
         repeat (8) @(posedge clk);
         n = n + 1;
         c = $fgetc(fd);
      end
      $fclose(fd);
      repeat (8) @(posedge clk);
      while (ioctl_wait) @(posedge clk);
      ioctl_download <= 1'b0;
      $display("tb: %0t ns: loaded %s (%0d bytes, index %02h)", $time / 1000, name, n, index);
   endtask

   // -------------------------------------------------------------------------------------------------
   // Disk image (drive 0) and SD block interface (like hps_io)
   // -------------------------------------------------------------------------------------------------

   byte unsigned disk [0:1048575];
   int           disk_len = 0;
   int           sd_byte_ns = 0;

   task automatic load_disk(input string name);
      int fd, c;
      fd = $fopen(name, "rb");
      if (fd == 0) begin
         $display("tb: cannot open %s", name);
         $finish;
      end
      c = $fgetc(fd);
      while (c >= 0 && disk_len < 1048576) begin
         disk[disk_len] = c[7:0];
         disk_len = disk_len + 1;
         c = $fgetc(fd);
      end
      $fclose(fd);
   endtask

   task automatic byte_delay();
      if (sd_byte_ns > 0) #(sd_byte_ns * 1ns);
   endtask

   initial begin
      forever begin
         @(posedge clk);
         if (sd_rd[0] || sd_wr[0]) begin
            automatic logic        wr  = sd_wr[0];
            automatic int unsigned lba = sd_lba;
            repeat (20) @(posedge clk);
            sd_ack <= 1'b1;
            for (int i = 0; i < 512; i++) begin
               @(posedge clk);
               sd_buff_addr <= i;
               if (!wr) begin
                  sd_buff_dout <= (lba * 512 + i < disk_len) ? disk[lba * 512 + i] : 8'h00;
                  sd_buff_wr   <= 1'b1;
                  @(posedge clk);
                  sd_buff_wr   <= 1'b0;
               end else begin
                  repeat (3) @(posedge clk);
                  if (lba * 512 + i < disk_len) disk[lba * 512 + i] = sd_buff_din;
               end
               byte_delay();
            end
            @(posedge clk);
            sd_ack <= 1'b0;
            if ($test$plusargs("sd_log"))
               $display("tb: %0t ns: sd %s lba %0d", $time / 1000, wr ? "write" : "read", lba);
         end
      end
   end

   // -------------------------------------------------------------------------------------------------
   // Frame capture
   // -------------------------------------------------------------------------------------------------

   logic [23:0] line_buf [0:1023];
   logic [23:0] frame [0:1023][0:511];
   int          x = 0, y = 0, width = 0, height = 0, frames = 0;
   logic        hb_d = 1'b1, vb_d = 1'b1;
   string       snap_name = "";

   task automatic write_frame(input string name);
      int fd;
      fd = $fopen(name, "wb");
      $fwrite(fd, "P6\n%0d %0d\n255\n", width, height);
      for (int j = 0; j < height; j++)
         for (int i = 0; i < width; i++)
            $fwrite(fd, "%c%c%c", frame[i][j][23:16], frame[i][j][15:8], frame[i][j][7:0]);
      $fclose(fd);
   endtask

   always @(posedge clk) begin
      if (vid_ce) begin
         hb_d <= vid_hb;
         vb_d <= vid_vb;
         if (!vid_hb && !vid_vb) begin
            if (x < 1024 && y < 512) frame[x][y] <= {vid_r, vid_g, vid_b};
            x <= x + 1;
         end
         if (vid_hb && !hb_d && !vid_vb) begin   // end of a visible line
            width <= x;
            x <= 0;
            y <= y + 1;
         end
         if (vid_vb && !vb_d) begin              // end of the frame
            height <= y;
            y <= 0;
            x <= 0;
            frames <= frames + 1;
         end
      end
   end

   // write the frame one line after its end (width/height are updated)
   always @(posedge clk) begin
      if (vid_ce && vid_vb && !vb_d && y > 0) begin
         #1;
         write_frame("frame.ppm");
         if (snap_name != "") begin
            write_frame(snap_name);
            $display("tb: %0t ns: wrote %s (%0dx%0d)", $time / 1000, snap_name, width, height);
            snap_name = "";
         end
      end
   end

   // -------------------------------------------------------------------------------------------------
   // Sequence
   // -------------------------------------------------------------------------------------------------

   string rom, prg, cas, text, dsk;
   int    sim_ms, load_ms, type_ms;

   initial begin
      if (!$value$plusargs("rom=%s", rom)) rom = "boot.rom";
      if (!$value$plusargs("ms=%d", sim_ms)) sim_ms = 1000;
      if (!$value$plusargs("load_ms=%d", load_ms)) load_ms = 1500;
      if (!$value$plusargs("type_ms=%d", type_ms)) type_ms = 1000;
      if (!$value$plusargs("type=%s", text)) text = "";
      if (!$value$plusargs("prg=%s", prg)) prg = "";
      if (!$value$plusargs("cas=%s", cas)) cas = "";
      if (!$value$plusargs("dsk=%s", dsk)) dsk = "";
      if (!$value$plusargs("sd_byte_ns=%d", sd_byte_ns)) sd_byte_ns = 0;

      repeat (20) @(posedge clk);
      download(rom, 16'h0000, 1'b0);
      if (dsk != "") begin
         load_disk(dsk);
         img_size    <= disk_len;
         repeat (4) @(posedge clk);
         img_mounted <= 4'b0001;
         repeat (4) @(posedge clk);
         img_mounted <= 4'b0000;
         $display("tb: mounted %s (%0d bytes) as drive 0", dsk, disk_len);
      end
      repeat (100) @(posedge clk);
      reset = 1'b0;
      $display("tb: %0t ns: reset released", $time / 1000);
   end

   initial begin
      #1ms;
      if (text != "") begin
         #((type_ms - 1) * 1ms);
         $display("tb: %0t ns: typing \"%s\"", $time / 1000, text);
         for (int i = 0; i < text.len(); i++) press(text[i]);
         $display("tb: %0t ns: typing done", $time / 1000);
      end
   end

   initial begin
      #1ms;
      if (prg != "" || cas != "") begin
         #((load_ms - 1) * 1ms);
         if (prg != "") download(prg, 16'h0002, 1'b1);
         if (cas != "") download(cas, 16'h0001, 1'b0);
      end
   end

   initial begin
      int t;
      for (int i = 0; i < 16; i++) begin
         if ($value$plusargs($sformatf("snap%0d=%%d", i), t)) begin
            fork
               automatic int tt = t;
               begin
                  #(tt * 1ms);
                  snap_name = $sformatf("frame_%0d.ppm", tt);
               end
            join_none
         end
      end
   end

   initial begin
      #1ms;
      for (int ms = 1; ms < sim_ms; ms++) begin
         #1ms;
         if (ms % 100 == 0) $display("tb: %0d ms, %0d frames (%0dx%0d)", ms, frames, width, height);
      end
      #1ms;
      $display("tb: done after %0d ms, %0d frames", sim_ms, frames);
      $finish;
   end

endmodule

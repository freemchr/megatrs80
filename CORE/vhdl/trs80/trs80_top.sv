//============================================================================
// TRS-80 for MEGA65
//
// The TRS-80 part of the MiSTer core's top level module TRS-80.sv (module emu)
// without the MiSTer framework: hps_io is replaced by the ports of this module
// (the MEGA65 framework emulates the ioctl downloads, the virtual drives and
// the status bits), the video mixer / scandoubler is part of the MEGA65
// framework and MT32-pi and the savestates (DDR3 RAM) are not supported.
//
// Otherwise the logic is taken unchanged from TRS-80.sv:
//
//  HT1080Z port to MiSTer
//  Renamed to TRS-80 after Cassette and CMD loading support
//
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
// TRS-80 port 2026, licensed under GPL v3
//============================================================================

module trs80_top
(
	input         clk_sys,          // 42.578 MHz
	input         RESET,            // reset of the core (reset button of the MEGA65 etc.)

	// Configuration (MiSTer status bits, see CONF_STR in TRS-80.sv)
	input   [1:0] disp_color,       // status[6:5]   Screen Color: White, Green, Amber
	input         flicker,          // status[14]    Video Flicker
	input         lcasetype,        // status[7]     Lowercase Type: Normal, Symbol
	input   [1:0] overscan,         // status[13:12] Overscan: None, Partial, Full
	input         debug,            // status[15]    Overscan Status Line
	input         skin,             // status[23]    TRS80 Skin
	input   [1:0] execute_method,   // status[22:21] CMD Exec Method: CAS, JMP, NONE
	input   [1:0] joytype,          // status[11:10] TRISSTICK: None, BIG5, ALPHA
	input   [1:0] overclock,        // status[9:8]   Clockspeed: 1x, 2x, 3x, 12x
	input         omikron,          // status[24]    Omikron CP/M
	input         erase_mem,        // status[16]    Erase memory and reset (pulse)

	// Keyboard matrix (see CORE/vhdl/trs80/keyboard_matrix.vhd)
	input  [10:0] ps2_key,

	// Joystick (MiSTer format: bit 0 = right, 1 = left, 2 = down, 3 = up, 4 = fire)
	input  [15:0] joystick_0,

	// ioctl downloads (see CORE/vhdl/trs80/ioctl_loader.vhd)
	input         ioctl_download,
	input  [15:0] ioctl_index,
	input         ioctl_wr,
	input  [23:0] ioctl_addr,
	input   [7:0] ioctl_data,
	output        ioctl_wait,

	// Virtual floppy drives 0 .. 3
	input   [3:0] img_mounted,
	input   [3:0] img_readonly,
	input  [31:0] img_size,
	output [31:0] sd_lba,
	output  [3:0] sd_rd,
	output  [3:0] sd_wr,
	input         sd_ack,
	input   [8:0] sd_buff_addr,
	input   [7:0] sd_buff_dout,
	output  [7:0] sd_buff_din,
	input         sd_buff_wr,

	// Video
	output        ce_pix,
	output [23:0] RGB,
	output        HSync,
	output        VSync,
	output        HBlank,
	output        VBlank,

	// Audio (signed)
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,

	// RS232 (MiSTer UART)
	input         UART_RXD,
	output        UART_TXD,
	output        UART_RTS,
	input         UART_CTS,
	output        UART_DTR,
	input         UART_DSR,
	input   [7:0] uart_mode,        // 0=None, 1=PPP or Modem, 2=Console, 3=MIDI
	input  [31:0] uart_speed,

	output        LED               // floppy motor on
);

// All signals are declared before they are used: Vivado creates new, undriven implicit
// nets for identifiers that are used in port connections before their declaration.
reg  omkr_reset;
wire cpum1;
wire [7:0] trsram_din;

wire rom_download = ioctl_download && ioctl_index==0;
wire CPMreset = RESET | rom_download | omkr_reset;
wire reset = CPMreset;

// signals from loader
wire loader_wr;
wire loader_download;
wire [15:0] loader_addr;
wire [7:0] loader_data;
wire [15:0] execute_addr;
wire execute_enable;
reg  debug_select_line;
reg  prev_status_15;
wire [15:0] dgb_min_addr;
wire [15:0] dgb_max_addr;
reg  [15:0] prev_execute_addr;
reg  old_omikron;
reg  [3:0] omkr_ctr;

always_ff @(posedge clk_sys or posedge reset) begin
	if (reset) begin
		debug_select_line <= 1'b0 ;
		prev_execute_addr <= execute_addr ;
	end else
	begin
		prev_status_15 <= debug ;
		prev_execute_addr <= execute_addr ;
		if ( (debug != prev_status_15) && (debug == 1'b0) ) begin // reset status line if OSD request to see debug
			debug_select_line <= ! debug_select_line  ;
		end
		if (execute_addr != prev_execute_addr) debug_select_line <= 1'b1 ;  // if exec_addr change, see it.
	end
end

always_ff @(posedge clk_sys) begin
		old_omikron <= omikron;
		if (old_omikron != omikron) omkr_ctr <= 4'hf ;
		if (omkr_ctr != 4'h0) begin
			omkr_ctr <= omkr_ctr - 1'd1 ;
			omkr_reset <= 1'b1 ;
		end  else omkr_reset <= 1'b0 ;
end

wire [15:0] exec_stack;

wire trsram_wr;         // Writing loader data to ram
wire trsram_rd;         // Reading loader data from ram
wire trsram_download;   // Download in progress (active high)
wire [16:0] trsram_addr;
wire [7:0] trsram_data;

wire [13:0] omkr_addr ;
wire [7:0]  omkr_data ;
wire  [8:0] audiomix;

cmd_loader cmd_loader
(
	.clock(clk_sys),
	.reset(reset),
	.cpum1(cpum1),
	.erase_mem(erase_mem),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_dout(ioctl_data),
	.ioctl_addr(ioctl_addr),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.loader_wr(loader_wr),
	.loader_download(loader_download),
	.loader_addr(loader_addr),
	.loader_data(loader_data),
	.loader_din(trsram_din),
	.execute_addr(execute_addr),
	.execute_enable(execute_enable),
	.execute_method(execute_method),
	.exec_stack(exec_stack),
	.dbg_min_addr(dgb_min_addr),
	.dbg_max_addr(dgb_max_addr),
	.iterations()
);

assign trsram_wr = loader_download ? loader_wr : |ioctl_index[7:1]==1'b0 ?  ioctl_wr : 1'b0 ; // we don't want a spurious write if loader_download is late
assign trsram_rd = loader_download ;
assign trsram_download = loader_download ? loader_download : ioctl_index == 1 ? ioctl_download : 1'b0;
assign trsram_addr = loader_download ? {1'b0, loader_addr} : {|ioctl_index[7:0],ioctl_addr[15:0]};
assign trsram_data = loader_download ? loader_data : ioctl_data;

//  Omikron alternate ROM loading
dpram #(.DATA(8), .ADDR(11)) omikron_rom
(
	.a_clk(clk_sys),
	.a_wr(ioctl_wr & (ioctl_index[7:0]==8'h40)),  // file 0, rom 01 = Omikron
	.a_addr(ioctl_addr[10:0]),
	.a_din(ioctl_data),
	.a_dout(),

	// Port B
	.b_clk(clk_sys),
	.b_wr(1'b0),
	.b_addr(omkr_addr[10:0]),
	.b_din(8'h00),
	.b_dout(omkr_data)
);

trs80 trs80
(
	.reset(reset),
	.clk42m(clk_sys),
	.cpum1_out(cpum1),
	.omikron(omikron),
	.omkr_addr(omkr_addr),
	.omkr_data(omkr_data),
	.reset_mapper(CPMreset),

	.joy0(joystick_0[7:0]),
	.joy1(8'h00),
	.joytype(joytype),

	.RGB(RGB),
	.HSYNC(HSync),
	.VSYNC(VSync),
	.hblank(HBlank),
	.vblank(VBlank),
	.ce_pix(ce_pix),
	.skin(skin),

	.LED(LED),
	.audiomix(audiomix),

	.ps2_key(ps2_key),
	.kybdlayout(1'b0),
	.disp_color(disp_color),
	.lcasetype(lcasetype),
	.overscan(overscan),
	.overclock(overclock),
	.flicker(flicker),
	.debug(debug),

	.dn_clk(clk_sys),
	.dn_go(trsram_download),
	.dn_wr(trsram_wr),
	.dn_rd(trsram_rd),
	.dn_addr(trsram_addr),			// CPU = 0000-FFFF; cassette = 10000-1FFFF
	.dn_data(trsram_data),
	.dn_din(trsram_din),

	.loader_download(loader_download),
	.execute_addr(execute_addr),
	.execute_enable(execute_enable),
	.execute_method(execute_method),
	.debug_select_line(debug_select_line),
	.exec_stack(exec_stack),
	.dbg_min_addr(dgb_min_addr),
	.dbg_max_addr(dgb_max_addr),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),

	.UART_TXD(UART_TXD),
	.UART_RXD(UART_RXD),
	.UART_RTS(UART_RTS),
	.UART_CTS(UART_CTS),
	.UART_DTR(UART_DTR),
	.UART_DSR(UART_DSR),

	.uart_mode(uart_mode),
	.uart_speed(uart_speed),

	// savestates are not supported: the DDR3 RAM interface is not connected
	.DDRAM_BUSY(1'b0),
	.DDRAM_BURSTCNT(),
	.DDRAM_ADDR(),
	.DDRAM_DOUT(64'd0),
	.DDRAM_DOUT_READY(1'b0),
	.DDRAM_RD(),
	.DDRAM_DIN(),
	.DDRAM_BE(),
	.DDRAM_WE(),

	.load_state(1'b0),
	.save_state(1'b0),
	.ss_slot(2'b00)
);

// Audio: like TRS-80.sv without the MT32-pi ({1'b0, audiomix, 7'b0} clamped to 16 bit signed)
wire [15:0] audio_out = audiomix[8] ? 16'h7FFF : {1'b0, audiomix[7:0], 7'b0000000};
assign AUDIO_L = audio_out;
assign AUDIO_R = audio_out;

endmodule

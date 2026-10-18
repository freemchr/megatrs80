#!/bin/bash
# -----------------------------------------------------------------------------
# TRS-80 for MEGA65: full system boot simulation of the core (main.vhd) with
# Verilator
#
# The core's top level (trs80_top.sv) and parts of the MiSTer core (FDC, loader,
# sound) are SystemVerilog/Verilog, which GHDL cannot simulate. So the VHDL of
# main.vhd and of the TRS-80 (trs80.vhd with the T80 CPU and the video
# controller) is converted to Verilog netlists with GHDL's synthesis
# (ghdl --synth), and the netlists, the Verilog of the core and a small
# SystemVerilog testbench (boot_sim/tb_boot.sv) are compiled with Verilator.
#
# Usage: CORE/sim/boot_sim.sh <boot.rom> [simulated milliseconds] [testbench options]
#        testbench options (see tb_boot.sv), e.g.
#          +type=<text> +type_ms=<ms>     type on the keyboard ("_" = Return)
#          +prg=<file.cmd|bas> +load_ms=<ms>   load a program
#          +cas=<file.cas> +load_ms=<ms>       load a cassette
#          +dsk=<file.dsk>                mount a JV1 disk image as drive 0 (at reset)
#          +sd_byte_ns=<ns>               slow sector transfers down (M2M firmware speed)
#          +sd_log                        log the sector transfers
#          +snap0=<ms> .. +snap15=<ms>    save the picture as frame_<ms>.ppm
#        The picture of the last frame is saved as frame.ppm in $WORK.
#        RESYNTH=1: redo the GHDL synthesis (after changes of the VHDL)
# Needs the OSS CAD Suite (GHDL, Verilator) in the PATH.
#
# Based on the boot simulation of the X68000 port (MegaX68000).
# TRS-80 port 2026, licensed under GPL v3
# -----------------------------------------------------------------------------
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ROM=$(realpath "$1")
SIM_MS=${2:-1000}
shift 2 || shift $#
XPR="$ROOT/CORE/CORE-R6.xpr"
WORK=${WORK:-/tmp/trs80_boot}
mkdir -p "$WORK/fix"
FLAGS="--std=08 -fsynopsys -frelaxed --workdir=$WORK -P$WORK"
FLAGS93="--std=93c -fsynopsys -frelaxed --workdir=$WORK -P$WORK"

if [ ! -f "$WORK/main.v" ] || [ -n "$RESYNTH" ]; then
   ghdl -a $FLAGS --work=xpm    "$ROOT/CORE/sim/models/xpm_sim.vhd"
   ghdl -a $FLAGS --work=unisim "$ROOT/CORE/sim/models/unisim_decl.vhd"

   FILES=$(grep -o 'File Path="[^"]*\.vhd"' "$XPR" | sed "s|File Path=\"\\\$PPRDIR/|$ROOT/CORE/|; s|\"\$||")

   SYNFILES=""
   for f in $FILES; do
      b=$(basename "$f")
      if [ "$b" = "vdrives.vhd" ]; then
         python3 - "$f" "$WORK/fix/vdrives.vhd" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
i = s.index("architecture beh of vdrives is")
open(sys.argv[2], "w").write(s[:i] + "architecture beh of vdrives is\nbegin\nend beh;\n")
PYEOF
         SYNFILES="$SYNFILES $WORK/fix/vdrives.vhd"
      elif grep -q "text is in" "$f"; then
         sed 's/: *text is in \([a-z_]*\);/: text open read_mode is \1;/' "$f" > "$WORK/fix/$b"
         SYNFILES="$SYNFILES $WORK/fix/$b"
      else
         SYNFILES="$SYNFILES $f"
      fi
   done

   cd "$WORK"
   ghdl -i $FLAGS $SYNFILES
   ghdl -m $FLAGS ${GHDL_LDFLAGS} main > ghdl_make.log 2>&1 || true
   ghdl -m $FLAGS ${GHDL_LDFLAGS} trs80 >> ghdl_make.log 2>&1 || true
   echo "ghdl --synth main, trs80 ..."
   VDNUM=$(sed -n 's/^constant C_VDNUM *: *natural *:= *\([0-9]*\).*/\1/p' "$ROOT/CORE/vhdl/globals.vhd")
   ghdl --synth $FLAGS -gG_VDNUM=$VDNUM --out=verilog main > main.v 2> ghdl_synth.log ||
      { grep -m 20 "error" ghdl_synth.log || tail -20 ghdl_synth.log; exit 1; }
   ghdl --synth $FLAGS --out=verilog trs80 > trs80.v 2>> ghdl_synth.log ||
      { grep -m 20 "error" ghdl_synth.log || tail -20 ghdl_synth.log; exit 1; }
fi
cd "$WORK"
echo "netlists: main.v $(wc -l < main.v) lines, trs80.v $(wc -l < trs80.v) lines"

VFILES=$(grep -o 'File Path="[^"]*\.s\?v"' "$XPR" | sed "s|File Path=\"\\\$PPRDIR/|$ROOT/CORE/|; s|\"\$||" | grep -v "/M2M/")
# fdc1771.sv has a misplaced /* verilator public */ metacomment (Verilator syntax error): use copies
# of the Verilog files without these metacomments
mkdir -p vfix
SIMVFILES=""
for f in $VFILES; do
   sed 's|/\*\s*verilator public\s*\*/||g' "$f" > "vfix/$(basename "$f")"
   # +fdc_log: log the FDC register accesses (cpu_rd/cpu_wr are low active) (status reads only when the status changes)
   if [ "$(basename "$f")" = "fdc1771.sv" ]; then
      python3 - "vfix/fdc1771.sv" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.rindex("endmodule")
log = """
// ---- boot_sim: FDC access log (+fdc_log) ----
reg tbl_rd_d = 1'b0, tbl_wr_d = 1'b0;
reg [7:0] tbl_last_st = 8'h00, tbl_dout = 8'h00;
reg [3:0] tbl_drv_d = 4'hF;
always @(posedge clk_sys) begin
	tbl_rd_d <= cpu_sel & ~cpu_rd;
	tbl_wr_d <= cpu_sel & ~cpu_wr;
	tbl_drv_d <= floppy_drive;
	if (cpu_sel & ~cpu_rd) tbl_dout <= cpu_dout;   // cpu_dout is only valid during the access
	if ($test$plusargs("fdc_log")) begin
		if (tbl_drv_d != floppy_drive)
			$display("fdc: %0t ns: select %b motor %b", $time / 1000, floppy_drive, motor_on);
		if (tbl_wr_d & ~(cpu_sel & ~cpu_wr))
			$display("fdc: %0t ns: write reg %0d = %02h", $time / 1000, cpu_addr, cpu_din);
		if (tbl_rd_d & ~(cpu_sel & ~cpu_rd)) begin
			if (cpu_addr != 2'd0 || tbl_dout != tbl_last_st)
				$display("fdc: %0t ns: read reg %0d = %02h (track %0d fd_track %0d ready %b)",
					$time / 1000, cpu_addr, tbl_dout, track, fd_track, fd_ready);
			if (cpu_addr == 2'd0) tbl_last_st <= tbl_dout;
		end
	end
end
"""
open(p, "w").write(s[:i] + log + s[i:])
PYEOF
   fi
   SIMVFILES="$SIMVFILES vfix/$(basename "$f")"
done

if [ ! -x obj_dir/Vtb_boot ] || [ main.v -nt obj_dir/Vtb_boot ] || [ trs80.v -nt obj_dir/Vtb_boot ] ||
   [ "$ROOT/CORE/sim/boot_sim/tb_boot.sv" -nt obj_dir/Vtb_boot ]; then
   echo "verilator ..."
   verilator --binary --timing --top-module tb_boot -j ${VL_JOBS:-8} --x-assign fast \
      --x-initial fast -Wno-fatal -Wno-lint -Wno-style -Wno-MULTIDRIVEN -Wno-UNOPTFLAT -Wno-TIMESCALEMOD \
      -Wno-INITIALDLY -Wno-COMBDLY -Wno-ENUMVALUE -Wno-BLKANDNBLK -O3 --no-assert +1364-2005ext+v \
      "$ROOT/CORE/sim/boot_sim/tb_boot.sv" main.v trs80.v $SIMVFILES > verilator.log 2>&1 ||
      { grep -E "%Error" verilator.log | head -30; exit 1; }
fi

echo "simulating $SIM_MS ms ..."
./obj_dir/Vtb_boot +rom="$ROM" +ms=$SIM_MS "$@" | tee boot.log

#!/bin/bash
# -----------------------------------------------------------------------------
# TRS-80 for MEGA65: static check of the complete MEGA65 design with GHDL
#
# Analyzes all VHDL files of the Vivado project (default: CORE-R6.xpr) and
# elaborates MEGA65_Core (everything below the M2M framework). Xilinx primitives and Verilog modules are
# black boxes (see CORE/sim/models), so this does NOT replace a Vivado run,
# but it catches VHDL errors, port/generic mismatches and binding problems.
#
# Usage: CORE/sim/check_design.sh [R3|R4|R5|R6]
# (taken from the X68000 port, MegaX68000)
# Needs GHDL (e.g. from the OSS CAD Suite) in the PATH.
# -----------------------------------------------------------------------------
set -e
BOARD=${1:-R6}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
XPR="$ROOT/CORE/CORE-$BOARD.xpr"
WORK=${WORK:-/tmp/trs80_ghdl_check_$BOARD}
rm -rf "$WORK"
mkdir -p "$WORK"
FLAGS="--std=08 -fsynopsys -frelaxed --workdir=$WORK -P$WORK"

ghdl -a $FLAGS --work=xpm    "$ROOT/CORE/sim/models/xpm_sim.vhd"
ghdl -a $FLAGS --work=unisim "$ROOT/CORE/sim/models/unisim_decl.vhd"

FILES=$(grep -o 'File Path="[^"]*\.vhd"' "$XPR" | sed "s|File Path=\"\\\$PPRDIR/|$ROOT/CORE/|; s|\"\$||")
# The M2M framework itself (framework.vhd and the board top) uses constructs that Vivado accepts but GHDL
# does not, so the check elaborates everything below the framework: MEGA65_Core (mega65.vhd)
TOP=MEGA65_Core

# Some QNICE files use the VHDL-87 file declaration syntax, which Vivado accepts in VHDL-2008 mode but GHDL does
# not: use rewritten temporary copies of these files
mkdir -p "$WORK/vhdl87"
CHECKFILES=""
for f in $FILES; do
   if [ "$(basename "$f")" = "vdrives.vhd" ]; then
      # GHDL does not accept the generic dependent partial port associations of M2M's (Vivado-proven)
      # vdrives.vhd: check against an entity-only stub generated from the original file
      python3 - "$f" "$WORK/vhdl87/vdrives.vhd" <<'PYEOF'
import sys, re
s = open(sys.argv[1]).read()
i = s.index("architecture beh of vdrives is")
open(sys.argv[2], "w").write(s[:i] + "architecture beh of vdrives is\nbegin\nend beh;\n")
PYEOF
      CHECKFILES="$CHECKFILES $WORK/vhdl87/vdrives.vhd"
   elif grep -q "text is in" "$f"; then
      sed 's/: *text is in \([a-z_]*\);/: text open read_mode is \1;/' "$f" > "$WORK/vhdl87/$(basename "$f")"
      CHECKFILES="$CHECKFILES $WORK/vhdl87/$(basename "$f")"
   else
      CHECKFILES="$CHECKFILES $f"
   fi
done

cd "$WORK"
ghdl -i $FLAGS $CHECKFILES
echo "Elaborating $TOP ..."
ghdl -m $FLAGS ${GHDL_LDFLAGS} "$TOP" 2>&1 | grep -v "Wshared\|shared variable\|^\s*\^\|Wbinding\|Wlibrary\|^library\|is not bound\|Wport\|Wnowrite" || true
[ -x "$WORK/$(echo $TOP | tr A-Z a-z)" ] && echo "check_design: $TOP elaborated successfully"

# The TRS-80 core itself is instantiated by the Verilog module trs80_top.sv (a black box for GHDL):
# elaborate its VHDL part separately
echo "Elaborating trs80 ..."
ghdl -m $FLAGS ${GHDL_LDFLAGS} trs80 2>&1 | grep -v "Wshared\|shared variable\|^\s*\^\|Wbinding\|Wlibrary\|^library\|is not bound\|Wport\|Wnowrite" || true
[ -x "$WORK/trs80" ] && echo "check_design: trs80 elaborated successfully"

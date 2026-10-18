#!/bin/bash
# -----------------------------------------------------------------------------
# TRS-80 for MEGA65: run one of the GHDL testbenches in CORE/sim
#
# Usage: CORE/sim/run_tb.sh <testbench>     e.g. CORE/sim/run_tb.sh tb_ioctl_loader
# Needs GHDL (e.g. from the OSS CAD Suite) in the PATH.
#
# Taken from the X68000 port (MegaX68000).
# -----------------------------------------------------------------------------
set -e
TB=$1
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=${WORK:-/tmp/trs80_ghdl_$TB}
mkdir -p "$WORK"
GHDL_FLAGS="--std=08 -fsynopsys -frelaxed --workdir=$WORK -P$WORK"

SRC=(
   "$ROOT/CORE/vhdl/trs80/ioctl_loader.vhd"
   "$ROOT/CORE/vhdl/trs80/keyboard_matrix.vhd"
   "$ROOT/CORE/vhdl/m65_keyboard.vhd"
   "$ROOT/CORE/sim/$TB.vhd"
)

# simulation models of the Xilinx XPM macros
ghdl -a $GHDL_FLAGS --work=xpm "$ROOT/CORE/sim/models/xpm_sim.vhd"

for f in "${SRC[@]}"; do
   [ -f "$f" ] && ghdl -a $GHDL_FLAGS "$f"
done
cd "$WORK"
ghdl -e $GHDL_FLAGS ${GHDL_LDFLAGS} "$TB"
ghdl -r $GHDL_FLAGS "$TB" ${TBGENERICS} --assert-level=error ${STOPTIME:+--stop-time=$STOPTIME} ${SIMFLAGS}

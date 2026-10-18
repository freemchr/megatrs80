#!/bin/bash
# -----------------------------------------------------------------------------
# TRS-80 for MEGA65
#
# A few VHDL files of the TRS-80 MiSTer core need small changes for the
# Xilinx tools and GHDL, which Quartus accepts: case statements on
# std_logic_vector without "when others" (trs80.vhd) and component
# instantiations of entities without the keyword "entity" and an "and" of two
# vectors of different length (T80), procedural assignments to wires
# (fdc1771.sv). Instead of forking the MiSTer core, the
# submodule stays untouched and this script creates patched copies in
# CORE/vhdl/trs80_patched. The Vivado project uses these copies instead of the
# originals (see CORE/tools/update_xpr.py).
#
# Run this script after updating the CORE/TRS-80_MiSTer submodule:
#    CORE/patches/apply_patches.sh
#
# Taken from the X68000 port (MegaX68000).
# -----------------------------------------------------------------------------
set -e
CORE=$(cd "$(dirname "$0")/.." && pwd)
OUT="$CORE/vhdl/trs80_patched"
mkdir -p "$OUT"
for p in "$CORE"/patches/*.patch; do
   src=$(sed -n 's|^--- a/\(\S*\).*|\1|p' "$p" | head -1)
   dst="$OUT/$(basename "$src")"
   cp "$CORE/TRS-80_MiSTer/$src" "$dst"
   patch --quiet --no-backup-if-mismatch "$dst" "$p"
   echo "patched: $src"
done

#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# TRS-80 for MEGA65
#
# Converts the TRS-80 skin image of the MiSTer core (Quartus .mif, 32 bit
# RGBA words) into a Xilinx .mem file (24 bit RGB words) for the ROM in
# CORE/vhdl/trs80/sprom.vhd. The alpha channel (bits 7..0) is always 0xFF
# and not used by the core, so it is dropped.
#
# Run it after updating the TRS-80_MiSTer submodule:
#    python3 CORE/tools/mif2mem.py
# -----------------------------------------------------------------------------

import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "CORE", "TRS-80_MiSTer", "rtl", "skin4.mif")
DST = os.path.join(ROOT, "CORE", "vhdl", "trs80", "skin4.mem")

words = {}
depth = 0
in_content = False
for line in open(SRC):
    line = line.split("--")[0].strip()
    if not line:
        continue
    m = re.match(r"DEPTH\s*=\s*(\d+)", line)
    if m:
        depth = int(m.group(1))
    if line.startswith("CONTENT BEGIN"):
        in_content = True
        continue
    if not in_content or line.startswith("END"):
        continue
    addr, data = line.rstrip(";").split(":")
    addr = int(addr, 16)
    for i, w in enumerate(data.split()):
        words[addr + i] = int(w, 16) >> 8

assert depth and len(words) == depth, (depth, len(words))
with open(DST, "w") as f:
    f.write("@0000\n")
    for a in range(depth):
        f.write("%06X\n" % words[a])
print("%s: %d words" % (DST, depth))

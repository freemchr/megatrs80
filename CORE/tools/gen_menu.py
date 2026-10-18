#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# TRS-80 for MEGA65
#
# Generates the on-screen menu (OSM) definition:
#   * the OPTM_* block in CORE/vhdl/config.vhd (between the GEN_MENU markers)
#   * CORE/vhdl/trs80/trs80_menu_pkg.vhd with the line index of every menu
#     item, which is the bit position in qnice_osm_control_i / main_osm_control_i
#   * CORE/m2m-rom/menu_ids.asm with the same indices (OPTMI_*) and the menu
#     group ids (OPTMG_*) for the firmware
#
# The menu line index is easy to get wrong when editing config.vhd by hand,
# so edit the MENU list below and re-run:
#    python3 CORE/tools/gen_menu.py
#
# The main menu (without the contents of the submenus) must not have more than
# 22 lines: the on-screen menu has 24 lines (VGA_DY / FONT_DY, see globals.vhd)
# including the frame.
#
# IMPORTANT: If OPTM_SIZE changes, a new config file is needed (see README.md).
#
# Based on the menu generator of the X68000 port (MegaX68000).
# TRS-80 port 2026, licensed under GPL v3
# -----------------------------------------------------------------------------

import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CONFIG = os.path.join(ROOT, "CORE", "vhdl", "config.vhd")
PKG = os.path.join(ROOT, "CORE", "vhdl", "trs80", "trs80_menu_pkg.vhd")
ASM = os.path.join(ROOT, "CORE", "m2m-rom", "menu_ids.asm")

MAX_VISIBLE = 22

# (text, kind, group, flags, constant name)
#   kind:  head | line | item | single | mount | loadrom | help | sub | subclose | close
#   group: group name for "item", "single", "mount", "loadrom", "help"
#   flags: "std" (selected by default), "start" (cursor start position)
MENU = [
    (" TRS-80 Model I",             "head"),
    ("",                            "line"),
    (" Disk 0:%s",                  "mount",   "DISK0", "start"),
    (" Disk 1:%s",                  "mount",   "DISK1"),
    (" Disk 2:%s",                  "mount",   "DISK2"),
    (" Disk 3:%s",                  "mount",   "DISK3"),
    (" Program:%s",                 "loadrom", "PRG"),
    (" Cassette:%s",                "loadrom", "CAS"),
    ("",                            "line"),

    (" CPU speed: %s",              "sub"),
    (" CPU speed",                  "head"),
    ("",                            "line"),
    (" 1.78 MHz (1x)",              "item",    "SPEED", "std",  "SPEED_1X"),
    (" 3.56 MHz (2x)",              "item",    "SPEED", "",     "SPEED_2X"),
    (" 5.34 MHz (3x)",              "item",    "SPEED", "",     "SPEED_3X"),
    (" 21.29 MHz (12x)",            "item",    "SPEED", "",     "SPEED_12X"),
    ("",                            "line"),
    (" Back to main menu",          "subclose"),

    (" Screen: %s",                 "sub"),
    (" Screen",                     "head"),
    ("",                            "line"),
    (" White",                      "item",    "COLOR", "std",  "COLOR_WHITE"),
    (" Green",                      "item",    "COLOR", "",     "COLOR_GREEN"),
    (" Amber",                      "item",    "COLOR", "",     "COLOR_AMBER"),
    ("",                            "line"),
    (" No overscan",                "item",    "OVERSCAN", "std", "OVERSCAN_NONE"),
    (" Partial overscan",           "item",    "OVERSCAN", "",  "OVERSCAN_PARTIAL"),
    (" Full overscan",              "item",    "OVERSCAN", "",  "OVERSCAN_FULL"),
    ("",                            "line"),
    (" TRS-80 skin (overscan)",     "single",  "SKIN",  "",     "SKIN"),
    (" Lowercase as symbols",       "single",  "LCASE", "",     "LCASE_SYMBOL"),
    (" Video flicker",              "single",  "FLICKER", "",   "FLICKER"),
    (" Debug status line",          "single",  "DEBUG", "",     "DEBUG"),
    ("",                            "line"),
    (" Back to main menu",          "subclose"),

    (" System settings",            "sub"),
    (" System settings",            "head"),
    ("",                            "line"),
    (" Start CMD: stack 4200h",     "item",    "EXEC",  "std",  "EXEC_CAS"),
    (" Start CMD: JMP",             "item",    "EXEC",  "",     "EXEC_JMP"),
    (" Start CMD: no (load only)",  "item",    "EXEC",  "",     "EXEC_NONE"),
    ("",                            "line"),
    (" Joystick: none",             "item",    "JOY",   "std",  "JOY_NONE"),
    (" Joystick: BIG5 Trisstick",   "item",    "JOY",   "",     "JOY_BIG5"),
    (" Joystick: Alpha Trisstick",  "item",    "JOY",   "",     "JOY_ALPHA"),
    ("",                            "line"),
    (" Omikron CP/M mapper",        "single",  "OMIKRON", "",   "OMIKRON"),
    ("",                            "line"),
    (" Back to main menu",          "subclose"),

    (" HDMI: %s",                   "sub"),
    (" HDMI settings",              "head"),
    ("",                            "line"),
    (" 720p 50 Hz 16:9",            "item",    "HDMI",  "",     "HDMI_16_9_50"),
    (" 720p 60 Hz 16:9",            "item",    "HDMI",  "std",  "HDMI_16_9_60"),
    (" 576p 50 Hz 4:3",             "item",    "HDMI",  "",     "HDMI_4_3_50"),
    (" 576p 50 Hz 5:4",             "item",    "HDMI",  "",     "HDMI_5_4_50"),
    (" 640x480 60 Hz",              "item",    "HDMI",  "",     "HDMI_640_60"),
    (" 720x480 59.94 Hz",           "item",    "HDMI",  "",     "HDMI_720_5994"),
    (" 800x600 60 Hz",              "item",    "HDMI",  "",     "SVGA_800_60"),
    ("",                            "line"),
    (" Back to main menu",          "subclose"),

    (" VGA: %s",                    "sub"),
    (" VGA settings",               "head"),
    ("",                            "line"),
    (" 31 kHz (standard)",          "item",    "VGA",   "std",  "VGA_31KHZ"),
    (" 15 kHz (RGB, SCART)",        "item",    "VGA",   "",     "VGA_15KHZ"),
    (" 15 kHz with CSync",          "item",    "VGA",   "",     "VGA_CSYNC"),
    ("",                            "line"),
    (" Back to main menu",          "subclose"),

    (" HDMI: CRT emulation",        "single",  "CRT",   "",     "CRT_EMULATION"),
    (" HDMI: Zoom-in",              "single",  "ZOOM",  "",     "HDMI_ZOOM"),
    (" Audio improvements",         "single",  "AUDIO", "",     "IMPROVE_AUDIO"),
    ("",                            "line"),
    (" Erase memory & reset",       "single",  "ERASE", "",     "ERASE"),
    (" Reset TRS-80",               "single",  "RESET", "",     "RESET"),
    (" About & Help",               "help",    "ABOUT"),
    (" Close Menu",                 "close"),
]


def main():
    groups = {}
    items, gexpr, consts = [], [], []
    width = 0
    visible = 0
    in_sub = False
    for idx, entry in enumerate(MENU):
        text, kind = entry[0], entry[1]
        group = entry[2] if len(entry) > 2 else ""
        flags = entry[3] if len(entry) > 3 else ""
        cname = entry[4] if len(entry) > 4 else ""

        items.append('   "%s\\n"' % text.replace('"', '""'))
        width = max(width, len(text.replace("%s", "<Mount Drive>")))

        if kind == "sub":
            in_sub = True
            visible += 1
        elif kind == "subclose":
            in_sub = False
        elif not in_sub:
            visible += 1

        if group and group not in groups:
            groups[group] = len(groups) + 1
        g = "OPTM_G_%s" % group if group else ""

        if kind == "head":
            e = "OPTM_G_TEXT + OPTM_G_HEADLINE"
        elif kind == "line":
            e = "OPTM_G_LINE"
        elif kind == "item":
            e = g
        elif kind == "single":
            e = g + " + OPTM_G_SINGLESEL"
        elif kind == "mount":
            e = g + " + OPTM_G_MOUNT_DRV"
        elif kind == "loadrom":
            e = g + " + OPTM_G_LOAD_ROM"
        elif kind == "help":
            e = g + " + OPTM_G_HELP"
        elif kind == "sub":
            e = "OPTM_G_SUBMENU"
        elif kind == "subclose":
            e = "OPTM_G_CLOSE + OPTM_G_SUBMENU"
        elif kind == "close":
            e = "OPTM_G_CLOSE"
        else:
            raise ValueError(kind)
        if "std" in flags:
            e += " + OPTM_G_STDSEL"
        if "start" in flags:
            e += " + OPTM_G_START"
        gexpr.append("      %-45s -- %2d %s" % (e + ("," if idx < len(MENU) - 1 else ""), idx, text.strip() or "-"))
        if cname:
            consts.append((cname, idx))

    size = len(MENU)
    block = []
    block.append("constant OPTM_SIZE         : natural := %d;  -- amount of items including empty lines:" % size)
    block.append("                                             -- needs to be equal to the number of lines in OPTM_ITEMS and amount of items in OPTM_GROUPS")
    block.append("                                             -- IMPORTANT: If SAVE_SETTINGS is true and OPTM_SIZE changes: Make sure to re-generate and")
    block.append("                                             -- and re-distribute the config file. You can make a new one using M2M/tools/make_config.sh")
    block.append("")
    block.append("-- Net size of the Options menu on the screen in characters (excluding the frame, which is hardcoded to two characters)")
    block.append("constant OPTM_DX           : natural := %d;" % (width + 1))
    block.append("constant OPTM_DY           : natural := %d;" % visible)
    block.append("")
    block.append("constant OPTM_ITEMS        : string :=")
    block.append(" &\n".join(items) + ";")
    block.append("")
    # group names must not clash with the framework's OPTM_G_* flags (VHDL is case insensitive)
    reserved = {"TEXT", "CLOSE", "STDSEL", "LINE", "START", "HEADLINE", "SINGLESEL",
                "MOUNT_DRV", "HELP", "SUBMENU", "LOAD_ROM"}
    for name in groups:
        if name.upper() in reserved:
            sys.exit("gen_menu.py: group name %s clashes with the framework constant OPTM_G_%s" % (name, name.upper()))
    for name, num in groups.items():
        block.append("constant OPTM_G_%-10s : integer := %d;" % (name, num))
    block.append("")
    block.append("-- !!! DO NOT TOUCH !!!")
    block.append("type OPTM_GTYPE is array (0 to OPTM_SIZE - 1) of integer range 0 to 2**OPTM_GTC- 1;")
    block.append("")
    block.append("constant OPTM_GROUPS       : OPTM_GTYPE := (")
    block.append("\n".join(gexpr))
    block.append(");")

    cfg = open(CONFIG).read()
    start = "-- GEN_MENU_BEGIN (generated by CORE/tools/gen_menu.py - do not edit by hand)\n"
    end = "-- GEN_MENU_END\n"
    i, j = cfg.index(start) + len(start), cfg.index(end)
    cfg = cfg[:i] + "\n".join(block) + "\n" + cfg[j:]
    open(CONFIG, "w").write(cfg)

    pkg = []
    pkg.append("-- -----------------------------------------------------------------------------")
    pkg.append("-- TRS-80 for MEGA65")
    pkg.append("--")
    pkg.append("-- AUTO-GENERATED by CORE/tools/gen_menu.py - DO NOT EDIT")
    pkg.append("--")
    pkg.append("-- Line index of each on-screen menu item = bit position in the OSM control vector")
    pkg.append("-- -----------------------------------------------------------------------------")
    pkg.append("")
    pkg.append("package trs80_menu_pkg is")
    pkg.append("")
    for name, num in consts:
        pkg.append("   constant C_MENU_%-18s : natural := %d;" % (name, num))
    pkg.append("")
    pkg.append("end package trs80_menu_pkg;")
    pkg.append("")
    open(PKG, "w").write("\n".join(pkg))

    asm = ["; AUTO-GENERATED by CORE/tools/gen_menu.py - DO NOT EDIT", ";",
           "; Menu group ids (OPTMG_*, as in config.vhd) and line indices of the menu items (OPTMI_*)", ""]
    for name, num in groups.items():
        asm.append("OPTMG_%-20s .EQU %d" % (name, num))
    asm.append("")
    for name, num in consts:
        asm.append("OPTMI_%-20s .EQU %d" % (name, num))
    open(ASM, "w").write("\n".join(asm) + "\n")
    assert visible <= MAX_VISIBLE, "the main menu has %d lines, maximum is %d" % (visible, MAX_VISIBLE)
    print("OPTM_SIZE=%d OPTM_DX=%d OPTM_DY=%d groups=%d" % (size, width + 1, visible, len(groups)))


if __name__ == "__main__":
    main()

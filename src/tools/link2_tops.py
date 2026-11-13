#!/usr/bin/env python3
"""Moves rtl/karabas_mini_top.vhd and rtl/karabas_go_top.vhd onto MCU link v2, as the Mini G top
(karabas_minig_top.vhd, link-v2 PR #9) was moved: kg_mcu2 (the OSD, RTC, AUX for the LED matrix,
RELOAD for the FLASHBOOT of v1, the eight function keys of the OSD items from their triggers), the
bitmap OSD (kg_l2_osd_overlay) over the picture.

The blocks are taken from the Mini G top (the kg_mcu2 part from "MCU_IO(1) <= mcu_int;" to the
function keys), only the board glue differs:
Mini: INT on MCU_IO(1) (MCU_IO of 4 bits; E7, MCU_IO<4> before, is FT_CLK_OUT now: 7 MHz), MCU_SCK
  straight (not on a clock pin), the OSD over the HDMI frame as on Mini G.
Go: INT on MCU_IO(0) (N9), MCU_SCK straight, the OSD over the 31 kHz picture of the scandoubler
  (the 15 kHz RGB output of the Go goes without it).
Run once on the v1 tops (src/): python3 tools/link2_tops.py; every replacement must match once.
"""
import re
import sys

def sub(s, old, new, what):
    if s.count(old) != 1:
        sys.exit("link2_tops.py: %s: %d matches of %r" % (what, s.count(old), old[:70]))
    return s.replace(old, new)

g = open("rtl/karabas_minig_top.vhd").read()

# the signals of link v2 (after fn_keys) and of the OSD picture
i = g.index("\tsignal fn_all")
j = g.index("\tsignal port_cfg")
j = g.index("\n", j) + 1
SIGS = g[i:j]
OSD_SIGS = "   signal osd_rgb                : std_logic_vector(23 downto 0);\n   signal osd_hs, osd_vs, osd_de : std_logic;\n"

# the kg_mcu2 block
i = g.index("MCU_IO(1) <= mcu_int;")
j = g.index("fn_all(12 downto 11) <= fn_keys(12 downto 11);\n") + len("fn_all(12 downto 11) <= fn_keys(12 downto 11);\n")
MCU = g[i:j]
MCU = sub(MCU, "\tMCU_SCK => mcu_sck_bufg,\n", "\tMCU_SCK => MCU_SCK,   -- not on a clock pin on this board\n", "mcu sck")
# no LED matrix on Mini / Go (no dot_matrix in their prj)
MCU = sub(MCU, "\tMATRIX_CMD => matrix_cmd,\n", "\tMATRIX_CMD => x\"000000\",   -- no LED matrix on this board\n", "matrix")
MCU = sub(MCU, "\tMATRIX_CMD_WR => matrix_cmd_wr,\n", "\tMATRIX_CMD_WR => '0',\n", "matrix wr")

# the overlay of Mini G
i = g.index("      overlay: entity work.kg_l2_osd_overlay")
j = g.index("      );\n", i) + len("      );\n")
OVL = g[i:j]


def common(s, name):
    s = sub(s, "\tsignal fn_keys						: std_logic_vector(12 downto 1);\n",
            "\tsignal fn_keys						: std_logic_vector(12 downto 1);\n" + SIGS, name + " sigs")
    s = sub(s, "   zxn_function_keys <= fn_keys(10 downto 5) & (fn_keys(4) or joy_reset) & fn_keys(3 downto 1);",
            "   zxn_function_keys <= fn_all(10 downto 5) & (fn_all(4) or joy_reset) & fn_all(3 downto 1);", name + " fkeys")
    s = sub(s, "zxn_buttons <= (kb_buttons(1) or fn_keys(10)) & (kb_buttons(0) or fn_keys(9));",
            "zxn_buttons <= (kb_buttons(1) or fn_all(10)) & (kb_buttons(0) or fn_all(9));", name + " buttons")
    i = s.index("U_MCU: entity work.kg_mcu\n")
    j = s.index("\n);\n", i) + 4
    return s, i, j


# ---------------------------------------------------------------- Mini
m = open("rtl/karabas_mini_top.vhd").read()
m = sub(m, "\t\tMCU_IO 				: in 		std_logic_vector(4 downto 0);",
        "\t\tMCU_IO 				: inout 	std_logic_vector(3 downto 0);   -- [1] INT of link v2, [2] sd2 cs_n, [3] ft cs_n\n"
        "\t\tFT_CLK_OUT			: out		std_logic;                      -- E7 (MCU_IO<4> before): the clock of the FT812", "mini ports")
m = sub(m, "   signal toHDMI_rgb24           : std_logic_vector(23 downto 0);\n",
        "   signal toHDMI_rgb24           : std_logic_vector(23 downto 0);\n" + OSD_SIGS, "mini osd sigs")
m, i, j = common(m, "mini")
mcu_m = MCU.replace("MCU_IO(5 downto 2) <= (others => 'Z');", "MCU_IO(3 downto 2) <= (others => 'Z');")
m = m[:i] + mcu_m.replace("U_MCU: entity work.kg_mcu2", "U_MCU: entity work.kg_mcu2", 1) + """
-- FT_CLK_OUT: the FT812 must always have its clock (~8 MHz, else it hums into the audio): 7 MHz
ODDR2_FT_CLK: ODDR2
port map(
	Q => FT_CLK_OUT,
	C0 => CLK_7,
	C1 => not(CLK_7),
	CE => '1',
	D0 => '1',
	D1 => '0',
	R => '0',
	S => '0'
);
""" + m[j:]
# the MCU block of Mini G starts at MCU_IO(1): the v1 instance it replaces is U_MCU only
m = sub(m, "      hdmi: entity work.hdmi_out\n", OVL + "\n      hdmi: entity work.hdmi_out\n", "mini overlay")
m = sub(m, "         rgb            => toHDMI_rgb24,\n         hsync_n        => toHDMI_hsync,\n"
           "         vsync_n        => toHDMI_vsync,\n         blank          => toHDMI_blank,",
        "         rgb            => osd_rgb,\n         hsync_n        => not osd_hs,\n"
        "         vsync_n        => not osd_vs,\n         blank          => not osd_de,", "mini hdmi")
MINI_OUT = m

# ---------------------------------------------------------------- Go
o = open("rtl/karabas_go_top.vhd").read()
o = sub(o, "\t\tMCU_IO 				: in 		std_logic_vector(3 downto 0);",
        "\t\tMCU_IO 				: inout 	std_logic_vector(3 downto 0);   -- [0] INT of link v2 (N9)", "go ports")
o = sub(o, "\tsignal fn_keys						: std_logic_vector(12 downto 1);\n",
        "\tsignal fn_keys						: std_logic_vector(12 downto 1);\n"
        "\tsignal vga_rgb24					: std_logic_vector(23 downto 0);\n" + OSD_SIGS.replace("   signal", "\tsignal"), "go osd sigs")
o, i, j = common(o, "go")
mcu_o = MCU.replace("MCU_IO(1) <= mcu_int;\nMCU_IO(0) <= 'Z';\nMCU_IO(5 downto 2) <= (others => 'Z');",
                    "MCU_IO(0) <= mcu_int;   -- N9 (IO1 of the firmware)\nMCU_IO(3 downto 1) <= (others => 'Z');")
assert mcu_o != MCU
mcu_o = sub(mcu_o, "\tHW_ID => hwid,\n\tDVI_ONLY => dvi_only,\n",
            "\tHW_ID => open,\n\tDVI_ONLY => open,   -- no HDMI on this board\n", "go hwid")
o = o[:i] + mcu_o + o[j:]
# the OSD over the 31 kHz picture of the scandoubler (2 clocks of CLK_28, its syncs with it)
ovl_o = OVL.replace("clk            => CLK_HDMI,", "clk            => CLK_28,") \
           .replace("rgb_i          => toHDMI_rgb24,", "rgb_i          => vga_rgb24,") \
           .replace("hs_i           => not toHDMI_hsync,", "hs_i           => not hsync_out,") \
           .replace("vs_i           => not toHDMI_vsync,", "vs_i           => not vsync_out,") \
           .replace("de_i           => not toHDMI_blank,", "de_i           => not blank_out,")
assert ovl_o.count("CLK_28") == 2 and "vga_rgb24" in ovl_o and "blank_out" in ovl_o
o = sub(o, "      ha_value <= 48 when zxn_machine_timing(1) = '0' else 64;   -- 48k = 000 or 001, Pentagon = 100\n",
        "      ha_value <= 48 when zxn_machine_timing(1) = '0' else 64;   -- 48k = 000 or 001, Pentagon = 100\n\n"
        "      -- the bitmap OSD of link v2 over the 31 kHz picture (the 15 kHz RGB output goes without it)\n"
        "      vga_rgb24 <= rgb_31(8 downto 6) & rgb_31(8 downto 6) & rgb_31(8 downto 7) &\n"
        "                   rgb_31(5 downto 3) & rgb_31(5 downto 3) & rgb_31(5 downto 4) &\n"
        "                   rgb_31(2 downto 0) & rgb_31(2 downto 0) & rgb_31(2 downto 1);\n\n" + ovl_o, "go overlay")
pat = re.compile(r'( *)VGA_R <= rgb_31\(8 downto 6\) & rgb_31\(8 downto 6\) & "00";\n'
                 r' *VGA_G <= rgb_31\(5 downto 3\) & rgb_31\(5 downto 3\) & "00";\n'
                 r' *VGA_B <= rgb_31\(2 downto 0\) & rgb_31\(2 downto 0\) & "00";\n'
                 r'(\s*)VGA_HS <= hsync_out;\n *VGA_VS <= vsync_out;')
if len(pat.findall(o)) != 1:
    sys.exit("link2_tops.py: go vga: no single match")
o = pat.sub(lambda mm: (mm.group(1) + "VGA_R <= osd_rgb(23 downto 16);\n" + mm.group(1) + "VGA_G <= osd_rgb(15 downto 8);\n"
                        + mm.group(1) + "VGA_B <= osd_rgb(7 downto 0);\n" + mm.group(2) + "VGA_HS <= not osd_hs;\n"
                        + mm.group(1) + "VGA_VS <= not osd_vs;"), o)
open("rtl/karabas_mini_top.vhd", "w").write(MINI_OUT)
open("rtl/karabas_go_top.vhd", "w").write(o)
print("link2_tops.py: rtl/karabas_mini_top.vhd, rtl/karabas_go_top.vhd")

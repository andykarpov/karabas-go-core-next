# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The ZX Spectrum Next core (3.02.01 of the ZX Next FPGA project) for the Karabas Go, Mini and Mini G boards: Xilinx Spartan-6 XC6SLX25, ISE 14.7 (XST). The machine is `src/rtl/zxnext/zxnext.vhd` and `src/rtl/zxnext/*`, the upstream code with local changes marked `-- karabas:` / `// karabas:` (keep them marked, so the tree can be compared with upstream). Three VHDL tops, ported from the upstream issue 2 top: `src/rtl/karabas_go_top.vhd` (VGA through the video DAC, the full system_pll: VGA-0..6), `karabas_mini_top.vhd` and `karabas_minig_top.vhd` (HDMI, system_pll_reduced: VGA-0 and VGA-1). The ESP8266 is on the uart of the Next; there is no OSD (the F keys come from `hid_parser`; the `osd` items of the json are hotkeys only), no FT812, no burst link.

The board modules (MCU link, memories, clocks, DACs, HDMI) come from the git submodule `modules/` ([karabas-go-modules](https://github.com/andykarpov/karabas-go-modules), shared by the Karabas Go cores; clone with `--recursive` or run `git submodule update --init`). A change to them is made there and taken here by updating the submodule commit. Its `CLAUDE.md` and `docs/PLAN.md` have the rules (Verilog-2001 for XST, tests, checks of LUTs and timing).

## Build

- `cd src && make` builds the three boards (`make go`, `mini`, `minig` one of them; `make minig-xst`, `-impl`, `-core` one step; `make minig-report` the utilization and timing of the last build, `make minig-modes` the timing runs of the other clock modes, see Timing). It runs the ISE command-line flow and sources `/opt/Xilinx/14.7/ISE_DS/settings64.sh` (`ISE_SETTINGS=` to change it). The boards share `xst/` and `_ngo/` in `src/`, so they are built one after the other; a board takes 15 to 30 minutes, mostly PAR.
- Inputs per board: `karabas_<board>.prj` (the source list, the shared modules as `"../modules/rtl/..."`), `.xst`, `.ucf`, `.ut`. There is no ISE GUI project (`.xise`) any more; the Makefile has the map / par options (those of tsconf). The map cost table is per board, `MAP_T_<board>`, 2 on all three (the one that works on these cores; with 1 the router of the Go did not finish in 47 minutes): when a build misses a constraint by a placement (a path without logic and a long route), try another before changing the design; check that `-t` in the `.mrp` is `MAP_T_<board>` before a release.
- `core` packs `karabas_<board>.bin` with `core.json` (Go), `core_mini.json`, `core_minig.json` into `zxnext.kg1` / `kg2` / `kg3` with `make_core.py` (a symlink to karabas-go-tools). The `.bin` and `.kg*` files are committed as the release; `build` of the json is `date +%y%m%d%H` of the release build.

## Timing

- Clocks: CLK_50MHZ -> IBUFG -> system_pll (PLL_ADV, reprogrammed through DRP for the VGA modes, from `CLK_50`, the BUFG of the pin) -> CLK_28, CLK_28_n, CLK_14, CLK_7, CLK_28x5_n (the SRAM write pulse). CLK_CPU is the BUFGMUX of the PLL output of CLK_28 (`CLK0PLL`, 28 MHz) and `cpu_clk_s`, a flip-flop on CLK_28 for 3.5 / 7 / 14 MHz (`gen_clkbuf_0` of the upstream top, for the boards with HDMI; the Go builds it too: its own `gen_clkbuf_1`, a cascade of BUFGMUXes of CLK_7 / CLK_14 / CLK_28 and `clk_3m5_cont`, made the cpu clock 2 ns later than CLK_28 and PAR could not fix the hold of the 14 MHz mode). hdmi_pll (Mini, Mini G): CLK_28 -> DCM_CLKGEN -> (a divider by 311 for 128K 50Hz) -> DCM_CLKGEN -> PLL_BASE: the pixel clock 26.2...27.04 MHz locked to the video frame, its 5x clocks; the MIDI clock is kg_dcm (28 x 3 / 7). The DCM_CLKGEN start with their static CLKFX_MULTIPLY / DIVIDE and `drp_dcm` waits for LOCKED on them before it programs the frame values: keep them those of the ZX Next (a CLKFX out of the DCM range does not lock and leaves HDMI without clocks; the unisim model locks anyway, so `tb_hdmi_pll` does not see it). Set the timing analysis with `CLKFX_MD_MAX` only.
- The ucf (the timing block at the end) has PERIOD on CLK_50MHZ, derived onto everything with the static values of the PLL (VGA-0) and the `CLKFX_MD_MAX` of the DCM_CLKGEN (see `hdmi_pll.vhd`: the chain to the pixel clock gives the fastest frame), TS_HDMI_DIV for the 128K divider (309 MHz, in ns with PRIORITY: ngdbuild drops the PRIORITY of a relative PERIOD), TS_CLK_MCU, DATAPATHONLY bounds for the asynchronous crossings (MCU_SCK, CLK_50 <-> CLK_28, CLK_28 <-> the HDMI pixel clock, CLK_50 -> the divider of hdmi_pll), the SRAM budget (12 ns out + 10 ns tAA + 12 ns in, one CLK_28 cycle). Each exception is explained there; do not TIG paths that are real.
- `make <board>-modes` runs trce again on the routed design with `pcf_modes.py`: the VGA modes of the board (the PERIODs of system_pll with its S<n> values) and the CPU flip-flops on `cpu_clk_s` at 14 MHz, 0 and 3 ns after CLK_28 (`cpu_clk_s` MAXDELAY in the ucf). Run it after every build.
- What the runs of -modes leave open (the clock design of the ZX Next; written in the ucf): in the CPU modes of 3.5 / 7 / 14 MHz the CPU clock comes 2.5 to 5.2 ns after CLK_28 and paths CLK_28 -> CPU have less hold slack than that (a flip-flop can take the next CLK_28 value); in VGA-1 / VGA-2 the 5x clock is 4.67 x CLK_28 and the SRAM write pulse logic misses by 1 ns; VGA-3..6 of the Go (30 to 33 MHz) miss on the paths of the CPU at 28 MHz (setup) and the half periods to CLK_28_n, more the faster the mode (the old build missed there as well).
- No clocks from logic but the CPU clock and the 128K divider of hdmi_pll (both upstream, constrained) and no latches: check "Clock Information" of the `.syr`.

## Simulation

- `src/sim/run_mcu_sim.sh` (ISim): `tb_mcu_next`, `kg_mcu` with the parameters of the tops against the old `mcu.vhd` (`sim/ref`, the coregen queue / rtc models in `sim/ref/ipcore`): frames of every command, the rtc registers both ways, the matrix and flashboot words, the mouse through `kg_cursor` against a model (the old link moved it twice per report).
- `src/sim/run_hdmi_sim.sh` (ISim): `tb_hdmi_pll`, the pixel clock of each frame type against the old hdmi_pll.
- `src/sim/run_eq_sim.sh` (iverilog): `tb_hdmi_out` (what reaches zhdmi), the I2S of `kg_pcm5102` (the old PCM5102 must fail it).
- Each prints `<tb>: 0 errors`. The tests of the shared modules are in `modules/sim` (`run_all.sh`; `sim/ipcore_eq` compares the kg_* memories with the coregen models in `src/sim/ref/ipcore` of this core).

## Layout

- `src/rtl/karabas_*_top.vhd`: the boards: clocks, resets, SRAM, video, `kg_mcu`, `ds1307` (the I2C RTC of the Next on the rtc registers of the mcu), `hid_parser` (the keyboard matrix and joysticks of the Next), `kg_cursor`, the DACs, HDMI.
- `src/rtl/hdmi/hdmi_out.v`: zhdmi with the audio of the core. `src/rtl/sound`: the mixer and soundrive used by `zxnext.vhd`. `src/rtl/mcu/dot_matrix.v`: the level meter of the Mini G.
- `src/rtl/zxnext`: the upstream tree (not all of it is built: see the prj).
- `src/sim/ref`: the old code for the tests.

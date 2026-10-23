# Command line build of the ZX Spectrum Next core for the three boards: the steps and options of the ISE 14.7
# project navigator (the .xise projects of the boards, removed when this Makefile replaced them).
#
#   make                 all three boards (zxnext.kg1, zxnext.kg2, zxnext.kg3)
#   make go|mini|minig   one board: synthesis, implementation, bitstream, .kg file
#   make minig-xst       one step: <board>-xst (.ngc), <board>-impl (.bin), <board>-core (.kg)
#   make minig-report    LUTs, slices, block RAMs and the timing result of the last build (and of -modes)
#   make minig-modes     the timing of the last build in the other modes of the clocks (see below)
#   make clean           the intermediate files (not the .bin / .kg files, they are in git)
#
# Inputs per board: karabas_<board>.prj (the source list, the shared modules as
# "../modules/rtl/..."), .xst, .ucf, .ut.
# A step runs again when one of its inputs is newer than its output.
# The boards share xst/ and _ngo/, so they are built one after the other.

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh
PART = xc6slx25-ftg256-2
BOARDS = go mini minig

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c
.NOTPARALLEL:
# settings64.sh takes the arguments of the shell that sources it: none here
XIL = set --; source $(ISE_SETTINGS) > /dev/null;

KG_go = zxnext.kg1
KG_mini = zxnext.kg2
KG_minig = zxnext.kg3
JSON_go = core.json
JSON_mini = core_mini.json
JSON_minig = core_minig.json

# map / par options (those of tsconf). The map cost table (-t, the placement seed) is per board, 2 by default (the
# one that works on these cores): on the Go, 1 left the router of the build of 2026-10-22 running for 47 minutes,
# 2 routed it in 4 minutes with all constraints met. When a build misses a constraint by a placement, try another.
MAP_T_go = 2
MAP_T_mini = 2
MAP_T_minig = 2
MAP_OPT = -logic_opt off -ol high -xe n -xt 0 -register_duplication off -r 4 -global_opt off -mt 2 -detail -ir off -pr b -lc off -power off
PAR_OPT = -ol high -xe n -mt 4

# The PERIODs of system_pll are derived from its static attributes (VGA-0); the DRP logic reprograms it for the
# other VGA modes, and the CPU clock is a BUFGMUX of CLK_28 and a flip-flop (cpu_clk_s) for 3.5 / 7 / 14 MHz.
# <board>-modes runs trce again on the routed design with the constraints of each of these modes (pcf_modes.py):
# the VGA modes of the board's system_pll (the Mini / Mini G build system_pll_reduced, VGA-0 and VGA-1) and the CPU
# flip-flops on cpu_clk_s at 14 MHz (pcf_modes.py; the delay of that clock is not modelled, see the ucf).
# Run it after every build.
PLLV_go = rtl/zxnext/pll/S6/system_pll.v
PLLV_mini = rtl/zxnext/pll/S6/system_pll_reduced.v
PLLV_minig = rtl/zxnext/pll/S6/system_pll_reduced.v
MODES_go = vga1 vga2 vga3 vga4 vga5 vga6 cpu
MODES_mini = vga1 cpu
MODES_minig = vga1 cpu

# included or read by the sources, not in the prj
INCLUDES = $(wildcard ../modules/rtl/mcu/*.vh) rtl/zxnext/pll/S6/drp_pll_func.h rtl/zxnext/video/sprite_pattern_e3.hex

.PHONY: all clean $(BOARDS) $(BOARDS:=-xst) $(BOARDS:=-impl) $(BOARDS:=-core) $(BOARDS:=-report) $(BOARDS:=-modes)

all: $(BOARDS)

define board
SRC_$(1) := $$(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' karabas_$(1).prj)

karabas_$(1).ngc: karabas_$(1).prj karabas_$(1).xst $$(SRC_$(1)) $(INCLUDES)
	mkdir -p xst/projnav.tmp
	$(XIL) xst -intstyle ise -ifn karabas_$(1).xst -ofn karabas_$(1).syr

karabas_$(1).bin: karabas_$(1).ngc karabas_$(1).ucf karabas_$(1).ut
	$(XIL) ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc karabas_$(1).ucf -p $(PART) karabas_$(1).ngc karabas_$(1).ngd
	$(XIL) map -intstyle ise -p $(PART) -w $(MAP_OPT) -t $(MAP_T_$(1)) -o karabas_$(1)_map.ncd karabas_$(1).ngd karabas_$(1).pcf
	$(XIL) par -w -intstyle ise $(PAR_OPT) karabas_$(1)_map.ncd karabas_$(1).ncd karabas_$(1).pcf
	$(XIL) trce -intstyle ise -v 3 -s 2 -n 3 -fastpaths -xml karabas_$(1).twx karabas_$(1).ncd -o karabas_$(1).twr karabas_$(1).pcf -ucf karabas_$(1).ucf
	$(XIL) bitgen -intstyle ise -f karabas_$(1).ut karabas_$(1).ncd

$(KG_$(1)): karabas_$(1).bin $(JSON_$(1))
	python3 make_core.py $(JSON_$(1)) $$@

$(1): $(KG_$(1))
$(1)-xst: karabas_$(1).ngc
$(1)-impl: karabas_$(1).bin
$(1)-core: $(KG_$(1))
$(1)-report:
	@grep -E "Number of (Slice LUTs|occupied Slices|RAMB16BWERs|RAMB8BWERs):" karabas_$(1)_map.mrp
	@grep -E "constraints? (was|were) met|constraints? not met|Timing Score" karabas_$(1).par | sort -u
	@for m in $(MODES_$(1)); do if [ -f karabas_$(1)_$$$$m.twr ]; then echo "mode $$$$m (-modes): \
		$$$$(grep -E 'Timing errors:|Score:' karabas_$(1)_$$$$m.twr | tr -s ' ' | tr '\n' ' ')"; fi; done

$(1)-modes: karabas_$(1).bin pcf_modes.py
	@for m in $(MODES_$(1)); do \
		python3 pcf_modes.py karabas_$(1).pcf karabas_$(1)_$$$$m.pcf $(PLLV_$(1)) $$$$m; \
		$(XIL) trce -intstyle ise -v 3 -s 2 -n 3 -fastpaths karabas_$(1).ncd -o karabas_$(1)_$$$$m.twr \
			karabas_$(1)_$$$$m.pcf > karabas_$(1)_$$$$m.log 2>&1; \
		! grep -q "No timing constraints found" karabas_$(1)_$$$$m.twr || { echo "trce did not read the pcf"; exit 1; }; \
		echo "mode $$$$m: $$$$(grep -E 'Timing errors:|Score:' karabas_$(1)_$$$$m.twr | tr -s ' ' | tr '\n' ' ')"; \
	done
endef

$(foreach b,$(BOARDS),$(eval $(call board,$(b))))

clean:
	rm -rf xst _ngo _xmsgs xlnx_auto_0_xdb iseconfig
	rm -f $(foreach b,$(BOARDS),$(addprefix karabas_$(b),.ngc .ngd .ngr .syr .lso .bld .pcf .ncd _map.ncd _map.ngm \
		_map.map _map.mrp _map.xrpt .par .pad _pad.csv _pad.txt .twr .twx .unroutes .xpi .ptwx .bgn .bit .drc \
		_bitgen.xwbt _summary.xml _usage.xml _xst.xrpt _ngdbuild.xrpt _par.xrpt _guide.ncd \
		$(foreach m,$(MODES_$(b)),_$(m).pcf _$(m).twr _$(m).log)))

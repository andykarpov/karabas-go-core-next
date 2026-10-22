#!/bin/bash
# The HDMI clocks of the Mini / Mini G (ISim, ISE 14.7):
#   tb_hdmi_pll: hdmi_pll (zxnext/pll/S6) against the one of the ZX Next (sim/ref), the pixel clock of each frame type
# Usage: src/sim/run_hdmi_sim.sh [path to ISE_DS/settings64.sh]
# Prints "tb_hdmi_pll: 0 errors"; the script fails on any other count.

set -e
SETTINGS=${1:-/opt/Xilinx/14.7/ISE_DS/settings64.sh}
SIM="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$SIM")"
RTL="$SRC/rtl"
OUT="$SIM/build/hdmi"
mkdir -p "$OUT"
set --
source "$SETTINGS" > /dev/null
cd "$OUT"

{
	echo "vhdl work \"$RTL/zxnext/pll/S6/drp_dcm.vhd\""
	echo "vhdl work \"$RTL/zxnext/pll/S6/hdmi_pll.vhd\""
	echo "vhdl work \"$SIM/ref/drp_dcm_ref.vhd\""
	echo "vhdl work \"$SIM/ref/hdmi_pll_ref.vhd\""
	echo "verilog work \"$SIM/tb_hdmi_pll.v\""
	echo "verilog work \"$XILINX/verilog/src/glbl.v\""
} > tb_hdmi_pll.prj
fuse -prj tb_hdmi_pll.prj -L unisim -L unisims_ver -top work.tb_hdmi_pll -top work.glbl -o tb_hdmi_pll.exe > fuse.log \
	|| { grep ERROR fuse.log; exit 1; }
echo "run all; quit" > run.tcl
./tb_hdmi_pll.exe -tclbatch run.tcl > tb_hdmi_pll.log 2>&1 || true
grep -E "ERROR|^frame|tb_hdmi_pll: " tb_hdmi_pll.log | head -20
grep -q "tb_hdmi_pll: 0 errors" tb_hdmi_pll.log || { echo "tb_hdmi_pll FAILED"; exit 1; }
echo "HDMI SIMULATION PASSED"

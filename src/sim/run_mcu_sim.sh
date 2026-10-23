#!/bin/bash
# The MCU link of the tops against the old one (ISim, ISE 14.7):
#   tb_mcu_next: kg_mcu with the parameters of the tops against mcu.vhd / spi_slave.vhd of the core (sim/ref, the
#                coregen queue and rtc models in sim/ref/ipcore): the commands of the core, the rtc registers both
#                ways, the matrix words, the flashboot word, the mouse through the cursor (cursor.vhd before)
# Usage: src/sim/run_mcu_sim.sh [path to ISE_DS/settings64.sh]
# Prints "tb_mcu_next: 0 errors"; the script fails on any other count.

set -e
SETTINGS=${1:-/opt/Xilinx/14.7/ISE_DS/settings64.sh}
SIM="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$SIM")"
M="$SRC/../modules/rtl"
OUT="$SIM/build/mcu"
mkdir -p "$OUT"
set --
source "$SETTINGS" > /dev/null
cd "$OUT"
CORELIB=$XILINX/verilog/src/XilinxCoreLib
python3 -I "$SIM/buffer_wrap.py" "$SIM/ref/mcu_ref.vhd" mcu_ref mcu_ref_sim.vhd

{
	for f in mem/kg_fifo.v mem/kg_sdpram.v mcu/kg_spi_slave.v mcu/kg_burst_rx.v mcu/kg_mcu_link.v mcu/kg_mcu_ctl.v \
		mcu/kg_mcu_hid.v mcu/kg_mcu_loader.v mcu/kg_mcu_rtc.v mcu/kg_mcu_uart.v mcu/kg_mcu_img.v mcu/kg_mcu_debug.v \
		mcu/kg_mcu_esp.v mcu/kg_mcu.v hid/kg_cursor.v; do
		echo "verilog work \"$M/$f\" -i \"$M/mcu\""
	done
	echo "verilog work \"$CORELIB/FIFO_GENERATOR_V9_3.v\""
	echo "verilog work \"$CORELIB/BLK_MEM_GEN_V7_3.v\""
	echo "verilog work \"$SIM/ref/ipcore/queue.v\""
	echo "verilog work \"$SIM/ref/ipcore/rtc.v\""
	echo "vhdl work \"$SIM/ref/spi_slave_ref.vhd\""
	echo "vhdl work \"$OUT/mcu_ref_sim.vhd\""
	echo "vhdl work \"$SIM/ref/cursor_ref.vhd\""
	echo "verilog work \"$SIM/tb_mcu_next.v\""
} > tb_mcu_next.prj
fuse -prj tb_mcu_next.prj -top work.tb_mcu_next -o tb_mcu_next.exe > fuse.log || { grep ERROR fuse.log; exit 1; }
echo "run all; quit" > run.tcl
./tb_mcu_next.exe -tclbatch run.tcl > tb_mcu_next.log 2>&1 || true
grep -E "ERROR|old link|tb_mcu_next: " tb_mcu_next.log | head -20
grep -q "tb_mcu_next: 0 errors" tb_mcu_next.log || { echo "tb_mcu_next FAILED"; exit 1; }
echo "MCU SIMULATION PASSED"

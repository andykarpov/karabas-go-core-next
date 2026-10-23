#!/bin/bash
# The rewrites of the board glue against what they replace (Icarus Verilog):
#   tb_hdmi_out: rtl/hdmi/hdmi_out.v, what reaches hdmi_tx (zhdmi) in place of the encoder of the ZX Next
#   tb_pcm5102:  the I2S stream of kg_pcm5102 (DIV_BITS 1 and 2, as the Go and the Mini G) with the testbench of
#                karabas-go-modules (strict: all 16 bits, din changing with the falling bck); the old PCM5102 of
#                this core (sim/ref) is run with it too and must fail: it changed din with the rising bck
# Prints "<tb>: 0 errors" for each; the script fails otherwise.
set -e
SIM="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$SIM")"
M="$SRC/../modules"
OUT="$SIM/build/eq"
mkdir -p "$OUT"
cd "$OUT"
fail=0

iverilog -g2001 -Wall -Wno-timescale -o tb_hdmi_out.vvp "$SIM/tb_hdmi_out.v" "$SRC/rtl/hdmi/hdmi_out.v"
vvp -n tb_hdmi_out.vvp > tb_hdmi_out.log
grep -E "ERROR|tb_hdmi_out:" tb_hdmi_out.log | head
grep -q "tb_hdmi_out: 0 errors" tb_hdmi_out.log || fail=1

for div in 1 2; do
	sed "s/DIV_BITS(1)/DIV_BITS($div)/; s/!= 8) begin/!= $((4 << div))) begin/; s/!= 256) begin/!= $((128 << div))) begin/" \
		"$M/sim/audio/tb_pcm5102.v" > tb_pcm5102_$div.v
	iverilog -g2001 -Wall -Wno-timescale -DKG_PCM5102 -o kg_$div.vvp tb_pcm5102_$div.v "$M/rtl/audio/kg_pcm5102.v"
	vvp -n kg_$div.vvp > kg_pcm5102_$div.log
	echo "kg_pcm5102 DIV_BITS $div: $(grep 'tb_pcm5102: .* errors' kg_pcm5102_$div.log)"
	grep -q "tb_pcm5102: 0 errors" kg_pcm5102_$div.log || fail=1
	printf 'module pcm5102_old #(parameter DIV_BITS = 1) (input clk, input reset, input [15:0] left, input [15:0] right,\n\toutput din, output bck, output lrck);\nPCM5102 #(.DAC_CLK_DIV_BITS(DIV_BITS)) u(.clk(clk), .reset(reset), .left(left), .right(right),\n\t.din(din), .bck(bck), .lrck(lrck));\nendmodule\n' > pcm5102_old.v
	sed "s/^kg_pcm5102 #/pcm5102_old #/" tb_pcm5102_$div.v > tb_pcm5102_old_$div.v
	iverilog -g2001 -Wno-timescale -DKG_PCM5102 -o old_$div.vvp tb_pcm5102_old_$div.v pcm5102_old.v "$SIM/ref/pcm5102_ref.v"
	vvp -n old_$div.vvp > old_pcm5102_$div.log
	echo "old PCM5102 DAC_CLK_DIV_BITS $div (expected to fail): $(grep 'tb_pcm5102: .* errors' old_pcm5102_$div.log)"
	grep -q "tb_pcm5102: 0 errors" old_pcm5102_$div.log && { echo "the old PCM5102 passed: the test does not test"; fail=1; }
done
[ $fail = 0 ] && echo "EQ SIMULATION PASSED" || { echo "EQ SIMULATION FAILED"; exit 1; }

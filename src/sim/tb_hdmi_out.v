`timescale 1ps / 1ps

// rtl/hdmi/hdmi_out.v (iverilog): what reaches hdmi_tx, a stub here (zhdmi is VHDL; modules has its tests):
// - rgb / hsync / vsync / de: the 9-bit colour widened as the old encoder did (RRR RRR RR), de = not blank, in the
//   same pixel clock;
// - audio_en: HDMI audio enable (clk_28) and not DVI_ONLY, through two flip-flops of the pixel clock;
// - audio: a sample every 583 clocks of clk_28 (48.03 kHz), one audio_clk pulse each, the sample of that moment.
// clk_28 28 MHz, the pixel clock 27.04 MHz (unrelated). Ends with "tb_hdmi_out: N errors".

module hdmi_tx #(parameter SAMPLE_FREQ = 48000) (
	input wire clk, input wire sclk, input wire sclk_n, input wire reset,
	input wire [23:0] rgb, input wire vsync, input wire hsync, input wire de,
	input wire audio_en, input wire [23:0] audio_l, input wire [23:0] audio_r, input wire audio_clk,
	output wire tx_clk_n, output wire tx_clk_p, output wire [2:0] tx_d_n, output wire [2:0] tx_d_p
);
assign tx_clk_n = 1'b0; assign tx_clk_p = 1'b0; assign tx_d_n = 3'b000; assign tx_d_p = 3'b000;
endmodule

module tb_hdmi_out;

reg clk28 = 1'b0, pix = 1'b0;
always #17857 clk28 = ~clk28;
always #18489 pix = ~pix;

integer errors = 0;
task automatic fail(input [8*60-1:0] what);
	begin
		if (errors < 20) $display("%t ERROR: %0s", $time, what);
		errors = errors + 1;
	end
endtask

reg [15:0] al = 16'h0000, ar = 16'h0000;
reg audio_on = 1'b1, dvi_only = 1'b0, valid = 1'b0;
reg [8:0] rgb = 9'd0;
reg hs = 1'b1, vs = 1'b1, blank = 1'b1;
wire [3:0] tp, tn;

hdmi_out #(.SAMPLERATE(48000), .CLKRATE(28000000)) dut(
	.clk_28(clk28), .audio_l(al), .audio_r(ar), .audio_on(audio_on), .dvi_only(dvi_only),
	.clk_pix(pix), .clk_x5(1'b0), .clk_x5_n(1'b1), .pix_valid(valid),
	.rgb(rgb), .hsync_n(hs), .vsync_n(vs), .blank(blank), .tmds_p(tp), .tmds_n(tn)
);

// the samples: a new pair in clk_28 every 100 clocks
integer n28 = 0;
always @(negedge clk28) begin
	n28 = n28 + 1;
	if (n28 % 100 == 0) begin al = al + 16'h0101; ar = ar - 16'h0303; end
end

// video: random, compared at the next pixel clock edge
reg [23:0] exp_rgb;
always @(negedge pix) begin
	rgb = $random; hs = $random; vs = $random; blank = $random;
	exp_rgb = {rgb[8:6], rgb[8:6], rgb[8:7], rgb[5:3], rgb[5:3], rgb[5:4], rgb[2:0], rgb[2:0], rgb[2:1]};
	#1;
	if (dut.hdmi_tx.rgb !== exp_rgb || dut.hdmi_tx.hsync !== hs || dut.hdmi_tx.vsync !== vs || dut.hdmi_tx.de !== ~blank)
		fail("video into hdmi_tx");
	if (dut.hdmi_tx.reset !== ~valid) fail("reset");
end

// audio: the clk_28 count of the sample edges, and each sample against the inputs then
integer pulses = 0, last_t = 0, bad_gap = 0, n_at_tgl = 0;
reg [15:0] tgl_l, tgl_r;
always @(posedge clk28) if (dut.sample_cnt == 16'd582) begin tgl_l <= al; tgl_r <= ar; n_at_tgl = n28; end
always @(posedge pix) if (dut.hdmi_tx.audio_clk) begin
	pulses = pulses + 1;
	if (pulses > 2 && (n_at_tgl - last_t != 583)) bad_gap = bad_gap + 1;
	last_t = n_at_tgl;
	// the sample of the last toggle (the inputs only change every 100 clk_28: the value taken is that of then)
	if (dut.hdmi_tx.audio_l !== {tgl_l, 8'h00} || dut.hdmi_tx.audio_r !== {tgl_r, 8'h00}) fail("audio sample");
end

initial begin
	#1000000; valid = 1'b1;
	#2000000000;                                        // 2 ms: 96 samples
	if (pulses < 94 || pulses > 98) begin $display("ERROR: %0d audio_clk pulses in 2 ms", pulses); errors = errors + 1; end
	if (bad_gap != 0) fail("a sample period other than 583 clocks of clk_28");
	if (dut.hdmi_tx.audio_en !== 1'b1) fail("audio_en with audio on, not dvi only");
	@(negedge clk28) dvi_only = 1'b1; #200000;
	if (dut.hdmi_tx.audio_en !== 1'b0) fail("audio_en with dvi only");
	@(negedge clk28) begin dvi_only = 1'b0; audio_on = 1'b0; end #200000;
	if (dut.hdmi_tx.audio_en !== 1'b0) fail("audio_en with the audio off");
	@(negedge clk28) audio_on = 1'b1; #200000;
	if (dut.hdmi_tx.audio_en !== 1'b1) fail("audio_en back");
	@(negedge pix) valid = 1'b0; #100000;
	$display("tb_hdmi_out: %0d audio samples, %0d errors", pulses, errors);
	$display("tb_hdmi_out: %0d errors", errors);
	$finish;
end

endmodule

`timescale 1ns / 1ps
`default_nettype wire

/*
 HDMI output of the Mini / Mini G: the frame of hdmi_frame (zxnext, 720x576 / 720x480 at the pixel
 clock of hdmi_pll, about 27 MHz) with the audio of the core, through zhdmi (hdmi_tx of
 karabas-go-modules). It replaces the HDMI encoder of the ZX Next (hdmi.vhd with hdmidataencoder,
 dvi.vhd and hdmi_out_xilinx_s6), which sent the same frame.

 audio_en of hdmi_tx: HDMI with the audio when the core enables the HDMI audio (nextreg 08) and
 the mcu did not set DVI_ONLY; DVI otherwise. The old encoder sent no data island at all then.

 The pixel clock is not related to clk_28 (hdmi_pll makes it from the frame rate through two
 DCM_CLKGEN): audio_on and dvi_only go through two flip-flops; a sample is taken every
 CLKRATE / SAMPLERATE clocks of clk_28 and passed with a toggle (the data stays the same for a whole
 sample period, far longer than the synchronizer takes). hdmi_tx measures the CTS of the audio
 clock regeneration from the pixel clock, so the sample rate may follow clk_28 (28 / 28.57 MHz).
*/

module hdmi_out #(
	parameter SAMPLERATE = 48000,
	parameter CLKRATE = 28000000 // clk_28
) (
	input wire clk_28,
	input wire [15:0] audio_l,  // two's complement, clk_28
	input wire [15:0] audio_r,
	input wire audio_on,        // clk_28
	input wire dvi_only,        // clk_28

	input wire clk_pix,
	input wire clk_x5,
	input wire clk_x5_n,
	input wire pix_valid,       // the pixel clocks run (low resets hdmi_tx)

	input wire [8:0] rgb,       // RRRGGGBBB, clk_pix
	input wire hsync_n,
	input wire vsync_n,
	input wire blank,

	output wire [3:0] tmds_p,
	output wire [3:0] tmds_n
);

// settings from clk_28
reg [1:0] audio_on_s = 2'b00, dvi_only_s = 2'b00;
always @(posedge clk_pix) begin
	audio_on_s <= {audio_on_s[0], audio_on};
	dvi_only_s <= {dvi_only_s[0], dvi_only};
end

// audio samples in clk_28, passed to the pixel clock
localparam integer SAMPLE_DIV = CLKRATE / SAMPLERATE;
reg [15:0] sample_cnt = 16'd0;
reg [31:0] sample_28 = 32'd0;
reg sample_tgl = 1'b0;
always @(posedge clk_28) begin
	if (sample_cnt == SAMPLE_DIV - 1) begin
		sample_cnt <= 16'd0;
		sample_28 <= {audio_l, audio_r};
		sample_tgl <= ~sample_tgl;
	end
	else
		sample_cnt <= sample_cnt + 16'd1;
end

reg [2:0] sample_sync = 3'b000;
reg audio_clk = 1'b0;
reg [23:0] hdmi_audio_l = 24'd0, hdmi_audio_r = 24'd0;
always @(posedge clk_pix) begin
	sample_sync <= {sample_sync[1:0], sample_tgl};
	audio_clk <= sample_sync[2] ^ sample_sync[1];
	if (sample_sync[2] ^ sample_sync[1]) begin
		hdmi_audio_l <= {sample_28[31:16], 8'd0};
		hdmi_audio_r <= {sample_28[15:0], 8'd0};
	end
end

// the 9-bit colour to 24 bits as the old encoder did: RRR -> RRRRRRRR (RRR RRR RR)
wire [23:0] rgb24 = {rgb[8:6], rgb[8:6], rgb[8:7], rgb[5:3], rgb[5:3], rgb[5:4], rgb[2:0], rgb[2:0], rgb[2:1]};

hdmi_tx #(.SAMPLE_FREQ(SAMPLERATE)) hdmi_tx(
	.clk(clk_pix),
	.sclk(clk_x5),
	.sclk_n(clk_x5_n),
	.reset(~pix_valid),
	.rgb(rgb24),
	.vsync(vsync_n),
	.hsync(hsync_n),
	.de(~blank),

	.audio_en(audio_on_s[1] & ~dvi_only_s[1]),
	.audio_l(hdmi_audio_l),
	.audio_r(hdmi_audio_r),
	.audio_clk(audio_clk),

	.tx_clk_n(tmds_n[3]),
	.tx_clk_p(tmds_p[3]),
	.tx_d_n(tmds_n[2:0]),
	.tx_d_p(tmds_p[2:0]) // 0:blue, 1:green, 2:red
);

endmodule

`timescale 1ns / 1ps

// rtl/sound/audio_mixer.v (iverilog): EAR and MIC count for about 37 ms after they went to 1, then the
// output has no constant level from them; a 0 restarts the time; AY and the DAC are not touched.
// clk 28 MHz. Ends with "tb_audio_mixer: N errors".

module tb_audio_mixer;

reg clk = 1'b0, reset = 1'b1, exc = 1'b0, ear = 1'b0, mic = 1'b0;
reg [11:0] ay_l = 12'd0, ay_r = 12'd0;
reg [15:0] dac_l = 16'd0, dac_r = 16'd0;
wire [15:0] pcm_l, pcm_r;

audio_mixer dut(.clk(clk), .reset(reset), .exc(exc), .ear(ear), .mic(mic), .ay_l(ay_l), .ay_r(ay_r),
	.dac_l(dac_l), .dac_r(dac_r), .pcm_l(pcm_l), .pcm_r(pcm_r));

always #17.857 clk = ~clk;

integer errors = 0;

task check(input [15:0] want, input [255:0] what);
begin
	if (pcm_l !== want || pcm_r !== want) begin
		$display("%t ERROR: %0s: l %0d r %0d, want %0d", $time, what, pcm_l, pcm_r, want);
		errors = errors + 1;
	end
end
endtask

task ms(input integer n);
begin
	repeat (n * 28000) @(posedge clk);
	@(negedge clk);
end
endtask

initial begin
	repeat (4) @(posedge clk);
	reset = 1'b0;
	ms(1); check(16'd0, "silence");

	mic = 1'b1; ms(1); check(16'd1024, "mic just set");
	ms(29); check(16'd1024, "mic at 30 ms");
	ms(10); check(16'd0, "mic relaxed at 40 ms");
	ms(5); check(16'd0, "mic stays relaxed");

	mic = 1'b0; ms(1); check(16'd0, "mic back to 0");
	mic = 1'b1; ms(1); check(16'd1024, "mic set again sounds again");

	// a 0 restarts the time: 30 ms + 30 ms with a short 0 between never relaxes
	ms(29); check(16'd1024, "mic before the short 0");
	mic = 1'b0; ms(1); mic = 1'b1; ms(30); check(16'd1024, "mic 30 ms after the short 0");
	mic = 1'b0; ms(1);

	ear = 1'b1; ms(1); check(16'd4096, "ear just set");
	ms(29); check(16'd4096, "ear at 30 ms");
	ms(10); check(16'd0, "ear relaxed at 40 ms");

	// independent
	mic = 1'b1; ms(1); check(16'd1024, "mic sounds while ear is relaxed");
	ear = 1'b0; ms(1); ear = 1'b1; ms(1); check(16'd5120, "ear and mic");
	exc = 1'b1; ms(1); check(16'd0, "exclusive speaker");
	exc = 1'b0; ear = 1'b0; mic = 1'b0; ms(1);

	// AY and the DAC stay for ever
	ay_l = 12'd100; ay_r = 12'd100; dac_l = 16'd7; dac_r = 16'd7;
	ms(50); check(16'd3207, "ay and dac held");

	$display("tb_audio_mixer: %0d errors", errors);
	$finish;
end

endmodule

module audio_mixer(
    input wire clk,
    input wire reset,

    input wire exc,
    input wire ear,
    input wire mic,
    
    input wire [11:0] ay_l,
    input wire [11:0] ay_r,

    input wire [15:0] dac_l,
    input wire [15:0] dac_r,

    output wire [15:0] pcm_l,
    output wire [15:0] pcm_r
);

// A level held at 1 for a long time is not sound: the ROM leaves MIC at 1 after every BEEP and BORDER,
// which was a constant 1024 on the output in silence. EAR and MIC count here only for 37 ms after they
// went to 1 (64 ticks of 16384 clocks of 28 MHz, about 13 Hz at 50 % duty); port FE and the tape are not affected.
reg [13:0] relax_div = 14'd0;
wire relax_tick = &relax_div;
reg [6:0] ear_hold = 7'd0;
reg [6:0] mic_hold = 7'd0;
always @(posedge clk) begin
    relax_div <= relax_div + 14'd1;
    if (!ear) ear_hold <= 7'd0;
    else if (relax_tick && !ear_hold[6]) ear_hold <= ear_hold + 7'd1;
    if (!mic) mic_hold <= 7'd0;
    else if (relax_tick && !mic_hold[6]) mic_hold <= mic_hold + 7'd1;
end
wire ear_on = ear & ~ear_hold[6];
wire mic_on = mic & ~mic_hold[6];

wire [15:0] ear_mix = (ear_on & ~exc) ? {16'b0001000000000000} : 16'b0;
wire [15:0] mic_mix = (mic_on & ~exc) ? {16'b0000010000000000} : 16'b0;
wire signed [15:0] ay_l_mix = $signed({1'b0, ay_l[11:0]});
wire signed [15:0] ay_r_mix = $signed({1'b0, ay_r[11:0]});
wire signed [15:0] ay_l_out = ay_l_mix << 5; // amp the ay mix a bit
wire signed [15:0] ay_r_out = ay_r_mix << 5;

reg signed [15:0] mix_l, mix_r;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        mix_l <= 0;
        mix_r <= 0;
    end 
    else begin
        mix_l <= $signed(ay_l_out) + $signed(dac_l) + $signed(ear_mix) + $signed(mic_mix);
        mix_r <= $signed(ay_r_out) + $signed(dac_r) + $signed(ear_mix) + $signed(mic_mix);
    end
end

assign pcm_l = mix_l;
assign pcm_r = mix_r;

endmodule


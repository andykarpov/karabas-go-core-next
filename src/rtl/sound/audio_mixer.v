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

wire [15:0] ear_mix = (ear & ~exc) ? {16'b0001000000000000} : 16'b0;
wire [15:0] mic_mix = (mic & ~exc) ? {16'b0000010000000000} : 16'b0;
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


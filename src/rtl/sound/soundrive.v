module soundrive(
    input wire clk,
    input wire reset,
    
    input wire [7:0] din,
    input wire ch_a_wr,
    input wire ch_b_wr,
    input wire ch_c_wr,
    input wire ch_d_wr,

    input wire nr_mono_we,
    input wire nr_left_we,
    input wire nr_right_we,
    input wire [7:0] nr_audio_dat,

    output wire signed [15:0] pcm_l,
    output wire signed [15:0] pcm_r
);

reg [7:0] ch_a, ch_b, ch_c, ch_d;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        ch_a <= 8'h80;
        ch_b <= 8'h80;
        ch_c <= 8'h80;
        ch_d <= 8'h80;
    end
    else begin
        if (ch_a_wr) ch_a <= din;
        else if (nr_mono_we) ch_a <= nr_audio_dat;
        if (ch_b_wr) ch_b <= din;
        else if (nr_left_we) ch_b <= nr_audio_dat;
        if (ch_c_wr) ch_c <= din;
        else if (nr_right_we) ch_c <= nr_audio_dat;
        if (ch_d_wr) ch_d <= din;
        else if (nr_mono_we) ch_d <= nr_audio_dat;
    end
end

reg signed [8:0] mix_l, mix_r;
wire signed [15:0] out_l, out_r;
always @(posedge clk) begin
    mix_l <= $signed({~ch_a[7], ch_a[6:0]}) + $signed({~ch_b[7], ch_b[6:0]});
    mix_r <= $signed({~ch_c[7], ch_c[6:0]}) + $signed({~ch_d[7], ch_d[6:0]});
end
assign out_l = mix_l;
assign out_r = mix_r;

assign pcm_l = out_l << 6; // extend amplitude
assign pcm_r = out_r << 6;

endmodule


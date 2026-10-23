`timescale 1ps / 1ps

// hdmi_pll of the core against the one of the ZX Next (sim/ref, ISim with the unisim DCM_CLKGEN / PLL models): for
// each frame type (V5060, VMODEL: 48K, 128K, Pentagon at 50 Hz, 48K, 128K at 60 Hz) both are restarted (SSTEP), and
// once VALID is up the period of CLK2OUT (the pixel clock) is measured over 2000 cycles: the same frequency is
// expected (within 0.02 %; the BUFGs, the constraints and the rom size changed), and for each frame the frequency of
// drp_dcm.vhd (128K 50Hz: 210/19, the divider by 311 of hdmi_pll, 75/2: 540000 pixels of 576p in a 128K frame of
// 311 x 456 pixels at 7 MHz, 26.654 MHz; the comment of the rom says 312). CLK0OUT (5x) has 1/5 of the period.
// Ends with "tb_hdmi_pll: N errors".

module tb_hdmi_pll;

reg clk50 = 1'b0, clk28 = 1'b0;
always #10000 clk50 = ~clk50;
always #17857 clk28 = ~clk28;

integer errors = 0;

reg sstep = 1'b0;
reg v5060 = 1'b0;
reg [2:0] vmodel = 3'b000;
wire n_x5, n_x5n, n_pix, n_valid, o_x5, o_x5n, o_pix, o_valid;

hdmi_pll new_pll(.RST(1'b0), .SSTEP(sstep), .CLKDRP(clk50), .V5060(v5060), .VMODEL(vmodel), .CLKIN(clk28),
	.CLKIN_RDY_N(1'b0), .CLK0OUT(n_x5), .CLK1OUT(n_x5n), .CLK2OUT(n_pix), .VALID(n_valid));
hdmi_pll_ref old_pll(.RST(1'b0), .SSTEP(sstep), .CLKDRP(clk50), .V5060(v5060), .VMODEL(vmodel), .CLKIN(clk28),
	.CLKIN_RDY_N(1'b0), .CLK0OUT(o_x5), .CLK1OUT(o_x5n), .CLK2OUT(o_pix), .VALID(o_valid));

// period of a clock over n rising edges, ps
task automatic period(input integer which, input integer n, output real p);
	time t0, t1;
	integer k;
	begin
		if (which == 0) begin @(posedge n_pix); t0 = $time; for (k = 0; k < n; k = k + 1) @(posedge n_pix); end
		else if (which == 1) begin @(posedge o_pix); t0 = $time; for (k = 0; k < n; k = k + 1) @(posedge o_pix); end
		else begin @(posedge n_x5); t0 = $time; for (k = 0; k < n; k = k + 1) @(posedge n_x5); end
		t1 = $time;
		p = (t1 - t0) * 1.0 / n;
	end
endtask

// the pixel clock of drp_dcm.vhd: 28 MHz * M1 / D1 * M2 / D2 * 25 / 35
function real expect_mhz(input integer f);
	begin
		case (f)
		0: expect_mhz = 28.0 * 75 / 52 * 15 / 16 * 5 / 7;
		1: expect_mhz = 28.0 * 210 / 19 / 311 * 75 / 2 * 5 / 7;
		2: expect_mhz = 28.0 * 45 / 32 * 15 / 16 * 5 / 7;
		3: expect_mhz = 28.0 * 35 / 32 * 39 / 32 * 5 / 7;
		default: expect_mhz = 28.0 * 49 / 38 * 65 / 64 * 5 / 7;
		endcase
	end
endfunction

real pn, po, p5, fe, fn, fo;
integer f, w;
initial begin
	for (f = 0; f < 5; f = f + 1) begin
		// frame: 0 48K 50, 1 128K 50, 2 Pentagon 50, 3 48K 60, 4 128K 60
		case (f)
		0: begin v5060 = 1'b0; vmodel = 3'b000; end
		1: begin v5060 = 1'b0; vmodel = 3'b010; end
		2: begin v5060 = 1'b0; vmodel = 3'b100; end
		3: begin v5060 = 1'b1; vmodel = 3'b000; end
		default: begin v5060 = 1'b1; vmodel = 3'b010; end
		endcase
		#1000000;
		sstep = 1'b1; #200000; sstep = 1'b0;
		#1000000;
		w = 0;
		while (!(n_valid === 1'b1 && o_valid === 1'b1) && w < 2000) begin #1000000; w = w + 1; end
		if (!(n_valid === 1'b1 && o_valid === 1'b1)) begin
			$display("ERROR: frame %0d: VALID new %b old %b", f, n_valid, o_valid); errors = errors + 1;
		end
		else begin
			#20000000;
			period(0, 2000, pn);
			period(1, 2000, po);
			period(2, 2000, p5);
			fn = 1.0e6 / pn; fo = 1.0e6 / po; fe = expect_mhz(f);
			$display("frame %0d: new %f MHz, old %f MHz, drp_dcm %f MHz, 5x %f MHz", f, fn, fo, fe, 1.0e6 / p5);
			if (fn > fo * 1.0002 || fn < fo * 0.9998 || fn > fe * 1.0002 || fn < fe * 0.9998) begin
				$display("ERROR: frame %0d: the pixel clock", f); errors = errors + 1;
			end
			if (p5 * 5 > pn * 1.0002 || p5 * 5 < pn * 0.9998) begin
				$display("ERROR: frame %0d: the 5x clock", f); errors = errors + 1;
			end
		end
	end
	$display("tb_hdmi_pll: %0d errors", errors);
	$finish;
end

endmodule

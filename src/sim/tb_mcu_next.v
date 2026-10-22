`timescale 1ns / 1ps

// The MCU link of the tops (kg_mcu with their parameters, ISim) against the old one (sim/ref: mcu.vhd and
// spi_slave.vhd of the core with the coregen queue / rtc models), the same frames from one MCU model on the SPI
// bus, the replies of each read on its own MISO:
// - INIT_START / DONE, HW_SETUP, the rtc registers 00..3F from the mcu (CMD_RTC), read back on RTC_A / RTC_DO;
// - 600 random frames of KBD, MOUSE, JOY, BTNS: KB_*, MS_X / Y / Z / B, JOY_L / R, BTNS, HWID, DVI_ONLY, BUSY
//   compared after every frame; the mouse through the cursor of the tops (kg_cursor, cursor.vhd of the core before)
//   against a model: one move per report (CMD_MOUSE 03). The old link toggled MS_UPD twice per frame (it decoded a
//   frame on both clocks of do_valid) and cursor.vhd moved twice: printed as "old link:";
// - writes of the core to the rtc registers (ds1307: RTC_A 00..3F, also 0D): the CMD_RTC words to the mcu, in order,
//   and the RAM read back;
// - MATRIX_CMD (Mini G): the words to the mcu;
// - FLASHBOOT_START (the hard reset of the ZX Next, with the core id): the CMD_FLASHBOOT word; the old link put one
//   in its queue in every clock while the start was high (printed as "old link:"), the new one exactly one.
// Errors count the new link against the old one. Ends with "tb_mcu_next: N errors".

module tb_mcu_next;

localparam real T = 35.714; // CLK_28
reg clk = 1'b0;
always #(T / 2) clk = ~clk;

integer errors = 0;
task automatic fail(input [8*80-1:0] what);
	begin
		if (errors < 30) $display("%t ERROR: %0s", $time, what);
		errors = errors + 1;
	end
endtask

reg cs_n = 1'b1, sck = 1'b0, mosi = 1'b0;
wire miso_new, miso_old;

// core side
reg [7:0] rtc_a = 8'h00, rtc_di = 8'h00;
reg rtc_wr = 1'b0;
reg [23:0] matrix_cmd = 24'h0;
reg matrix_cmd_wr = 1'b0;
reg fb_start = 1'b0;
reg [4:0] fb_coreid = 5'd0;

// ---------------- new: as the tops (Mini G: ENABLE_MATRIX) ----------------

wire [7:0] n_kbs, n_kb0, n_kb1, n_kb2, n_kb3, n_kb4, n_kb5, n_msx, n_msy, n_rtc, n_hwid;
wire [3:0] n_msz;
wire [2:0] n_msb;
wire [12:0] n_joyl, n_joyr;
wire [1:0] n_btns;
wire n_msupd, n_dvi, n_busy;

kg_mcu #(
	.BURST_MAX_MHZ(0), .CS_FILTER(3), .ENABLE_RTC(1), .RTC_SKIP_0D(0), .RTC_SEND_LIMIT(256), .ENABLE_UART(0),
	.ENABLE_MATRIX(1), .ENABLE_DEBUG(0), .ENABLE_IMG(0), .ENABLE_FILE(0), .ENABLE_FT(0), .ENABLE_SD2(0),
	.ENABLE_ESP(0), .ENABLE_FLASHBOOT(1)
) new_mcu(
	.CLK(clk), .N_RESET(1'b1),
	.MCU_MOSI(mosi), .MCU_MISO(miso_new), .MCU_SCK(sck), .MCU_SS(cs_n),
	.MCU_SPI_FT_SS(1'b1), .MCU_SPI_SD2_SS(1'b1), .MCU_BURST_CS_N(1'b1), .MCU_BURST_READY(),
	.MS_X(n_msx), .MS_Y(n_msy), .MS_Z(n_msz), .MS_B(n_msb), .MS_UPD(n_msupd),
	.KB_STATUS(n_kbs), .KB_DAT0(n_kb0), .KB_DAT1(n_kb1), .KB_DAT2(n_kb2), .KB_DAT3(n_kb3), .KB_DAT4(n_kb4),
	.KB_DAT5(n_kb5), .JOY_L(n_joyl), .JOY_R(n_joyr), .BTNS(n_btns),
	.RTC_A({2'b00, rtc_a[5:0]}), .RTC_DI(rtc_di), .RTC_DO(n_rtc), .RTC_CS(1'b1), .RTC_WR_N(~rtc_wr),
	.UART_TX_DATA(8'h00), .UART_TX_WR(1'b0), .UART_TX_MODE(1'b0), .UART_DLM(8'h00), .UART_DLL(8'h00),
	.UART_DLM_WR(1'b0), .UART_DLL_WR(1'b0), .FT_MISO(1'b1), .SD2_MISO(1'b1),
	.MATRIX_CMD(matrix_cmd), .MATRIX_CMD_WR(matrix_cmd_wr), .DEBUG_ADDR(16'h0000), .DEBUG_DATA(16'h0000),
	.IMG_Q_WR(1'b0), .IMG_Q_DI(24'h000000), .ESP_UART_RX_DATA(8'h00), .ESP_UART_RX_WR(1'b0),
	.FLASHBOOT_START(fb_start), .FLASHBOOT_COREID(fb_coreid),
	.HWID(n_hwid), .DVI_ONLY(n_dvi), .BUSY(n_busy)
);

// ---------------- old ----------------

wire [7:0] o_kbs, o_kb0, o_kb1, o_kb2, o_kb3, o_kb4, o_kb5, o_msx, o_msy, o_rtc, o_hwid;
wire [3:0] o_msz;
wire [2:0] o_msb;
wire [12:0] o_joyl, o_joyr;
wire [1:0] o_btns;
wire o_msupd, o_dvi, o_busy;

mcu_ref old_mcu(
	.CLK(clk), .N_RESET(1'b1),
	.MCU_MOSI(mosi), .MCU_MISO(miso_old), .MCU_SCK(sck), .MCU_SS(cs_n),
	.MS_X(o_msx), .MS_Y(o_msy), .MS_Z(o_msz), .MS_B(o_msb), .MS_UPD(o_msupd),
	.KB_STATUS(o_kbs), .KB_DAT0(o_kb0), .KB_DAT1(o_kb1), .KB_DAT2(o_kb2), .KB_DAT3(o_kb3), .KB_DAT4(o_kb4),
	.KB_DAT5(o_kb5), .JOY_L(o_joyl), .JOY_R(o_joyr), .BTNS(o_btns),
	.RTC_A({2'b00, rtc_a[5:0]}), .RTC_DI(rtc_di), .RTC_DO(o_rtc), .RTC_CS(1'b1), .RTC_WR_N(~rtc_wr),
	.FLASHBOOT_START(fb_start), .FLASHBOOT_COREID(fb_coreid),
	.SOFTSW_COMMAND(), .ROMLOADER_ACTIVE(), .ROMLOAD_ADDR(), .ROMLOAD_DATA(), .ROMLOAD_WR(), .OSD_COMMAND(),
	.MATRIX_CMD(matrix_cmd), .MATRIX_CMD_WR(matrix_cmd_wr),
	.HWID(o_hwid), .DVI_ONLY(o_dvi), .BUSY(o_busy)
);

// ---------------- the cursors ----------------

wire [7:0] n_cx, n_cy, n_cz, o_cx, o_cy, o_cz;
kg_cursor #(.Z_W(8), .Z_NEG(0), .Z_ACC(1), .Z_SEXT(0)) new_cursor(
	.clk(clk), .ms_x(n_msx), .ms_y(n_msy), .ms_z(n_msz), .ms_b(n_msb), .ms_upd(n_msupd),
	.x(n_cx), .y(n_cy), .z(n_cz), .b()
);
cursor_ref old_cursor(
	.CLK(clk), .RESET(1'b0), .MS_X(o_msx), .MS_Y(o_msy), .MS_Z(o_msz), .MS_B(o_msb), .MS_UPD(o_msupd),
	.OUT_X(o_cx), .OUT_Y(o_cy), .OUT_Z(o_cz), .OUT_B()
);

// ---------------- mcu model: 16 MHz SPI mode 0 ----------------

reg [23:0] q_new [0:4095], q_old [0:4095];
integer n_new = 0, n_old = 0, rd_new = 0, rd_old = 0;
integer fb_old = 0;

task automatic spi_byte(input [7:0] tx, output [7:0] rn, output [7:0] ro);
	integer k;
	begin
		for (k = 7; k >= 0; k = k - 1) begin
			mosi = tx[k];
			#31;
			sck = 1'b1;
			rn[k] = miso_new;
			ro[k] = miso_old;
			#31;
			sck = 1'b0;
		end
	end
endtask

// a frame; the reply words that are not NOPE go to the queues (the old link puts the flashboot words aside)
task automatic frame(input [7:0] c, input [7:0] a, input [7:0] d);
	reg [7:0] nc, na, nd, oc, oa, od;
	begin
		cs_n = 1'b0;
		#100;
		spi_byte(c, nc, oc);
		spi_byte(a, na, oa);
		spi_byte(d, nd, od);
		#50;
		cs_n = 1'b1;
		#500;
		if (nc !== 8'hFF) begin q_new[n_new] = {nc, na, nd}; n_new = n_new + 1; end
		if (oc === 8'hFB) fb_old = fb_old + 1;
		else if (oc !== 8'hFF) begin q_old[n_old] = {oc, oa, od}; n_old = n_old + 1; end
	end
endtask

task automatic poll(input integer n);
	integer k;
	begin
		for (k = 0; k < n; k = k + 1) frame(8'hFF, 8'h00, 8'h00);
	end
endtask

// the reply words of both since the last check: the same, in order
task automatic check_replies(input [8*40-1:0] what);
	begin
		while (rd_new < n_new || rd_old < n_old) begin
			if (rd_new >= n_new) begin
				$display("%t ERROR: %0s: old %h, new none", $time, what, q_old[rd_old]); errors = errors + 1;
				rd_old = rd_old + 1;
			end
			else if (rd_old >= n_old) begin
				$display("%t ERROR: %0s: new %h, old none", $time, what, q_new[rd_new]); errors = errors + 1;
				rd_new = rd_new + 1;
			end
			else begin
				if (q_new[rd_new] !== q_old[rd_old]) begin
					$display("%t ERROR: %0s: new %h, old %h", $time, what, q_new[rd_new], q_old[rd_old]);
					errors = errors + 1;
				end
				rd_new = rd_new + 1;
				rd_old = rd_old + 1;
			end
		end
	end
endtask

task automatic check_outputs;
	begin
		if ({n_kbs, n_kb0, n_kb1, n_kb2, n_kb3, n_kb4, n_kb5} !== {o_kbs, o_kb0, o_kb1, o_kb2, o_kb3, o_kb4, o_kb5})
			fail("KB_*");
		if ({n_msx, n_msy, n_msz, n_msb} !== {o_msx, o_msy, o_msz, o_msb}) fail("MS_X / Y / Z / B");
		if ({n_joyl, n_joyr} !== {o_joyl, o_joyr}) fail("JOY_L / JOY_R");
		if (n_btns !== o_btns) fail("BTNS");
		if ({n_hwid, n_dvi, n_busy} !== {o_hwid, o_dvi, o_busy}) begin
			$display("%t ERROR: HWID / DVI_ONLY / BUSY: new %h %b %b, old %h %b %b", $time, n_hwid, n_dvi, n_busy,
				o_hwid, o_dvi, o_busy);
			errors = errors + 1;
		end
	end
endtask

integer tg_new = 0, tg_old = 0;
reg p_new = 1'b0, p_old = 1'b0;
always @(posedge clk) begin
	if (n_msupd !== p_new) tg_new = tg_new + 1;
	if (o_msupd !== p_old && o_msupd !== 1'bx && p_old !== 1'bx) tg_old = tg_old + 1;
	p_new = n_msupd;
	p_old = o_msupd;
end

task automatic rtc_read_check(input [5:0] a);
	begin
		@(negedge clk); rtc_a = {2'b00, a};
		@(negedge clk); @(negedge clk);
		if (n_rtc !== o_rtc) begin
			$display("%t ERROR: rtc %h: new %h, old %h", $time, a, n_rtc, o_rtc); errors = errors + 1;
		end
	end
endtask

task automatic host_rtc_write(input [5:0] a, input [7:0] d);
	begin
		@(negedge clk); rtc_a = {2'b00, a}; rtc_di = d; rtc_wr = 1'b1;
		@(negedge clk); rtc_wr = 1'b0;
	end
endtask

integer i, k, r, tg_n0, tg_o0, n_ms3 = 0;
reg [7:0] mx = 8'h7F, my = 8'h7F, mz = 8'h7F, ox0, oy0, mx0, my0;
reg [7:0] c, a, d;
initial begin
	#2000;
	poll(8);
	rd_new = n_new; rd_old = n_old;

	// ---- init: INIT_START, HW_SETUP, the rtc registers, INIT_DONE ----
	frame(8'hFD, 8'h00, 8'h00);
	check_outputs;
	frame(8'hF9, 8'h00, 8'h02);
	frame(8'hF9, 8'h01, 8'h01);
	for (i = 0; i < 64; i = i + 1) frame(8'hFA, i, (i * 37 + 5) & 8'hFF);
	frame(8'hFE, 8'h00, 8'h00);
	check_outputs;
	for (i = 0; i < 64; i = i + 1) rtc_read_check(i);
	poll(6);
	check_replies("init");

	// ---- random input frames ----
	tg_n0 = tg_new; tg_o0 = tg_old;
	for (i = 0; i < 600; i = i + 1) begin
		r = {$random} % 4;
		c = r + 1;               // 01 KBD, 02 MOUSE, 03 JOY, 04 BTNS
		a = (r == 0) ? {$random} % 7 : (r == 3) ? {$random} % 2 : {$random} % 4;
		d = $random;
		frame(c, a, d);
		check_outputs;
		if (c == 8'h02 && a == 8'h03) begin
			n_ms3 = n_ms3 + 1;
			mx = mx + n_msx; my = my - n_msy; mz = mz + {4'h0, n_msz};
			if ({n_cx, n_cy, n_cz} !== {mx, my, mz}) begin
				$display("%t ERROR: cursor %h %h %h, expected %h %h %h", $time, n_cx, n_cy, n_cz, mx, my, mz);
				errors = errors + 1;
			end
		end
	end
	if (tg_new - tg_n0 != n_ms3) begin
		$display("%t ERROR: MS_UPD toggles %0d, %0d reports", $time, tg_new - tg_n0, n_ms3);
		errors = errors + 1;
	end
	$display("old link: MS_UPD toggled %0d times for %0d mouse reports", tg_old - tg_o0, n_ms3);
	// the same moves once more: the old cursor moves twice as far
	ox0 = o_cx; oy0 = o_cy; mx0 = n_cx; my0 = n_cy;
	frame(8'h02, 8'h00, 8'h05); frame(8'h02, 8'h01, 8'h03); frame(8'h02, 8'h02, 8'h00); frame(8'h02, 8'h03, 8'h00);
	$display("old link: a report of x +5, y +3 moved the old cursor by %0d, %0d (the new one by %0d, %0d)",
		$signed(o_cx - ox0), $signed(oy0 - o_cy), $signed(n_cx - mx0), $signed(my0 - n_cy));
	if (n_cx - mx0 !== 8'd5 || my0 - n_cy !== 8'd3) fail("cursor: a report of +5, +3");
	poll(6);
	check_replies("input frames");

	// ---- writes of the core to the rtc registers ----
	for (i = 0; i < 16; i = i + 1) begin
		host_rtc_write(i * 4 + 1, 8'hA0 + i);
		repeat (40) @(negedge clk);
	end
	host_rtc_write(6'h0D, 8'h80);
	repeat (40) @(negedge clk);
	poll(24);
	check_replies("rtc writes");
	for (i = 0; i < 64; i = i + 1) rtc_read_check(i);

	// ---- matrix words ----
	for (i = 0; i < 8; i = i + 1) begin
		@(negedge clk); matrix_cmd = {8'h70, i[7:0], 8'h55}; matrix_cmd_wr = 1'b1;
		@(negedge clk); matrix_cmd_wr = 1'b0;
		repeat (20) @(negedge clk);
	end
	poll(16);
	check_replies("matrix");

	// ---- flashboot ----
	fb_old = 0;
	@(negedge clk); fb_coreid = 5'd1; fb_start = 1'b1;
	repeat (100) @(negedge clk);
	poll(20);
	if (n_new - rd_new != 1 || q_new[rd_new] !== 24'hFB_00_01) begin
		$display("%t ERROR: flashboot: %0d words, the first %h", $time, n_new - rd_new, q_new[rd_new]);
		errors = errors + 1;
	end
	rd_new = n_new;
	$display("old link: %0d CMD_FLASHBOOT words in 20 frames (one per clock in its queue while the start is high)",
		fb_old);
	if (fb_old == 0) fail("old link sent no flashboot word (the test does not test)");

	$display("tb_mcu_next: %0d errors", errors);
	$finish;
end

initial begin
	#300000000;
	$display("ERROR: timeout");
	$display("tb_mcu_next: 1 errors");
	$finish;
end

endmodule

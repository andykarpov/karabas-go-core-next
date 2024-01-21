//------------------------------------------------------------
// Firefly FDC Top Level
//------------------------------------------------------------
// Grabbed from original project Firefly by IanPo (c) 2020-2023
// Refactored by Andy Karpov (c) 2024
`default_nettype none

module firefly_fdc (
	// clocks
	input wire          clk,
	input wire         clk_16,
	input wire         reset,

	// cpu signals
	input	wire [15:0] 	a,
	input	wire [7:0]		d,
	input	wire			m1_n,
	input	wire			wr_n,
	input	wire			rd_n,
	input	wire			iorq_n,

	// decoded ports
	input wire          cs_n,
	input wire          csff_n,

	// controller output signals
	output wire         oe_n,
	output wire [7:0]   dout,

	// physical floppy signals
	output wire			FDC_SIDE1,
	input	wire			FDC_RDATA,
	input	wire			FDC_WPRT,
	input	wire			FDC_TR00,
	input	wire			FDC_INDEX,
	output wire			FDC_WG,
	output wire			FDC_WR_DATA,
	output wire			FDC_STEP,
	output wire			FDC_DIR,
	output wire			FDC_MOTOR,
	output wire	[1:0]	FDC_DS
);

reg	[4:0]		r_bdi_ff;
reg				r_drq_r_dreg, r_intrq_r_sreg, r_bdi_drq, r_bdi_drq0, r_bdi_intrq, r_bdi_intrq0;
wire				ior, vfoe, wg, rawr, rclk, sync, start, byte_2_read, byte_2_write, translate, reset_crc, vg_reset_n, tr43, next_byte;

wire	[3:0]		ip_cnt;
wire 	[47:0]	words;
wire	[7:0]		byte_2_main;
wire	[7:0]		main_2_byte;
wire	[10:0]	byte_cnt;
wire	[15:0]	crc16_d8;

wire	[7:0]		bdi_do;
wire				bdi_drq, bdi_intrq, bdi_wr_en;
wire 				motor;
reg  [7:0]		outdata;
reg 				vg_req;

/////////////////////////////////////////////////////////////////

assign FDC_SIDE1 = !r_bdi_ff[4];
assign FDC_DS[0] = motor & (r_bdi_ff[1:0] == 2'b00);
assign FDC_DS[1] = motor & (r_bdi_ff[1:0] == 2'b01);
assign FDC_MOTOR = motor;
assign FDC_WG = wg;

assign ior = iorq_n | rd_n;

assign bdi_wr_en = ~( cs_n | wr_n );
assign vg_reset_n = r_bdi_ff[2];

// bdi_drq, bdi_intrq crossing clock domain
always @( posedge clk )
begin
	r_bdi_drq0 <= bdi_drq;
	r_bdi_drq <= r_bdi_drq0;
	
	r_bdi_intrq0 <= bdi_intrq;
	r_bdi_intrq <= r_bdi_intrq0;
end

// bdi status register
always @(posedge clk)
	if (~vg_reset_n)
		r_intrq_r_sreg <= 1'b0;
	else
		if (~r_intrq_r_sreg)
			if ( (~ior) && (~cs_n) && (a[6:5] == 2'b00) )	//    BDI (STATUS register)
				r_intrq_r_sreg <= 1'b1;
			else	;
		else
			if ( ~r_bdi_intrq )
				r_intrq_r_sreg <= 1'b0;

// bdi data register
always @( posedge clk )
	if (~vg_reset_n)
		r_drq_r_dreg <= 1'b0;
	else
		if (~r_drq_r_dreg)
			if (  (~( iorq_n | ( wr_n & rd_n ) )) && (~cs_n ) && (a[6:5] == 2'b11) )	// -   BDI (DATA register)
				r_drq_r_dreg <= 1'b1;
			else	;
		else
			if ( ~r_bdi_drq )
				r_drq_r_dreg <= 1'b0;

// output data
always @( vg_reset_n, bdi_intrq, bdi_drq, bdi_do, ior, csff_n, cs_n )     
	if ( (ior == 1'b1) )
	begin
		outdata = 8'hFF;
		vg_req = 1'b0;
	end
	else
	begin
		if (~csff_n)
		begin
			outdata = { bdi_intrq, bdi_drq, 6'b111111 };
			vg_req = 1'b1;
		end
		else if ( (~cs_n) ) begin
			outdata = bdi_do;
			vg_req = 1'b1;
		end
		else 
			vg_req = 1'b0;
	end

// data output
assign dout = outdata;
assign oe_n = ~vg_req;

// port ff
always @( posedge clk )	//    #FF (TR-DOS)
	if ( reset )
		r_bdi_ff <= 5'b0;
	else if ( (~csff_n) & (~wr_n) & (~iorq_n) ) 
		r_bdi_ff <= d[4:0];
	
Main_CTRL U14 (
	.iCLK ( clk_16 ),
	.iRESETn ( vg_reset_n ),
	.iWR_EN ( bdi_wr_en ),
	.iADR ( a[6:5] ),
	.iDATA ( d ),
	.oDATA ( bdi_do ),
//
	.oSTEP ( FDC_STEP ),
	.oDIRC ( FDC_DIR ),
	.oHLD ( motor ),
	.iHRDY ( r_bdi_ff[3] ),
	.iTR00 ( FDC_TR00 ),
	.iIP ( FDC_INDEX ),
	.iWRPT ( FDC_WPRT ),
	.oWG ( wg ),
	.oDRQ ( bdi_drq ),
	.oINTRQ ( bdi_intrq ),
//
	.iSYNC			( sync ),
	.iBYTE_CNT		( byte_cnt ),
	.iCRC16_D8		( crc16_d8 ),
	.oRESET_CRC		( reset_crc ),
	.oVFOE			( vfoe ),
	.oIP_CNT		( ip_cnt ),
	.iBYTE_2_MAIN	( byte_2_main ),
	.iBYTE_2_READ	( byte_2_read ),
	.oMAIN_2_BYTE	( main_2_byte ),
	.oBYTE_2_WRITE	( byte_2_write ),
	.oTRANSLATE		( translate ),
	.iNEXT_BYTE		( next_byte ),
//
	.iDRQ_R_DREG	( r_drq_r_dreg ),			//  DRQ     
	.i2RQ_R_SREG	( r_intrq_r_sreg )		//  INTRQ  DRQ    
);

DPLL U15 (
	.iCLK	( clk_16 ),
	.iRDDT	( FDC_RDATA ),
	.oRCLK	( rclk ),
	.oRAWR	( rawr ),
	.iVFOE	( vfoe )
);

AMD U16 (
	.iCLK		( clk_16 ),
	.iRCLK		( rclk ),
	.iRAWR		( rawr ),
	.iVFOE		( vfoe ),
	.iIP_CNT	( ip_cnt ),
	.o3WORDS	( words ),
	.oSTART		( start ),
	.oSYNC		( sync )
);

MFMDEC U17 (
	.iCLK			( clk_16 ),
	.iRCLK			( rclk ),
	.iVFOE			( vfoe ),
	.iSTART			( start ),
	.iSYNC			( sync ),
	.i3WORDS		( words ),
	.oBYTE_2_MAIN	( byte_2_main ),
	.oBYTE_2_READ	( byte_2_read )
);

CRC16_D8 U19 (
	.iCLK			( clk_16 ),
	.iRESET_CRC		( reset_crc ),
	.iBYTE_2_MAIN	( byte_2_main ),
	.iMAIN_2_BYTE	( main_2_byte ),
	.iBYTE_2_READ	( byte_2_read ),
	.iBYTE_2_WRITE	( byte_2_write ),
	.oBYTE_CNT		( byte_cnt ),
	.oCRC16_D8		( crc16_d8 )
);

MFMCDR U20 (
	.iCLK			( clk_16 ),
	.iRESETn		( vg_reset_n ),
	.iWG			( wg ),
	.iMAIN_2_BYTE	( main_2_byte ),
	.iBYTE_2_WRITE	( byte_2_write ),
	.iTRANSLATE		( translate ),
	.oNEXT_BYTE		( next_byte ),
	.oWDATA			( FDC_WR_DATA )
);

endmodule

//`define USE_EDGEDETECT_IP

`timescale 1ns / 10ps

`ifdef USE_EDGEDETECT_IP
module USER_PRJ2 #(
    parameter pUSER_PROJECT_SIDEBAND_WIDTH   = 5,
    parameter pADDR_WIDTH   = 12,
    parameter pDATA_WIDTH   = 32
)
(
  output wire                        awready,
  output wire                        arready,
  output wire                        wready,
  output wire                        rvalid,
  output wire  [(pDATA_WIDTH-1) : 0] rdata,
  input  wire                        awvalid,
  input  wire                [11: 0] awaddr,
  input  wire                        arvalid,
  input  wire                [11: 0] araddr,
  input  wire                        wvalid,
  input  wire                 [3: 0] wstrb,
  input  wire  [(pDATA_WIDTH-1) : 0] wdata,
  input  wire                        rready,
  input  wire                        ss_tvalid,
  input  wire  [(pDATA_WIDTH-1) : 0] ss_tdata,
  input  wire                 [1: 0] ss_tuser,
  `ifdef USER_PROJECT_SIDEBAND_SUPPORT
    input  wire  [pUSER_PROJECT_SIDEBAND_WIDTH-1: 0] ss_tupsb,
  `endif
  input  wire                 [3: 0] ss_tstrb,
  input  wire                 [3: 0] ss_tkeep,
  input  wire                        ss_tlast,
  input  wire                        sm_tready,
  output wire                        ss_tready,
  output wire                        sm_tvalid,
  output wire  [(pDATA_WIDTH-1) : 0] sm_tdata,
  output wire                 [2: 0] sm_tid,
  `ifdef USER_PROJECT_SIDEBAND_SUPPORT
    output  wire [pUSER_PROJECT_SIDEBAND_WIDTH-1: 0] sm_tupsb,
  `endif
  output wire                 [3: 0] sm_tstrb,
  output wire                 [3: 0] sm_tkeep,
  output wire                        sm_tlast,
  output wire                        low__pri_irq,
  output wire                        High_pri_req,
  output wire                [23: 0] la_data_o,
  input  wire                        axi_clk,
  input  wire                        axis_clk,
  input  wire                        axi_reset_n,
  input  wire                        axis_rst_n,
  input  wire                        user_clock2,
  input  wire                        uck2_rst_n
);

//[TODO] does tlast from FPGA to SOC need send to UP? or use upsb as UP's tlast?
`ifdef USER_PROJECT_SIDEBAND_SUPPORT
	localparam	FIFO_WIDTH = (pUSER_PROJECT_SIDEBAND_WIDTH + 4 + 4 + 1 + pDATA_WIDTH);		//upsb, tstrb, tkeep, tlast, tdata  
`else
	localparam	FIFO_WIDTH = (4 + 4 + 1 + pDATA_WIDTH);		//tstrb, tkeep, tlast, tdata
`endif

`ifdef USER_PROJECT_SIDEBAND_SUPPORT
    wire [33:0] dat_in_rsc_dat = {ss_tupsb[1:0], ss_tdata[31:0]};
`else
    wire [33:0] dat_in_rsc_dat = {2'b00,         ss_tdata[31:0]};
`endif

wire [33:0] dat_out_rsc_dat;

wire        ram0_en;
wire [63:0] ram0_q;
wire        ram0_we;
wire [63:0] ram0_d;
wire [6:0]  ram0_adr;
wire        ram1_en;
wire [63:0] ram1_q;
wire        ram1_we;
wire [63:0] ram1_d;
wire [6:0]  ram1_adr;


reg  [9:0]  reg_widthIn;
reg  [8:0]  reg_heightIn;
reg         reg_sw_in;
reg         reg_rst;
wire [31:0] crc32_stream_in;
wire [31:0] crc32_stream_out;
wire        edgedetect_done;
reg  [31:0] crc32_hw_pix_zin;
reg  [31:0] crc32_hw_dat_zin;
reg  [31:0] reg_crc32_stream_in;
reg  [31:0] reg_crc32_stream_out;
reg         reg_edgedetect_done;
reg         crc32_lzout;
reg      	  IP_en;
reg         reg_crc32_stream_in_en;

wire awvalid_in;
wire wvalid_in;

reg [31:0] RegisterData;
reg        eol;

//write addr channel
assign 	awvalid_in	= awvalid; 
wire awready_out;
assign awready = awready_out;

//write data channel
assign 	wvalid_in	= wvalid;
wire wready_out;
assign wready = wready_out;

// if both awvalid_in=1 and wvalid_in=1 then output awready_out = 1 and wready_out = 1
assign awready_out = (awvalid_in && wvalid_in) ? 1 : 0;
assign wready_out = (awvalid_in && wvalid_in) ? 1 : 0;

always @(posedge axi_clk or negedge axi_reset_n) begin
  if (!axi_reset_n) begin
    eol <= 0;
  end
  else begin
    eol <= dat_out_rsc_dat[33];
  end
end

//write register
always @(posedge axi_clk or negedge axi_reset_n)  begin
  if ( !axi_reset_n ) begin
    reg_widthIn         <= 640;
    reg_heightIn        <= 360;
    reg_sw_in           <= 1;
    reg_rst             <= 0;
  end else begin
    if ( awvalid_in && wvalid_in ) begin		//when awvalid_in=1 and wvalid_in=1 means awready_out=1 and wready_out=1
      if (awaddr[11:2] == 10'h000 ) begin //offset 0
        if ( wstrb[0] == 1) reg_rst           <= wdata[0];
      end
      else if (awaddr[11:2] == 10'h001 ) begin //offset 1
        if ( wstrb[0] == 1) reg_widthIn[7:0]  <= wdata[7:0];
        if ( wstrb[1] == 1) reg_widthIn[9:8]  <= wdata[9:8];
      end
      else if (awaddr[11:2] == 10'h002 ) begin //offset 2
        if ( wstrb[0] == 1) reg_heightIn[7:0] <= wdata[7:0];
        if ( wstrb[1] == 1) reg_heightIn[8]   <= wdata[8];
      end
      else if (awaddr[11:2] == 10'h003 ) begin //offset 3
        if ( wstrb[0] == 1) reg_sw_in         <= wdata[0];
      end
    end
  end
end

always @(posedge axi_clk or negedge axi_reset_n)  begin
  if ( !axi_reset_n ) begin
      reg_edgedetect_done <= 0;
  end
  else begin
    if (edgedetect_done) begin
      reg_edgedetect_done <= 1;
    end
    else if (awaddr[11:2] == 10'h006 ) begin //offset 6
      if ( wstrb[0] == 1) reg_edgedetect_done <= 0;
    end
  end
end

//read register
reg [(pDATA_WIDTH-1) : 0] rdata_tmp;
assign arready = 1; // ?
assign rvalid  = 1; // ?
assign rdata =  rdata_tmp;

always @* begin
  if      (araddr[11:2] == 10'h000) rdata_tmp = reg_rst;
  else if (araddr[11:2] == 10'h001) rdata_tmp = reg_widthIn;
  else if (araddr[11:2] == 10'h002) rdata_tmp = reg_heightIn;
  else if (araddr[11:2] == 10'h003) rdata_tmp = reg_sw_in;
  else if (araddr[11:2] == 10'h004) rdata_tmp = reg_crc32_stream_in;
  else if (araddr[11:2] == 10'h005) rdata_tmp = reg_crc32_stream_out;
  else if (araddr[11:2] == 10'h006) rdata_tmp = reg_edgedetect_done;
  else                              rdata_tmp = 0;
end

//DUT
assign sm_tdata = dat_out_rsc_dat[31: 0]; 

`ifdef USER_PROJECT_SIDEBAND_SUPPORT
    assign sm_tupsb = {eol, dat_out_rsc_dat[32]};
`endif

assign {sm_tstrb, sm_tkeep} = 0;

assign sm_tlast = eol;

wire dat_in_rsc_rdy;

assign ss_tready = dat_in_rsc_rdy;

always @(posedge axi_clk or negedge axi_reset_n) begin
	if (!axi_reset_n) begin
		IP_en <= 2'b0;
	end
	else if (IP_en == 1'b1) begin
		IP_en <= IP_en;
	end
	else if (crc32_lzout == 1'b1) begin
		IP_en <= 1'b1;
	end
end

always @(posedge axi_clk or negedge axi_reset_n) begin
	if (!axi_reset_n) begin
		crc32_hw_pix_zin <= 32'hffff_ffff;
		crc32_hw_dat_zin <= 32'hffff_ffff;
	end
	else if (crc32_lzout && IP_en)begin
		crc32_hw_pix_zin <= crc32_stream_in;
		crc32_hw_dat_zin <= crc32_stream_out;
	end
end

always @(posedge axi_clk) begin
    if (eol) 
      reg_crc32_stream_in_en <= 1'b1;
    else
      reg_crc32_stream_in_en <= 1'b0;
end

always @(posedge axi_clk or negedge axi_reset_n)  begin
  if ( !axi_reset_n ) begin
    reg_crc32_stream_in  <= 0;
    reg_crc32_stream_out <= 0;
  end else if (reg_crc32_stream_in_en) begin
    reg_crc32_stream_in  <= crc32_stream_in ;
    reg_crc32_stream_out <= crc32_stream_out;
  end
end

EdgeDetect_IP_EdgeDetect_Top U_EdgeDetect (
.clk                        (axi_clk           ), //user_clock2 ?
.rst                        (reg_rst           ), 
.arst_n                     (axi_reset_n       ), //~uck2_rst_n ? 
.widthIn                    (reg_widthIn       ), //I 
.heightIn                   (reg_heightIn      ), //I
.sw_in_rsc_dat              (reg_sw_in         ), //I
.crc32_hw_pix_in_rsc_zin    (crc32_hw_pix_zin  ), //I
.crc32_hw_pix_in_rsc_zout   (crc32_stream_in   ), //O
.crc32_hw_pix_in_rsc_lzout  (crc32_lzout       ), //O
.crc32_hw_dat_out_rsc_zin   (crc32_hw_dat_zin  ), //I
.crc32_hw_dat_out_rsc_zout  (crc32_stream_out  ), //O
.crc32_hw_dat_out_triosy_lz (edgedetect_done   ), //O
.dat_in_rsc_dat             (dat_in_rsc_dat    ), //I
.dat_in_rsc_vld             (ss_tvalid         ), //I
.dat_in_rsc_rdy             (dat_in_rsc_rdy    ), //O
.dat_out_rsc_dat            (dat_out_rsc_dat   ), //O
.dat_out_rsc_vld            (sm_tvalid         ), //O
.dat_out_rsc_rdy            (sm_tready         ), //I
.line_buf0_rsc_en           (ram0_en           ), //O
.line_buf0_rsc_q            (ram0_q            ), //I
.line_buf0_rsc_we           (ram0_we           ), //O
.line_buf0_rsc_d            (ram0_d            ), //O
.line_buf0_rsc_adr          (ram0_adr          ), //O
.line_buf1_rsc_en           (ram1_en           ), //O
.line_buf1_rsc_q            (ram1_q            ), //I 
.line_buf1_rsc_we           (ram1_we           ), //O 
.line_buf1_rsc_d            (ram1_d            ), //O 
.line_buf1_rsc_adr          (ram1_adr          )  //O
);

//SRAM
SPRAM #(.data_width(64),.addr_width(7),.depth(80)) U_SPRAM_0(
.adr (ram0_adr ), 
.d   (ram0_d   ), 
.en  (ram0_en  ), 
.we  (ram0_we  ), 
.clk (axi_clk  ), //user_clock2 ? 
.q   (ram0_q   )
);

SPRAM #(.data_width(64),.addr_width(7),.depth(80)) U_SPRAM_1(
.adr (ram1_adr ), 
.d   (ram1_d   ), 
.en  (ram1_en  ), 
.we  (ram1_we  ), 
.clk (axi_clk  ), //user_clock2 ? 
.q   (ram1_q   )
);
//~

endmodule
`endif
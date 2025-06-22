// vendor-independent top module
module galaksija
(
    input clk, // 12 MHz (now 25 MHz)
    input pixclk, // 19.2 MHz (now 25 MHz)
    input reset_n, // 1 when clocks are ready to be used
    input ser_rx, // serial keyboard
    output flash_csn,
    output flash_holdn,
    output flash_wpn,
    output flash_clk,
    output flash_mosi,
    input  flash_miso,
    input  ps2clk,
    input  ps2data,
    output [7:0] LCD_DAT,
    output LCD_CLK,
    output LCD_HS,
    output LCD_VS,
    output LCD_DEN,
    output LCD_RST,
    output LCD_PWM,
    output mreq_n
);

parameter integer f_clk = 25000000;
parameter integer baud = 115200; // serial keyboard baud rate

/* ------------------------
       Clock generator 
   ------------------------*/

wire clk;
wire reset_n;
wire pixclk;

reg [6:0] reset_cnt = 0;

assign cpu_resetn = reset_cnt[6];

always @(posedge clk) begin
  if(reset_n == 0)
    reset_cnt <= 0;
  else
   if(cpu_resetn == 0)
    reset_cnt <= reset_cnt + 1;
end

// CPU output lines
wire [15:0] addr;
wire [7:0] odata;

reg rd_ram;
reg wr_ram;
wire [7:0] ram_out;

/* ----------------------------
       Video signal generator 
   ----------------------------*/

reg rd_video;
reg wr_video;

assign LCD_CLK = pixclk;
assign LCD_RST = 1'b1;
assign LCD_PWM = 1'b1;

/* ----------------------------
       Custom video generator 
   ----------------------------*/

// video has internal 2K RAM
// it is currently write-only
// read is from main 64K RAM
video
 #(
  .h_visible(10'd640),
  .h_front(10'd16),
  .h_sync(10'd96),
  .h_back(10'd48),
  .v_visible(10'd480),
  .v_front(10'd10),
  .v_sync(10'd2),
  .v_back(10'd33)
 )
 generator
 (
  .clk(pixclk), // pixel clock 25 MHz
  .resetn(reset_n),
  .lcd_dat(LCD_DAT),
  .lcd_hsync(LCD_HS),
  .lcd_vsync(LCD_VS),
  .lcd_den(LCD_DEN),
  .rd_ram1(1'b0),
  .wr_ram1(wr_video),
  //.ram1_out(ram1_out),
  .addr(addr[10:0]),
  .data(odata)
 );

	reg ce = 0;
	reg [7:0] idata; // CPU input

	wire m1_n;
	wire mreq_n;
	wire iorq_n;
	wire rd_n;
	wire wr_n;
	wire rfsh_n;
	wire halt_n;
	wire busak_n;
	wire wait_n = 1'b1;
	reg int_n = 1'b1;
	wire nmi_n = 1'b1;
	wire busrq_n = 1'b1;
		
	reg [5:0] latch; // U8 74HCT174

	reg[31:0] int_cnt = 0;

	always @(posedge clk) begin
		if (int_cnt==(f_clk / (50 * 2)))
		begin
			int_n <= 1'b0;		
			int_cnt <= 0;
		end
		else
		begin
			int_n <= 1'b1;		
			int_cnt <= int_cnt + 1;
		end
	end

	wire key_bit;
	
	reg rd_key;
	reg wr_latch;

	always @(*)
	begin
		rd_video = 0;
		rd_ram = 0;

		wr_video = 0;
		wr_ram = 0;

		rd_key = 0;

		wr_latch = 0;
		idata = 8'hff;
		casex ({~wr_n,~rd_n,mreq_n,addr[15:0]})
			// MEM MAP
			{3'b010,16'h0xxx}: begin idata = ram_out; rd_ram = 1; end // 0x0000-0x0fff
			{3'b010,16'h1xxx}: begin idata = ram_out; rd_ram = 1; end // 0x1000-0x1fff

			{3'b010,4'h2,12'b0xxxxxxxxxxx}: begin idata[0] = key_bit; rd_key = 1; end // 0x2000-0x27ff (keys, flash_miso, serial_rx)
			{3'b010,4'h2,12'b1xxxxxxxxxxx}: begin idata = ram_out; rd_ram = 1; end // 0x2800-0x2fff
			{3'b010,4'h3,12'b0xxxxxxxxxxx}: begin idata = ram_out; rd_ram = 1; end // 0x3000-0x37ff
			{3'b010,4'h3,12'b1xxxxxxxxxxx}: begin idata = ram_out; rd_ram = 1; end // 0x3800-0x3fff
			{3'b010,16'b01xxxxxxxxxxxxxx}: begin idata = ram_out; rd_ram = 1; end // 0x4000-0x7fff
			{3'b010,16'b1xxxxxxxxxxxxxxx}: begin idata = ram_out; rd_ram = 1; end // 0x8000-0xffff

			{3'b100,12'h203,4'b1xxx}: wr_latch = 1; // 0x2038-0x203f
			{3'b100,16'b00101xxxxxxxxxxx}: begin wr_video = 1; wr_ram = 1; end // 0x2800-0x2fff
			{3'b100,16'b00110xxxxxxxxxxx}: wr_ram   = 1; // 0x3000-0x37ff
			{3'b100,16'b00111xxxxxxxxxxx}: wr_ram   = 1; // 0x3800-0x3fff
			{3'b100,16'b01xxxxxxxxxxxxxx}: wr_ram   = 1; // 0x4000-0x7fff
			{3'b100,16'b100xxxxxxxxxxxxx}: wr_ram   = 1; // 0x8000-0x9fff
			//{3'b100,16'b101xxxxxxxxxxxxx}: wr_ram   = 1; // 0xA000-0xbfff
			//{3'b100,16'b11xxxxxxxxxxxxxx}: wr_ram   = 1; // 0xC000-0xffff
		endcase
	end
	
	always @(posedge clk)
	begin
		if(wr_latch)
			latch[5:0] <= odata[7:2];
	end

	assign flash_mosi  = latch[1];
	assign flash_clk   = latch[2];
	assign flash_wpn   = latch[3];
	assign flash_csn   = ~(latch[4] & reset_n); // 1/4 74HC00 pins 11-13
	assign flash_holdn = 1'b1;

	tv80n cpu (
		.m1_n(m1_n), .mreq_n(mreq_n), .iorq_n(iorq_n), 
		.rd_n(rd_n), .wr_n(wr_n), .rfsh_n(rfsh_n), .halt_n(halt_n), .busak_n(busak_n),
		.A(addr), .do(odata), 
		.reset_n(cpu_resetn), .clk(clk), .wait_n(wait_n), .int_n(int_n), .nmi_n(nmi_n), .busrq_n(busrq_n), .di(idata)
	);

        wire [10:0] ps2_key;

        // Get PS/2 keyboard events
        ps2 ps2_inst (
                .clk(clk),
                .ps2_clk(ps2clk),
                .ps2_data(ps2data),
                .ps2_key(ps2_key)
        );

        galaksija_keyboard galaksija_keyboard_inst (
                .clk(clk),
                .addr(addr[5:0]),
                .ps2_key(ps2_key),
                .key_out(key_bit)
        );

// 64K RAM initialized with ROM content
bram_true2p_2clk
 #(
    .dual_port(0),
    .data_width(8),
    .addr_width(16),
    .initial_filename("galaksija2024.mem")
    //.initial_filename("galaksija.mem")
 )
 ram64k
 (
   .clk_a(clk),
   .addr_a(addr[15:0]),
   .we_a(wr_ram),
   .data_in_a(odata),
   .data_out_a(ram_out)
 );

endmodule

//--------------------------
// ULX3S Top level for GALAKSIJA
// http://github.com/emard
//--------------------------
// vendor specific library for clock, ddr and differential video out

module galaksija_ulx3s(
input wire clk_25mhz,
output wire ftdi_rxd,
input wire ftdi_txd,
input  wire flash_miso,
output wire flash_mosi,
// output wire flash_clk, // USRMCLK
output wire flash_csn,
output wire flash_holdn,
output wire flash_wpn,
output wire [7:0] led,
input wire [6:0] btn,
input wire [3:0] sw,
inout wire [27:0] gp,
inout wire [27:0] gn,
inout wire [3:0] audio_l,
inout wire [3:0] audio_r,
inout wire [3:0] audio_v,
output wire [3:0] gpdi_dp,
output wire [3:0] gpdi_dn,
output wire usb_fpga_pu_dp,
output wire usb_fpga_pu_dn,
input wire usb_fpga_dp,
input wire usb_fpga_dn
);

localparam C_ddr = 1'b1; // 1-DDR 0-SDR

reg reset_n;
wire clk_pixel, clk_pixel_shift, clk_pixel_shift1, clk_pixel_shift2, locked;
wire [7:0] S_LCD_DAT;
wire [2:0] S_vga_r; wire [2:0] S_vga_g; wire [2:0] S_vga_b;
wire S_vga_vsync; wire S_vga_hsync;
wire S_vga_vblank; wire S_vga_blank;
wire [2:0] ddr_d;
wire ddr_clk;
wire [1:0] dvid_red; wire [1:0] dvid_green; wire [1:0] dvid_blue; wire [1:0] dvid_clock;
wire [17:0] audio_data;
wire [23:0] S_audio = 1'b0;
wire S_spdif_out;

  // PS2 keyboard requires pullups
  assign usb_fpga_pu_dp = 1'b1;
  assign usb_fpga_pu_dn = 1'b1;

  wire flash_clk;

  // holding reset for 2 sec will activate ESP32 loader
  assign led[7:0] = {flash_miso,flash_mosi,flash_clk,flash_csn,flash_holdn,flash_wpn,1'b0,btn[1]};
  // assign led[7:0] = ps2_key[10:3];
  // visual indication of btn press
  // btn(0) has inverted logic
  always @(posedge clk_pixel) begin
    reset_n <= ~btn[1] & locked;
  end

/*
  clk_25_250_125_25
  clkgen_inst
  (
    .clki(clk_25mhz), //  25 MHz input from board
    .clkop(clk_pixel_shift2), // 250 MHz
    .clkos(clk_pixel_shift1), // 125 MHz
    .clkos2(clk_pixel), //  25 MHz
    .locked(locked)
  );
*/

  wire [3:0] clocks;
  wire clk_pixel_shift1 = clocks[0];
  wire clk_pixel_shift2 = clocks[0];
  wire clk_pixel = clocks[1];
  ecp5pll
  #(
      .in_hz(25000000),
    .out0_hz(25000000*5*(C_ddr?1:2)),
    .out1_hz(25000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(locked)
  );

  generate
  if(C_ddr)
    assign clk_pixel_shift = clk_pixel_shift1;
  else
    assign clk_pixel_shift = clk_pixel_shift2;
  endgenerate

  galaksija
  galaksija_inst
  (
    .clk(clk_pixel),
    .pixclk(clk_pixel),
    .reset_n(reset_n),
    .serial_rx(ftdi_txd),
    .serial_tx(ftdi_rxd),
    .ps2clk(usb_fpga_dp),
    .ps2data(usb_fpga_dn),
    .eeprom_csn(flash_csn),
    .eeprom_holdn(flash_holdn),
    .eeprom_wpn(flash_wpn),
    .eeprom_clk(flash_clk),
    .eeprom_mosi(flash_mosi),
    .eeprom_miso(flash_miso),
    .LCD_DAT(S_LCD_DAT),
    .LCD_HS(S_vga_hsync),
    .LCD_VS(S_vga_vsync),
    .LCD_DEN(S_vga_blank)
  );

  wire spi_sck_or = flash_clk & reset_n;
  (* noprune *) USRMCLK
  usrmclk_inst (
    .USRMCLKI(spi_sck_or),
    // .USRMCLKO(flash_clk_noprune),
    .USRMCLKTS(flash_csn)
  ) /* synthesis syn_noprune=1 */;

  // register stage to offload routing
  reg R_vga_hsync, R_vga_vsync, R_vga_blank;
  reg [2:0] R_vga_r, R_vga_g, R_vga_b;
  always @(posedge clk_pixel)
  begin
    R_vga_hsync <= S_vga_hsync;
    R_vga_vsync <= S_vga_vsync;
    R_vga_blank <= S_vga_blank;
    R_vga_r[2:1] <= S_LCD_DAT[7:6];
    R_vga_r[0]   <= S_LCD_DAT[6];
    R_vga_g[2:0] <= S_LCD_DAT[5:3];
    R_vga_b[2:0] <= S_LCD_DAT[2:0];
  end
  
  // DVI will report 960x260 @ 76.1 Hz
  // led(7) <= not S_vga_vsync;
  // led(1) <= locked;
  vga2dvid
  #(
    .C_ddr(C_ddr),
    .C_depth(3)
  )
  vga2dvi_converter
  (
    .clk_pixel(clk_pixel), // 25 MHz
    .clk_shift(clk_pixel_shift), // 5*25 or 10*25 MHz
    .in_red(R_vga_r),
    .in_green(R_vga_g),
    .in_blue(R_vga_b),
    .in_hsync(R_vga_hsync),
    .in_vsync(R_vga_vsync),
    .in_blank(R_vga_blank),
    // single-ended output ready for differential buffers
    .out_red(dvid_red),
    .out_green(dvid_green),
    .out_blue(dvid_blue),
    .out_clock(dvid_clock)
  );

  fake_differential
  #(
    .C_ddr(C_ddr)
  )
  fake_differential_instance
  (
    .clk_shift(clk_pixel_shift),
    .in_clock(dvid_clock),
    .in_red(dvid_red),
    .in_green(dvid_green),
    .in_blue(dvid_blue),
    .out_p(gpdi_dp),
    .out_n(gpdi_dn)
  );
endmodule

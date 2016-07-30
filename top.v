module iCE40_top(
    // 12MHz clock input
    output[4:0] led,
    //input [7:0] pmod,
    input pmod_0,  //bit-stuffed clock
    input pmod_1,  //bit-stuffed data
    input pmod_2,  //spi clk
    output pmod_3, //spi miso
    input pmod_4,  //spi cs
    input pmod_5,  //packet reset
    input pmod_6,
    input pmod_7,

    //unused pins
    input clk,
    input fdti_rx,
    input fdti_tx,
    input fdti_rts,
    input fdti_cts,
    input fdti_dtr,
    input fdti_dsr,
    input fdti_dcd,

    input fdti_clk,
    input ftdi_din,
    input ftdi_dout,
    input ftdi_ss
  );


  wire din;
  wire dout;
  wire clkin;
  wire clkout;
  wire error;

  assign led[4] = error;
  assign led[0] = din;
  assign led[1] = dout;
  assign led[2] = clkin;
  assign led[3] = clkout;

  assign clkin = pmod_0;
  assign din = pmod_1;
  

  canUnstuff #(.CONSEC(4)) stuffer (
    .clkin(clkin),
    .rxin(din),      //signal containing stuffed bits synced to clkin
    .en(1),        //enable/disable the unstuffing (for EOF data)
    .rxout(dout),    //signal with bits we've stuffed. (use clkout as the baud clock for the data source)
    .clkout(clkout),   //clock signal with high periods missing where we're stuffing/masking bits
    .err(error)       //we expected a stuffed bit on the rxin, but didn't find one.
  );

  wire [15:0] crcsum;

  //canCRC #(.BITS(8), .POLY(150)) simpleCRC (
  canCRC simpleCRC (
    .clk(clkout),
    .din(dout),
    //.zero(),
    .remainder(crcsum)
  );


  wire spi_clk;
  wire spi_miso;
  wire spi_cs;
  assign spi_clk = pmod_2;  //spi clk
  assign pmod_3 = spi_miso; //spi miso
  assign spi_cs = pmod_4;  //spi cs

  spiSlave #(.WIDTH(134)) inspection (
    .clk(spi_clk),
    .cs(spi_cs),
    .s_in(0),
    .s_out(spi_miso),
    //.p_in(crcsum)
    //.p_in(canPacket[131:131-15])
    .p_in(canPacket)
  );


  wire [133:0] canPacket;

  packetCapture stateMachine (
    .rst(pmod_5),
    .clk(clkout),
    .rx(din),
    .en(1),
    .dout(canPacket)
  );

  


endmodule

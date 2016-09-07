/*
 * CANbus receiver interface
 * still missing reset logic and live tests
 */

module iCE40_top(
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

    input clk,

    //unused pins
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
  //wire dout;
  wire clkin;
  wire clkout;
  wire error;
  reg pkRst =1;
  wire baudLock;
  //assign led[4] = error;
  //assign led[4] = baudLock;
  //assign led[0] = din;
  //assign led[1] = dout;
  //assign led[2] = clkin;
  //assign led[3] = clkout;

  //assign clkin = pmod_0;  //use the baud clock from now on
  assign din = pmod_1;
  //assign pkRst = pmod_5;

  parameter CLK_RATE = 12000000;  //12MHz xtal
  parameter BAUD_RATE = 125000;   //125KHz CANBus
  
  parameter CLK_MAX = (CLK_RATE/BAUD_RATE);  //96

  //parameter SYNC_TOL = (CLK_MAX/10);  //9
  parameter SYNC_TOL = 9;
  parameter SYNC_MAX = SYNC_TOL;  //permit edges until SYNC_TOL cycles after counter reset
  parameter SYNC_MIN = (CLK_MAX - SYNC_TOL);  //105, permit edges after SYNC_TOL cycles after counter reset


  parameter CLK_WIDTH = $clog2(CLK_MAX); //7


  baudclock #(.COUNTER_WIDTH(CLK_WIDTH)) baudclock(
    .clk(clk),
    .rst(pkRst),
    .rx(din),
    .baud(clkin), //the stuffed bits are for clock recovery
    .lock(baudLock),
    //.glitch(glitch),
    .sync_max(SYNC_MAX),
    .sync_min(SYNC_MIN),
    .count_max(CLK_MAX)
  );

  canUnstuff #(.CONSEC(4)) stuffer (
    .clkin(clkin),
    .rxin(din),      //signal containing stuffed bits synced to clkin
    .en(1),        //enable/disable the unstuffing (for EOF data)
    //.rxout(dout),    //signal with bits we've stuffed for transmission.
    .clkout(clkout),   //clock signal with high periods missing where we're stuffing/masking bits
    .err(error)       //we expected a stuffed bit on the rxin, but didn't find one.
  );

  wire [15:0] crcsum;
  wire [134:0] canPacket;

  //canCRC #(.BITS(8), .POLY(150)) simpleCRC (
  canCRC #(.BITS(15), .POLY('h4599)) canCRC (
    .clk(clkout),
    .din(din),
    //.zero(),
    .remainder(crcsum)
  );


  wire [63:0] canPayload;
  wire canstdaddr;
  wire [29:0] canAddr;
  assign led[3:0] = canPacket[83:80];
  //assign led[3:0] = canPayload[51:48];
  //assign led[4] = !din;
  //assign led[4] = clkin;
  assign led[4] = !pkRst;

  wire endtx;
//--------- start detect
  wire rst;
  assign rst = pmod_5;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      // reset
      pkRst <= 1;
    end else begin
      if (pkRst) begin
        if(din == 0) begin
          pkRst <= 0;
        end
      end else if (endtx) begin
        pkRst <= 1;
      end
    end
  end



  packetCapture stateMachine (
    .rst(pkRst),
    .clk(clkout),
    .rx(din),   //n
    .en(1),
    .dout(canPacket),
    .done(endtx),
    .ext_addressing(canstdaddr),
    .payload(canPayload),
    .address(canAddr)
  );



  //-------SPI to read the packets captured
//
  //wire spi_clk;
  //wire spi_miso;
  //wire spi_cs;
  //assign spi_clk = pmod_2;  //spi clk
  //assign pmod_3 = spi_miso; //spi miso
  assign pmod_3 = 0; //spi miso
  //assign spi_cs = pmod_4;  //spi cs
//
//
//  spiSlave #(.WIDTH(134)) inspection (
//    .clk(spi_clk),
//    .cs(spi_cs),
//    .s_in(0),
//    .s_out(spi_miso),
//    //.p_in(crcsum)
//    //.p_in(canPacket[131:131-15])
//    .p_in(canPacket)
//  );



  


endmodule

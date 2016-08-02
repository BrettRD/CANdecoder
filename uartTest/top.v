module iCE40_top(
    output[4:0] led,
    //input [7:0] pmod,
    input pmod_0,  //reset
    input pmod_1,  //edge source to sync with
    input pmod_2,  
    output pmod_3, 
    input pmod_4, 
    input pmod_5, 
    input pmod_6,
    input pmod_7,

    input clk,      //12MHz clock source

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

  wire rst;
  wire rx;
  wire cs;
  wire clkout;
  wire lock;
  wire glitch;

  assign led[4] = clkout;
  assign led[0] = !lock;
  assign led[1] = glitch;
  assign led[2] = !rx;
  assign led[3] = 0;

  //assign rst = pmod_0;  //baud clock reset, uart chip select
  assign rx = pmod_1;   //data
  

  parameter CLK_RATE = 'd12000000;  //12MHz xtal
  parameter BAUD_RATE = 'd3;   //125KHz CANBus
  parameter CLK_MAX = (CLK_RATE/BAUD_RATE);

  parameter SYNC_TOL = (CLK_MAX/10);
  parameter SYNC_MAX = SYNC_TOL;  //permit edges until SYNC_MAX cycles after counter reset
  parameter SYNC_MIN = (CLK_MAX - SYNC_TOL);  //permit edges after SYNC_MIN cycles after counter reset
  parameter CLK_WIDTH = $clog2(CLK_MAX) + 1; //

  parameter N_BITS = 'd11;

  baudclock #(.COUNTER_WIDTH(CLK_WIDTH)) baudclock(
  //baudclock #(.COUNTER_WIDTH(11)) baudclock(
    .clk(clk),
    .rst(uartState),
    .rx(0),
    //.rx(rx),
    .baud(clkout),
    .lock(lock),
    .glitch(glitch),
    .sync_max(SYNC_MAX),
    .sync_min(SYNC_MIN),
    .count_max(CLK_MAX)
    //.sync_max(125),
    //.sync_min(1125),
    //.count_max(1250)
  );


  wire [N_BITS-1:0] packet; //packet captured on uart is buffered by uartCore



 spiSlave #(.WIDTH(N_BITS)) uartCore(
    .clk(clkout),
    .cs(uartState),
    .s_in(rx),
    //.s_out(),
    .p_in(0),
    .p_out(packet)
  );

//---------Uart start/stop logic

  reg [$clog2(N_BITS)+1:0] bitCount = 0;
  parameter STOP = 1;
  parameter RUN = 0;
  reg uartState = STOP;
  //change to RUN on first edge of rx start bit (negedge)
  //change to STOP on 8th rising clock after run

  //wire startEdge;
  //assign startEdge = ((!rx) & uartState);   //idle "1" on ttl rx line
  always @(negedge rx) begin
    uartState <= RUN;   //this assertion is ignored because of the driver below
  end

  always @(posedge clkout) begin
    if (bitCount >= 8) begin
      bitCount <= 0;
      uartState <= STOP;  //uartCore.packet() becomes valid now
    end else begin
      //reset
      bitCount <= bitCount +1;
    end
  end




  //-------SPI to read the packets captured

  wire spi_clk;
  wire spi_miso;
  wire spi_cs;
  assign spi_clk = pmod_2;  //spi clk
  assign pmod_3 = spi_miso; //spi miso
  assign spi_cs = pmod_4;  //spi cs


  spiSlave #(.WIDTH(8)) spiSlave (
    .clk(spi_clk),
    .cs(spi_cs),
    .s_in(0),
    .s_out(spi_miso),
    .p_in(packet[8:1])
    //.p_in('h5A)
  );





endmodule

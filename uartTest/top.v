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
  wire uart_rx;
  wire cs;
  wire clkout;
  wire lock;
  wire glitch;

  wire uartState;

  assign led[4] = clkout;
  assign led[0] = !uartState;
  assign led[1] = glitch;
  assign led[2] = !uart_rx;
  assign led[3] = !lock;
  //assign led[0] = uartState;
  //assign led[1] = uartStart;
  //assign led[2] = !uart_rx;
  //assign led[3] = uartStop;
  
  //assign rst = pmod_0;  //baud clock reset, uart chip select
  assign uart_rx = pmod_1;   //data
  //assign pmod_2 = uartState;

  parameter CLK_RATE = 'd12000000;  //12MHz xtal
  parameter BAUD_RATE = 'd9600;   //9600 uart
  parameter CLK_MAX = (CLK_RATE/BAUD_RATE);

  //parameter SYNC_TOL = 100;
  parameter SYNC_TOL = (CLK_MAX/5);
  parameter SYNC_MAX = SYNC_TOL;  //permit edges until SYNC_MAX cycles after counter reset
  parameter SYNC_MIN = (CLK_MAX - SYNC_TOL);  //permit edges after SYNC_MIN cycles after counter reset
  parameter CLK_WIDTH = $clog2(CLK_MAX+1) + 1; //

  parameter N_BITS = 9;

  baudclock #(.COUNTER_WIDTH(CLK_WIDTH)) baudclock(
  //baudclock #(.COUNTER_WIDTH(11)) baudclock(
    .clk(clk),
    //.rst(0),
    .rst(uartState),
    //.rx(1),
    .rx(uart_rx),
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
    .s_in(uart_rx),
    //.s_out(),
    .p_in(0),
    .p_out(packet)
  );

  uartRst #(.N_BITS(N_BITS)) uartLogic (
    .baud(clkout),
    //.baud(pmod_0),
    .rx(uart_rx),
    .run(uartState)
  );



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
    .p_in(packet[7:0])
    //.p_in('h5A)
  );





endmodule

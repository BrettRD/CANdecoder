/*
 *a uart module based on a clock recovery circuit and a spi slave
 */


module uartRx #(
    parameter N_BITS = 'd9,
    parameter CLK_RATE = 'd12000000,
    parameter BAUD_RATE = 'd9600
  )(
    input clk,
    input rx,
    output [N_BITS-1:0] charOut,
    output glitch,
    output lock,
    output baud
  );

  parameter CLK_MAX = (CLK_RATE/BAUD_RATE);

  parameter SYNC_TOL = (CLK_MAX/10);
  parameter SYNC_MAX = SYNC_TOL;  //permit edges until SYNC_MAX cycles after counter reset
  parameter SYNC_MIN = (CLK_MAX - SYNC_TOL);  //permit edges after SYNC_MIN cycles after counter reset
  parameter CLK_WIDTH = $clog2(CLK_MAX) + 1; //


  //wire baud;



//---------Uart start/stop logic


  reg [$clog2(N_BITS)+1:0] bitCount = 0;

  parameter UART_STOP = 1'b1;
  parameter UART_RUN = 1'b0;
  reg uartState = UART_STOP;
  //change to UART_RUN on first edge of rx start bit (negedge)
  //change to UART_STOP on 8th rising clock after run

  wire startEdge;
  assign startEdge = ((!rx) & uartState);   //idle "1" on ttl rx line

  always @(posedge baud or posedge startEdge) begin
    if(startEdge)begin  //using startEdge as a reset bar on the flipflops
      uartState <= UART_RUN;
      bitCount <= 0;
    end else begin
      if (bitCount >= 'd8) begin
        uartState <= UART_STOP;  //uartCore.packet() becomes valid now
        bitCount <= 0;
      end else begin
        //reset
        bitCount <= bitCount +1;
      end
    end
  end



  baudclock #(.COUNTER_WIDTH(CLK_WIDTH)) baudclock(
  //baudclock #(.COUNTER_WIDTH(11)) baudclock(
    .clk(clk),
    .rst(uartState),
    .rx(0),
    //.rx(rx),
    .baud(baud),
    .lock(lock),
    .glitch(glitch),
    .sync_max(SYNC_MAX),
    .sync_min(SYNC_MIN),
    .count_max(CLK_MAX)
    //.sync_max(125),
    //.sync_min(1125),
    //.count_max(1250)
  );




 spiSlave #(.WIDTH(N_BITS)) uartCore(
    .clk(baud),
    .cs(uartState),
    .s_in(rx),
    //.s_out(),
    .p_in(0),
    .p_out(charOut)
  );

endmodule
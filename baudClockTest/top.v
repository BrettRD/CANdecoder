module iCE40_top(
    output[4:0] led,
    //input [7:0] pmod,
    input pmod_0,  //reset
    input pmod_1,  //edge source to sync with
    input pmod_2,  
    input pmod_3, 
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
  wire clkout;
  wire lock;
  wire glitch;

  assign led[4] = clkout;
  assign led[0] = !lock;
  assign led[1] = glitch;
  assign led[2] = rx;
  assign led[3] = rst;

  assign rst = pmod_0;
  assign rx = pmod_1;
  

  baudclock #(.COUNTER_WIDTH(24)) baudclock(
    .clk(clk),
    .rst(pmod_0),
    .rx(rx),
    .baud(clkout),
    .lock(lock),
    .glitch(glitch),
    .sync_max( 24'd0120000),
    .sync_min( 24'd1080000),
    .count_max(24'd1200000)
  );

endmodule

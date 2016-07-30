module iCE40_top(
    // 12MHz clock input
    output[4:0] led,
    input [7:0] pmod,
  
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
  assign din = pmod[1];
  assign clkin = pmod[0];
  

  canUnstuff #(.CONSEC(2)) stuffer (
    .clkin(clkin),
    .rxin(din),      //signal containing stuffed bits synced to clkin
    .en(1),        //enable/disable the unstuffing (for EOF data)
    .rxout(dout),    //signal with bits we've stuffed. (use clkout as the baud clock for the data source)
    .clkout(clkout),   //clock signal with high periods missing where we're stuffing/masking bits
    .err(error)       //we expected a stuffed bit on the rxin, but didn't find one.
  );



   


endmodule

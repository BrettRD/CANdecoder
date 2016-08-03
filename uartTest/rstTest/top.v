module iCE40_top(
    output[4:0] led,
    //input [7:0] pmod,
    input pmod_0,  //reset
    input pmod_1,  //edge source to sync with
    output pmod_2,
    input clk,      //12MHz clock source

  );
  parameter CYCLES = 4;
  //wire [$clog2(CYCLES+1)-1:0] bitCount;
  wire run;
  assign led[0] = pmod_0;
  assign led[1] = pmod_1;
  assign led[2] = 0;
  assign led[3] = 0;
  assign pmod_2 = run;
  assign led[4] = run;

  uartRst #(.N_BITS(CYCLES)) uartLogic (
    .baud(pmod_0),
    .rx(pmod_1),
    //.count(bitCount),
    .run(run)
  );


endmodule

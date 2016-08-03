module uartRst #(
    parameter N_BITS = 9
  )(
    input baud,
    input rx,
    //output [$clog2(N_BITS+1):0] count,
    output run, //active low
  );


  reg [$clog2(N_BITS):0] counter = 0;
  //reg [4:0] counter = 0;
  reg uartStart;
  reg uartStop;

  reg clkhold;  //shutdown the baud clock after the negedge

  //assign count = counter;
  assign run = (uartStart == uartStop);

  always @(negedge rx) begin
    if(run==1) begin  //only start when inactive
      uartStart <= !uartStop;
    end
  end

  always @(posedge baud) begin
    if (counter >= (N_BITS-1)) begin
      counter <= 0;
      clkhold <= uartStart;
      //uartStop <= uartStart;
    end else begin
      if(run==0) begin  //only increment when active
        counter <= counter+1;
      end
    end
  end

  always @(negedge baud) begin
    uartStop <= clkhold;
  end

endmodule
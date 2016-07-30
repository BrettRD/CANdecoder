/*
This module removes the bit-stuffing from the CANbus signal
data changes on negative edge, reads on positive edge
*/

module canUnstuff #(parameter CONSEC = 5) (
  input clkin,
  input rxin,      //signal containing stuffed bits synced to clkin
  input en,        //enable/disable the unstuffing (for EOF data)
  output rxout,    //signal with bits we've stuffed. (use clkout as the baud clock for the data source)
  output clkout,   //clock signal with high periods missing where we're stuffing/masking bits
  output err       //we expected a stuffed bit on the rxin, but didn't find one.
);
  //parameter CONSEC = 5;

  reg bitState = 0;
  reg stuffBit = 0;
  reg [3:0] consecBits = 0;  //a counter for consecutive bits
  reg stuffing = 0; //a flag to indicate if we're expecting a stuffed bit.


  always @(*) begin
    clkout = clkin && !stuffing;  //mask out the next clock cycle if we're stuffing a bit
    rxout = stuffing ? stuffBit : rxin; //output whatever the previous bit was not.
    //can reasonably expect a glitch in rxout as stuffing becomes false.
    //(only when rxin did not contain a stuffed bit, and the data change occurs slightly after the clock falling edge, and the next rxin bit changes)
  end

  always @(posedge clkin) begin
    if(en)begin
      //bitState <= rxin;   //store the rx input
      bitState <= rxout;   //store the rx input, but account for stuffed bits we've generated at rxout

      if(stuffing) begin
        err <= (rxin == bitState);  //set the error flag if no edge is found in rxin.
        consecBits <= 0;  //we've just injected an edge, reset the counter
      end else begin
        if(rxin == bitState) begin
          consecBits <= consecBits + 1;
        end else begin
          consecBits <= 0;  //fresh edge detectd on input, reset
        end
      end
    end else begin
      bitState <= rxin;
      consecBits <= 0;  //full reset
      err <= 0;
    end

  end

  always @(negedge clkin) begin
    //when we expect the next bit to change.
    if(en) begin
      stuffBit <= !bitState;  //store the bit to stuff so we can mask it into place with combinatorial
      stuffing <= (consecBits >= CONSEC);  //too many consecutive bits, start stuffing
      //rxout <= (consecBits >= CONSEC) ? !bitState : rxin; //output whatever the previous bit was not.
    end else begin
      //rxout <= rxin;
      stuffing <= 0;
    end

  end

endmodule

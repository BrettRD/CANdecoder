/*
This module removes the bit-stuffing from the CANbus signal

*/

module canUnstuff(
  input clkin,
  input rxin,      //signal containing stuffed bits synced to clkin
  input en,        //enable/disable the unstuffing (for EOF data)
  output rxout,    //signal with bits we've stuffed. (use clkout as the baud clock for the data source)
  output clkout,   //clock signal with high periods missing where we're stuffing/masking bits
  output err       //we expected a stuffed bit on the rxin, but didn't find one.
)
  parameter CONSEC = 5;

  reg bitState;
  reg [3:0] consecBits  //a counter for consecutive bits
  reg stuffing = 0; //a flag to indicate if we're expecting a stuffed bit.


  always @(*) begin
    clkout = clkin && !stuffing;  //mask out the next clock cycle if we're stuffing a bit
  end



  always @(posedge clkin) begin
    if(en)begin
      bitstate <= rxin;   //store the rx input (also makes phase shift avaialble)

      if(stuffing) begin
        rxout <= !bitState; //output whatever the previous bit was not.
        err <= (rxin == bitState);  //set the error flag if no edge is found in rxin.
      end else begin
        rxout <= rxin;        //play pass-through

        if(rxin == bitState) begin
          consecBits <= consecBits + 1; //overflow handled via stuffing flag at negative clock cycle
        end else begin
          consecBits <= 0;
        end
      end
    end else begin
      consecBits <= 0;  //full reset
      stuffing <= 0;
      err <= 0;
      bitstate <= rxin;
      rxout <= rxin;    //play pass-through
    end

  end

  always @(negedge clkin) begin
    //when we expect the next bit to change.
    //stuffing <= (consecBits == CONSEC);  //only delete one bit.
    stuffing <= (consecBits >= CONSEC);  //hold all bits until the next start bit

  end

endmodule

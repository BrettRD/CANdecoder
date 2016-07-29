/*
This module removes the bit-stuffing from the CANbus signal

*/

module canUnstuff(
  input clkin,
  input rxin,
  input en,        //enable/disable the unstuffing (for EOF data)
  output rxout,
  output clkout,
  output err      //we expected a stuffed bit, but didn't find one.
)
  reg bitState;
  reg [3:0] consecBits  //a counter for consecutive bits
  reg stuffing; //a flag to indicate if we're expecting a stuffed bit.


  always @(*) begin
    
    clkout = clkin && !stuffing;
    err = (consecBits > 5);
  end


  
  always @(posedge clkin) begin
    bitstate <= rxin;   //store the rx input (also makes phase shift avaialble)

    //count bits
    if(rxin == bitState) begin

      consecBits <= consecBits + 1;
      //XXX fix the overflow error here
    end else begin
      consecBits <= 0;
    end

  end

  always @(negedge clkin) begin
    //when we expect the next bit to change.
    //stuffing <= (consecBits == 5);  //only delete one bit.
    stuffing <= (consecBits >= 5);  //hold all bits until the next start bit

  end

endmodule

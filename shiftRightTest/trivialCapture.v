/*
trivialCapture
Collect bits in an addressable mux.
*/


module trivialCapture(
    input rst,                 //drive high to disable the baud clock, restart
    input clk,                 //a clock input to the baud counter, used for clock recovery
    input rx,                  //attach to an input edge to enable clock recovery
    input en,                  //enable count and capture.
    //output reg [7:0] count,     //the number of bits captured since rst.
    output [HEAD:0] dout
  );

  parameter HEAD = 7;


  reg [HEAD:0] packet = 0;   //the packet captured so far, this gets broken into fields by assign operators
  reg [HEAD:0] selector = {1,{HEAD{0}}}; //the one-hot state selector (based on shift registers)

  assign dout = packet;

  always @(posedge clk or posedge rst) begin
    if(rst) begin
      packet <= 0;
    end else begin
      if(en) begin
        //load the rx line into the appropriate bit of the packet:
        packet <= (selector & {HEAD+1{rx}}) | packet;

      end
    end
  end

  
  //shift the selector on the negative edges of the baud clock so we have half a clock to run packet decoding. (particularly the data length field)
  always @(negedge clk or posedge rst) begin
    if(rst) begin
      selector[HEAD] <= 1;  //start with the first bit
      selector[HEAD-1:0] <= 0;  //and zeroes elsewhere
    end else begin
      if(en) begin
        //heaps of right shift operations:
        selector [HEAD-1:0] <= selector [HEAD:1]; //up to and including the IDE bit
        selector [HEAD] <= selector[0];
      end
    end
  end


endmodule






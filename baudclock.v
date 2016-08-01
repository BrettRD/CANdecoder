/*
This module creates a clock recovery system. 
The clock output will have a 50% duty cycle or slightly less due to rounding.
Use as the baud clock of uart rx (external start-bit detctor required)

*/

module baudclock#(
    parameter COUNTER_WIDTH = 24,  //really slow (1Hz)
  )(
    input clk,             //a clock input to the baud counter, used for clock recovery
    input rst,             //drive high to disable the baud clock, reset/enable
    input rx,              //attach to an input edge to enable clock recovery
    output baud,           //the baud clock output, negedges synchronised to rx edges
    output reg lock,       //does the baud clock have a lock on the edges?
    output reg glitch,     //
    input [COUNTER_WIDTH-1:0] sync_max = 1024;
    input [COUNTER_WIDTH-1:0] sync_min = count_max - 1024;
    input [COUNTER_WIDTH-1:0] count_max = -1;   //I think this maxes out the counter
  );

  reg [COUNTER_WIDTH-1:0] counter = 0;

  reg rxold = 0;  //for rx change detection
  reg trig = 0;   //trigger flag for retrigger inhibit

  wire rxEdge;   
  wire inWindow; //counter is within the sync window
  
  always @(*) begin
    baud = counter > (count_max/2);  //rx edges coincide with negedge baud (count reset)
    rxEdge = rx != rxold;  //there has been an edge in the last sample clock cycle.
    inWindow = (counter < sync_max) || (counter>sync_min);
  end


  always @(posedge sampleclk) begin
    rxold <= rx;

    if (rst) begin
      counter <= 0; //start clock low
      trig <= 0;  //no trigger events seen
      lock <= 1;  //put warnings on negedge lock
      glitch <= 0;
    end else begin

      if(rxEdge && inWindow && !trig) begin
          counter <= 0;  //we can re-sync the clock
          trig <= 1;   
          lock <= 1;
      end else begin
        if(counter >= count_max) begin
          counter <= 0; //reset
        end else begin
          counter <= counter + 1;
        end
      end

      
      //if(counter == (count_max/2)) begin  //at about posedge baud
      if(counter == sync_min) begin  //just before the next sync window
        trig <= 0;  //reset the trigger inhibitor
        glitch <= 0;  //reset the glitch flag
      end

      if(rxEdge && !inWindow) begin
        lock <= 0;  //we're lost.
      end

      //if(rxEdge && trig && !inWindow) begin  //early rxEdge after sync (wrong baud rate?)
      //if(rxEdge && trig && inWindow) begin  //hiccup on the rx line (logic glitch)
      if(rxEdge && trig) begin  //pedantic
        glitch <= 1; //we've seen two rx edges this clock cycle
      end

    end
    
  end

endmodule
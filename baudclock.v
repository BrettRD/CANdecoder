/*
This module creates a clock system for UART systems that implements clock phase recovery
The system will wait for an edge of the rx line, then go into RUN mode.
The clock output will start immediately after that edge (resetting the div/N counter)

The clock output will have a 50% duty cycle or slightly less due to rounding.
*/

module baudclock#(
    parameter COUNTER_WIDTH = 24,
  )(
    input clk,             //a clock input to the baud counter, used for clock recovery
    input rst,             //drive high to disable the baud clock, reset/enable
    input rx,              //attach to an input edge to enable clock recovery
    output baud,           //the baud clock output, negedges synchronised to rx edges
    output reg lock,       //does the baud clock have a lock on the edges?
    output reg glitch,     
    input [COUNTER_WIDTH-1:0] sync_max = 1024;
    input [COUNTER_WIDTH-1:0] sync_min = count_max - 1024;
    input [COUNTER_WIDTH-1:0] count_max = -1;   //I think this maxes out the counter
  )

  reg [COUNTER_WIDTH-1:0] counter = 0;
  reg rxold = 0;  //for rx change detection
  reg retrig = 0;  //retrigger inhibit
  always @(*) begin
    baudclk = counter > (count_max/2);  //rx edges coincide with negedge baud (count reset)
  end

  always @(posedge sampleclk) begin
    rxold <= rx;

    if (rst) begin
      counter <= 0;
      retrig <= 0;
    end else begin
      //if there's been an edge, the first edge, and the phase of the moon is right enough
      if( (rx != rxold) & !retrig & ( (counter < sync_max) | (counter>sync_min) ) ) begin
        counter <= 0;  //we can re-sync the clock
        retrig <= 1;
        lock <= 1;
      end else begin
        
        if(counter >= count_max) begin
          counter <= 0; //reset
        end else begin
          counter <= counter + 1;
        end

        if(counter == (count_max/2))begin
          retrig <= 0;  //reset the retrigger inhibitor outside of the sync windows
        end

      end
    end
  end

endmodule
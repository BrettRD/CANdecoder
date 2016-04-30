/*
This module creates a clock system for UART systems that implements clock phase recovery
The system will wait for an edge of the rx line, then go into RUN mode.
The clock output will start immediately after that edge (resetting the div/N counter)

The clock output will have a 50% duty cycle or slightly less due to rounding.
*/

module baudclock(
  input sampleclk,          //a clock input to the baud counter, used for clock recovery
  input rst,                //drive high to disable the baud clock, restart
  input rx,                 //attach to an input edge to enable clock recovery
  input edgeSel,            //select edges to start the baud clock
  output reg [1:0] state,   //the current state of the clock generator
  output clk,               //the clock line for sample and edge generation
  output lock               //does the baud clock have a lock on the edges?
  )


  //autostart edge selection
  //parameter [1:0] AUTO = 2'b00; //baud clock starts immediately on rst falling edge
  //parameter [1:0] RISE = 2'b01; //baud clock starts on rx falling edge
  //parameter [1:0] FALL = 2'b10; //baud clock starts on rx rising edge
  //parameter [1:0] BOTH = 2'b11; //baud clock starts on any edge of rx

  //names for the state machine
  parameter [1:0] WAIT  = 2'b01;   //wait for an edge on the rx line to do a hard-sync with the rx lne
  parameter [1:0] RUN = 2'b10;     //the baud clock is running

  parameter [7:0] EdgeTolerance = 8'd2; //how many samples either side of zero are we allowed to be to re-sync?

  reg [7:0] sampleCounter, sampleCounter_next;
  reg [7:0] samplesPerBit;  //part of clock division, arbitrary div/N counter.
  reg [7:0] edgeposition;   //stores the position of the last measured edge.
  reg edgeSource;

  always @(*)
  begin
    edgeSource = edgesel ^ rx;                //set up the edge source
    clk = sampleCounter < (samplesPerBit/2)   //output a square wave.
    (sampleCounter >= samplesPerBit) ? sampleCounter_next = 0 : sampleCounter_next = sampleCounter_next + 1;

  end

  always @(posedge sampleclk)
  begin
    if (rst) state <= wait;
    else begin
      case(state)
        RUN:
          sampleCounter <= sampleCounter_next;  //increment the sample counter

        WAIT:  
          //do nothing      
        default:

      endcase
    end
  end

  always @(posedge edgeSource)
  begin
    case(state)
      RUN:
      begin
        if((sampleCounter < EdgeTolerance) || (sampleCounter > (samplesPerBit-EdgeTolerance) ))
        begin   //we're within the re-sync window
          //sampleCounter <= 0; //force a resync, reset the counter.
          edgeposition <= sampleCounter; //store the location of the edge. (I don't know why yet, maybe this can become a digital PLL)
          lock <= 1;
        end
        else
        begin
          //edge outside of where we expect it.  This means either noise, or a phase drift we've given up on.
          lock <= 0;
        end

      end

      WAIT:
      begin
        if(!rst)  //if we are not held in reset, WAIT is an edge-activated state
        begin
          state <= RUN;
          sampleCounter <= 0; //force a resync, reset the counter.
          lock <= 1;
        end
      end
      default:

  end

endmodule
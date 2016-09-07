/*
 * A basic SPI slave built from a 7495 practice chip.
 * mode zero, with hacks to correctly capture and output data on cs falling edge
 */
module spiSlave #(
    parameter WIDTH = 8
  )(
    input clk,
    input cs,
    input s_in,
    output reg s_out,

    input [WIDTH-1:0] p_in,
    output reg [WIDTH-1:0] p_out,
    output p_strobe,  //strobes high when the register is full
  );

  reg [WIDTH-1:0] shift_reg;
  wire core_clk;
  parameter PAR = 0;
  parameter SER = 1;
  reg mode = PAR;
  reg [$clog2(WIDTH):0] bitcount = 0;

  //assign p_out = shift_reg;
  //assign s_out = shift_reg[WIDTH-1];
  assign core_clk = clk | cs; //cs is active low, shift in on 

  reg p_clk = 0;
  assign p_strobe = !mode & p_clk;
  reg [WIDTH-1:0] p_buf;

  always @(negedge core_clk) begin  //cs or clk falling edge: set miso
    p_clk <= (mode == PAR);
    if(mode == PAR) begin
      s_out <= p_in[WIDTH-1];  //set miso from parallel data
      p_buf <= p_in;  //capture the data on cs falling edge, but don't load the shift reg yet
    end else begin
      s_out <= shift_reg[WIDTH-1];
      p_buf <= shift_reg;
    end
  end

  always @(posedge core_clk or posedge cs) begin  //cs or clk rising edge, shift data in
    if(cs) begin  //cs rising edge, end of transmission
      //p_out <= shift_reg;   //generates a warning "non-constant async reset value"
      shift_reg <= 0;  //ignores the initialiser because I have a reset bar here
      bitcount <= 0;
      mode <= PAR;
    end else begin  //cs is enabled, shift in
      if(bitcount + 1 == WIDTH) begin
        bitcount <= 0;
        mode <= PAR;
        p_out <= {shift_reg[WIDTH-2:0],s_in}; //if this was the last bit, also load it to the output
      end else begin
        bitcount <= bitcount + 1;
        mode <= SER;  //change to serial mode
      end

      if(mode == PAR) begin
      //if(bitcount == 0) begin
        shift_reg <= {p_buf[WIDTH-2:0],s_in};  //load the shift register with the parallel data (buffered from cs negedge)
      end else begin
        shift_reg <= {shift_reg[WIDTH-2:0], s_in};
      end
    end
  end



  //always @(posedge cs) begin
  //  p_out <= p_buf;   //should be edge triggered, not promoted to async
  //end

endmodule
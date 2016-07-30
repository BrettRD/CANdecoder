/*
 * A basic SPI slave built from a 7495 practice chip.
 * mode zero, with hacks to correctly capture and output data on cs falling edge
 */
module spiSlave #(
    parameter WIDTH = 8
  )(
    input clk,
    input cs,
    //input rst,
    input s_in,
    output reg s_out,

    input [WIDTH-1:0] p_in,
    output reg [WIDTH-1:0] p_out,
  );

  reg [WIDTH-1:0] shift_reg = 0;
  wire core_clk;
  parameter PAR = 0;
  parameter SER = 1;
  reg mode = PAR;

  //assign p_out = shift_reg;
  //assign s_out = shift_reg[WIDTH-1];
  assign core_clk = clk | cs; //cs is active low, shift in on 

  reg [WIDTH-1:0] p_buf;

  always @(negedge core_clk) begin  //cs or clk falling edge: set miso
    if(mode == PAR) begin
      s_out <= p_in[WIDTH-1];  //set miso from parallel data
      p_buf <= p_in;  //capture the data on cs falling edge, but don't load the shift reg yet
    end else begin
      s_out <= shift_reg[WIDTH-1];
    end
  end

  always @(posedge core_clk) begin  //cs or clk rising edge, shift data in
    if(cs) begin  //cs rising edge, end of transmission
      p_out <= shift_reg;
      mode <= PAR;
    end else begin  //cs is enabled, shift in
      if(mode == PAR) begin
        shift_reg <= {p_buf[WIDTH-2:0],s_in};  //load the shift register with the parallel data (buffered from cs negedge)
        mode <= SER;  //change to serial mode
      end else begin
        shift_reg <= {shift_reg[WIDTH-2:0], s_in};
      end
    end
  end
endmodule
module canCRC #(parameter BITS = 15, parameter POLY= 0x4599) (
    input clk,
    input din,
    output zero,
    output [BITS-1:0] remainder
  );

  reg [BITS-1:0] poly = POLY; //will almost certainly be optimised away
  //wire [BITS-1:0] xorflag = {BITS{remainder[BITS-2]}};  //anticipate the shift, select 2nd MSB
  wire [BITS-1:0] xorflag = remainder[BITS-2];  //anticipate the shift, select 2nd MSB
  
  assign zero = remainder == 0;

  always @(posedge clk) begin
    if(xorflag) begin
      remainder <= {remainder[BITS-2:0],din} ^ poly;
    end else begin
      remainder <= {remainder[BITS-2:0],din};
    end
  end

endmodule
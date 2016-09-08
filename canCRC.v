module canCRC #(
    parameter BITS = 15,
    parameter POLY = 'h4599
  )(
    input clk,
    input rst,
    input en,
    input din,
    output reg zero,
    output reg [BITS-1:0] remainder = 0 //actually only need [BITS-2:0], MSB is always zero
  );

  reg [BITS-1:0] poly = POLY;
  wire xorflag;
  assign xorflag = remainder[BITS-2];
  
  //assign zero = remainder == 0;

  always @(posedge clk or posedge rst) begin
    if(rst) begin
      remainder <= 0;
      zero <= 1;
    end else begin
      if (en) begin
        //remainder <= {remainder[BITS-2:0],din} ^ (poly & {BITS{xorflag}});  //is one line easier to read?
        if(xorflag) begin
          remainder <= {remainder[BITS-2:0],din} ^ poly;
          zero <= (({remainder[BITS-2:0],din} ^ poly) == 0);
        end else begin
          remainder <= {remainder[BITS-2:0],din};
          zero <= (({remainder[BITS-2:0],din}) == 0);
        end
      end
    end
  end

endmodule
/*
PacketCapture
Collect bits in an addressable mux.
Decode on the fly, advancing the bit selector according to the data in the RX buffer
decoded fields are output on assigned wires.
  

*/


module packetCapture(
    input rst,                 //drive high to disable the baud clock, restart
    input clk,                 //a clock input to the baud counter, used for clock recovery
    input rx,                  //attach to an input edge to enable clock recovery
    input en,                  //enable count and capture.
    //output reg [7:0] count,     //the number of bits captured since rst.
    output [HEAD:0] dout
  );

  //the lengths of the various fields
  parameter LEN_STDADDR = 11;
  parameter LEN_SRR     =  1;  //rtr bit for standard length
  parameter LEN_IDE     =  1;
  parameter LEN_EXTADDR = 18;
  parameter LEN_RTR     =  1;
  parameter LEN_R1      =  1;
  parameter LEN_R0      =  1;
  parameter LEN_DLC     =  4;
  parameter LEN_DATA    =  8;
  parameter LEN_CRC     = 16;
  parameter LEN_EOF     =  7;
  parameter LEN_IFS     =  7;
  
  //the LSB locations of the various fields
  parameter STDADDR_LSB = SRR_LSB     + LEN_SRR;
  parameter SRR_LSB     = IDE_LSB     + LEN_IDE;
  parameter IDE_LSB     = EXTADDR_LSB + LEN_EXTADDR;
  parameter EXTADDR_LSB = RTR_LSB     + LEN_RTR;
  parameter RTR_LSB     = R1_LSB      + LEN_R1;
  parameter R1_LSB      = R0_LSB      + LEN_R0;
  parameter R0_LSB      = DLC_LSB     + LEN_DLC;
  parameter DLC_LSB     = DATA_LSB    + (8 * LEN_DATA);
  parameter DATA_LSB    = CRC_LSB     + LEN_CRC;
  //parameter [7:0] DATA_LSB  = { 
  //                        CRC_LSB     + LEN_CRC + (7 * LEN_DATA),
  //                        CRC_LSB     + LEN_CRC + (6 * LEN_DATA),
  //                        CRC_LSB     + LEN_CRC + (5 * LEN_DATA),
  //                        CRC_LSB     + LEN_CRC + (4 * LEN_DATA),
  //                        CRC_LSB     + LEN_CRC + (3 * LEN_DATA),
  //                        CRC_LSB     + LEN_CRC + (2 * LEN_DATA),
  //                        CRC_LSB     + LEN_CRC + (    LEN_DATA),
  //                        CRC_LSB     + LEN_CRC};
  parameter CRC_LSB     = EOF_LSB     + LEN_EOF;
  parameter EOF_LSB     = IFS_LSB     + LEN_IFS;
  parameter IFS_LSB     = 0;

  //the MSB locations of the various fields
  parameter STDADDR_MSB = STDADDR_LSB + LEN_STDADDR -1;
  parameter EXTADDR_MSB = EXTADDR_LSB + LEN_EXTADDR -1;
  parameter DLC_MSB     = DLC_LSB     + LEN_DLC     -1;
  parameter DATA_MSB    = DATA_LSB    + (8 * LEN_DATA) -1;
  //parameter [7:0] DATA_MSB [7:0]  = {
  //                        DATA_LSB[0] + LEN_DATA    -1,
  //                        DATA_LSB[1] + LEN_DATA    -1,
  //                        DATA_LSB[2] + LEN_DATA    -1,
  //                        DATA_LSB[3] + LEN_DATA    -1,
  //                        DATA_LSB[4] + LEN_DATA    -1,
  //                        DATA_LSB[5] + LEN_DATA    -1,
  //                        DATA_LSB[6] + LEN_DATA    -1,
  //                        DATA_LSB[7] + LEN_DATA    -1 };
  parameter CRC_MSB     = CRC_LSB     + LEN_CRC     -1;
  parameter EOF_MSB     = EOF_LSB     + LEN_EOF     -1;
  parameter IFS_MSB     = IFS_LSB     + LEN_IFS     -1;

  parameter HEAD = STDADDR_MSB;


  reg [HEAD:0] packet = 0;   //the packet captured so far, this gets broken into fields by assign operators
  reg [HEAD:0] selector = {1,{HEAD{0}}}; //the one-hot state selector (based on shift registers)

  assign dout = packet;
  //assign dout = selector;


  wire std_addressing;
  assign std_addressing = packet[IDE_LSB];
  
  wire rtr;
  assign rtr = std_addressing? packet [RTR_LSB]: packet [SRR_LSB];
  
  wire [LEN_DLC - 1:0] data_length;
  wire [LEN_DLC - 1:0] dlc_input;
  assign dlc_input = packet [DLC_MSB:DLC_LSB];
  //assign data_length = (dlc_input < 'd8) ? dlc_input : 'd8;
  assign data_length = 1;

  wire [LEN_STDADDR + LEN_EXTADDR -1 : 0] address;
  assign address = {packet[STDADDR_MSB:STDADDR_LSB],packet[EXTADDR_MSB:EXTADDR_LSB]};

  always @(posedge clk or posedge rst) begin
    if(rst) begin
      packet <= 0;
    end else begin
      if(en) begin
        //load the rx line into the appropriate bit of the packet:
        packet <= (selector & {HEAD+1{rx}}) | packet;
      //end else begin
      //  packet[131] <=1;    //HEAD = 131 
      end
    end
  end

  reg i;  //used in for loop
  //shift the selector on the negative edges of the baud clock so we have half a clock to run packet decoding. (particularly the data length field)
  always @(negedge clk or posedge rst) begin
    if(rst) begin
      selector[HEAD] <= 1;  //start with the first bit
      selector[HEAD-1:0] <= {HEAD{0}};  //and zeroes elsewhere
    end else begin
      if(en) begin
        //heaps of right shift operations:
        //selector [HEAD-1:IDE_LSB] <= selector [HEAD:SRR_LSB]; //up to and including the IDE bit
        selector [HEAD] <=0;
        selector [HEAD-1:IDE_LSB] <= selector [HEAD:IDE_LSB+1]; //up to and including the IDE bit

        if(std_addressing) begin
          selector [DLC_MSB] <= selector [IDE_LSB];       //not using extended addressing, skip to data length field (DLC)
          selector [DLC_MSB-1:DLC_LSB] <= selector [DLC_MSB:DLC_LSB +1];
        end else begin
          selector [EXTADDR_MSB : DLC_LSB] <= selector [IDE_LSB : DLC_LSB +1]; //shift the MSB extaddr down through the DLC
        end



        if(data_length == 0) begin
          selector [CRC_MSB] <= selector [DLC_LSB];
        end else begin  
          selector [DATA_MSB] <= selector [DLC_LSB];
          for (i = 0; i<64; i=i+1) begin
              selector [DATA_MSB - i -1] <= selector [DATA_MSB - i] & ((i+1)<(8*data_length));
          end
          //selector [DATA_MSB:DATA_MSB-(8)+1] <= selector [DLC_LSB:DATA_MSB-(8)+2];
          //selector [DATA_MSB:DATA_MSB-(64)+1] <= selector [DLC_LSB:DATA_MSB-(64)+2];
          //selector [DATA_MSB:DATA_MSB-(8*data_length)+1] <= selector [DLC_LSB:DATA_MSB-(8*data_length)+2];
          

          //mux the input to the CRC from the payload length
          selector [CRC_MSB] <= selector[DATA_MSB-(8*data_length)+1];
        
        end
        //generate
        //for (i = 0; i<7; i=i+1) begin
        //  //bit shift the selector through each data byte
        //  selector [DATA_MSB[i]-1:DATA_LSB[i]] <= selector [DATA_MSB[i]:DATA_LSB[i]+1];
        //  //shift to the next byte only if the payload is big enough
        //  selector [DATA_MSB[i+1]] <= selector [DATA_LSB[i]] & (data_length > i+1);
        //end

        //endgenerate
        //
        //selector [DATA_MSB[7]-1:DATA_LSB[7]] <= selector [DATA_MSB[7]:DATA_LSB[7]+1];
        
        //shift down through the CRC to the interframe space as normal
        selector [CRC_MSB-1:IFS_LSB] <= selector [CRC_MSB:IFS_LSB+1];

      end
    end
  end


endmodule






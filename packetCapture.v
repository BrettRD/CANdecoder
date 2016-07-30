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
    //output reg [7:0] count,    //the number of bits captured since rst.
    output [HEAD:0] dout,
    input ack,                 //external logic has requested an ack to the packet
    output tx                  //canTX line to ack
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
  parameter LEN_DATA    = 64;
  parameter LEN_CRC     = 15;
  parameter LEN_CRCDEL  =  1;
  parameter LEN_ACK     =  1;
  parameter LEN_ACKDEL  =  1;
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
  parameter DLC_LSB     = DATA_LSB    + LEN_DATA;
  parameter DATA_LSB    = CRC_LSB     + LEN_CRC;
  parameter CRC_LSB     = CRCDEL_LSB  + LEN_CRCDEL;
  parameter CRCDEL_LSB  = ACK_LSB     + LEN_ACK;
  parameter ACK_LSB     = ACKDEL_LSB  + LEN_ACKDEL;
  parameter ACKDEL_LSB  = EOF_LSB     + LEN_EOF;
  parameter EOF_LSB     = IFS_LSB     + LEN_IFS;
  parameter IFS_LSB     = 0;

  //the MSB locations of the various fields
  parameter STDADDR_MSB = STDADDR_LSB + LEN_STDADDR -1;
  parameter EXTADDR_MSB = EXTADDR_LSB + LEN_EXTADDR -1;
  parameter DLC_MSB     = DLC_LSB     + LEN_DLC     -1;
  parameter DATA_MSB    = DATA_LSB    + LEN_DATA    -1;
  parameter CRC_MSB     = CRC_LSB     + LEN_CRC     -1;
  parameter EOF_MSB     = EOF_LSB     + LEN_EOF     -1;
  parameter IFS_MSB     = IFS_LSB     + LEN_IFS     -1;

  parameter HEAD = STDADDR_MSB;

  //HEAD = 133.
  reg [HEAD:0] packet = 0;   //the packet captured so far, this gets broken into fields by assign operators
  reg [HEAD:0] selector = {1,{HEAD{0}}}; //the one-hot state selector (based on shift registers)

  assign dout = packet;

  wire std_addressing;
  assign std_addressing = packet[IDE_LSB];
  
  wire rtr;
  assign rtr = std_addressing? packet [RTR_LSB]: packet [SRR_LSB];
  
  wire [LEN_DLC - 1:0] data_length;
  wire [LEN_DLC - 1:0] dlc_input;
  assign dlc_input = packet [DLC_MSB:DLC_LSB];
  assign data_length = (dlc_input < 'd8) ? dlc_input : 'd8;

  //collect the address bits (extened with extention equal to zero is different to standard addressing)
  wire [LEN_STDADDR + LEN_EXTADDR + LEN_IDE -1 : 0] address;
  assign address = {packet[STDADDR_MSB:STDADDR_LSB], packet[IDE_LSB] ,packet[EXTADDR_MSB:EXTADDR_LSB]};

  //drive the ack bit at the right time. External logic can handle the address matching
  assign tx = selector[ACK_LSB] & ack;
  //real ones check that rx behaves itself when we drive ack

  always @(posedge clk or posedge rst) begin
    if(rst) begin
      packet <= 0;
    end else begin
      if(en) begin
        //load the rx line into the appropriate bit of the packet:
        packet <= (selector & {HEAD+1{rx}}) | packet;

        if(tx & !rx) begin
          //we've failed to deliver the ack to the bus, throw some kind of error flag
        end
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
          for (i = 0; i<LEN_DATA; i=i+1) begin
              //if statements use a whole lot more resources.
              selector [DATA_MSB - i -1] <= selector [DATA_MSB - i] & ((i+1)<(8*data_length));
          end

          //mux the input to the CRC from the payload length
          selector [CRC_MSB] <= selector[DATA_MSB-(8*data_length)+1];
        end
        
        //shift down through the CRC to the interframe space as normal
        selector [CRC_MSB-1:IFS_LSB] <= selector [CRC_MSB:IFS_LSB+1];

      end
    end
  end


endmodule






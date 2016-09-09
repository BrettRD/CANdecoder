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
    output tx,                 //canTX line to ack
    output reg stuffing,       //remove bit-stuffing
    output reg runCRC,         //count incoming bits for CRC
    output done,
    output ext_addressing,
    output [64] payload,
    output [LEN_STDADDR + LEN_IDE + LEN_EXTADDR] address
  );

  //the lengths of the various fields
  parameter LEN_SOF     =  1;
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
  parameter SOF_LSB     = STDADDR_LSB + LEN_STDADDR;  //134
  parameter STDADDR_LSB = SRR_LSB     + LEN_SRR;      //123
  parameter SRR_LSB     = IDE_LSB     + LEN_IDE;      //122
  parameter IDE_LSB     = EXTADDR_LSB + LEN_EXTADDR;  //121
  parameter EXTADDR_LSB = RTR_LSB     + LEN_RTR;      //103
  parameter RTR_LSB     = R1_LSB      + LEN_R1;       //102
  parameter R1_LSB      = R0_LSB      + LEN_R0;       //101
  parameter R0_LSB      = DLC_LSB     + LEN_DLC;      //100
  parameter DLC_LSB     = DATA_LSB    + LEN_DATA;     //96
  parameter DATA_LSB    = CRC_LSB     + LEN_CRC;      //32
  parameter CRC_LSB     = CRCDEL_LSB  + LEN_CRCDEL;   //17
  parameter CRCDEL_LSB  = ACK_LSB     + LEN_ACK;      //16
  parameter ACK_LSB     = ACKDEL_LSB  + LEN_ACKDEL;   //15
  parameter ACKDEL_LSB  = EOF_LSB     + LEN_EOF;      //14
  parameter EOF_LSB     = IFS_LSB     + LEN_IFS;      //7
  parameter IFS_LSB     = 0;                          //0

  //the MSB locations of the various fields
  parameter STDADDR_MSB = STDADDR_LSB + LEN_STDADDR -1;
  parameter EXTADDR_MSB = EXTADDR_LSB + LEN_EXTADDR -1;
  parameter DLC_MSB     = DLC_LSB     + LEN_DLC     -1;
  parameter DATA_MSB    = DATA_LSB    + LEN_DATA    -1;
  parameter CRC_MSB     = CRC_LSB     + LEN_CRC     -1;
  parameter EOF_MSB     = EOF_LSB     + LEN_EOF     -1;
  parameter IFS_MSB     = IFS_LSB     + LEN_IFS     -1;

  parameter HEAD = SOF_LSB;

  //HEAD = 134.
  reg [HEAD:0] packet = 0;   //the packet captured so far, this gets broken into fields by assign operators
  reg [HEAD:0] selector = {1,{HEAD{0}}}; //the one-hot state selector (based on shift registers)

  assign dout = packet;

  wire ext_addressing;
  assign ext_addressing = packet[IDE_LSB]; //IDE ==1 for extended addresses
  //assign ext_addressing = 1;  //testing
  
  wire rtr;
  assign rtr = ext_addressing? packet [RTR_LSB]: packet [SRR_LSB];
  
  wire [LEN_DLC - 1:0] data_length;
  wire [LEN_DLC - 1:0] dlc_input;
  assign dlc_input = packet [DLC_MSB:DLC_LSB];
  assign data_length = (dlc_input < 'd8) ? dlc_input : 'd8;
  //assign data_length =2;    //testing

  //collect the address bits (extened with extention equal to zero is different to standard addressing)
  assign address = {packet[STDADDR_MSB:STDADDR_LSB], packet[IDE_LSB] ,packet[EXTADDR_MSB:EXTADDR_LSB]};

  //drive the ack bit at the right time. External logic can handle the address matching
  assign tx = selector[ACK_LSB] & ack;

  assign done = selector[IFS_LSB];


  reg crcmsbD;  //allow halt of CRC updates prior to CRC reception

  //reg j;  //used in for loop
  always @(posedge clk or posedge rst) begin
    if(rst) begin
      //packet <= 0;
    end else begin
      if(en) begin
        //load the rx line into the appropriate bit of the packet:
        packet <= (selector & {HEAD+1{rx}}) | (~selector & packet); //not glitching 

        //for (j = 0; j<(HEAD+1); j=j+1) begin
        //  if(selector[j]) packet[j] <= rx;
        //end

        if(tx & ~rx) begin
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

      stuffing <= 0;
      runCRC <= 0;
    end else begin
      if(en) begin
        //heaps of right shift operations:
        selector [HEAD] <= 0;
        selector [HEAD-1:IDE_LSB] <= selector [HEAD:IDE_LSB+1]; //up to and including the IDE bit

        if(ext_addressing) begin
          selector [EXTADDR_MSB] <= selector [IDE_LSB]; //shift the MSB extaddr down through the DLC
          selector [R0_LSB] <= selector [R1_LSB];
        end else begin
          selector [R0_LSB] <= selector [IDE_LSB];       //not using extended addressing, skip to data length field (DLC)
        end

        //extended address bits skipped in normal addressing
        selector [EXTADDR_MSB-1 : EXTADDR_LSB] <= selector [EXTADDR_MSB : EXTADDR_LSB+1]; //shift the MSB extaddr down to the DLC
        selector [RTR_LSB] <= selector [EXTADDR_LSB];
        selector [R1_LSB] <= selector [RTR_LSB];

        //R0 and DLC are required
        selector [DLC_MSB] <= selector [R0_LSB];
        selector [DLC_MSB-1:DLC_LSB] <= selector [DLC_MSB:DLC_LSB +1];  //shift through the dlc

        //DATA_MSB -0 +1 == DLC_LSB
        for (i = 0; i<8; i=i+1) begin  //there are 8 data bytes
          //unconditional shifts within each byte
          selector [DATA_MSB - (8*i) -1: DATA_MSB - (8*(i+1))] <= selector [DATA_MSB - (8*i): DATA_MSB - (8*(i+1)) +1];
          //and a bunch of gated shifts into the MSB of each byte
          selector [DATA_MSB - (8*i)] <= selector [DATA_MSB - (8*i) +1] & ((data_length) > (i));
        end

        //the crc msb comes from the LSB of the byte where the gated shifts stop
        crcmsbD = selector[DATA_MSB-(8*data_length)+1];   //tmp variable for disabling the CRC unit
        selector [CRC_MSB] <= crcmsbD;
        
        //shift down through the CRC to the interframe space as normal
        selector [CRC_MSB-1:IFS_LSB] <= selector [CRC_MSB:IFS_LSB+1];


        //---------state outputs
        if(selector[STDADDR_LSB]) begin
          stuffing<=1;
          runCRC<=1;
        end

        if(selector[CRC_LSB]) begin  //stop after CRC
        //if(crcmsbD) begin  //stop before CRC
          runCRC<=0;
        end

        //disable the bit-stuffing for the end of frame space
        if(selector[ACKDEL_LSB]) begin
          stuffing<=0;
        end
      end
    end
  end


endmodule






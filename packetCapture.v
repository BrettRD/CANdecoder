/*
PacketCapture
Collect bits in an addressable mux.
Decode on the fly, advancing the bit selector according to the data in the RX buffer
decoded fields are output on assigned wires.
  

*/


module PacketCapture(
  input rst,                 //drive high to disable the baud clock, restart
  input clk,                 //a clock input to the baud counter, used for clock recovery
  input rx,                  //attach to an input edge to enable clock recovery
  input en,                  //enable count and capture.
  output reg [7:0] count     //the number of bits captured since rst.
  )

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
  parameter BIT_STDADDR = BIT_SRR     + LEN_SRR;
  parameter BIT_SRR     = BIT_IDE     + LEN_IDE;
  parameter BIT_IDE     = BIT_EXTADDR + LEN_EXTADDR;
  parameter BIT_EXTADDR = BIT_RTR     + LEN_RTR;
  parameter BIT_RTR     = BIT_R1      + LEN_R1;
  parameter BIT_R1      = BIT_R0      + LEN_R0;
  parameter BIT_R0      = BIT_DLC     + LEN_DLC;
  parameter BIT_DLC     = BIT_DATA[0] + LEN_DATA;
  parameter BIT_DATA [7:0] = {
    BIT_CRC + LEN_CRC + (7 * LEN_DATA),
    BIT_CRC + LEN_CRC + (6 * LEN_DATA),
    BIT_CRC + LEN_CRC + (5 * LEN_DATA),
    BIT_CRC + LEN_CRC + (4 * LEN_DATA),
    BIT_CRC + LEN_CRC + (3 * LEN_DATA),
    BIT_CRC + LEN_CRC + (2 * LEN_DATA),
    BIT_CRC + LEN_CRC + (1 * LEN_DATA),
    BIT_CRC + LEN_CRC }
  parameter BIT_CRC     = BIT_EOF     + LEN_EOF;
  parameter BIT_EOF     = BIT_IFS     + LEN_IFS;
  parameter BIT_IFS     = 0;

  //the MSB locations of the various fields
  parameter BIT_STDADDR_MSB = BIT_STDADDR + LEN_STDADDR -1;
  parameter BIT_EXTADDR_MSB = BIT_EXTADDR + LEN_EXTADDR -1;
  parameter BIT_DLC_MSB     = BIT_DLC     + LEN_DLC     -1;
  parameter BIT_DATA_MSB [7:0] = {
    BIT_DATA[0] + LEN_DATA -1,
    BIT_DATA[1] + LEN_DATA -1,
    BIT_DATA[2] + LEN_DATA -1,
    BIT_DATA[3] + LEN_DATA -1,
    BIT_DATA[4] + LEN_DATA -1,
    BIT_DATA[5] + LEN_DATA -1,
    BIT_DATA[6] + LEN_DATA -1,
    BIT_DATA[7] + LEN_DATA -1 }
  parameter BIT_CRC_MSB     = BIT_CRC     + LEN_CRC     -1;
  parameter BIT_EOF_MSB     = BIT_EOF     + LEN_EOF     -1;
  parameter BIT_IFS_MSB     = BIT_IFS     + LEN_IFS     -1;




  reg [BIT_STDADDR_MSB:0] packet;   //the packet captured so far, this gets broken into fields by assign operators
  reg [BIT_HEAD:0] selector; //the one-hot state selector (based on shift registers)


  assign wire std_addressing = packet [BIT_IDE];
  assign wire rtr = std_addressing? packet [BIT_RTR]: packet [BIT_SRR];
  assign wire [LEN_DLC - 1:0] data_length = packet [BIT_DLC + LEN_DLC - 1:BIT_DLC];
  assign wire [LEN_STDADDR + LEN_EXTADDR -1 : 0] address = {packet[BIT_STDADDR_MSB:BIT_STDADDR],packet[BIT_EXTADDR_MSB:BIT_EXTADDR]}


  always @(posedge clk or posedge rst) begin
    if(rst) begin
      packet <= 0;
    end else begin
      if(en) begin
        //load the rx line into the appropriate bit of the packet:
        packet <= (selector & {BIT_HEAD+1{rx}}) | packet;

      end
    end
  end


  //shift the selector on the negative edges of the baud clock so we have half a clock to run packet decoding. (particularly the data length field)
  always @(negedge clk or posedge rst) begin
    if(rst) begin
      selector[BIT_HEAD-1:BIT_IFS] <= 0;
      selector[BIT_HEAD] <= 1;
    end else begin
      if(en) begin
        //heaps of right shift operations:
        selector [BIT_HEAD-1:IDE] <= selector [BIT_HEAD:SRR]; //up to and including the IDE bit

        selector [BIT_EXTADDR_MSB] <= selector [BIT_IDE] & !std_addressing;  //using extended addressing, shift through extaddr msb
        selector [BIT_DLC_MSB] <= selector [BIT_IDE] & std_addressing;           //not using extended addressing, skip to data_length

        selector [BIT_EXTADDR_MSB -1 : BIT_DLC] <= selector [BIT_EXTADDR_MSB : BIT_DLC +1]; //shift the MSB extaddr down through the DLC

        selector [BIT_DATA_MSB[0]] <= selector [BIT_DLC] & (data_length > 0);
        genvar i;
        generate for (i = 0; i<7; i=i+1) begin
          //bit shift the selector through each data byte
          selector [BIT_DATA_MSB[i]-1:BIT_DATA[i]] <= selector [BIT_DATA_MSB[i]:BIT_DATA[i]+1];
          //shift to the next byte only if the payload is big enough
          selector [BIT_DATA_MSB[i+1]] <= selector [BIT_DATA[i]] & (data_length > i+1);
        end
        //
        selector [BIT_DATA_MSB[7]-1:BIT_DATA[7]] <= selector [BIT_DATA_MSB[7]:BIT_DATA[7]+1];
        //mux the input to the CRC from the payload length
        selector [BIT_CRC_MSB] <= selector [BIT_DATA[data_length]];
        
        //shift down through the CRC to the interframe space as normal
        selector [BIT_CRC_MSB-1:BIT_IFS] <= selector [BIT_CRC_MSB:BIT_IFS+1];

      end
    end
  end


endmodule





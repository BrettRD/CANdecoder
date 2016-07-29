/*
CANdecoder
run this module live on the captured pakcet.
This module is meant to be a combinatorial-only CAN packet decoder.
Make sure the MSB of the address is suitably aligned.




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
  
  parameter LEN_ADDR = LEN_STDADDR + LEN_EXTADDR;
  parameter LEN_EXT_OFFSET = LEN_EXTADDR + LEN_RTR + LEN_R1 + LEN_R0;

  //the LSB locations of the various fields
  parameter BIT_STDADDR = BIT_SRR     + LEN_SRR;
  parameter BIT_SRR     = BIT_IDE     + LEN_IDE;
  parameter BIT_IDE     = BIT_EXTADDR + LEN_EXTADDR;
  parameter BIT_EXTADDR = BIT_RTR     + LEN_RTR;
  parameter BIT_RTR     = BIT_R1      + LEN_R1;
  parameter BIT_R1      = BIT_R0      + LEN_R0;
  parameter BIT_R0      = BIT_DLC     + LEN_DLC;
  parameter BIT_DLC     = BIT_DATA[0] + LEN_DATA;
  parameter BIT_DATA [7:0] = '{
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
  parameter BIT_DATA_MSB [7:0] = '{
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






//

*/





module CANdecoder(
  input packet [132:0],
  input count [7:0],
  output addressValid,    //the whole address has been captured
  )

  assign wire std_addressing = packet[packet[BIT_IDE]];
  wire [LEN_ADDR-1:0] address;
  wire rtr;
  wire [LEN_DLC-1:0] data_length;
  wire [LEN_CRC-1:0] crc;
  wire [LEN_DATA-1:0] data [7:0];
  wire eof;
  wire ifs;

  assign address = {LEN_EXTADDR{0}, packet[BIT_STDADDR_MSB:BIT_STDADDR]}  : {packet[BIT_STDADDR_MSB:BIT_STDADDR],packet[BIT_EXTADDR_MSB:BIT_EXTADDR]};
  wire rtr
  always @(*) begin
    if(std_addressing) begin
      address = address = {LEN_EXTADDR{0}, packet[BIT_STDADDR_MSB:BIT_STDADDR]};
      rtr = packet[BIT_SRR];
      data_length = packet[BIT_DLC_MSB - LEN_EXT_OFFSET : BIT_DLC - LEN_EXT_OFFSET];
      
      genvar i;
      generate for(i=0;i<8;i++) begin
        data[i] = (i<data_length) ? packet[BIT_DATA_MSB[i] - LEN_EXT_OFFSET : BIT_DATA[i] - LEN_EXT_OFFSET] : 0;
      end
      {crc,eof,ifs} = packet[BIT_CRC_MSB - LEN_EXT_OFFSET + (8*data_length):BIT_IFS - LEN_EXT_OFFSET + (8*data_length)];

    end else begin

      address = {packet[BIT_STDADDR_MSB:BIT_STDADDR],packet[BIT_EXTADDR_MSB:BIT_EXTADDR]};
      rtr = packet[BIT_RTR];
      data_length = packet[BIT_DLC_MSB:BIT_DLC];
      genvar i;
      generate for(i=0;i<8;i++) begin
        data[i] = (i<data_length) ? packet[BIT_DATA_MSB[i]:BIT_DATA[i]] : 0;
      end

      {crc,eof,ifs} = packet[BIT_CRC_MSB + (8*data_length):BIT_IFS + (8*data_length)];

    end
  end
  
  assign srr = packet[131-12];
  assign rtr = (ide==1? packet[131-12] : packet[131-32]);
  assign ide = packet[131-13];
  assign address[17:0] = (ide==1? 0: packet[131-14:131-31]);




endmodule
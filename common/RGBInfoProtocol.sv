// SPDX-License-Identifier: BSD-3-Clause
/*
 * RGBInfoProtocol - A serial protocol to execute video timing measurements and report back with the measurement data
 *
 * Copyright (C) 2023 Luís Mendes <luis.p.mendes@gmail.com>
 */
module RGBInfoProtocol #(parameter CLKFreq=27000000.0, parameter CommsTimeout = 10, parameter ErrorDelay = 2000) //Timeout and delay in ms
(clk, dataValidRxStrobe, dataRx, dataToTx, dataTxStart, dataTxActive, dataTxDone, decodedNibble, nibbleError, 
 serialError,
 reset, complete, hasDE,
 counterFrame, counterHS, counterVS, counterDE, counterLines, counterFrameLines, counterColumns, counterBPH, counterBPV, counterFPH,
 counterFPV, counterVgaFPV, counterVgaBPV, counterVgaBPHEnd, counterVgaFPHStart, counterVgaFPHEnd
);

input  logic        clk;
input  logic        dataValidRxStrobe;
input  logic  [7:0] dataRx;
output logic  [7:0] dataToTx;
output logic        dataTxStart;
input  logic        dataTxActive;
input  logic        dataTxDone;
input  logic  [3:0] decodedNibble;
input  logic        nibbleError;
output logic        serialError;
output logic        reset;
input  logic        complete;
input  logic        hasDE;
input  logic [19:0] counterFrame;
input  logic [11:0] counterHS;
input  logic [15:0] counterVS;
input  logic [11:0] counterDE;
input  logic [11:0] counterLines;
input  logic [11:0] counterFrameLines;
input  logic [11:0] counterColumns;
input  logic [11:0] counterBPH;
input  logic [11:0] counterBPV;
input  logic [11:0] counterFPH;
input  logic [11:0] counterFPV;
input  logic [11:0] counterVgaFPV;
input  logic [11:0] counterVgaBPV;
input  logic [11:0] counterVgaBPHEnd;
input  logic [11:0] counterVgaFPHStart;
input  logic [11:0] counterVgaFPHEnd;

initial dataTxStart = 1'b0;
initial serialError = 1'b0;
initial reset = 1'b1;

localparam integer unsigned CYCLES_CommsTimeout = $ceil(CommsTimeout/1000.0 * CLKFreq);
localparam integer unsigned CYCLES_ErrorDelay =  $ceil(ErrorDelay/1000.0 * CLKFreq);
localparam integer unsigned BITS_CommsTimeout = $clog2(CYCLES_CommsTimeout);
localparam integer unsigned BITS_ErrorDelay = $clog2(CYCLES_ErrorDelay);
localparam integer unsigned ZERO_CommsTimeout = {BITS_CommsTimeout{1'b0}};
localparam integer unsigned ONE_CommsTimeout = {{(BITS_CommsTimeout-1){1'b0}}, 1'b1};
localparam integer unsigned ZERO_ErrorDelay = {BITS_ErrorDelay{1'b0}};
localparam integer unsigned ONE_ErrorDelay =  {{(BITS_ErrorDelay-1){1'b0}}, 1'b1};

localparam s_CMD_WAIT      = 3'b000;
localparam s_CMD_MEASURE   = 3'b001;
localparam s_CMD_READ      = 3'b010;
localparam s_CMD_SEND      = 3'b011;
localparam s_CMD_ACK       = 3'b110;
localparam s_CMD_ERROR     = 3'b111;

localparam s_INNER_00 = 5'b00000;
localparam s_INNER_01 = 5'b00001;
localparam s_INNER_02 = 5'b00010;
localparam s_INNER_03 = 5'b00011;
localparam s_INNER_04 = 5'b00100;
localparam s_INNER_05 = 5'b00101;
localparam s_INNER_06 = 5'b00110;
localparam s_INNER_07 = 5'b00111;
localparam s_INNER_08 = 5'b01000;
localparam s_INNER_09 = 5'b01001;
localparam s_INNER_10 = 5'b01010;
localparam s_INNER_11 = 5'b01011;
localparam s_INNER_12 = 5'b01100;
localparam s_INNER_13 = 5'b01101;
localparam s_INNER_14 = 5'b01110;
localparam s_INNER_15 = 5'b01111;
localparam s_INNER_16 = 5'b10000;
localparam s_INNER_17 = 5'b10001;
localparam s_INNER_18 = 5'b10010;
localparam s_INNER_19 = 5'b10011;
localparam s_INNER_20 = 5'b10100;
localparam s_INNER_21 = 5'b10101;

localparam CR = 8'h0d;
localparam LF = 8'h0a;

logic [2:0]  statesCMD     = 3'b000;
logic [4:0]  statesINNER   = 5'b00000;
logic [3:0]  counter       = 4'b0000;
logic [7:0]  cmdReceived   = "Z";
logic [3:0]  nibbleIndex   = 3'b000;
logic [7:0]  nibbleChar;
logic [19:0] nibbleData;
logic [3:0]  nibbleToEncode;
logic        nibbleSent    = 1'b0;

assign nibbleToEncode = nibbleIndex[2] ? nibbleData[3:0] : (nibbleIndex[1] ? (nibbleIndex[0] ? nibbleData[7:4] : nibbleData[11:8]) : (nibbleIndex[0] ? nibbleData[15:12] : nibbleData[19:16]));

hexEncoderUnit myHexEncoder(
   .nibble(nibbleToEncode),
   .nibbleChar(nibbleChar)
) /* synthesis syn_noprune = 1 */ ;

logic errorDelayReset = 1'b1;
logic [BITS_ErrorDelay-1:0] errorDelayCounter = ZERO_ErrorDelay;
logic errorDelayFlag = 1'b0;
//
logic commsTimeoutReset = 1'b1;
logic [BITS_CommsTimeout-1:0] commsTimeoutCounter = ZERO_CommsTimeout;
logic commsTimeoutFlag = 1'b0;

always @(posedge clk)
begin
   if (commsTimeoutReset)
   begin
      commsTimeoutCounter <= ZERO_CommsTimeout;
      commsTimeoutFlag = 1'b0;
   end
   else
   begin
      if (commsTimeoutCounter < CYCLES_CommsTimeout)
      begin
         commsTimeoutCounter <= commsTimeoutCounter + ONE_CommsTimeout;
      end
      else
      begin
         commsTimeoutFlag = 1'b1;
      end
  end
end

always @(posedge clk)
begin
   if (errorDelayReset)
   begin
      errorDelayCounter = ZERO_ErrorDelay;
      errorDelayFlag = 1'b0;
   end
   else
   begin
      if (errorDelayCounter < CYCLES_ErrorDelay)
      begin
         errorDelayCounter <= errorDelayCounter + ONE_ErrorDelay;
      end
      else
      begin
         errorDelayFlag = 1'b1;
      end
  end
end

always @(posedge clk)
begin
   if (dataTxActive)
   begin
      dataTxStart <= 1'b0;
   end

   unique case (statesCMD)
   s_CMD_WAIT:
   begin        
      commsTimeoutReset = 1'b1;
      errorDelayReset = 1'b1;
      counter <= 4'b0000;
      if (dataValidRxStrobe)          
      begin
         cmdReceived <= dataRx;
         statesINNER <= s_INNER_00;
         unique case (dataRx)             
            "M": 
            begin
               statesCMD <= s_CMD_MEASURE;
            end

            "R": 
            begin
               statesCMD <= s_CMD_READ;
            end

            default:
            begin
               statesCMD <= s_CMD_ERROR;
            end
         endcase
      end
   end

   s_CMD_MEASURE:
   begin
      commsTimeoutReset = 1'b1;
      errorDelayReset = 1'b0;
      if (errorDelayReset)
      begin
         statesINNER <= s_INNER_00;
         statesCMD <= s_CMD_ERROR;
      end
      else
      begin
         unique case (statesINNER)
         s_INNER_00:
         begin
            reset <= 1'b1;
            if (counter < 15)
               counter <= counter + 4'b0001;
            else
            begin
               statesINNER <= s_INNER_01;
               counter <= 4'b0000;
               reset <= 1'b0;
            end
         end

         s_INNER_01:
         begin
            if (complete)
            begin          
               statesINNER <= s_INNER_00;
               statesCMD <= s_CMD_ACK;
            end
         end

         default:
         begin
            statesINNER <= s_INNER_00;
            statesCMD <= s_CMD_ERROR;
         end
         endcase
      end
   end

   s_CMD_READ:
   begin
      commsTimeoutReset = 1'b1;
      errorDelayReset = 1'b1;

      unique case (statesINNER)
      s_INNER_00:
      begin
         if (!complete)
         begin
            statesCMD <= s_CMD_ERROR;
         end
         else
            statesINNER <= s_INNER_01;      
      end

      s_INNER_01:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= hasDE ? "1" : "0";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_02;
         end
      end         

      s_INNER_02:
      begin          
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= ",";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_03;
         end
      end

      s_INNER_03:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_04;
         nibbleData <= counterFrame;
         counter <= 5;
         nibbleIndex <= 0;
      end

      s_INNER_04:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_05;
         nibbleData <= {{8{1'b0}}, counterHS};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_05:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_06;
         nibbleData <= {{4{1'b0}}, counterVS};
         counter <= 5;
         nibbleIndex <= 1;
      end

      s_INNER_06:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_07;
         nibbleData <= {{8{1'b0}}, counterDE};
         counter <= 5;
         nibbleIndex <= 2;
      end
      
      s_INNER_07:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_08;
         nibbleData <= {{8{1'b0}}, counterLines};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_08:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_09;
         nibbleData <= {{8{1'b0}}, counterFrameLines};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_09:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_10;
         nibbleData <= {{8{1'b0}}, counterColumns};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_10:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_11;
         nibbleData <= {{8{1'b0}}, counterBPH};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_11:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_12;
         nibbleData <= {{8{1'b0}}, counterBPV};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_12:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_13;
         nibbleData <= {{8{1'b0}}, counterFPH};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_13:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_14;
         nibbleData <= {{8{1'b0}}, counterFPV};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_14:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_15;
         nibbleData <= {{8{1'b0}}, counterVgaFPV};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_15:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_16;
         nibbleData <= {{8{1'b0}}, counterVgaBPV};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_16:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_17;
         nibbleData <= {{8{1'b0}}, counterVgaBPHEnd};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_17:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_18;
         nibbleData <= {{8{1'b0}}, counterVgaFPHStart};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_18:
      begin
         statesCMD <= s_CMD_SEND;
         statesINNER <= s_INNER_19;
         nibbleData <= {{8{1'b0}}, counterVgaFPHEnd};
         counter <= 5;
         nibbleIndex <= 2;
      end

      s_INNER_19:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= CR;
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_20;
         end
      end

      s_INNER_20:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= LF;
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_21;
         end
      end

      s_INNER_21:
      begin
         statesINNER <= s_INNER_00;
         statesCMD <= s_CMD_ACK;
      end

      default:
      begin
         statesINNER <= s_INNER_00;
         statesCMD <= s_CMD_ERROR;
      end

      endcase
   end

   s_CMD_ACK:
   begin
      //Send ACK\r\n
      commsTimeoutReset = 1'b1;
      errorDelayReset = 1'b1;

      unique case (statesINNER)
      s_INNER_00:
      begin      
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= "A";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_01;
         end         
      end

      s_INNER_01:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= "C";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_02;
         end         
      end

      s_INNER_02:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= "K";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_03;
         end
      end

      s_INNER_03:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= CR;
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_04;
         end
      end

      s_INNER_04:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= LF;
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_05;
         end
      end

      s_INNER_05:
      begin
         statesINNER <= s_INNER_00;
         statesCMD <= s_CMD_WAIT;
      end

      default:
      begin
         statesINNER <= s_INNER_00;
         statesCMD <= s_CMD_ERROR;
      end
      endcase
   end

   s_CMD_SEND:
   begin
      if (nibbleIndex < counter)
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= nibbleChar;
            dataTxStart <= 1'b1;
            nibbleSent <= 1'b1;          
         end
         else if (nibbleSent)
         begin
            nibbleIndex <= nibbleIndex + 3'b001;
            nibbleSent <= 1'b0;
         end
      end
      else if (nibbleIndex == counter)
      begin
         if (statesINNER < s_INNER_19)
         begin
            if (!dataTxActive && !dataTxStart)
            begin
               dataToTx <= ",";
               dataTxStart <= 1'b1;
               nibbleSent <= 1'b1;
            end
            else if (nibbleSent)
            begin
               nibbleIndex <= nibbleIndex + 3'b001;
               nibbleSent <= 1'b0;
            end
         end
         else
            nibbleIndex <= nibbleIndex + 3'b001;
      end
      else
      begin
         nibbleIndex <= 0;
         statesCMD <= s_CMD_READ;
      end
   end

   s_CMD_ERROR:
   begin
      //Send NAK\r\n
      commsTimeoutReset = 1'b1;
      errorDelayReset = 1'b0;

      unique case (statesINNER)
      s_INNER_00:
      begin      
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= "N";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_01;
         end         
      end

      s_INNER_01:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= "A";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_02;
         end         
      end

      s_INNER_02:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= "K";
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_03;
         end
      end

      s_INNER_03:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= CR;
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_04;
         end
      end

      s_INNER_04:
      begin
         if (!dataTxActive && !dataTxStart)
         begin
            dataToTx <= LF;
            dataTxStart <= 1'b1;
            statesINNER <= s_INNER_05;
         end
      end

      s_INNER_05:
      begin
         serialError = 1'b1;
         statesINNER <= s_INNER_06;
         errorDelayReset = 1'b0;
      end

      s_INNER_06:
      begin
         if (errorDelayFlag)
         begin
            serialError = 1'b0;
            statesCMD <= s_CMD_WAIT;
            statesINNER <= s_INNER_00;
         end
      end

      default:
      begin
         serialError = 1'b1;
         statesINNER <= s_INNER_15;
      end
      endcase
   end

   default:
   begin
      statesCMD <= s_CMD_ERROR;
      statesINNER <= s_INNER_00;
   end

   endcase
end

endmodule
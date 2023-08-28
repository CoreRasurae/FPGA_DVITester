-------------------------------------------------------------------------------
--
-- File: OutputSERDES.vhd
-- Author: Elod Gyorgy, Mihaita Nagy
-- Original Project: HDMI output on 7-series Xilinx FPGA
-- Date: 28 October 2014
--
-------------------------------------------------------------------------------
-- (c) 2014 Copyright Digilent Incorporated
-- All Rights Reserved
-- 
-- This program is free software; distributed under the terms of BSD 3-clause 
-- license ("Revised BSD License", "New BSD License", or "Modified BSD License")
--
-- Redistribution and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
-- 3. Neither the name(s) of the above-listed copyright holder(s) nor the names
--    of its contributors may be used to endorse or promote products derived
--    from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE 
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-------------------------------------------------------------------------------
--
-- Purpose:
-- This module instantiates the Xilinx 7-series primitives necessary for
-- serializing the TMDS data stream. 
--  
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

library gw2a;
use gw2a.components.all;

entity OutputSERDES is
   Port (
      PixelClk : in STD_LOGIC;   --TMDS clock x1 (CLKDIV)
      SerialClk : in STD_LOGIC;  --TMDS clock x5 (CLK)
      
      --Encoded serial data
      sDataOut_p : out STD_LOGIC;
      sDataOut_n : out STD_LOGIC;
      
      --Encoded parallel data (raw)
      pDataOut : in STD_LOGIC_VECTOR (9 downto 0);
      
      aRst : in STD_LOGIC);
end OutputSERDES;

architecture Behavioral of OutputSERDES is

signal sDataOut : std_logic;
signal pDataOut_q : std_logic_vector(13 downto 0);
begin



-- Differential output buffer for TMDS I/O standard 
OutputBuffer : ELVDS_OBUF
    port map (
		I => sDataOut,
		O =>sDataOut_p,
		OB => sDataOut_n
	);

Serializer : OSER10
port map (
  Q => sDataOut,
  D0 => pDataOut_q(13),
  D1 => pDataOut_q(12),
  D2 => pDataOut_q(11),
  D3 => pDataOut_q(10),
  D4 => pDataOut_q(9),
  D5 => pDataOut_q(8),
  D6 => pDataOut_q(7),
  D7 => pDataOut_q(6),
  D8 => pDataOut_q(5),
  D9 => pDataOut_q(4),
  PCLK => PixelClk,
  FCLK => SerialClk,
  RESET => aRst);


------------------------------------------------------------- 
-- Concatenate the serdes inputs together. Keep the timesliced
-- bits together, and placing the earliest bits on the right
-- ie, if data comes in 0, 1, 2, 3, 4, 5, 6, 7, ...
-- the output will be 3210, 7654, ...
-------------------------------------------------------------   
SliceOSERDES_q: for slice_count in 0 to 9 generate begin
   --DVI sends least significant bit first 
   --OSERDESE2 sends D1 bit first
   pDataOut_q(14-slice_count-1) <= pDataOut(slice_count);
end generate SliceOSERDES_q;

end Behavioral;

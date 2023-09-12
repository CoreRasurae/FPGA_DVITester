-- SPDX-License-Identifier: BSD-3-Clause
--
-- Asynchronous Reset with metastability compensation
--
-- Copyright (C) 2023 Luís Mendes
--
--
-- When the capture is completed the signal "complete" goes high
-- Relevant signals to capture are:
-- signal "counterFrame"      : Total number of clock cycles in an image frame
-- signal "counterHS"         : Total number of clock cycles in a horizontal sync
-- signal "counterVS"         : Total number of clock cycles in a vertical sync
-- signal "counterDE"         : Total number of clock cycles with data enable active (aka: valid image pixels) (only if DE signal is available, 0 otherwise)
-- signal "counterLines"      : Total number of image lines in a frame (only if DE signal is available, 0 otherwise)
-- signal "counterFrmLines"   : Total number of lines in a frame
-- signal "counterColumns"    : Total number of clock cycles/columns in an image line (includes FPH + Pixels_H + BPH, but excludes HS)  
-- signal "counterBPH"        : Total number of clock cycles for the Horizontal Back Porch (only if DE signal is available, 0 otherwise)
-- signal "counterBPV"        : Total number of lines for the Vertical Back Porch (only if DE signal is available, 0 otherwise)
-- signal "counterFPH"        : Total number of clock cycles for the Horizontal Front Porch (only if DE signal is available, 0 otherwise)
-- signal "counterFPV"        : Total number of lines for the Vertical Front Porch (only if DE signal is available, 0 otherwise)
-- signal "counterVgaFPV"     : Total number of lines estimated for the Vertical Front Porch 
----                            (works even if DE signal is not available, provided it is a VGA signal)
-- signal "counterVgaBPV"     : Total number of lines estimated for the Vertical Back Porch 
----                            (works even if DE signal is not available, provided it is a VGA signal)
-- signal "counterVgaBPHEnd"  : Total number of cycles for the estimated Horizontal Back Porch by analyzing all the image lines in a given frame 
-- signal "counterVgaFPHStart": Total number of cycles for the estimated Horizontal Front Porch start clock cycle offset in a line
----                            (by analyzing all the image lines in a given frame )
----                            NOTE: To obtain the estimated pixels in an image line, do: counterVgaFPHStart - counterVgaBPHEnd = vgaPixels_H
----                            NOTE: To obtain the estimated VgaFPH in an image line, do: counterColumns - counterVgaFPHStart = vgaFPH
-- signal "counterVgaFPHEnd"  : Total number of cycles for the estimated horizontal line, excluding horizontal sync (alternate method to the above)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RGB_Debug is
  generic (
    HasDELine  : boolean := true
  );
  port (
    RESET      : in std_logic;
    VGA_CLK    : in std_logic;
    VGA_HS     : in std_logic;             -- Active low
    VGA_VS     : in std_logic;             -- Active low
    VGA_DE     : in std_logic;
    VGA_R      : in unsigned(7 downto 0);
    VGA_G      : in unsigned(7 downto 0);
    VGA_B      : in unsigned(7 downto 0)
    );
  
end RGB_Debug;

architecture rtl of RGB_Debug is
    signal last_hs     : std_logic := '0';
    signal last_vs     : std_logic := '0';
    signal last_de     : std_logic := '0';
    signal preStart    : std_logic := '0'; -- Allow the first clock cycle to capture the initial signal condition
    signal start       : std_logic := '0';
    signal complete    : std_logic := '0';
    signal readyBPH    : std_logic := '0';
    --
    signal doneFrame : std_logic := '0';
    signal doneHS : std_logic := '0';
    signal doneVS : std_logic := '0';
    signal doneDE : std_logic := '0';
    signal doneLines : std_logic := '0';
    signal doneFrmLines : std_logic := '0';
    signal doneColumns : std_logic := '0';
    signal doneBPH : std_logic := '0';
    signal doneBPV : std_logic := '0';
    signal doneFPH : std_logic := '0';
    signal doneFPV : std_logic := '0';
    signal doneVgaFPV : std_logic := '0';
    signal doneVgaBPV : std_logic := '0';
    signal doneVgaFPHStart : std_logic := '0';
    signal doneVgaFPHEnd : std_logic := '0';
    signal doneVgaBPHEnd : std_logic := '0';
    --
    signal countingFrame : std_logic := '0';
    signal countingHS  : std_logic := '0';
    signal countingVS  : std_logic := '0';
    signal countingDE  : std_logic := '0';
    signal countingLines : std_logic := '0';
    signal countingFrmLines: std_logic := '0';
    signal countingColumns : std_logic := '0';
    signal countingBPH : std_logic := '0';
    signal countingBPV : std_logic := '0';
    signal countingFPH : std_logic := '0';
    signal countingFPV : std_logic := '0';
    signal countingVgaFPV : std_logic := '0';
    signal countingVgaBPV : std_logic := '0';
    signal countingVgaFPHStart : std_logic := '0';
    signal countingVgaFPHEnd : std_logic := '0';
    signal countingVgaBPHEnd : std_logic := '0';
    --
    -------------------------------------------------------------
    -- Relevant signals for GAO analyzer or other data capture --
    -------------------------------------------------------------
    -- Total number of clock cycles in an image frame
    signal counterFrame: std_logic_vector(19 downto 0);
    -- Total number of clock cycles in a horizontal sync
    signal counterHS   : std_logic_vector(11 downto 0);
    -- Total number of clock cycles in a vertical sync
    signal counterVS   : std_logic_vector(15 downto 0);
    -- Total number of clock cycles with data enable active (aka: valid image pixels) (only if DE signal is available, 0 otherwise)
    signal counterDE   : std_logic_vector(11 downto 0);
    -- Total number of image lines in a frame (only if DE signal is available, 0 otherwise)
    signal counterLines: std_logic_vector(11 downto 0);
    -- Total number of lines in a frame
    signal counterFrmLines : std_logic_vector(11 downto 0);
    -- Total number of clock cycles/columns in an image line (includes FPH + Pixels_H + BPH, but excludes HS)  
    signal counterColumns: std_logic_vector(11 downto 0); 
    -- Total number of clock cycles for the Horizontal Back Porch (only if DE signal is available, 0 otherwise)
    signal counterBPH : std_logic_vector(11 downto 0);
    -- Total number of lines for the Vertical Back Porch (only if DE signal is available, 0 otherwise)
    signal counterBPV : std_logic_vector(11 downto 0);
    -- Total number of clock cycles for the Horizontal Front Porch (only if DE signal is available, 0 otherwise)
    signal counterFPH : std_logic_vector(11 downto 0);
    -- Total number of lines for the Vertical Front Porch (only if DE signal is available, 0 otherwise)
    signal counterFPV : std_logic_vector(11 downto 0);
    -- Total number of lines estimated for the Vertical Front Porch 
    -- (works even if DE signal is not available, provided it is a VGA signal)
    signal counterVgaFPV : std_logic_vector(11 downto 0);
    -- Total number of lines estimated for the Vertical Back Porch 
    -- (works even if DE signal is not available, provided it is a VGA signal)
    signal counterVgaBPV : std_logic_vector(11 downto 0);
    -- Total number of cycles for the estimated Horizontal Back Porch by analyzing all the image lines in a given frame 
    signal counterVgaBPHEnd : std_logic_vector(11 downto 0);
    -- Total number of cycles for the estimated Horizontal Front Porch start clock cycle offset in a line
    -- (by analyzing all the image lines in a given frame )
    -- NOTE: To obtain the estimated pixels in an image line, do: counterVgaFPHStart - counterVgaBPHEnd = vgaPixels_H
    -- NOTE: To obtain the estimated VgaFPH in an image line, do: counterColumns - counterVgaFPHStart = vgaFPH
    signal counterVgaFPHStart : std_logic_vector(11 downto 0);
    -- Total number of cycles for the estimated horizontal line, excluding horizontal sync (alternate method to the above)
    signal counterVgaFPHEnd : std_logic_vector(11 downto 0);
    --
    --Helper signals for the VgaBPHEnd and VgaFPHStart information
    signal lastDataValid : std_logic := '0';
    signal dataValid : std_logic;
    signal readyVgaFPHEnd : std_logic := '0';
    signal partialCounterVgaBPHEnd : std_logic_vector(11 downto 0);
    signal partialCounterVgaFPHStart : std_logic_vector(11 downto 0);
begin

dataValid <= VGA_R(7) or VGA_R(6) or VGA_R(5) or VGA_R(4) or VGA_R(3) or VGA_R(2) or VGA_R(1) or VGA_R(0) or
             VGA_G(7) or VGA_G(6) or VGA_G(5) or VGA_G(4) or VGA_G(3) or VGA_G(2) or VGA_G(1) or VGA_G(0) or
             VGA_B(7) or VGA_B(6) or VGA_B(5) or VGA_B(4) or VGA_B(3) or VGA_B(2) or VGA_B(1) or VGA_B(0);

process(vga_clk, RESET)
begin
   if RESET then
      preStart <= '0'; -- Allow the first clock cycle to capture the initial signal condition
      start    <= '0';
      readyBPH <= '0';
      readyVgaFPHEnd <= '0';
      --
      doneFrame       <= '0';
      doneHS          <= '0';
      doneVS          <= '0';
      doneDE          <= '0';
      doneLines       <= '0';
      doneFrmLines    <= '0';
      doneColumns     <= '0';
      doneBPH         <= '0';
      doneBPV         <= '0';
      doneFPH         <= '0';
      doneFPV         <= '0';
      doneVgaFPV      <= '0';
      doneVgaBPV      <= '0';
      doneVgaFPHStart <= '0';
      doneVgaFPHEnd   <= '0';
      doneVgaBPHEnd   <= '0';
      --
      countingFrame       <= '0';
      countingHS          <= '0';
      countingVS          <= '0';
      countingDE          <= '0';
      countingLines       <= '0';
      countingFrmLines    <= '0';
      countingColumns     <= '0';
      countingBPH         <= '0';
      countingBPV         <= '0';
      countingFPH         <= '0';
      countingFPV         <= '0';
      countingVgaFPV      <= '0';
      countingVgaBPV      <= '0';
      countingVgaFPHStart <= '0';
      countingVgaFPHEnd   <= '0';
      countingVgaBPHEnd   <= '0';
      --
      -- This is probably not needed, since the counters are likely initalized before being incremented
      -- however, just to be on the safe side, in case it happens that some counter is not reset, in
      -- the code below.
      counterFrame    <= (19 downto 0 => '0');
      counterHS       <= (11 downto 0 => '0');
      counterVS       <= (15 downto 0 => '0');
      counterDE       <= (11 downto 0 => '0');
      counterLines    <= (11 downto 0 => '0');
      counterFrmLines <= (11 downto 0 => '0');
      counterColumns  <= (11 downto 0 => '0');
      counterBPH      <= (11 downto 0 => '0');
      counterBPV      <= (11 downto 0 => '0');
      counterFPH      <= (11 downto 0 => '0');
      counterFPV      <= (11 downto 0 => '0');
   elsif rising_edge(vga_clk) then
      last_vs <= vga_vs;
      last_hs <= vga_hs;
      last_de <= vga_de;
      lastDataValid <= dataValid;
      preStart <= '1'; -- After this first clock cycle, the data analysis can start
      if (not complete and preStart) then
         if (countingVgaBPHEnd and not doneVgaBPHEnd) then
            partialCounterVgaBPHEnd <= std_logic_vector(unsigned(partialCounterVgaBPHEnd) + x"001");
         end if;
         if (countingVgaFPHStart and not doneVgaFPHStart) then
            partialCounterVgaFPHStart <= std_logic_vector(unsigned(partialCounterVgaFPHStart) + x"001");
         end if;

         --VSync related logic 
         --Negative edge of VSync - consider start of vsync
         if (last_vs = '1' and vga_vs = '0') then
            if (not start) then
               start <= '1';
            end if; -- not start
            -- It does not matter if this is the start or not, since the VSync will always take the same time
            if (not countingVS and not doneVS) then
               -- Since we are in sync to the clock, one cycle will already have past when register is updated
               countingVS <= '1'; 
               counterVS <= x"0001";            
            end if;
            -- If we receive the start of the next VSync and we are couting the Vertical Front Porch,
            -- we can conclude here
            if (countingFPV and not doneFPV) then
               doneFPV <= '1';
            end if;
            if (countingVgaFPV and not doneVgaFPV) then
               doneVgaFPV <= '1';
            end if;

            if (not countingFrame and not doneFrame) then
               countingFrame <= '1';
               counterFrame <= x"00001";
            elsif (countingFrame and not doneFrame) then
               doneFrame <= '1';
            end if;

            if (not countingFrmLines and not doneFrmLines) then
               countingFrmLines <= '1';
               counterFrmLines <= x"000";
            elsif (countingFrmLines and not doneFrmLines) then
               doneFrmLines <= '1';
            end if;

            if (countingVgaBPHEnd and not doneVgaBPHEnd) then
               doneVgaBPHEnd <= '1';
            end if;
            if (countingVgaFPHStart and not doneVgaFPHStart) then
               doneVgaFPHStart <= '1';
            end if;
         elsif (countingFrame and not doneFrame) then
            counterFrame <= std_logic_vector(unsigned(counterFrame) + x"00001");
         end if; -- If vsync

         --Positive edge of VSync - consider end of vsync
         if (last_vs = '0' and vga_vs = '1') then
            --If we are counting the VSync 
            if (countingVS and not doneVS) then
               doneVS <= '1';
            end if;
            -- After the vertical sync ends we can both start and end counting the image line resolution 
            if (countingLines and not doneLines) then
               doneLines <= '1';
            elsif (not doneLines) then
               countingLines <= '1';
               counterLines <= x"000";
            end if;
            -- At this stage we can also count the Vertical Back Porch lines
            if (not doneBPV) then
               countingBPV <= '1';
               -- It starts counting at zero, because the hsync positive edge does not occurs simulatneously with vsync,
               -- so to avoid double increment we start counter at 0
               counterBPV <= x"000";
            end if;
            if (not doneVgaBPV) then
               countingVgaBPV <= '1';
               -- It starts counting at zero, because the hsync positive edge does not occurs simulatneously with vsync,
               -- so to avoid double increment we start counter at 0
               counterVgaBPV <= x"000";
            end if; 

            if (not countingVgaBPHEnd and not doneVgaBPHEnd) then
               countingVgaBPHEnd <= '1';
               counterVgaBPHEnd <= x"FFF";
            end if;
            if (not countingVgaFPHStart and not doneVgaFPHStart) then
               countingVgaFPHStart <= '1';
               counterVgaFPHStart <= x"000";
            end if;
            if (not countingVgaFPHEnd and not doneVgaFPHEnd) then
               countingVgaFPHEnd <= '1';
               counterVgaFPHEnd <= x"001";
            end if;
         -- If we didn't find the end of VSync and we are counting the VSync, increment the counter, otherwise
         -- it should not be updated, since it would overcount one more cycle
         elsif (countingVs and not doneVS) then
            counterVS <= std_logic_vector(unsigned(counterVS) + x"0001");
         end if;

         --HSync related logic
         --Negative edge of HSync - considered start of hsync
         if (last_hs = '1' and vga_hs = '0') then
            -- It does not matter if this is the start or not, since the HSync will always take the same time
            if (not countingHS and not doneHS) then
               -- Since we are in sync to the clock, one cycle will already have past when register is updated
               countingHS <= '1'; 
               counterHS <= x"001";            
            end if;
            -- We count the Horizontal Front Porch once
            if (countingFPH and not doneFPH) then
               doneFPH <= '1';
            end if;
            -- End frame columns not the DE frame columns
            if (countingColumns and not doneColumns) then
               doneColumns <= '1';
            end if;

            if (countingFrmLines and not doneFrmLines) then
               counterFrmLines <= std_logic_vector(unsigned(counterFrmLines) + x"001");
            end if;

            if (countingVgaFPHEnd and not doneVgaFPHEnd and readyVgaFPHEnd) then
               doneVgaFPHEnd <= '1';
            end if;
         else
            if (countingFPH and not doneFPH) then
               -- While the horizontal sync does not go low again, we count the horizontal front porch cycles
               counterFPH <= std_logic_vector(unsigned(counterFPH) + x"001");
            end if;

            if (countingColumns and not doneColumns) then
               counterColumns <= std_logic_vector(unsigned(counterColumns) + x"001");
            end if;

            if (countingVgaFPHEnd and not doneVgaFPHEnd) then
               counterVgaFPHEnd <= std_logic_vector(unsigned(counterVgaFPHEnd) + x"001");
            end if;
         end if; -- If start hsync

         --Positive edge of HSync - consider end of hsync
         if (last_hs = '0' and vga_hs = '1') then
            --If we are counting the HSync 
            if (countingHS and not doneHS) then
               doneHS <= '1';
            end if;
            -- We can only count BPH cycles when the DE signal is available, which only occurs,
            -- on non Front Porch or Back Porch vertical lines. So we start counting after the end
            -- of the next horizontal sync.
            if (readyBPH and not doneBPH) then
               countingBPH <= '1';
               counterBPH <= x"001";
            end if;
          
            if (not countingColumns and not doneColumns) then
               countingColumns <= '1';
               counterColumns <= x"001";
            end if;

            -- At each horizontal sync increment the line count of the vertical back and front porches 
            if (countingBPV and not doneBPV) then
               counterBPV <= std_logic_vector(unsigned(counterBPV) + x"001");
            end if;
            if (countingFPV and not doneFPV) then
               counterFPV <= std_logic_vector(unsigned(counterFPV) + x"001");
            end if;
            if (countingVgaBPV and not doneVgaBPV) then
               counterVgaBPV <= std_logic_vector(unsigned(counterVgaBPV) + x"001");
            end if;
            if (countingVgaFPV and not doneVgaFPV) then
               counterVgaFPV <= std_logic_vector(unsigned(counterVgaFPV) + x"001");
            end if;

            if (countingVgaBPHEnd and not doneVgaBPHEnd) then
               partialCounterVgaBPHEnd <= x"001";
            end if;
            if (countingVgaFPHStart and not doneVgaFPHStart) then
               partialCounterVgaFPHStart <= x"001";
            end if;
            if (countingVgaFPHEnd and not doneVgaFPHEnd) then
               counterVgaFPHEnd <= x"001";
            end if;
         else
            -- If we didn't find the end of HSync and we are counting the HSync, increment the counter, otherwise
            -- it should not be updated, since it would overcount one more cycle
            if (countingHS and not doneHS) then
               counterHS <= std_logic_vector(unsigned(counterHS) + x"001");
            end if;
         end if;

         --DE related logic
         if (last_de = '0' and vga_de = '1') then
            -- It does not matter if this is the start or not, since the DE will always take the same time
            if (not countingDE and not doneDE) then
               -- Since we are in sync to the clock, one cycle will already have past when register is updated
               countingDE <= '1'; 
               counterDE <= x"001";
            end if;
            --When DE goes high, it is the end of the horizontal back porch
            if (countingBPH and not doneBPH) then
               doneBPH <= '1';
            end if;
            if (countingBPV and not doneBPV) then
               doneBPV <= '1';
               --This line is already a valid line, so it does not count as a Vertical Back Porch line
               counterBPV <= std_logic_vector(unsigned(counterBPV) - x"001");
            end if;
         elsif (countingBPH and not doneBPH) then
            -- While DE does not go high, count the cycles of the horizontal back porch
            counterBPH <= std_logic_vector(unsigned(counterBPH) + x"001");            
         end if; -- If start hsync

         --Negative edge of DE - consider end of DE
         if (last_de = '1' and vga_de = '0') then
            --If we are counting the DE 
            if (countingDE and not doneDE) then
               doneDE <= '1';
               countingFPH <= '1';
               counterFPH <= x"001";
            end if;
            if (countingLines and not doneLines) then
               counterLines <= std_logic_vector(unsigned(counterLines) + x"001");
            end if;
            -- Okay we reached the end of the first valid scanline, so the next one should also be valid,
            -- and as such we can measure the Horizontal Back Porch cycles
            readyBPH <= '1';
            -- We keep resetting the counter until the end of the last DE of a frame
            if (not doneFPV) then
               countingFPV <= '1';
               counterFPV <= x"000";
            end if;
         -- If we didn't find the end of DE and we are counting the DE, increment the counter, otherwise
         -- it should not be updated, since it would overcount one more cycle
         elsif (countingDE and not doneDE) then
            counterDE <= std_logic_vector(unsigned(counterDE) + x"001");
         end if;

         -- RGB lines changed from no information to having information
         if (lastDataValid = '0' and dataValid = '1') then
            --When RGB goes high, it is the end of the VGA vertical back porch
            if (countingVgaBPV and not doneVgaBPV) then
               doneVgaBPV <= '1';
               --This line is already a valid line, so it does not count as a Vertical Back Porch line
               counterVgaBPV <= std_logic_vector(unsigned(counterVgaBPV) - x"001");
            end if;

            if (countingVgaBPHEnd and not doneVgaBPHEnd) then
               if (unsigned(partialCounterVgaBPHEnd) < unsigned(counterVgaBPHEnd)) then
                  -- This cycle is already a valid pixel, so we need to exclude this cycle by subtracting 1 cycle,
                  -- to compensate for the increment that will occur at this cycle
                  counterVgaBPHEnd <= std_logic_vector(unsigned(partialCounterVgaBPHEnd) - x"001");
               end if;
            end if;
            
            if (countingVgaFPHEnd and not doneVgaFPHEnd) then
               readyVgaFPHEnd <= '1';
            end if;
         end if;
 
         -- RGB lines changed from having information to no information
         if (lastDataValid = '1' and dataValid = '0') then
            if (countingVgaFPHStart and not doneVgaFPHStart) then
               if (unsigned(partialCounterVgaFPHStart) > unsigned(counterVgaFPHStart)) then
                  -- This cycle is no longer valid pixel, so this is already the first cycle of the FPH, so we need to subtract 1,
                  -- to compensate the increment that will occur at this cycle
                  counterVgaFPHStart <= std_logic_vector(unsigned(partialCounterVgaFPHStart) - x"001");
               end if;
            end if;         
  
            -- We keep resetting the counter until the end of the last valid RGB of a frame
            if (not doneVgaFPV) then
               countingVgaFPV <= '1';
               counterVgaFPV <= x"000";
            end if;  

            if (countingVgaFPHEnd and not doneVgaFPHEnd) then
               readyVgaFPHEnd <= '1';
            end if;
        end if;
      end if; --If complete
   end if; -- If Rising edge
end process;

Has_DE_Line_complete : if HasDELine = true generate
   complete <= doneFrame and doneVS and doneHS and doneDE and doneFPH and doneBPH and doneLines and doneFPV and doneBPV and doneFrmLines and doneVgaFPHStart and doneVgaFPHEnd and doneVgaBPHEnd and doneVgaBPV and doneVgaFPV;
end generate Has_DE_Line_complete;

Has_DE_Line_complete_false : if HasDELine = false generate
   complete <= doneFrame and doneVS and doneHS and doneFrmLines and doneVgaFPHStart and doneVgaFPHEnd and doneVgaBPHEnd and doneVgaBPV and doneVgaFPV;
end generate Has_DE_Line_complete_false;

end rtl;

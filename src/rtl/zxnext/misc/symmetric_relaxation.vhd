-- Tape Ear Relaxation
-- Copyright 2024 Alvin Albrecht
--
-- This file is part of the ZX Spectrum Next Project
-- <https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/tree/master/cores>
--
-- The ZX Spectrum Next FPGA source code is free software: you can 
-- redistribute it and/or modify it under the terms of the GNU General 
-- Public License as published by the Free Software Foundation, either 
-- version 3 of the License, or (at your option) any later version.
--
-- The ZX Spectrum Next FPGA source code is distributed in the hope 
-- that it will be useful, but WITHOUT ANY WARRANTY; without even the 
-- implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
-- PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with the ZX Spectrum Next FPGA source code.  If not, see 
-- <https://www.gnu.org/licenses/>.

-- When the incoming signal holds its value for the prescribed period,
-- the signal will be changed to its relaxed value until the signal
-- changes again.
--
-- Eg:  The signal remains stable at 0 for the time period indicated
-- by COUNTER_SIZE.  After that period, the output is changed to
-- the input relax_0.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity symmetric_relaxation is
   generic
   (
      INVERT         : std_logic := '0';
      INITIAL_STATE  : std_logic := '0';
      COUNTER_SIZE   : positive := 4
   );
   port
   (
      i_CLK          : in std_logic;
      i_CLK_EN       : in std_logic;
      i_sig          : in std_logic;
      i_relax_0      : in std_logic;
      i_relax_1      : in std_logic;
      o_sig          : out std_logic
   );
end entity;

architecture rtl of symmetric_relaxation is

   signal sig           : std_logic;
   signal sig_d         : std_logic;
   signal counter       : std_logic_vector(COUNTER_SIZE downto 0) := (others => '0');
   signal sig_relaxed   : std_logic := INITIAL_STATE;

begin

   -- optional signal inversion
   
   sig <= i_sig xor INVERT;
   
   process (i_CLK)
   begin
      if rising_edge(i_CLK) then
         sig_d <= sig;
      end if;
   end process;
   
   -- counter
   
   process (i_CLK)
   begin
      if rising_edge(i_CLK) then
         if sig /= sig_d then
            counter <= (others => '0');
         elsif i_CLK_EN = '1' and counter(COUNTER_SIZE) = '0' then
            counter <= counter + 1;
         end if;
      end if;
   end process;
   
   -- output
   
   process (i_CLK)
   begin
      if rising_edge(i_CLK) then
         if counter(COUNTER_SIZE) = '1' then
            sig_relaxed <= (i_relax_0 and not sig) or (i_relax_1 and sig);
         else
            sig_relaxed <= sig;
         end if;
      end if;
   end process;
   
   o_sig <= sig_relaxed;

end architecture;

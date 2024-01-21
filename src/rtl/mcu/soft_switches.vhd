-------------------------------------------------------------------------------
-- MCU Soft switches receiver
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.conv_integer;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity soft_switches is
	port(
	CLK : in std_logic;	
	SOFTSW_COMMAND : in std_logic_vector(15 downto 0);
	
    HARD_RESET : out std_logic; -- F1
    SCANDOUBLER : out std_logic; -- F2
    VGA_60HZ : out std_logic; -- F3
    SOFT_RESET : out std_logic; -- F4
    SCANLINE : out std_logic; -- F7
    CPU_SPEED : out std_logic; -- F8
    MULTIFACE : out std_logic; -- F9
    DIVMMC : out std_logic -- F10

	);
end soft_switches;

architecture rtl of soft_switches is
	signal prev_command : std_logic_vector(15 downto 0) := x"FFFF";
begin 

process (CLK, prev_command, SOFTSW_COMMAND)
begin
	if rising_edge(CLK) then 
		if (prev_command /= SOFTSW_COMMAND) then
			prev_command <= SOFTSW_COMMAND;
			case SOFTSW_COMMAND(15 downto 8) is
				when x"00" => HARD_RESET <= SOFTSW_COMMAND(0);
				when x"01" => SCANDOUBLER <= SOFTSW_COMMAND(0);
				when x"02" => VGA_60HZ <= SOFTSW_COMMAND(0);
				when x"03" => SOFT_RESET <= SOFTSW_COMMAND(0);
				when x"04" => SCANLINE <= SOFTSW_COMMAND(0);
				when x"05" => CPU_SPEED <= SOFTSW_COMMAND(0);
				when x"06" => MULTIFACE <= SOFTSW_COMMAND(0);
				when x"07" => DIVMMC <= SOFTSW_COMMAND(0);
				when others => null;
			end case;
		end if;
	end if;
end process;

end rtl;

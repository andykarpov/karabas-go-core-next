-- 
-- DS1307 i2c emulator
--

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity ds1307 is
	port(
		clk		    : in	std_logic;
		reset_n		: in	std_logic;
		scl_i			: in	std_logic;
		sda_i			: in	std_logic;
		scl_o			: out	std_logic;
		sda_o			: out	std_logic;

		rtc_a       : out std_logic_vector(7 downto 0);
		rtc_di      : out std_logic_vector(7 downto 0);
		rtc_do      : in std_logic_vector(7 downto 0);
		rtc_wr      : out std_logic := '0'
	);
end ds1307;

architecture rtl of ds1307 is

	signal rd			: std_logic;	
	signal buffer8		: std_logic_vector(7 downto 0);

begin

	U_I2C : entity work.i2cslave
		generic map (DEVICE => x"68")
		port map (
			MCLK		=> clk,
			nRST		=> reset_n,

			SDA_IN		=> sda_i,
			SCL_IN		=> scl_i,
			SDA_OUT		=> sda_o,
			SCL_OUT		=> scl_o,

			ADDRESS		=> rtc_a,
			DATA_OUT	=> rtc_di,
			DATA_IN		=> buffer8,
			WR			=> rtc_wr,
			RD			=> rd
		);
		
	B8 : process(clk, reset_n)
	begin
		if (reset_n = '0') then
			buffer8 <= (others => '0');
		elsif (clk'event and clk='1') then
			if (rd = '1') then
				buffer8 <= rtc_do;
			end if;
		end if;
	end process B8;

end rtl;


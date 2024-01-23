----------------------------------------------------------------------------------
-- Company: 
-- Engineer: emax73 
-- 
-- Create Date:    14:25:50 08/04/2021 
-- Design Name: UnoXT Next Core
-- Module Name:    unoxt_top - Behavioral 
-- Project Name: UnoXT Next Core
-- Target Devices: SLX16
-- Tool versions: ISE 14.7
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
--Max
-- Leds PWM
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity led_pwm is
    port ( reset_n_i : 	in	std_logic;
			  clock_i : in std_logic;
           enable_i : in std_logic;
			  y1: in integer;
			  y2: in integer;
			  led_o : out std_logic);
end led_pwm;

architecture rtl of led_pwm is
begin
	process (y1, y2, enable_i)
	begin
	end process;
	process (clock_i)
		variable cnt: integer := 0;
		variable pwm: integer;
		constant period: integer := 10000;
		begin
			pwm := (y1 * y2) when (enable_i = '1') else 0;
			if (reset_n_i = '0')
			then
				cnt := 0;
			elsif (rising_edge(clock_i))
			then
				if (cnt = period - 1)
				then
					cnt := 0;
				else	
					cnt := cnt+1;
				end if;	
         end if;
			if (cnt < pwm)
			then
				led_o <= '1';
			else
				led_o <= '0';
			end if;	
		end process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity unoxt_top is

  port (
      -- Clocks
      clock_50_i        : in    std_logic;

		-- SRAM (AS7C316098A)
		-- SRAM (IS61WV204816BLL-10TLI)
		ram_addr_o        : out   std_logic_vector(20 downto 0)  := (others => '0');
		ram_lb_n_o			: out std_logic								:= '1';
		ram_ub_n_o			: out std_logic								:= '1';
 	 
		ram_data_io       : inout std_logic_vector(15 downto 0)  := (others => 'Z');
      ram_oe_n_o        : out   std_logic                      := '1';
      ram_we_n_o        : out   std_logic                      := '1';
      ram_ce_n_o        : out   std_logic  							:= '1';

      -- PS2
      ps2_clk_io        : inout std_logic                      := 'Z';
      ps2_data_io       : inout std_logic                      := 'Z';
      ps2_pin6_io       : inout std_logic                      := 'Z';  -- Mouse clock
      ps2_pin2_io       : inout std_logic                      := 'Z';  -- Mouse data

      -- SD Card
      sd_cs0_n_o        : out   std_logic                      := '1';
      sd_sclk_o         : out   std_logic                      := '0';
      sd_mosi_o         : out   std_logic                      := '0';
      sd_miso_i         : in    std_logic;

      -- Flash
      flash_cs_n_o      : out   std_logic                      := '1';
      flash_sclk_o      : out   std_logic                      := '0';
      flash_mosi_o      : out   std_logic                      := '0';
      flash_miso_i      : in    std_logic;
      flash_wp_o        : out   std_logic                      := '0';
      flash_hold_o      : out   std_logic                      := '1';

      -- Joystick
      joyp1_i           : in    std_logic;
      joyp2_i           : in    std_logic;
      joyp3_i           : in    std_logic;
      joyp4_i           : in    std_logic;
      joyp6_i           : in    std_logic;
      joyp7_o           : out   std_logic                      := '1';
      joyp9_i           : in    std_logic;

      -- Audio
      audioext_l_o      : out   std_logic                      := '0';
      audioext_r_o      : out   std_logic                      := '0';

      -- K7
      ear_port_i        : in    std_logic;
      mic_port_o        : out   std_logic                      := '0';

      -- Buttons
      btn_divmmc_n_i    : in    std_logic;
      btn_multiface_n_i : in    std_logic;

      -- VGA
      rgb_r_o           : out   std_logic_vector( 2 downto 0)  := (others => '0');
      rgb_g_o           : out   std_logic_vector( 2 downto 0)  := (others => '0');
      rgb_b_o           : out   std_logic_vector( 2 downto 0)  := (others => '0');
      hsync_o           : out   std_logic                      := '1';
      vsync_o           : out   std_logic                      := '1';

      -- ESP
      esp_gpio0_io      : inout std_logic                      := 'Z';
      esp_gpio2_io      : inout std_logic                      := 'Z';
      esp_rx_i          : in    std_logic;
      esp_tx_o          : out   std_logic                      := '1';
		
		-- LEDs
     led_red_o          : out   std_logic                      := '0';
     led_yellow_o       : out   std_logic                      := '0';
     led_green_o        : out   std_logic                      := '0';
     led_blue_o         : out   std_logic                      := '0' 		
   );


end unoxt_top;

architecture rtl of unoxt_top is

     --Joy
	  signal joyp1s_i : std_logic := '1';
     signal joyp2s_i : std_logic := '1';
     signal joyp3s_i : std_logic := '1';
     signal joyp4s_i : std_logic := '1';
     signal joyp6s_i : std_logic := '1';
     signal joyp7s_o : std_logic := '1';
     signal joyp9s_i : std_logic := '1';
     signal joysels_o : std_logic := '0';
	  --SD
	  signal sd_cs0_n : std_logic;
	  --LEDs
	  signal sd_i: std_logic := '0';
	  signal wi_fi_i: std_logic := '0';
	  signal turbo_o: integer := 0;
	  
 		-- 3mm round diffused LEDs
		--constant led_red_k : integer := 20;
		--constant led_yellow_k : integer := 50;
		--constant led_green_k : integer := 12;
		--constant led_blue_k : integer := 50;

		-- square color LEDs
		--constant led_red_k : integer := 20;
		--constant led_yellow_k : integer := 33;
		--constant led_green_k : integer := 100;
		--constant led_blue_k : integer := 20;

		-- 100% PWM
		constant led_red_k : integer := 100;
		constant led_yellow_k : integer := 100;
		constant led_green_k : integer := 100;
		constant led_blue_k : integer := 100;

begin

	-- Next Core
   next_top : entity work.zxnext_top_issue2
   port map
   (
      clock_50_i        =>    clock_50_i,
		ram_addr_o			=>		ram_addr_o(19 downto 0),
		ram_lb_n_o			=>		ram_lb_n_o,
		ram_ub_n_o			=>		ram_ub_n_o,
 	 
		ram_data_io       =>		ram_data_io,
      ram_oe_n_o        =>		ram_oe_n_o,
      ram_we_n_o        =>		ram_we_n_o,
      ram_ce_n_o(0)     =>		ram_ce_n_o,
		ram_ce_n_o(1)     =>		open,
		ram_ce_n_o(2)     =>		open,
		ram_ce_n_o(3)     =>		open,
		
		turbo_o				=>		turbo_o,

      ps2_clk_io        =>		ps2_clk_io,
      ps2_data_io       =>		ps2_data_io,
      ps2_pin6_io       =>		ps2_pin6_io,
      ps2_pin2_io       =>		ps2_pin2_io,

      --sd_cs0_n_o        =>		sd_cs0_n_o,
      sd_cs0_n_o        =>		sd_cs0_n,
      sd_sclk_o			=>		sd_sclk_o,
      sd_mosi_o         =>		sd_mosi_o,
      sd_miso_i         =>		sd_miso_i,

      flash_cs_n_o      =>		flash_cs_n_o,
      flash_sclk_o		=>		flash_sclk_o,
      flash_mosi_o      =>		flash_mosi_o,
      flash_miso_i      =>		flash_miso_i,
      flash_wp_o			=>		flash_wp_o,
      flash_hold_o		=>		flash_hold_o,

      joyp1_i 				=>		joyp1s_i,
      joyp2_i				=>		joyp2s_i,
      joyp3_i				=>		joyp3s_i,
      joyp4_i				=>		joyp4s_i,
      joyp6_i           =>		joyp6s_i,
      joyp7_o				=>		joyp7s_o,
      joyp9_i				=> 	joyp9s_i,
		joysel_o          => 	joysels_o,

      audioext_l_o		=> 	audioext_l_o,
      audioext_r_o		=>		audioext_r_o,

      ear_port_i			=>		ear_port_i,
      mic_port_o			=>		mic_port_o,

      btn_reset_n_i    	=>		'1',
      btn_divmmc_n_i    =>		btn_divmmc_n_i,
      btn_multiface_n_i	=>	 	btn_multiface_n_i,
		
   	keyb_col_i			=>		(others => '1'),
		
		bus_nmi_n_i       =>		'1',
      bus_ramcs_i       =>		'0',
		bus_romcs_i			=>		'0',
      bus_wait_n_i      => 	'1',
		bus_busreq_n_i    =>		'1',
		bus_iorqula_n_i   =>		'1',
 
      rgb_r_o				=>		rgb_r_o,
      rgb_g_o				=>		rgb_g_o,
      rgb_b_o				=>		rgb_b_o,
      hsync_o				=>		hsync_o,
      vsync_o				=>		vsync_o,
		
		hdmi_p_o          => 	open,
      hdmi_n_o          =>		open,

		esp_gpio0_io		=>		esp_gpio0_io,
      esp_gpio2_io      =>		esp_gpio2_io,
		esp_rx_i				=>		esp_rx_i,
      esp_tx_o				=>		esp_tx_o
   );
	
	-- 4MB not used, only 2MB
	ram_addr_o(20) <= '0';
	-- ESP01 Mod
	esp_gpio2_io <= '0';
	
	--One left Joystick
	process(joysels_o, joyp7s_o, joyp1_i, joyp2_i, joyp3_i, joyp4_i, joyp6_i, joyp9_i)
	begin
		if (joysels_o = '0') then
			joyp7_o <= 	joyp7s_o;
			joyp1s_i <= joyp1_i;
			joyp2s_i <= joyp2_i;
			joyp3s_i <= joyp3_i;
			joyp4s_i <= joyp4_i;
			joyp6s_i <= joyp6_i;
			joyp9s_i <= joyp9_i;
		else
			joyp7_o <=  '1';			
			joyp1s_i <= '1';
			joyp2s_i <= '1';
			joyp3s_i <= '1';
			joyp4s_i <= '1';
			joyp6s_i <= '1';
			joyp9s_i <= '1';
		end if;
	end process;
	
	-- Leds
	led_red_pwm: entity work.led_pwm
   port map
	(
		reset_n_i  => '1',
		clock_i 	=> clock_50_i,
		enable_i => '1',
		y1 		=> 100,
		y2			=> led_red_k,
		led_o 	=> led_red_o
	);

	led_yellow_pwm: entity work.led_pwm
   port map
	(
		reset_n_i  => '1',
		clock_i 	=> clock_50_i,
		enable_i => '1',
		y1 		=> turbo_o,
		y2			=> led_yellow_k,
		led_o 	=> led_yellow_o
	);

	sd_i <= not sd_cs0_n;
	sd_cs0_n_o <= sd_cs0_n;

	led_green_pwm: entity work.led_pwm
   port map
	(
		reset_n_i  => '1',
		clock_i 	=> clock_50_i,
		enable_i => sd_i,
		y1 		=> 100,
		y2			=> led_green_k,
		led_o 	=> led_green_o
	);

	wi_fi_i <= not esp_rx_i;
	
	led_blue_pwm: entity work.led_pwm
   port map
	(
		reset_n_i  => '1',
		clock_i 	=> clock_50_i,
		enable_i => wi_fi_i,
		y1 		=> 100,
		y2			=> led_blue_k,
		led_o 	=> led_blue_o
	);
	
end rtl;
-------------------------------------------------------------------------------
-- MCU HID keyboard parser / transformer to 8x5 spectrum matrix
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.conv_integer;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity hid_parser is
	generic 
	(
		NUM_KEYS : integer range 1 to 6 := 2 -- number of simultaneously pressed keys to process
	);
	port
	(
	 CLK			 : in std_logic;
	 CLK_EN		 : in std_logic;
	 RESET 		 : in std_logic;
	 
	 -- incoming usb hid report data
	 KB_STATUS : in std_logic_vector(7 downto 0);
	 KB_DAT0 : in std_logic_vector(7 downto 0);
	 KB_DAT1 : in std_logic_vector(7 downto 0);
	 KB_DAT2 : in std_logic_vector(7 downto 0);
	 KB_DAT3 : in std_logic_vector(7 downto 0);
	 KB_DAT4 : in std_logic_vector(7 downto 0);
	 KB_DAT5 : in std_logic_vector(7 downto 0);

	 -- cpu address for spectrum keyboard row address
	 A : in std_logic_vector(15 downto 8);
	 
	 -- keyboard output data
	 KB_DO : out std_logic_vector(4 downto 0);

	 -- cancel of extended keys processing
	 -- https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/nextreg.txt#L659
	 -- see nextreg 0x68 bit 4 = Cancel entries in 8x5 matrix for extended keys
	 CANCEL_EXT : in std_logic;

	-- extended keys (active 1)
	-- EXT_KEYS(15 downto 8) = DOWN LEFT RIGHT DELETE . , " ;
	-- EXT_KEYS( 7 downto 0) = EDIT BREAK INV TRU GRAPH CAPSLOCK UP EXTEND
	 
	 EXT_KEYS : out std_logic_vector(15 downto 0) := (others => '0');
	 
	 -- joystick types
 	 -- 000 = Sinclair 2 (67890)
	 -- 001 = Kempston 1 (port 0x1F)
	 -- 010 = Cursor (56780)
	 -- 011 = Sinclair 1 (12345)
	 -- 100 = Kempston 2 (port 0x37)
	 -- 101 = MD 1 (3 or 6 button joystick port 0x1F)
	 -- 110 = MD 2 (3 or 6 button joystick port 0x37)
	 -- 111 = User defined keys via keymap
	 JOY_TYPE_L : in std_logic_vector(2 downto 0) := "000";
	 JOY_TYPE_R : in std_logic_vector(2 downto 0) := "000";
	 
	 -- active high  MODE X Z Y START A C B U D L R
	 JOY_L : in std_logic_vector(11 downto 0) := (others => '0');
	 JOY_R : in std_logic_vector(11 downto 0) := (others => '0');
	 
	 -- joysticks enabled (active 0)
	 JOY_EN_N : in std_logic := '1';
	 
	 -- mapper from zxnext TODO
    KEYMAP_ADDR        : in std_logic_vector(4 downto 0);   -- left/right (4), button number (3:0)
    KEYMAP_DATA        : in std_logic_vector(5 downto 0);   -- membrane row (5:3), membrane col (2:0)
    KEYMAP_WE          : in std_logic
	 
	);
end hid_parser;

architecture rtl of hid_parser is

	-- col0
	constant ZX_K_CS : natural := 0; 
	constant ZX_K_A : natural := 1;
	constant ZX_K_Q : natural := 2;
	constant ZX_K_1 : natural := 3;
	constant ZX_K_0 : natural := 4;
	constant ZX_K_P : natural := 5;
	constant ZX_K_ENT : natural := 6;
	constant ZX_K_SP : natural := 7;

	-- col1
	constant ZX_K_Z : natural := 8;
	constant ZX_K_S : natural := 9;
	constant ZX_K_W : natural := 10;
	constant ZX_K_2 : natural := 11;
	constant ZX_K_9 : natural := 12;
	constant ZX_K_O : natural := 13;
	constant ZX_K_L : natural := 14;
	constant ZX_K_SS : natural := 15;	

	-- col2
	constant ZX_K_X : natural := 16;
	constant ZX_K_D : natural := 17;
	constant ZX_K_E : natural := 18;
	constant ZX_K_3 : natural := 19;
	constant ZX_K_8 : natural := 20;
	constant ZX_K_I : natural := 21;
	constant ZX_K_K : natural := 22;
	constant ZX_K_M : natural := 23;

	-- col3
	constant ZX_K_C : natural := 24;
	constant ZX_K_F : natural := 25;
	constant ZX_K_R : natural := 26;
	constant ZX_K_4 : natural := 27;
	constant ZX_K_7 : natural := 28;
	constant ZX_K_U : natural := 29;
	constant ZX_K_J : natural := 30;
	constant ZX_K_N : natural := 31;

	-- col4
	constant ZX_K_V : natural := 32;
	constant ZX_K_G : natural := 33;
	constant ZX_K_T : natural := 34;
	constant ZX_K_5 : natural := 35;
	constant ZX_K_6 : natural := 36;
	constant ZX_K_Y : natural := 37;
	constant ZX_K_H : natural := 38;
	constant ZX_K_B : natural := 39;

	signal kb_data : std_logic_vector(39 downto 0) := (others => '0'); -- 40 keys
	
	signal data : std_logic_vector(47 downto 0);
	
	signal is_macros : std_logic := '0';
	type macros_machine is (MACRO_START, MACRO_CS_ON, MACRO_SS_ON, MACRO_SS_OFF, MACRO_KEY, MACRO_CS_OFF, MACRO_END);
	signal macros_key : natural;
	signal macros_state : macros_machine := MACRO_START;
	signal macro_cnt : std_logic_vector(21 downto 0) := (others => '0');
	
	signal ext_keys_int : std_logic_vector(15 downto 0) := (others => '0');

	constant EX_EXTEND : natural := 0;
	constant EX_UP : natural := 1;
	constant EX_CAPSLOCK : natural := 2;
	constant EX_GRAPH : natural := 3;
	constant EX_TRU : natural := 4;
	constant EX_INV : natural := 5;
	constant EX_BREAK : natural := 6;
	constant EX_EDIT : natural := 7;
	constant EX_SEMICOL : natural := 8;
	constant EX_DQUOT : natural := 9;
	constant EX_COMMA : natural := 10;
	constant EX_DOT : natural := 11;
	constant EX_DELETE : natural := 12;
	constant EX_RIGHT : natural := 13;
	constant EX_LEFT : natural := 14;
	constant EX_DOWN : natural := 15;
	
	constant JOY_TYPE_SINCLAIR1 : std_logic_vector(2 downto 0) := "011";
	constant JOY_TYPE_SINCLAIR2 : std_logic_vector(2 downto 0) := "000";
	constant JOY_TYPE_CURSOR : std_logic_vector(2 downto 0) := "010";
	constant JOY_TYPE_KEMPSTON1 : std_logic_vector(2 downto 0) := "001";
	constant JOY_TYPE_KEMPSTON2 : std_logic_vector(2 downto 0) := "100";
	constant JOY_TYPE_MD1 : std_logic_vector(2 downto 0) := "101";
	constant JOY_TYPE_MD2 : std_logic_vector(2 downto 0) := "110";
	constant JOY_TYPE_USER : std_logic_vector(2 downto 0) := "111";
	
	-- ZXN joy buttons: MODE X Z Y START A C B U D L R
   constant	SC_BTN_RIGHT: natural := 0;
	constant SC_BTN_LEFT: natural := 1;
	constant SC_BTN_DOWN: natural := 2;
	constant SC_BTN_UP : natural := 3;
	constant SC_BTN_B : natural := 4;
	constant SC_BTN_C : natural := 5;
   constant SC_BTN_A : natural := 6;	
	constant SC_BTN_START: natural := 7;
	constant SC_BTN_Y : natural := 8;
	constant SC_BTN_Z : natural := 9;
	constant SC_BTN_X : natural := 10;
	constant SC_BTN_MODE : natural := 11;	
	
	-- joy map
	signal map_btn_up_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_down_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_left_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_right_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_start_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_a_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_b_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_c_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_x_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_y_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_z_l : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_mode_l : std_logic_vector(5 downto 0) := (others => '1');

	signal map_btn_up_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_down_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_left_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_right_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_start_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_a_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_b_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_c_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_x_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_y_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_z_r : std_logic_vector(5 downto 0) := (others => '1');
	signal map_btn_mode_r : std_logic_vector(5 downto 0) := (others => '1');
	
begin 

	-- incoming data of pressed keys from usb hid report
	data <= KB_DAT5 & KB_DAT4 & KB_DAT3 & KB_DAT2 & KB_DAT1 & KB_DAT0;

	process( kb_data, A)
	begin
		KB_DO(0) <=	not(( kb_data(ZX_K_CS)  and not( A(8)  ) ) 
					or    ( kb_data(ZX_K_A)  and not(   A(9)  ) ) 
					or    ( kb_data(ZX_K_Q) and not(    A(10) ) ) 
					or    ( kb_data(ZX_K_1) and not(    A(11) ) ) 
					or    ( kb_data(ZX_K_0) and not(    A(12) ) ) 
					or    ( kb_data(ZX_K_P) and not(    A(13) ) ) 
					or    ( kb_data(ZX_K_ENT) and not(  A(14) ) ) 
					or    ( kb_data(ZX_K_SP) and not(   A(15) ) )
					);

		KB_DO(1) <=	not( ( kb_data(ZX_K_Z)  and not(A(8) ) ) 
					or   ( kb_data(ZX_K_S)  and not(A(9) ) ) 
					or   ( kb_data(ZX_K_W) and not(A(10)) ) 
					or   ( kb_data(ZX_K_2) and not(A(11)) ) 
					or   ( kb_data(ZX_K_9) and not(A(12)) ) 
					or   ( kb_data(ZX_K_O) and not(A(13)) ) 
					or   ( kb_data(ZX_K_L) and not(A(14)) ) 
					or   ( kb_data(ZX_K_SS) and not(A(15)) ) 
					);

		KB_DO(2) <=		not( ( kb_data(ZX_K_X) and not( A(8)) ) 
					or   ( kb_data(ZX_K_D) and not( A(9)) ) 
					or   ( kb_data(ZX_K_E) and not(A(10)) ) 
					or   ( kb_data(ZX_K_3) and not(A(11)) ) 
					or   ( kb_data(ZX_K_8) and not(A(12)) ) 
					or   ( kb_data(ZX_K_I) and not(A(13)) ) 
					or   ( kb_data(ZX_K_K) and not(A(14)) ) 
					or   ( kb_data(ZX_K_M) and not(A(15)) ) 
					);

		KB_DO(3) <=		not( ( kb_data(ZX_K_C) and not( A(8)) ) 
					or   ( kb_data(ZX_K_F) and not( A(9)) ) 
					or   ( kb_data(ZX_K_R) and not(A(10)) ) 
					or   ( kb_data(ZX_K_4) and not(A(11)) ) 
					or   ( kb_data(ZX_K_7) and not(A(12)) ) 
					or   ( kb_data(ZX_K_U) and not(A(13)) ) 
					or   ( kb_data(ZX_K_J) and not(A(14)) ) 
					or   ( kb_data(ZX_K_N) and not(A(15)) ) 
					);

		KB_DO(4) <=		not( ( kb_data(ZX_K_V) and not( A(8)) ) 
					or   ( kb_data(ZX_K_G) and not( A(9)) ) 
					or   ( kb_data(ZX_K_T) and not(A(10)) ) 
					or   ( kb_data(ZX_K_5) and not(A(11)) ) 
					or   ( kb_data(ZX_K_6) and not(A(12)) ) 
					or   ( kb_data(ZX_K_Y) and not(A(13)) ) 
					or   ( kb_data(ZX_K_H) and not(A(14)) ) 
					or   ( kb_data(ZX_K_B) and not(A(15)) ) 
					);					
	end process;

process (RESET, CLK)

	variable is_shift : std_logic := '0';
	variable is_cs_used : std_logic := '0';
	variable is_ss_used : std_logic := '0';

	begin
		if RESET = '1' then
			kb_data <= (others => '0');
			is_shift := '0';
			is_cs_used := '0';
			is_ss_used := '0';
			macro_cnt <= (others => '0');
			ext_keys_int <= (others => '0');
			
		elsif CLK'event and CLK = '1' then
				
			-- macro state machine
			if is_macros = '1' then 
					macro_cnt <= macro_cnt + 1;
					if (macro_cnt = "1111111111111111111111") then 
					case macros_state is 
						when MACRO_START  => kb_data <= (others => '0'); macros_state <= MACRO_CS_ON;
						when MACRO_CS_ON  => kb_data(ZX_K_CS) <= '1';    macros_state <= MACRO_SS_ON;
						when MACRO_SS_ON  => kb_data(ZX_K_SS) <= '1';    macros_state <= MACRO_SS_OFF;
						when MACRO_SS_OFF => kb_data(ZX_K_SS) <= '0';    macros_state <= MACRO_KEY;
						when MACRO_KEY    => kb_data(macros_key) <= '1'; macros_state <= MACRO_CS_OFF;
						when MACRO_CS_OFF => kb_data(ZX_K_CS) <= '0'; kb_data(macros_key) <= '0'; macros_state <= MACRO_END;
						when MACRO_END    => kb_data <= (others => '0'); is_macros <= '0';        macros_state <= MACRO_START;
						when others => null;
					end case;
					end if;
			else
				macro_cnt <= (others => '0');
				kb_data <= (others => '0');
				ext_keys_int <= (others => '0');
				is_shift := '0';
				is_cs_used := '0';
				is_ss_used := '0';
				
				-- L Shift -> CS
				if KB_STATUS(1) = '1' then 
					kb_data(ZX_K_CS) <= '1'; 
					is_shift := '1'; 
				end if;

				-- R Shift -> CS
				if KB_STATUS(5) = '1' then 
					kb_data(ZX_K_CS) <= '1'; 
					is_shift := '1'; 
				end if;
							
				-- L Ctrl 
				if KB_STATUS(0) = '1' then 
					kb_data(ZX_K_SS) <= '1';
				end if;
				
				-- R Ctrl
				if KB_STATUS(4) = '1' then 
					kb_data(ZX_K_SS) <= '1';
				end if;
							
				-- L Alt -> SS+CS / EXTEND key
				if KB_STATUS(2) = '1' then 
					if CANCEL_EXT = '1' then
						ext_keys_int(EX_EXTEND) <= '1';
					else
						kb_data(ZX_K_CS) <= '1'; 
						kb_data(ZX_K_SS) <= '1'; 
						is_cs_used := '1'; 					
					end if;
				end if;

				-- R Alt -> SS+CS / EXTEND key
				if KB_STATUS(6) = '1' then 
					if CANCEL_EXT = '1' then
						ext_keys_int(EX_EXTEND) <= '1';
					else
						kb_data(ZX_K_CS) <= '1'; 
						kb_data(ZX_K_SS) <= '1'; 
						is_cs_used := '1'; 					
					end if;
				end if;
				
				-- Win
				--if KB_STATUS(7) = '1' then end if;

				for II in 0 to NUM_KEYS-1 loop		
				case data((II+1)*8-1 downto II*8) is							

					-- DEL -> SS + C
					when X"4c" => 
						if (is_shift = '0') then 
							kb_data(ZX_K_SS) <= '1'; 
							kb_data(ZX_K_C) <= '1'; 
						end if;	
						
					-- INS -> SS + A
					when X"49" => 
						if (is_shift = '0') then 
							kb_data(ZX_K_SS) <= '1'; 							
							kb_data(ZX_K_A) <= '1'; 
						end if; 
					
					-- Cursor -> CS + 5,6,7,8
					when X"50" =>	
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_LEFT) <= '1';
						else
							if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_5) <= '1'; is_cs_used := '1'; end if; -- left
						end if;
						
					when X"51" =>	
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_DOWN) <= '1';
						else
							if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_Data(ZX_K_6) <= '1'; is_cs_used := '1'; end if;  -- down
						end if;
						
					when X"52" =>	
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_UP) <= '1';
						else
							if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_7) <= '1'; is_cs_used := '1'; end if; -- up
						end if;
					
					when X"4f" =>	
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_RIGHT) <= '1';
						else
							if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_8) <= '1'; is_cs_used := '1'; end if; -- right
						end if;

					-- ESC -> CS + Space
					when X"29" => 
						if CANCEL_EXT = '1' then
						ext_keys_int(EX_BREAK) <= '1';
						else
							kb_data(ZX_K_CS) <= '1'; 
							kb_data(ZX_K_SP) <= '1'; 
							is_cs_used := '1';
						end if;
						
					-- Backspace -> CS + 0
					when X"2a" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_DELETE) <= '1';
						else
							kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_0) <= '1'; is_cs_used := '1'; 
						end if;

					-- Enter
					when X"28" =>	kb_data(ZX_K_ENT) <= '1'; -- normal
					when X"58" =>  kb_data(ZX_K_ENT) <= '1'; -- keypad 					
					
					-- Space 
					when X"2c" =>	kb_data(ZX_K_SP) <= '1';
					
					-- Letters
					when X"04" =>	kb_data(ZX_K_A) <= '1'; -- A
					when X"05" =>	kb_data(ZX_K_B) <= '1'; -- B								
					when X"06" =>	kb_data(ZX_K_C) <= '1'; -- C
					when X"07" =>	kb_data(ZX_K_D) <= '1'; -- D
					when X"08" =>	kb_data(ZX_K_E) <= '1'; -- E
					when X"09" =>	kb_data(ZX_K_F) <= '1'; -- F
					when X"0a" =>	kb_data(ZX_K_G) <= '1'; -- G
					when X"0b" =>	kb_data(ZX_K_H) <= '1'; -- H
					when X"0c" =>	kb_data(ZX_K_I) <= '1'; -- I
					when X"0d" =>	kb_data(ZX_K_J) <= '1'; -- J
					when X"0e" =>	kb_data(ZX_K_K) <= '1'; -- K
					when X"0f" =>	kb_data(ZX_K_L) <= '1'; -- L
					when X"10" =>	kb_data(ZX_K_M) <= '1'; -- M
					when X"11" =>	kb_data(ZX_K_N) <= '1'; -- N
					when X"12" =>	kb_data(ZX_K_O) <= '1'; -- O
					when X"13" =>	kb_data(ZX_K_P) <= '1'; -- P
					when X"14" =>	kb_data(ZX_K_Q) <= '1'; -- Q
					when X"15" =>	kb_data(ZX_K_R) <= '1'; -- R
					when X"16" =>	kb_data(ZX_K_S) <= '1'; -- S
					when X"17" =>	kb_data(ZX_K_T) <= '1'; -- T
					when X"18" =>	kb_data(ZX_K_U) <= '1'; -- U
					when X"19" =>	kb_data(ZX_K_V) <= '1'; -- V
					when X"1a" =>	kb_data(ZX_K_W) <= '1'; -- W
					when X"1b" =>	kb_data(ZX_K_X) <= '1'; -- X
					when X"1c" =>	kb_data(ZX_K_Y) <= '1'; -- Y
					when X"1d" =>	kb_data(ZX_K_Z) <= '1'; -- Z
					
					-- Digits
					when X"1e" =>	kb_data(ZX_K_1) <= '1'; -- 1
					when X"1f" =>	kb_data(ZX_K_2) <= '1'; -- 2
					when X"20" =>	kb_data(ZX_K_3) <= '1'; -- 3
					when X"21" =>	kb_data(ZX_K_4) <= '1'; -- 4
					when X"22" =>	kb_data(ZX_K_5) <= '1'; -- 5
					when X"23" =>	kb_data(ZX_K_6) <= '1'; -- 6
					when X"24" =>	kb_data(ZX_K_7) <= '1'; -- 7
					when X"25" =>	kb_data(ZX_K_8) <= '1'; -- 8
					when X"26" =>	kb_data(ZX_K_9) <= '1'; -- 9
					when X"27" =>	kb_data(ZX_K_0) <= '1'; -- 0
					-- Numpad digits
					when X"59" =>	kb_data(ZX_K_1) <= '1'; -- 1
					when X"5A" =>	kb_data(ZX_K_2) <= '1'; -- 2
					when X"5B" =>	kb_data(ZX_K_3) <= '1'; -- 3
					when X"5C" =>	kb_data(ZX_K_4) <= '1'; -- 4
					when X"5D" =>	kb_data(ZX_K_5) <= '1'; -- 5
					when X"5E" =>	kb_data(ZX_K_6) <= '1'; -- 6
					when X"5F" =>	kb_data(ZX_K_7) <= '1'; -- 7
					when X"60" =>	kb_data(ZX_K_8) <= '1'; -- 8
					when X"61" =>	kb_data(ZX_K_9) <= '1'; -- 9
					when X"62" =>	kb_data(ZX_K_0) <= '1'; -- 0
					
					-- Special keys 					
					-- '/" -> SS+P / SS+7
					when X"34" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_DQUOT) <= '1';
						else
							kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_P) <= '1'; else kb_data(ZX_K_7) <= '1'; end if; is_ss_used := is_shift;					
						end if;
						
					-- ,/< -> SS+N / SS+R
					when X"36" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_COMMA) <= '1';
						else
							kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_R) <= '1'; else kb_data(ZX_K_N) <= '1'; end if; is_ss_used := is_shift;					
						end if;

					-- ./> -> SS+M / SS+T
					when X"37" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_DOT) <= '1';
						else
							kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_T) <= '1'; else kb_data(ZX_K_M) <= '1'; end if; is_ss_used := is_shift;					
						end if;

					-- ;/: -> SS+O / SS+Z
					when X"33" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_SEMICOL) <= '1';
						else
							kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_Z) <= '1'; else kb_data(ZX_K_O) <= '1'; end if; is_ss_used := is_shift;					
						end if;
					
					-- Macroses
					
					-- [,{ -> SS+Y / SS+F
					when X"2F" => 
							is_macros <= '1'; if is_shift = '1' then macros_key <= ZX_K_F; else macros_key <= ZX_K_Y; end if; 
					
					-- ],} -> SS+U / SS+G
					when X"30" => 
							is_macros <= '1'; if is_shift = '1' then macros_key <= ZX_K_G; else macros_key <= ZX_K_U; end if; 
						
					-- \,| -> SS+D / SS+S
					when X"31" => 
							is_macros <= '1'; if is_shift = '1' then macros_key <= ZX_K_S; else macros_key <= ZX_K_D; end if; 					
					
					-- /,? -> SS+V / SS+C
					when X"38" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_C) <= '1'; else kb_data(ZX_K_V) <= '1'; end if; is_ss_used := is_shift;					
					-- =,+ -> SS+L / SS+K
					when X"2E" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_K) <= '1'; else kb_data(ZX_K_L) <= '1'; end if; is_ss_used := is_shift;					
					-- -,_ -> SS+J / SS+0
					when X"2D" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_0) <= '1'; else kb_data(ZX_K_J) <= '1'; end if; is_ss_used := is_shift;
					-- `,~ -> SS+X / SS+A
					when X"35" => 
						if (is_shift = '1') then 
							is_macros <= '1'; macros_key <= ZX_K_A; 
						else
							kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_X) <= '1'; 
						end if;
						is_ss_used := '1';
					-- Keypad * -> SS+B
					when X"55" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_B) <= '1'; 					
					-- Keypad - -> SS+J
					when X"56" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_J) <= '1';					
					-- Keypad + -> SS+K
					when X"57" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_K) <= '1';					
					-- Tab -> CS + I
					when X"2B" => kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_I) <= '1'; is_cs_used := '1'; 				
					-- CapsLock -> CS + SS
					when X"39" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_CAPSLOCK) <= '1';
						else
							kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_CS) <= '1'; is_cs_used := '1'; 
						end if;
						
					-- PgUp -> CS+3 for ZX
					when X"4B" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_TRU) <= '1';
						else
							if is_shift = '0' then
									kb_data(ZX_K_CS) <= '1'; 
									kb_data(ZX_K_3) <= '1'; 
									is_cs_used := '1'; 
							end if;
						end if;

					-- PgDown -> CS+4 for ZX 
					when X"4E" => 
						if CANCEL_EXT = '1' then
							ext_keys_int(EX_INV) <= '1';
						else
							if is_shift = '0' then
									kb_data(ZX_K_CS) <= '1'; 
									kb_data(ZX_K_4) <= '1'; 
									is_cs_used := '1'; 
							end if;
						end if;
						
					-- Home -> 
					when X"4a" =>	ext_keys_int(EX_EDIT) <= '1';
					
					-- End -> 
					when X"4d" =>	ext_keys_int(EX_GRAPH) <= '1';
					
					-- Fx keys
					--when X"3a" => null;  -- F1
					--when X"3b" => null;	-- F2
					--when X"3c" => null;	-- F3
					--when X"3d" => null;	-- F4
					--when X"3e" => null;	-- F5
					--when X"3f" => null;	-- F6
					--when X"40" => null;	-- F7
					--when X"41" => null;	-- F8
					--when X"42" => null;	-- F9
					--when X"43" => null;	-- F10
					--when X"44" => null;	-- F11
					--when X"45" => null;	-- F12
	 
					-- Soft-only keys
					--when X"46" =>	-- PrtScr
					--when X"47" =>	-- Scroll Lock
					--when X"48" =>	-- Pause
					--when X"65" =>	-- WinMenu
					
					when others => null;
				end case;
				end loop;
				
				-- map joysticks to keyboard
				
				-- sinclair 1
				if joy_type_l = JOY_TYPE_SINCLAIR1 then 
					if (joy_l(SC_BTN_UP) = '1') then kb_data(ZX_K_4) <= '1'; end if; -- up
					if (joy_l(SC_BTN_DOWN) = '1') then kb_data(ZX_K_3) <= '1'; end if; -- down
					if (joy_l(SC_BTN_LEFT) = '1') then kb_data(ZX_K_1) <= '1'; end if; -- left
					if (joy_l(SC_BTN_RIGHT) = '1') then kb_data(ZX_K_2) <= '1'; end if; -- right
					if (joy_l(SC_BTN_B) = '1') then kb_data(ZX_K_5) <= '1'; end if; -- fire
				end if;
				if joy_type_r = JOY_TYPE_SINCLAIR1 then
					if (joy_r(SC_BTN_UP) = '1') then kb_data(ZX_K_4) <= '1'; end if; -- up
					if (joy_r(SC_BTN_DOWN) = '1') then kb_data(ZX_K_3) <= '1'; end if; -- down
					if (joy_r(SC_BTN_LEFT) = '1') then kb_data(ZX_K_1) <= '1'; end if; -- left
					if (joy_r(SC_BTN_RIGHT) = '1') then kb_data(ZX_K_2) <= '1'; end if; -- right
					if (joy_r(SC_BTN_B) = '1') then kb_data(ZX_K_5) <= '1'; end if; -- fire					
				end if;
				
				-- sinclair 2
				if joy_type_l = JOY_TYPE_SINCLAIR2 then 
					if (joy_l(SC_BTN_UP) = '1') then kb_data(ZX_K_9) <= '1'; end if; -- up
					if (joy_l(SC_BTN_DOWN) = '1') then kb_data(ZX_K_8) <= '1'; end if; -- down
					if (joy_l(SC_BTN_LEFT) = '1') then kb_data(ZX_K_6) <= '1'; end if; -- left
					if (joy_l(SC_BTN_RIGHT) = '1') then kb_data(ZX_K_7) <= '1'; end if; -- right
					if (joy_l(SC_BTN_B) = '1') then kb_data(ZX_K_0) <= '1'; end if; -- fire	
				end if;
				if joy_type_r = JOY_TYPE_SINCLAIR2 then
					if (joy_r(SC_BTN_UP) = '1') then kb_data(ZX_K_9) <= '1'; end if; -- up
					if (joy_r(SC_BTN_DOWN) = '1') then kb_data(ZX_K_8) <= '1'; end if; -- down
					if (joy_r(SC_BTN_LEFT) = '1') then kb_data(ZX_K_6) <= '1'; end if; -- left
					if (joy_r(SC_BTN_RIGHT) = '1') then kb_data(ZX_K_7) <= '1'; end if; -- right
					if (joy_r(SC_BTN_B) = '1') then kb_data(ZX_K_0) <= '1'; end if; -- fire					
				end if;
				
				-- cursor
				if joy_type_l = JOY_TYPE_CURSOR then 
					if (joy_l(SC_BTN_UP) = '1') then kb_data(ZX_K_7) <= '1'; end if; -- up
					if (joy_l(SC_BTN_DOWN) = '1') then kb_data(ZX_K_6) <= '1'; end if; -- down
					if (joy_l(SC_BTN_LEFT) = '1') then kb_data(ZX_K_5) <= '1'; end if; -- left
					if (joy_l(SC_BTN_RIGHT) = '1') then kb_data(ZX_K_8) <= '1'; end if; -- right
					if (joy_l(SC_BTN_B) = '1') then kb_data(ZX_K_0) <= '1'; end if; -- fire	
				end if;
				if joy_type_r = JOY_TYPE_CURSOR then
					if (joy_r(SC_BTN_UP) = '1') then kb_data(ZX_K_7) <= '1'; end if; -- up
					if (joy_r(SC_BTN_DOWN) = '1') then kb_data(ZX_K_6) <= '1'; end if; -- down
					if (joy_r(SC_BTN_LEFT) = '1') then kb_data(ZX_K_5) <= '1'; end if; -- left
					if (joy_r(SC_BTN_RIGHT) = '1') then kb_data(ZX_K_8) <= '1'; end if; -- right
					if (joy_r(SC_BTN_B) = '1') then kb_data(ZX_K_0) <= '1'; end if; -- fire					
				end if;
				
--				-- user defined keymapped joysticks
--				if joy_type_l = JOY_TYPE_USER then
--					if (joy_l(SC_BTN_UP) = '1' 	and map_btn_up_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_up_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_DOWN) = '1' 	and map_btn_down_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_down_l))) 	<= '1'; end if;
--					if (joy_l(SC_BTN_LEFT) = '1' 	and map_btn_left_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_left_l))) 	<= '1'; end if;
--					if (joy_l(SC_BTN_RIGHT) = '1' and map_btn_right_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_right_l))) 	<= '1'; end if;
--					if (joy_l(SC_BTN_A) = '1' 		and map_btn_a_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_a_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_B) = '1' 		and map_btn_b_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_b_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_C) = '1' 		and map_btn_c_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_c_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_START) = '1' and map_btn_start_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_start_l))) 	<= '1'; end if;
--				end if;
--				
--				if joy_type_r = JOY_TYPE_USER then
--					if (joy_r(SC_BTN_UP) = '1' 	and map_btn_up_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_up_r))) 		<= '1'; end if;
--					if (joy_r(SC_BTN_DOWN) = '1' 	and map_btn_down_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_down_r))) 	<= '1'; end if;
--					if (joy_r(SC_BTN_LEFT) = '1' 	and map_btn_left_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_left_r))) 	<= '1'; end if;
--					if (joy_r(SC_BTN_RIGHT) = '1' and map_btn_right_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_right_r))) 	<= '1'; end if;
--					if (joy_r(SC_BTN_A) = '1' 		and map_btn_a_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_a_r)))	 	<= '1'; end if;
--					if (joy_r(SC_BTN_B) = '1' 		and map_btn_b_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_b_r))) 		<= '1'; end if;
--					if (joy_r(SC_BTN_C) = '1' 		and map_btn_c_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_c_r))) 		<= '1'; end if;
--					if (joy_r(SC_BTN_START) = '1' and map_btn_start_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_start_r))) 	<= '1'; end if;
--				end if;
--				
--				-- map user defined joy keys for other joy types (upper unused keys)
--
--				if (joy_type_l = JOY_TYPE_SINCLAIR1 or 
--					 joy_type_l = JOY_TYPE_SINCLAIR2 or 
--					 joy_type_l = JOY_TYPE_CURSOR) then
--					if (joy_l(SC_BTN_A) = '1' 		and map_btn_a_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_a_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_C) = '1' 		and map_btn_c_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_c_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_START) = '1' and map_btn_start_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_start_l))) 	<= '1'; end if;
--				end if;
--				
--				if (joy_type_l = JOY_TYPE_KEMPSTON1 or 
--					 joy_type_l = JOY_TYPE_KEMPSTON2) then
--					if (joy_l(SC_BTN_A) = '1' 		and map_btn_a_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_a_l))) 		<= '1'; end if;
--					if (joy_l(SC_BTN_START) = '1' and map_btn_start_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_start_l))) 	<= '1'; end if;
--				end if;
--				
--				if (joy_type_r = JOY_TYPE_SINCLAIR1 or 
--					 joy_type_r = JOY_TYPE_SINCLAIR2 or 
--					 joy_type_r = JOY_TYPE_CURSOR) then
--					if (joy_r(SC_BTN_A) = '1' 		and map_btn_a_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_a_r)))	 	<= '1'; end if;
--					if (joy_r(SC_BTN_C) = '1' 		and map_btn_c_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_c_r))) 		<= '1'; end if;
--					if (joy_r(SC_BTN_START) = '1' and map_btn_start_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_start_r))) 	<= '1'; end if;					 
--				end if;
--
--				if (joy_type_r = JOY_TYPE_KEMPSTON1 or 
--					 joy_type_r = JOY_TYPE_KEMPSTON2) then
--					if (joy_r(SC_BTN_A) = '1' 		and map_btn_a_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_a_r)))	 	<= '1'; end if;
--					if (joy_r(SC_BTN_START) = '1' and map_btn_start_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_start_r))) 	<= '1'; end if;					 
--				end if;
--				
--				if (joy_l(SC_BTN_X) = '1' 		and map_btn_x_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_x_l))) 		<= '1'; end if;
--				if (joy_l(SC_BTN_Y) = '1' 		and map_btn_y_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_y_l))) 		<= '1'; end if;
--				if (joy_l(SC_BTN_Z) = '1' 		and map_btn_z_l(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_z_l))) 		<= '1'; end if;
--				if (joy_l(SC_BTN_MODE) = '1' 	and map_btn_mode_l(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_mode_l))) 	<= '1'; end if;
--
--				if (joy_r(SC_BTN_X) = '1' 		and map_btn_x_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_x_r))) 		<= '1'; end if;
--				if (joy_r(SC_BTN_Y) = '1' 		and map_btn_y_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_y_r))) 		<= '1'; end if;
--				if (joy_r(SC_BTN_Z) = '1' 		and map_btn_z_r(5 downto 3) 		<= "100") then kb_data(to_integer(unsigned(map_btn_z_r))) 		<= '1'; end if;
--				if (joy_r(SC_BTN_MODE) = '1' 	and map_btn_mode_r(5 downto 3) 	<= "100") then kb_data(to_integer(unsigned(map_btn_mode_r))) 	<= '1'; end if;				
				
				-- cleanup CS key when SS is marked
				if (is_ss_used = '1' and is_cs_used = '0') then 
					kb_data(ZX_K_CS) <= '0';
				end if;
							
			end if;
		end if;
	end process;
	
	EXT_KEYS <= ext_keys_int;
	
	-- receive joy map into registers
	process (CLK, RESET)
	begin
		if RESET = '1' then
			map_btn_up_l <= (others => '1');
			map_btn_down_l <= (others => '1');
			map_btn_left_l <= (others => '1');
			map_btn_right_l <= (others => '1');
			map_btn_start_l<= (others => '1');
			map_btn_a_l <= (others => '1');
			map_btn_b_l <= (others => '1');
			map_btn_c_l <= (others => '1');
			map_btn_x_l <= (others => '1');
			map_btn_y_l <= (others => '1');
			map_btn_z_l <= (others => '1');
			map_btn_mode_l <= (others => '1');
			map_btn_up_r <= (others => '1');
			map_btn_down_r <= (others => '1');
			map_btn_left_r <= (others => '1');
			map_btn_right_r <= (others => '1');
			map_btn_start_r <= (others => '1');
			map_btn_a_r <= (others => '1');
			map_btn_b_r <= (others => '1');
			map_btn_c_r <= (others => '1');
			map_btn_x_r <= (others => '1');
			map_btn_y_r <= (others => '1');
			map_btn_z_r <= (others => '1');
			map_btn_mode_r <= (others => '1');			
		elsif rising_edge(CLK) then
			if KEYMAP_WE = '1' then 
				-- MODE X Z Y START A C B U D L R
				case KEYMAP_ADDR is 
					when "00000" => map_btn_right_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3); -- row + col => col + row
					when "00001" => map_btn_left_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "00010" => map_btn_down_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "00011" => map_btn_up_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "00100" => map_btn_b_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "00101" => map_btn_c_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "00110" => map_btn_a_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "00111" => map_btn_start_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "01000" => map_btn_y_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "01001" => map_btn_z_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "01010" => map_btn_x_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "01011" => map_btn_mode_l <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);

					when "10000" => map_btn_right_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10001" => map_btn_left_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10010" => map_btn_down_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10011" => map_btn_up_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10100" => map_btn_b_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10101" => map_btn_c_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10110" => map_btn_a_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "10111" => map_btn_start_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "11000" => map_btn_y_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "11001" => map_btn_z_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "11010" => map_btn_x_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					when "11011" => map_btn_mode_r <= KEYMAP_DATA(2 downto 0) & KEYMAP_DATA(5 downto 3);
					
					when others => null;
				end case;
			end if;
		end if;
	end process;

end rtl;

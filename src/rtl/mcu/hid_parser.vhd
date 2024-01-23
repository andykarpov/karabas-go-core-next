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
	 CANCEL_EXT : in std_logic;

	-- extended keys
	-- EXT_KEYS(15 downto 8) = DOWN LEFT RIGHT DELETE . , " ;
	-- EXT_KEYS( 7 downto 0) = EDIT BREAK INV TRU GRAPH CAPSLOCK UP EXTEND
	 
	 EXT_KEYS : out std_logic_vector(15 downto 0) := (others => '0')
	 
	);
end hid_parser;

architecture rtl of hid_parser is

	type matrix IS (ZX_K_CS, ZX_K_A, ZX_K_Q, ZX_K_1, 
						 ZX_K_0, ZX_K_P, ZX_K_ENT, ZX_K_SP,
						 ZX_K_Z, ZX_K_S, ZX_K_W, ZX_K_2,
						 ZX_K_9, ZX_K_O, ZX_K_L, ZX_K_SS,
						 ZX_K_X, ZX_K_D, ZX_K_E, ZX_K_3,
						 ZX_K_8, ZX_K_I, ZX_K_K, ZX_K_M,
						 ZX_K_C, ZX_K_F, ZX_K_R, ZX_K_4,
						 ZX_K_7, ZX_K_U, ZX_K_J, ZX_K_N,
						 ZX_K_V, ZX_K_G, ZX_K_T, ZX_K_5,
						 ZX_K_6, ZX_K_Y, ZX_K_H, ZX_K_B);
					

	type kb_matrix is array(matrix) of std_logic;
	
	signal kb_data : kb_matrix := (others => '0'); -- 40 keys
	
	signal data : std_logic_vector(47 downto 0);
	
	signal is_macros : std_logic := '0';
	type macros_machine is (MACRO_START, MACRO_CS_ON, MACRO_SS_ON, MACRO_SS_OFF, MACRO_KEY, MACRO_CS_OFF, MACRO_END);
	signal macros_key : matrix;
	signal macros_state : macros_machine := MACRO_START;
	signal macro_cnt : std_logic_vector(21 downto 0) := (others => '0');
	
--	type matrix_ex is (EX_EXTEND, EX_UP, EX_CAPSLOCK, EX_GRAPH, EX_TRU, EX_INV, EX_BREAK, EX_EDIT,
--							 EX_SEMICOL, EX_DQUOT, EX_COMMA, EX_DOT, EX_DELETE, EX_RIGHT, EX_LEFT, EX_DOWN);
--   type kb_matrix_ex is array(matrix_ex) of std_logic;	
	
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
					or    ( kb_data(ZX_K_SP) and not(   A(15) ) )  );

		KB_DO(1) <=	not( ( kb_data(ZX_K_Z)  and not(A(8) ) ) 
					or   ( kb_data(ZX_K_S)  and not(A(9) ) ) 
					or   ( kb_data(ZX_K_W) and not(A(10)) ) 
					or   ( kb_data(ZX_K_2) and not(A(11)) ) 
					or   ( kb_data(ZX_K_9) and not(A(12)) ) 
					or   ( kb_data(ZX_K_O) and not(A(13)) ) 
					or   ( kb_data(ZX_K_L) and not(A(14)) ) 
					or   ( kb_data(ZX_K_SS) and not(A(15)) ) );

		KB_DO(2) <=		not( ( kb_data(ZX_K_X) and not( A(8)) ) 
					or   ( kb_data(ZX_K_D) and not( A(9)) ) 
					or   ( kb_data(ZX_K_E) and not(A(10)) ) 
					or   ( kb_data(ZX_K_3) and not(A(11)) ) 
					or   ( kb_data(ZX_K_8) and not(A(12)) ) 
					or   ( kb_data(ZX_K_I) and not(A(13)) ) 
					or   ( kb_data(ZX_K_K) and not(A(14)) ) 
					or   ( kb_data(ZX_K_M) and not(A(15)) ) );

		KB_DO(3) <=		not( ( kb_data(ZX_K_C) and not( A(8)) ) 
					or   ( kb_data(ZX_K_F) and not( A(9)) ) 
					or   ( kb_data(ZX_K_R) and not(A(10)) ) 
					or   ( kb_data(ZX_K_4) and not(A(11)) ) 
					or   ( kb_data(ZX_K_7) and not(A(12)) ) 
					or   ( kb_data(ZX_K_U) and not(A(13)) ) 
					or   ( kb_data(ZX_K_J) and not(A(14)) ) 
					or   ( kb_data(ZX_K_N) and not(A(15)) ) );

		KB_DO(4) <=		not( ( kb_data(ZX_K_V) and not( A(8)) ) 
					or   ( kb_data(ZX_K_G) and not( A(9)) ) 
					or   ( kb_data(ZX_K_T) and not(A(10)) ) 
					or   ( kb_data(ZX_K_5) and not(A(11)) ) 
					or   ( kb_data(ZX_K_6) and not(A(12)) ) 
					or   ( kb_data(ZX_K_Y) and not(A(13)) ) 
					or   ( kb_data(ZX_K_H) and not(A(14)) ) 
					or   ( kb_data(ZX_K_B) and not(A(15)) ) );					
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
					kb_data(ZX_K_CS) <= '1'; 
					kb_data(ZX_K_SS) <= '1'; 
					is_cs_used := '1'; 
					ext_keys_int(EX_EXTEND) <= '1';
				end if;

				-- R Alt -> SS+CS / EXTEND key
				if KB_STATUS(6) = '1' then 
					kb_data(ZX_K_CS) <= '1'; 
					kb_data(ZX_K_SS) <= '1'; 
					is_cs_used := '1'; 
					ext_keys_int(EX_EXTEND) <= '1';
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
						if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_5) <= '1'; is_cs_used := '1'; end if; -- left
						ext_keys_int(EX_LEFT) <= '1';
						
					when X"51" =>	
						if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_Data(ZX_K_6) <= '1'; is_cs_used := '1'; end if;  -- down
						ext_keys_int(EX_DOWN) <= '1';
						
					when X"52" =>	
						if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_7) <= '1'; is_cs_used := '1'; end if; -- up
						ext_keys_int(EX_UP) <= '1';
					
					when X"4f" =>	
						if (is_shift = '0') then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_8) <= '1'; is_cs_used := '1'; end if; -- right
						ext_keys_int(EX_DOWN) <= '1';

					-- ESC -> CS + Space
					when X"29" => 
						kb_data(ZX_K_CS) <= '1'; 
						kb_data(ZX_K_SP) <= '1'; 
						is_cs_used := '1';
						ext_keys_int(EX_BREAK) <= '1';
						
					-- Backspace -> CS + 0
					when X"2a" => 
						kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_0) <= '1'; is_cs_used := '1'; 
						ext_keys_int(EX_DELETE) <= '1';

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
						kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_P) <= '1'; else kb_data(ZX_K_7) <= '1'; end if; is_ss_used := is_shift;					
						ext_keys_int(EX_DQUOT) <= '1';
						
					-- ,/< -> SS+N / SS+R
					when X"36" => 
						kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_R) <= '1'; else kb_data(ZX_K_N) <= '1'; end if; is_ss_used := is_shift;					
						ext_keys_int(EX_COMMA) <= '1';

					-- ./> -> SS+M / SS+T
					when X"37" => 
						kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_T) <= '1'; else kb_data(ZX_K_M) <= '1'; end if; is_ss_used := is_shift;					
						ext_keys_int(EX_DOT) <= '1';

					-- ;/: -> SS+O / SS+Z
					when X"33" => 
						kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_Z) <= '1'; else kb_data(ZX_K_O) <= '1'; end if; is_ss_used := is_shift;					
						ext_keys_int(EX_SEMICOL) <= '1';
					
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
						kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_CS) <= '1'; is_cs_used := '1'; 
						ext_keys_int(EX_CAPSLOCK) <= '1';
					
					-- PgUp -> CS+3 for ZX
					when X"4B" => 
						if is_shift = '0' then
								kb_data(ZX_K_CS) <= '1'; 
								kb_data(ZX_K_3) <= '1'; 
								is_cs_used := '1'; 
						end if;
						ext_keys_int(EX_TRU) <= '1';

					-- PgDown -> CS+4 for ZX 
					when X"4E" => 
						if is_shift = '0' then
								kb_data(ZX_K_CS) <= '1'; 
								kb_data(ZX_K_4) <= '1'; 
								is_cs_used := '1'; 
						end if;
						ext_keys_int(EX_INV) <= '1';
						
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
				
				-- cleanup CS key when SS is marked
				if (is_ss_used = '1' and is_cs_used = '0') then 
					kb_data(ZX_K_CS) <= '0';
				end if;
							
			end if;
		end if;
	end process;
	
	process (RESET, CANCEL_EXT)
	begin 
		if RESET = '1' or CANCEL_EXT = '1' then 
			EXT_KEYS <= (others => '0');
		else
			EXT_KEYS <= ext_keys_int;
		end if;
	end process;

end rtl;

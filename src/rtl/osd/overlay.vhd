library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity overlay is
	port (
		CLK		: in std_logic;
		ENA_28	: in std_logic;
		ENA_14	: in std_logic;
		RGB_I 	: in std_logic_vector(8 downto 0);
		RGB_O 	: out std_logic_vector(8 downto 0);
		DS80		: in std_logic;
		HCNT_I	: in std_logic_vector(9 downto 0);
		VCNT_I	: in std_logic_vector(8 downto 0);
		PAPER_I  : in std_logic;
		BLINK 	: in std_logic;
		
		STATUS_SD : in std_logic := '0'; -- SD card r/w status
		STATUS_CF : in std_logic := '0'; -- CF card r/w status
		STATUS_FD : in std_logic := '0'; -- FDD r/w status
		
		OSD_COMMAND 	: in std_logic_vector(15 downto 0)
	);
end entity;

architecture rtl of overlay is

    signal video_on : std_logic;
	 signal rgb: std_logic_vector(8 downto 0);

    signal attr, attr2: std_logic_vector(7 downto 0);

    signal char_x: std_logic_vector(2 downto 0);
    signal char_y: std_logic_vector(2 downto 0);

    signal rom_addr: std_logic_vector(10 downto 0);
    signal row_addr: std_logic_vector(2 downto 0);
    signal bit_addr: std_logic_vector(2 downto 0);
    signal font_word: std_logic_vector(7 downto 0);
    signal font_reg : std_logic_vector(7 downto 0);	 
    signal pixel: std_logic;
	 signal pixel_reg: std_logic;
    
    signal addr_read: std_logic_vector(9 downto 0);
    signal addr_write: std_logic_vector(9 downto 0);
    signal vram_di: std_logic_vector(15 downto 0);
    signal vram_do: std_logic_vector(15 downto 0);
    signal vram_wr: std_logic_vector(0 downto 0) := "0";

    signal flash : std_logic;
    signal is_flash : std_logic;
    signal rgb_fg : std_logic_vector(8 downto 0);
    signal rgb_bg : std_logic_vector(8 downto 0);

    signal selector : std_logic_vector(3 downto 0);
	 signal last_osd_command : std_logic_vector(15 downto 0);
	 signal char_buf : std_logic_vector(7 downto 0);
	 signal paper : std_logic := '0';
	 signal paper2 : std_logic := '0';
	 
	 signal hcnt : std_logic_vector(9 downto 0) := (others => '0');
	 signal vcnt : std_logic_vector(8 downto 0) := (others => '0');
	 
 	 signal osd_overlay: std_logic := '0';
	 signal osd_popup: std_logic := '0';
	 
	 constant paper_start_h : natural := 0;
	 constant paper_end_h : natural := 256;
	 constant paper_start_v : natural := 0;
	 constant paper_end_v : natural := 208; -- 26 character lines
	 
	 signal cnt_dbl : std_logic_vector(1 downto 0) := "00";
begin

	 -- 8x8 font
	 U_FONT: entity work.rom_font
    port map (
        addra  => rom_addr,
        clka   => CLK and ena_14,
        douta  => font_word
    );

	 -- OSD icons
	 U_ICONS: entity work.icons
    port map (
		CLK		=> CLK,
		ENA_28 	=> ENA_28,
		ENA_14   => ENA_14,
		RGB_I 	=> RGB_I,
		RGB_O 	=> rgb,
		DS80		=> DS80,
		HCNT		=> HCNT,
		VCNT		=> VCNT,
		
		STATUS_SD => STATUS_SD,
		STATUS_CF => STATUS_CF,
		STATUS_FD => STATUS_FD
    );

	 -- OSD VRAM
    U_VRAM: entity work.osd_vram 
    port map (
        dina   => vram_di,
        addra  => addr_write,
        clka   => CLK,
        wea    => vram_wr,

        addrb  => addr_read,
        clkb   => CLK and ena_14,
        doutb  => vram_do
    );

	 flash <= BLINK;
	 hcnt <= '0' & hcnt_i(9 downto 1) when DS80 = '1' else hcnt_i;
	 vcnt <= vcnt_i - 24 when DS80='1' else vcnt_i;

    char_x <= hcnt(3 downto 1) when OSD_POPUP = '1' else hcnt(2 downto 0);
    char_y <= vcnt(3 downto 1) when OSD_POPUP = '1' else VCNT(2 downto 0);
	 
	 paper2 <= '1' when hcnt >= paper_start_h and hcnt < paper_end_h and vcnt >= paper_start_v and vcnt < paper_end_v else '0'; 
	 paper <= '1' when hcnt >= paper_start_h + 8 and hcnt < paper_end_h + 8 and vcnt >= paper_start_v and vcnt < paper_end_v else '0'; --        (8 px)
    video_on <= '1' when (OSD_OVERLAY = '1' or OSD_POPUP = '1') else '0';
	 
	 -- mem read character / attribute
	 process (CLK, ENA_14, vram_do)
	 begin
		if (rising_edge(CLK)) then 
			if (ENA_28 = '1' and ENA_14 = '1') then 
			
				if (OSD_POPUP = '1') then 
					case (hcnt(3 downto 0)) is
						when "1110" =>
							if (paper2 = '1') then
									addr_read <= VCNT(8 downto 4) & HCNT(8 downto 4);
							end if;
						when "1111" => 
							attr2 <= vram_do(7 downto 0);
						when "0000" => 
							attr <= attr2;
							when others => null;						
					end case;
				else 
					case (char_x) is
						when "110" =>
							if (paper2 = '1') then
								addr_read <= VCNT(7 downto 3) & HCNT(7 downto 3);
							end if;
						when "111" => 
							attr2 <= vram_do(7 downto 0);
						when "000" => 
							attr <= attr2;
							when others => null;						
					end case;
				end if;
			end if;
		end if;
	 end process;
	 
	 -- pixel 
	 process (CLK, ENA_14, OSD_POPUP, hcnt, char_x, char_y)
	 begin
		if rising_edge(CLK) then
			if ENA_28 = '1' then
				if ENA_14 = '1' then
					if char_x = "111" then 
						rom_addr <= vram_do(15 downto 8) & char_y;
					end if;
					pixel <= font_reg(7);
					
					if (OSD_POPUP = '0' and cnt_dbl = "01") then
						cnt_dbl <= "00";
					elsif (OSD_POPUP = '1' and cnt_dbl = "11") then 
						cnt_dbl <= "00";
					else
						cnt_dbl <= cnt_dbl + 1;
					end if;
				else 
					if cnt_dbl = "00" then
						if char_x = "000" then 
							font_reg <= font_word;
						else 
							font_reg <= font_reg(6 downto 0) & "0";
						end if;
					end if;
				end if;
			end if;
		end if;
	 end process;
					 
	 --pixel_reg <= pixel;
	 pixel_reg <= font_reg(7);
	 
    is_flash <= '1' when attr(3 downto 0) = "0001" else '0';
    selector <= video_on & pixel_reg & flash & is_flash;
    rgb_fg <= (attr(7) and attr(4)) & attr(7) & attr(7) & (attr(6) and attr(4)) & attr(6) & attr(6) & (attr(5) and attr(4)) & attr(5) & attr(5);
    rgb_bg <= (attr(3) and attr(0)) & attr(3) & attr(3) & (attr(2) and attr(0)) & attr(2) & attr(2) & (attr(1) and attr(0)) & attr(1) & attr(1);
    RGB_O <= 
				rgb_fg when paper = '1' and (selector="1111" or selector="1001" or selector="1100" or selector="1110") else 
            rgb_bg(8 downto 7) & RGB(8) & rgb_bg(5 downto 4) & RGB(5) & rgb_bg(2 downto 1) & RGB(2) when paper = '1' and (selector="1011" or selector="1101" or selector="1000" or selector="1010") else 
				"00" & RGB(8) & "00" & RGB(5) & "00" & RGB(2) when video_on = '1' else 
				RGB;

	process(CLK, osd_command, last_osd_command)
	begin
		  if rising_edge(CLK) then
				 vram_wr <= "0";
				 if (osd_command /= last_osd_command) then 
					last_osd_command <= osd_command;
					case osd_command(15 downto 8) is 
					  when x"01" => vram_wr <= "0"; osd_overlay <= osd_command(0); -- osd
					  when x"02" => vram_wr <= "0"; osd_popup <= osd_command(0); -- popup						
					  when X"10"  => vram_wr <= "0"; addr_write(4 downto 0) <= osd_command(4 downto 0); -- x: 0...32
					  when X"11" => vram_wr <= "0"; addr_write(9 downto 5) <= osd_command(4 downto 0); -- y: 0...32
					  when X"12"  => vram_wr <= "0"; char_buf <= osd_command(7 downto 0); -- char
					  when X"13"  => vram_wr <= "1"; vram_di <= char_buf & osd_command(7 downto 0); -- attrs
					  when others => vram_wr <= "0";
					end case;
				 end if;
		  end if;
	end process;

end architecture;

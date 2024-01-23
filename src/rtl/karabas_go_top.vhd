-------------------------------------------------------------------------------------------------------------------
-- 
-- 
-- #       #######                                                 #                                               
-- #                                                               #                                               
-- #                                                               #                                               
-- ############### ############### ############### ############### ############### ############### ############### 
-- #             #               # #                             # #             #               # #               
-- #             # ############### #               ############### #             # ############### ############### 
-- #             # #             # #               #             # #             # #             #               # 
-- #             # ############### #               ############### ############### ############### ############### 
--                                                                                                                 
--         ####### ####### ####### #######                                         ############### ############### 
--                                                                                 #               #             # 
--                                                                                 #   ########### #             # 
--                                                                                 #             # #             # 
-- https://github.com/andykarpov/karabas-go                                        ############### ############### 
--
-- FPGA ZX Spectrum Next core 3.01.08 for Karabas-Go
--
-- @author Andy Karpov <https://github.com/andykarpov>
-- @author Oleh Starychenko <https://github.com/solegstar>
-- @author Oleh Chastukhin <https://github.com/Caasper911>
-- @author Alexander Sharihin <https://github.com/nihirash>
-- @author Doctor Max <https://github.com/drmax-gc>
-- EU, 2024
------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

entity karabas_go is
   generic (
      g_machine_id      : unsigned(7 downto 0)  := X"0A";   -- 10 = ZX Spectrum Next
      g_version         : unsigned(7 downto 0)  := X"31";   -- 3.01
      g_sub_version     : unsigned(7 downto 0)  := X"08"    -- .08
   );
   port ( 
		CLK_50MHZ 			: in   	STD_LOGIC;

		TAPE_IN 				: in   	STD_LOGIC;
		TAPE_OUT 			: out  	STD_LOGIC;
		BEEPER 				: out  	STD_LOGIC;
		DAC_LRCK 			: out  	STD_LOGIC;
		DAC_DAT 				: out  	STD_LOGIC;
		DAC_BCK 				: out  	STD_LOGIC;
		DAC_MUTE 			: out  	STD_LOGIC;

		ESP_RESET_N 		: inout  STD_LOGIC;
		ESP_BOOT_N 			: inout  STD_LOGIC;
		UART_RX 				: inout  STD_LOGIC;
		UART_TX 				: inout  STD_LOGIC;
		UART_CTS 			: inout  STD_LOGIC;

		WA 					: out  	STD_LOGIC_VECTOR (2 downto 0);
		WCS_N 				: out  	STD_LOGIC_VECTOR(1 downto 0);
		WRD_N 				: out  	STD_LOGIC;
		WWR_N 				: out  	STD_LOGIC;
		WRESET_N 			: out  	STD_LOGIC;
		WD 					: inout  STD_LOGIC_VECTOR (15 downto 0);

		MA 					: out  	STD_LOGIC_VECTOR (20 downto 0);
		MD 					: inout  STD_LOGIC_VECTOR (15 downto 0);
		MWR_N 				: out  	STD_LOGIC_VECTOR (1 downto 0);
		MRD_N 				: out  	STD_LOGIC_VECTOR (1 downto 0);

		SDR_BA 				: out  	STD_LOGIC_VECTOR (1 downto 0);
		SDR_A 				: out  	STD_LOGIC_VECTOR (12 downto 0);
		SDR_CLK 				: out  	STD_LOGIC;
		SDR_DQM 				: out  	STD_LOGIC_VECTOR (1 downto 0);
		SDR_WE_N 			: out  	STD_LOGIC;
		SDR_CAS_N 			: out 	STD_LOGIC;
		SDR_RAS_N 			: out  	STD_LOGIC;
		SDR_DQ 				: inout  STD_LOGIC_VECTOR (15 downto 0);

		SD_CS_N 				: out  	STD_LOGIC;
		SD_DI 				: inout  STD_LOGIC;
		SD_DO 				: inout  STD_LOGIC;
		SD_CLK 				: out  	STD_LOGIC;
		SD_DET_N 			: in  	STD_LOGIC;

		FDC_INDEX 			: in  	STD_LOGIC;
		FDC_DRIVE 			: out  	STD_LOGIC_VECTOR (1 downto 0);
		FDC_MOTOR 			: out  	STD_LOGIC;
		FDC_DIR 				: out  	STD_LOGIC;
		FDC_STEP 			: out  	STD_LOGIC;
		FDC_WDATA 			: out  	STD_LOGIC;
		FDC_WGATE 			: out  	STD_LOGIC;
		FDC_TR00 			: in  	STD_LOGIC;
		FDC_WPRT 			: in  	STD_LOGIC;
		FDC_RDATA 			: in  	STD_LOGIC;
		FDC_SIDE_N 			: out  	STD_LOGIC;

		FT_SPI_CS_N 		: out  	STD_LOGIC;
		FT_SPI_SCK 			: out  	STD_LOGIC;
		FT_SPI_MISO 		: inout  STD_LOGIC;
		FT_SPI_MOSI 		: inout  STD_LOGIC;
		FT_INT_N 			: inout  STD_LOGIC;
		FT_CLK 				: inout  STD_LOGIC;
		FT_OE_N 				: out  	STD_LOGIC;

		VGA_R 				: out  	STD_LOGIC_VECTOR (7 downto 0);
		VGA_G 				: out  	STD_LOGIC_VECTOR (7 downto 0);
		VGA_B 				: out  	STD_LOGIC_VECTOR (7 downto 0);
		VGA_HS 				: out  	STD_LOGIC;
		VGA_VS 				: out  	STD_LOGIC;
		V_CLK 				: out  	STD_LOGIC;

		MCU_CS_N 			: in  	STD_LOGIC;
		MCU_SCK 				: in  	STD_LOGIC;
		MCU_MOSI 			: in  	STD_LOGIC;
		MCU_MISO 			: out  	STD_LOGIC);
end entity;

architecture rtl of karabas_go is

   component pll_top
   port
   (
      SSTEP       : in std_logic;
      STATE       : in std_logic_vector(2 downto 0);
      RST         : in std_logic;
      CLKIN       : in std_logic;
      SRDY        : out std_logic;
  
      CLK0OUT     : out std_logic;
      CLK1OUT     : out std_logic;
      CLK2OUT     : out std_logic;
      CLK3OUT     : out std_logic;
      CLK4OUT     : out std_logic;
      CLK5OUT     : out std_logic
   );
   end component;

	-- virtual bus
	signal bus_rst_n_io      		: std_logic                      := 'Z';
	signal bus_clk35_o       		: std_logic                      := 'Z';
	signal bus_addr_o        		: std_logic_vector(15 downto 0)  := (others => 'Z');
	signal bus_data_io       		: std_logic_vector( 7 downto 0)  := (others => 'Z');
	signal bus_int_n_io      		: std_logic                      := 'Z';
	signal bus_nmi_n_i       		: std_logic								:= '1';
	signal bus_ramcs_i       		: std_logic 							:= '0';
	signal bus_romcs_i       		: std_logic 							:= '0';
	signal bus_wait_n_i      		: std_logic 							:= '1';
	signal bus_halt_n_o      		: std_logic                      := 'Z';
	signal bus_iorq_n_o      		: std_logic                      := 'Z';
	signal bus_m1_n_o        		: std_logic                      := 'Z';
	signal bus_mreq_n_o      		: std_logic                      := 'Z';
	signal bus_rd_n_o        		: std_logic                      := 'Z';
	signal bus_wr_n_o        		: std_logic                      := 'Z';
	signal bus_rfsh_n_o      		: std_logic                      := 'Z';
	signal bus_busreq_n_i    		: std_logic 							:= '0';
	signal bus_busack_n_o    		: std_logic                      := 'Z';
	signal bus_iorqula_n_i   		: std_logic 							:= '0';

	-- virtual PI GPIO
	signal accel_io          		: std_logic_vector(27 downto 0)  := (others => 'Z');

	signal ear_port_i_q           : std_logic;
   
   signal bus_data_i_0           : std_logic_vector(7 downto 0);
   signal bus_int_n_i_0          : std_logic := '1';
   signal bus_nmi_n_i_0          : std_logic := '1';
-- signal bus_ramcs_i_0          : std_logic;
   signal bus_romcs_i_0          : std_logic;
   signal bus_wait_n_i_0         : std_logic;
   signal bus_busreq_n_i_0       : std_logic;
   signal bus_iorqula_n_i_0      : std_logic;

   signal bus_data_i_q           : std_logic_vector(7 downto 0);
   signal bus_int_n_i_q          : std_logic := '1';
   signal bus_nmi_n_i_q          : std_logic := '1';
   signal bus_nmi_n_i_qq         : std_logic;
-- signal bus_ramcs_i_q          : std_logic;
   signal bus_romcs_i_q          : std_logic;
   signal bus_wait_n_i_q         : std_logic;
   signal bus_busreq_n_i_q       : std_logic;
   signal bus_iorqula_n_i_q      : std_logic;

   signal esp_gpio0_i_0          : std_logic;
   signal esp_gpio2_i_0          : std_logic;
   signal esp_rx_i_0             : std_logic;

   signal esp_gpio0_i_q          : std_logic;
   signal esp_gpio2_i_q          : std_logic;
   signal esp_rx_i_q             : std_logic;

   signal accel_i_0              : std_logic_vector(27 downto 0);
   signal accel_i_q              : std_logic_vector(27 downto 0);

   -- resets
   
   signal video_timing_change    : std_logic;
   signal actual_video_mode      : std_logic_vector(2 downto 0)   := "000";
   signal poweron_counter        : std_logic_vector(4 downto 0)   := (others => '1');
   signal reset_poweron          : std_logic;
   
   type reset_state_t            is (S_RESET_IDLE, S_RESET_HARD_0, S_RESET_HARD_1, S_RESET_SOFT_0, S_RESET_SOFT_1);
   signal reset_state            : reset_state_t := S_RESET_HARD_0;
   signal reset_state_next       : reset_state_t;
   
   signal reset_counter_start    : std_logic;
   signal reset_counter_en       : std_logic;
   signal reset_counter          : std_logic_vector(9 downto 0);
   signal reset_counter_eb       : std_logic;
   signal reset_counter_done     : std_logic;
   
   signal reset_hard             : std_logic;
   signal reset_soft             : std_logic;
   signal reset                  : std_logic;

   signal bus_reset_n_q          : std_logic;
   signal bus_reset_noise_n      : std_logic;
   signal bus_reset_db_n         : std_logic;
   signal bus_reset_db_n_d       : std_logic := '1';
   signal expbus_reset           : std_logic;
   
   signal zxn_video_mode         : std_logic_vector(2 downto 0);
   signal zxn_reset_hard         : std_logic;
   signal zxn_reset_soft         : std_logic;
   signal zxn_reset_peripheral   : std_logic;
   
   -- clocks
   
   signal CLK_28                 : std_logic;
   signal CLK_28_n               : std_logic;
   signal CLK_14                 : std_logic;
   signal CLK_7                  : std_logic;
   signal CLK_HDMI               : std_logic;
   signal CLK_HDMI_n             : std_logic;
   
   signal CLK_3M5_CONT           : std_logic;
   signal CLK_i0                 : std_logic;
   signal CLK_i1                 : std_logic;
   signal CLK_CPU                : std_logic;
   
   signal clk_28_div             : std_logic_vector(17 downto 0);
   
   signal CLK_28_PSG_EN          : std_logic;
   signal CLK_28_DEBOUNCE_EN     : std_logic;
   
   signal zxn_clock_contend      : std_logic;
   signal zxn_clock_lsb          : std_logic;
   signal zxn_cpu_speed          : std_logic_vector(1 downto 0);
   
   -- sram interface
   
   signal sram_port_b_req        : std_logic;
   signal zxn_ram_b_req          : std_logic;
   signal sram_addr              : std_logic_vector(20 downto 0);
   signal sram_cs_n              : std_logic_vector(3 downto 0);
   signal sram_data_H            : std_logic;
   signal sram_rd                : std_logic;
   
   signal sram_cs_n_active       : std_logic_vector(3 downto 0)   := (others => '1');
   signal sram_oe_n_active       : std_logic                      := '0';
   signal sram_addr_active       : std_logic_vector(18 downto 0)  := (others => '0');
   signal sram_data_active       : std_logic_vector(15 downto 0)  := (others => '0');
   signal sram_port_a_active     : std_logic                      := '0';
   signal sram_port_b_active     : std_logic                      := '0';
   signal sram_data_H_active     : std_logic                      := '0';
   
   signal sram_data_in           : std_logic_vector(15 downto 0);
   signal sram_port_a_read       : std_logic;
   signal sram_port_b_read       : std_logic;
   signal sram_data_H_read       : std_logic;
   signal sram_data_in_byte      : std_logic_vector(7 downto 0);
   
   signal sram_port_a_dat        : std_logic_vector(7 downto 0);
   signal sram_port_b_dat        : std_logic_vector(7 downto 0);
   signal sram_port_a_do         : std_logic_vector(7 downto 0);
   signal sram_port_b_do         : std_logic_vector(7 downto 0);
   
   signal sram_we_line           : std_logic_vector(3 downto 0)   := (others => '0');

	signal ram_addr_o        		: std_logic_vector(18 downto 0)  := (others => '0');
	signal ram_data_i       		: std_logic_vector(15 downto 0)  := (others => 'Z');
	signal ram_data_o       		: std_logic_vector(15 downto 0)  := (others => 'Z');
	signal ram_data_dir 				: std_logic := '0';
	signal ram_oe_n_o       		: std_logic                      := '1';
	signal ram_we_n_o       		: std_logic                      := '1';
	signal ram_ce_n_o       		: std_logic_vector( 3 downto 0)  := (others => '1');	
   
   -- audio
   
   signal mic_port               : std_logic;
   
   signal zxn_hdmi_audio         : std_logic;
   signal zxn_speaker_en         : std_logic;
   signal zxn_speaker_beep       : std_logic;
   signal zxn_tape_mic           : std_logic;

   signal zxn_audio_ear          : std_logic;
   signal zxn_audio_mic          : std_logic;
   
   signal zxn_audio_L_pre        : std_logic_vector(12 downto 0);
   signal zxn_audio_R_pre        : std_logic_vector(12 downto 0);
   
   -- video : vga
   
   signal ha_value               : integer range 0 to 2047;
   
   signal rgb_15                 : std_logic_vector(8 downto 0);
   signal rgb_31                 : std_logic_vector(8 downto 0);
   
   signal hsync_out              : std_logic;
   signal vsync_out              : std_logic;
   signal blank_out              : std_logic;
   
   signal zxn_rgb                : std_logic_vector(8 downto 0);
   signal zxn_rgb_cs_n           : std_logic;
   signal zxn_rgb_hs_n           : std_logic;
   signal zxn_rgb_vs_n           : std_logic;
   signal zxn_video_scanlines    : std_logic_vector(1 downto 0);
   signal zxn_rgb_vb_n           : std_logic;
   signal zxn_rgb_hb_n           : std_logic;
   signal zxn_machine_timing     : std_logic_vector(2 downto 0);
   signal zxn_video_scandouble_en   : std_logic;
   
   signal zxn_video_50_60        : std_logic;
   
   -- buttons, joystick, mouse, keyboard
   
   signal zxn_buttons            : std_logic_vector(1 downto 0);
   
   signal rgb_hs_n_dly           : std_logic_vector(1 downto 0);
   signal CLK_28_HSYNC_EN        : std_logic;
   
   signal io_mode_pin_7          : std_logic;
   
   signal zxn_joy_left           : std_logic_vector(10 downto 0);
   signal zxn_joy_right          : std_logic_vector(10 downto 0);
   
   signal zxn_joy_io_mode_en     : std_logic_vector(1 downto 0);
   signal zxn_joy_io_mode_lr     : std_logic;
   signal zxn_joy_io_mode_pin_7  : std_logic;

   signal zxn_ps2_mode           : std_logic;
   signal zxn_mouse_control      : std_logic_vector(2 downto 0);
   signal zxn_mouse_x            : std_logic_vector(7 downto 0);
   signal zxn_mouse_y            : std_logic_vector(7 downto 0);
   signal zxn_mouse_wheel        : std_logic_vector(7 downto 0);
   signal zxn_mouse_button       : std_logic_vector(2 downto 0);
   
   signal zxn_keymap_addr        : std_logic_vector(8 downto 0);
   signal zxn_keymap_dat         : std_logic_vector(8 downto 0);
   signal zxn_keymap_we          : std_logic;
   
   signal zxn_key_row            : std_logic_vector(7 downto 0);
   signal key_row_filtered       : std_logic_vector(7 downto 0);
   signal zxn_key_col            : std_logic_vector(4 downto 0);
   
   signal zxn_cancel_extended_entries  : std_logic;
   signal zxn_extended_keys      : std_logic_vector(15 downto 0);
   
   -- serial communication
   
   signal zxn_i2c_scl_n_o        : std_logic;
   signal zxn_i2c_sda_n_o        : std_logic;
   signal zxn_i2c_scl_n_i        : std_logic;
   signal zxn_i2c_sda_n_i        : std_logic;
   
   signal zxn_spi_ss_sd0_n       : std_logic;
   signal zxn_spi_ss_sd1_n       : std_logic;
   signal zxn_spi_sck            : std_logic;
   signal zxn_spi_mosi           : std_logic;
   
   signal zxn_spi_ss_flash_n     : std_logic;
   
   signal zxn_uart0_tx           : std_logic;
   signal zxn_uart0_rx           : std_logic;

   -- expansion bus
   
   signal zxn_bus_di             : std_logic_vector(7 downto 0);
   signal zxn_bus_int_n          : std_logic;
   signal zxn_bus_nmi_n          : std_logic;
   signal zxn_bus_romcs_n        : std_logic;
   signal zxn_bus_wait_n         : std_logic;
   signal zxn_bus_busreq_n       : std_logic;
   signal zxn_bus_iorqula_n      : std_logic;
   
   signal zxn_cpu_a              : std_logic_vector(15 downto 0);
   signal zxn_cpu_do             : std_logic_vector(7 downto 0);
   signal zxn_cpu_mreq_n         : std_logic;
   signal zxn_cpu_iorq_n         : std_logic;
   signal zxn_cpu_rd_n           : std_logic;
   signal zxn_cpu_wr_n           : std_logic;
   signal zxn_cpu_m1_n           : std_logic;
   signal zxn_cpu_int_n          : std_logic;
   signal zxn_cpu_busak_n        : std_logic;
   signal zxn_cpu_halt_n         : std_logic;
   signal zxn_cpu_rfsh_n         : std_logic;
   
   signal o_zxn_cpu_a            : std_logic_vector(15 downto 0) := (others => '0');
   signal o_zxn_cpu_do           : std_logic_vector(7 downto 0) := (others => '0');
   signal o_zxn_cpu_mreq_n       : std_logic := '1';
   signal o_zxn_cpu_iorq_n       : std_logic := '1';
   signal o_zxn_cpu_rd_n         : std_logic := '1';
   signal o_zxn_cpu_wr_n         : std_logic := '1';
   signal o_zxn_cpu_m1_n         : std_logic := '1';
   signal o_zxn_cpu_int_n        : std_logic := '1';
   signal o_zxn_cpu_busak_n      : std_logic := '1';
   signal o_zxn_cpu_halt_n       : std_logic := '1';
   signal o_zxn_cpu_rfsh_n       : std_logic := '1';
   
   signal zxn_bus_en             : std_logic;
   signal zxn_bus_clken          : std_logic;
   signal zxn_bus_clk            : std_logic;
   
   signal bus_clk_cpu            : std_logic;
   signal bus_clk_cpu_en_n       : std_logic;
   
   signal zxn_bus_nmi_debounce_disable  : std_logic;

   -- esp gpio
   
   signal zxn_esp_gpio20_i       : std_logic_vector(2 downto 0);
   
   signal zxn_esp_gpio0_o        : std_logic;
   signal zxn_esp_gpio0_en_o     : std_logic;
   
   signal esp_gpio0_o            : std_logic := '1';
   signal esp_gpio0_en           : std_logic := '0';
   
   -- pi gpio
   
   signal zxn_pi_gpio_i          : std_logic_vector(27 downto 0);
   signal zxn_gpio_o             : std_logic_vector(27 downto 0);
   signal zxn_gpio_en            : std_logic_vector(27 downto 0);
   
   signal pi_gpio_o              : std_logic_vector(27 downto 0);
   signal pi_gpio_en             : std_logic_vector(27 downto 0) := (others => '0');

   -- zx next
   
   signal zxn_function_keys      : std_logic_vector(10 downto 1);
   
   signal zxn_flashboot          : std_logic;
   signal zxn_coreid             : std_logic_vector(4 downto 0);

   signal zxn_ram_a_addr         : std_logic_vector(20 downto 0);
   signal zxn_ram_a_req          : std_logic;
   signal zxn_ram_a_rd           : std_logic;
   signal zxn_ram_a_di           : std_logic_vector(7 downto 0);
   signal zxn_ram_a_do           : std_logic_vector(7 downto 0);
   
   signal zxn_ram_b_addr         : std_logic_vector(20 downto 0);
   signal zxn_ram_b_req_t        : std_logic;
   signal zxn_ram_b_di           : std_logic_vector(7 downto 0);

	-- karabas signals --

	-- Keyboard 
	signal kb_do 						: std_logic_vector(5 downto 0) := "111111";
	
	-- Triggers
	signal kb_hard_reset 			: std_logic := '0';
	signal kb_scandoubler 			: std_logic := '0';
	signal kb_60hz 					: std_logic := '0';
	signal kb_soft_reset 			: std_logic := '0';
	signal kb_scanline 				: std_logic := '0';
	signal kb_cpu_speed 				: std_logic := '0';
	signal kb_multiface 				: std_logic := '0';
	signal kb_divmmc 					: std_logic := '0';

	-- Mouse
	signal ms_x							: std_logic_vector(7 downto 0);
	signal ms_y							: std_logic_vector(7 downto 0);
	signal ms_z							: std_logic_vector(3 downto 0);
	signal ms_b							: std_logic_vector(2 downto 0);
	
	-- Joystick
	signal joy_l 						: std_logic_vector(12 downto 0);
	signal joy_r 						: std_logic_vector(12 downto 0);	

	-- OSD overlay
	signal osd_command 				: std_logic_vector(15 downto 0);

	-- SOFT switches command
	signal softsw_command			: std_logic_vector(15 downto 0);

	-- raw hid data
	signal hid_kb_status 			: std_logic_vector(7 downto 0);
	signal hid_kb_dat0 				: std_logic_vector(7 downto 0);
	signal hid_kb_dat1 				: std_logic_vector(7 downto 0);
	signal hid_kb_dat2 				: std_logic_vector(7 downto 0);
	signal hid_kb_dat3 				: std_logic_vector(7 downto 0);
	signal hid_kb_dat4 				: std_logic_vector(7 downto 0);
	signal hid_kb_dat5 				: std_logic_vector(7 downto 0);
	signal hid_ms_x 					: std_logic_vector(7 downto 0);
	signal hid_ms_y					: std_logic_vector(7 downto 0);
	signal hid_ms_z					: std_logic_vector(3 downto 0);
	signal hid_ms_b					: std_logic_vector(2 downto 0);
	signal hid_ms_upd 				: std_logic;
	signal ms_present 				: std_logic := '0';

	-- mcu related
	signal mcu_busy 					: std_logic := '0';
	signal areset 						: std_logic := '0';

begin

   ------------------------------------------------------------
   -- SYNCHRONIZE ASYNCHRONOUS INPUTS
   ------------------------------------------------------------

   ear_sync : entity work.synchronize
   port map
   (
      i_CLK    => CLK_28,
      i_signal => TAPE_IN,
      o_signal => ear_port_i_q
   );

   -- Bus

   process (CLK_28)
   begin
      if falling_edge(CLK_28) then
         bus_data_i_0      <= bus_data_io;
         bus_int_n_i_0     <= bus_int_n_io;
         bus_nmi_n_i_0     <= bus_nmi_n_i or reset;
--       bus_ramcs_i_0     <= bus_ramcs_i;
         bus_romcs_i_0     <= bus_romcs_i;
         bus_wait_n_i_0    <= bus_wait_n_i;
         bus_busreq_n_i_0  <= bus_busreq_n_i;
         bus_iorqula_n_i_0 <= bus_iorqula_n_i;
      end if;
   end process;
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         bus_data_i_q      <= bus_data_i_0;
         bus_int_n_i_q     <= bus_int_n_i_0;
         bus_nmi_n_i_q     <= bus_nmi_n_i_0 or reset;
--       bus_ramcs_i_q     <= bus_ramcs_i_0;
         bus_romcs_i_q     <= bus_romcs_i_0;
         bus_wait_n_i_q    <= bus_wait_n_i_0;
         bus_busreq_n_i_q  <= bus_busreq_n_i_0;
         bus_iorqula_n_i_q <= bus_iorqula_n_i_0;
      end if;
   end process;
   
   -- ESP

   process (CLK_28)
   begin
      if falling_edge(CLK_28) then
         esp_gpio0_i_0 <= ESP_BOOT_N;
         esp_gpio2_i_0 <= '1';
         esp_rx_i_0 <= UART_RX;
      end if;
   end process;
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         esp_gpio0_i_q <= esp_gpio0_i_0;
         esp_gpio2_i_q <= esp_gpio2_i_0;
         esp_rx_i_q <= esp_rx_i_0;
      end if;
   end process;

   -- PI GPIO

   process (CLK_28)
   begin
      if falling_edge(CLK_28) then
         accel_i_0 <= accel_io;
      end if;
   end process;
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         accel_i_q <= accel_i_0;
      end if;
   end process;
   
   ------------------------------------------------------------
   -- RESETS --------------------------------------------------
   ------------------------------------------------------------

   -- power on or video timing change
   
   video_timing_change <= '1' when zxn_video_mode /= actual_video_mode else '0';

   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if video_timing_change = '1' then
            actual_video_mode <= zxn_video_mode;
            poweron_counter <= (others => '1');
         elsif reset_poweron = '1' then
            poweron_counter <= poweron_counter - 1;
         end if;
      end if;
   end process;
   
   reset_poweron <= '1' when poweron_counter /= "00000" else '0';
   
   -- hard and soft reset state machine

   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         reset_state <= reset_state_next;
      end if;
   end process;
   
   process (reset_poweron, zxn_reset_hard, reset_state, zxn_reset_soft, expbus_reset, reset_counter_done)
   begin
      if reset_poweron = '1' or zxn_reset_hard = '1' then
         reset_state_next <= S_RESET_HARD_0;
      else
         case reset_state is
            when S_RESET_IDLE =>
               if zxn_reset_soft = '1' or expbus_reset = '1' then
                  reset_state_next <= S_RESET_SOFT_0;
               else
                  reset_state_next <= S_RESET_IDLE;
               end if;
            when S_RESET_HARD_0 =>
               if reset_poweron = '1' then
                  reset_state_next <= S_RESET_HARD_0;
               else
                  reset_state_next <= S_RESET_HARD_1;
               end if;
            when S_RESET_HARD_1 =>
               if reset_counter_done = '1' then
                  reset_state_next <= S_RESET_IDLE;
               else
                  reset_state_next <= S_RESET_HARD_1;
               end if;
            when S_RESET_SOFT_0 =>
               reset_state_next <= S_RESET_SOFT_1;
            when S_RESET_SOFT_1 =>
               if reset_counter_done = '1' then
                  reset_state_next <= S_RESET_IDLE;
               else
                  reset_state_next <= S_RESET_SOFT_1;
               end if;
            when others =>
               reset_state_next <= S_RESET_IDLE;
         end case;
      end if;
   end process;

   reset_counter_start <= '1' when reset_state = S_RESET_HARD_0 or reset_state = S_RESET_SOFT_0 else '0';
   reset_counter_en <= '1' when bus_reset_db_n = '1' or zxn_bus_en = '0' or zxn_reset_peripheral = '1' else '0';
   
   reset_hard <= '1' when reset_state = S_RESET_HARD_0 or reset_state = S_RESET_HARD_1 else '0';
   reset_soft <= '1' when reset_state = S_RESET_SOFT_0 or reset_state = S_RESET_SOFT_1 else '0';
   
   reset <= reset_hard or reset_soft;
   
   bus_rst_n_io <= '0' when zxn_reset_peripheral = '1' or (reset_counter_eb = '1' and (reset_hard = '1' or (reset_soft = '1' and zxn_bus_en = '1'))) else 'Z';  -- makes more sense if exp bus reset and esp reset are separated
   
   -- reset counter

   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if reset_counter_start = '1' then
            reset_counter <= (others => '1');
         elsif reset_counter_eb = '1' or (reset_counter_en = '1' and reset_counter(0) = '1') then
            reset_counter <= reset_counter - 1;
         end if;
      end if;
   end process;
   
   reset_counter_eb <= '1' when reset_counter(9 downto 1) /= "000000000" else '0';
   reset_counter_done <= '1' when reset_counter_eb = '0' and reset_counter(0) = '0' else '0';
   
   -- expansion bus reset

   btn_expbus_rst : entity work.synchronize
   port map
   (
      i_CLK    => CLK_28,
      i_signal => bus_rst_n_io,
      o_signal => bus_reset_n_q
   );
   
   db_expbus_rst_noise : entity work.debounce
      generic map
   (
      INITIAL_STATE  => '1',
      COUNTER_SIZE   => 4      -- 16 * CLK_28 = ~571ns
   )
   port map
   (
      clk_i          => CLK_28,
      clk_en_i       => '1',
      button_i       => bus_reset_n_q,
      button_o       => bus_reset_noise_n
   );

   db_expbus_rst : entity work.debounce
   generic map
   (
      INITIAL_STATE  => '1',
      COUNTER_SIZE   => 3      -- 8 * CLK_28_DEBOUNCE_EN period = ~ 74.8ms
   )
   port map
   (
      clk_i          => CLK_28,
      clk_en_i       => CLK_28_DEBOUNCE_EN,
      button_i       => bus_reset_noise_n,
      button_o       => bus_reset_db_n
   );
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         bus_reset_db_n_d <= bus_reset_db_n;
      end if;
   end process;   
   
   expbus_reset <= '1' when bus_reset_db_n_d = '1' and bus_reset_db_n = '0' and zxn_reset_peripheral = '0' and zxn_bus_en = '1' else '0';

   ------------------------------------------------------------
   -- CLOCKS --------------------------------------------------
   ------------------------------------------------------------
   
   pll : pll_top
   port map
   (
      SSTEP       => reset_poweron,      -- todo: change to single cycle assertion
      STATE       => zxn_video_mode,     -- VGA 0-6, HDMI
      RST         => '0',
      CLKIN       => CLK_50MHZ,
      SRDY        => open,
    
      CLK0OUT     => CLK_28,             -- 28 MHz
      CLK1OUT     => CLK_28_n,           -- 28 Mhz inverted
      CLK2OUT     => CLK_14,             -- 14 MHz
      CLK3OUT     => CLK_7,              -- 7 MHz
      CLK4OUT     => CLK_HDMI,           -- 28 * 5
      CLK5OUT     => CLK_HDMI_n          -- 28 * 5 inverted
   );
   
   -- cpu clock selection

   process (CLK_7)
   begin
      if rising_edge(CLK_7) then
         if zxn_clock_lsb = '1' and zxn_clock_contend = '0' then
            CLK_3M5_CONT <= '0';
         elsif zxn_clock_lsb = '0' then
            CLK_3M5_CONT <= '1';
         end if;
      end if;
   end process;

   BUFGMUX1_i0 : BUFGMUX_1
   port map
   (
      I0 => CLK_3M5_CONT,
      I1 => CLK_7,
      S => zxn_cpu_speed(0),
      O => CLK_i0
   );

   BUFGMUX1_i1 : BUFGMUX_1
   port map
   (
      I0 => CLK_14,
      I1 => CLK_28,
      S => zxn_cpu_speed(0),
      O => CLK_i1
   );
   
   BUFGMUX1_i2 : BUFGMUX_1
   port map
   (
      I0 => CLK_i0,
      I1 => CLK_i1,
      S => zxn_cpu_speed(1),
      O => CLK_CPU
   );

   -- Clock Enables
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         clk_28_div <= clk_28_div + 1;
      end if;
   end process;
   
   CLK_28_PSG_EN <= '1' when clk_28_div(3 downto 0) = "1110" else '0';                   -- AY clock enable @ 1.75MHz
   CLK_28_DEBOUNCE_EN <= '1' when clk_28_div(17 downto 0) = ("11" & X"FFFF") else '0';   -- 9.36ms period for debounce
   --CLK_28_MOUSE_109KHZ <= clk_28_div(7);                                                 -- 109 kHz clock 50% duty for ps2 mouse
   --CLK_28_PS2_218KHZ <= clk_28_div(6);                                                   -- 218 kHz clock 50% duty cycle for ps2 keyboard
   --CLK_28_MEMBRANE_EN <= '1' when clk_28_div(8 downto 0) = ('1' & X"FF") else '0';       -- complete scan every 2.5 scanlines (0.018ms per row)	


   
   ------------------------------------------------------------
   -- SRAM INTERFACE ------------------------------------------
   ------------------------------------------------------------
   
   -- https://www.alliancememory.com/wp-content/uploads/pdf/sram/fa/as7c34096a_v2.1.pdf
   -- https://www.idt.com/document/dst/71v424-data-sheet
   
   -- SRAM cycles are executed within every 28MHz cycle and are
   -- granted to one of three simultaneous requesters, with the
   -- cpu granted highest priority and layer 2 granted second
   -- priority.

   -- To ensure that a 28MHz cpu speed would be possible, the 
   -- initial design allocates the entire 28MHz period to the 
   -- sram memory cycle with the result of reads stored at the 
   -- end of the period on the next rising edge.  This has
   -- the consequence that cpu instruction fetches and DMA
   -- 2-cycle reads must have one wait state inserted at 28MHz 
   -- speed.

   -- For memory write timing, the 5 x 28MHz hdmi clock is used
   -- to time the write pulse to ensure the write address is
   -- stable before the write pulse is asserted and to ensure
   -- the write cycle is completed before the end of the 28MHz period.
   
   -- Hard and soft resets span many 28MHz cycles so the currently
   -- running sram cycle is allowed to complete before the sram
   -- is held in a neutral state during the reset.  This ensures
   -- spurious writes don't contaminate the sram during soft reset.
   
   -- In the notation below, port A is r/w and is the highest
   -- priority assigned to the cpu.  Port B is read-only and
   -- is second priority assigned to layer 2.  Layer 2 requests
   -- can be delayed by one cycle so they are fine soaking up
   -- spare sram bandwidth at second priority.

   -- PORT A (R/W) (cpu/dma):
   --
   -- zxn_ram_a_addr   : std_logic_vector(20 downto 0)
   -- zxn_ram_a_req    : '1' on rising edge indicates memory request
   -- zxn_ram_a_rd     : '1' for read, '0' for write
   -- zxn_ram_a_do     : std_logic_vector(7 downto 0) data to write to memory
   -- zxn_ram_a_di     : std_logic_vector(7 downto 0) data read from memory
   
   -- PORT B (R) (layer 2):
   --
   -- zxn_ram_b_addr   : std_logic_vector(20 downto 0)
   -- zxn_ram_b_req_t  : toggles to indicate new request
   -- zxn_ram_b_di     : std_logic_vector(7 downto 0) data read from memory
   
   -- PORT C (R/W) (dma, soaks up spare bandwidth)
   
   -- SRAM I/O PINS:
   --
   -- ram_addr_o       : std_logic_vector(18 downto 0)
   -- ram_data_io      : std_logic_vector(15 downto 0)
   -- ram_oe_n_o
   -- ram_we_n_o
   -- ram_ce_n_o       : std_logic_vector(3 downto 0)
   
   -- Determine active port and sram signals for next memory cycle
   
   zxn_ram_b_req <= (zxn_ram_b_req_t xor sram_port_b_req) and not zxn_ram_a_req;   -- 0 = Port A (or nothing), 1 = Port B
   sram_addr <= (zxn_ram_a_addr(20) & zxn_ram_a_addr(0) & zxn_ram_a_addr(19 downto 1)) when zxn_ram_b_req = '0' else (zxn_ram_b_addr(20) & zxn_ram_b_addr(0) & zxn_ram_b_addr(19 downto 1));
   
   -- Track port B request which operates on a toggled signal
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if zxn_ram_b_req = '1' then
            sram_port_b_req <= zxn_ram_b_req_t;
         end if;
      end if;
   end process;

   -- Select active sram chip
   
   process (zxn_ram_a_req, zxn_ram_b_req, sram_addr)
   begin
      if zxn_ram_a_req = '1' or zxn_ram_b_req = '1' then
         case sram_addr(20 downto 19) is
            when "00"   =>  sram_cs_n <= "1110";
            when "01"   =>  sram_cs_n <= "1101";
            when "10"   =>  sram_cs_n <= "1011";
            when others =>  sram_cs_n <= "0111";
         end case;
      else
         sram_cs_n <= (others => '1');
      end if;
   end process;
   
   sram_data_H <= sram_addr(19);
   sram_rd <= (zxn_ram_a_rd or not zxn_ram_a_req) when zxn_ram_b_req = '0' else '1';
   
   -- Memory cycle
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if reset = '1' then
         
            sram_cs_n_active <= (others => '1');
            sram_oe_n_active <= '0';
            sram_addr_active <= (others => '0');
            sram_data_active <= (others => '0');
            
            sram_port_a_active <= '0';
            sram_port_b_active <= '0';
            
            sram_data_H_active <= '0';

         else

            sram_cs_n_active <= sram_cs_n;
            sram_oe_n_active <= not sram_rd;
            sram_addr_active <= sram_addr(18 downto 0);
            sram_data_active <= zxn_ram_a_do & zxn_ram_a_do;
            
            sram_port_a_active <= zxn_ram_a_req;
            sram_port_b_active <= zxn_ram_b_req;
            
            sram_data_H_active <= sram_data_H;

         end if;
      end if;
   end process;
   
   -- Data in (R)
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         sram_data_in <= ram_data_i;
      end if;
   end process;
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         sram_port_a_read <= sram_port_a_active and not sram_oe_n_active;
         sram_port_b_read <= sram_port_b_active and not sram_oe_n_active;
         sram_data_H_read <= sram_data_H_active;
      end if;
   end process;
   
   sram_data_in_byte <= sram_data_in(7 downto 0) when sram_data_H_read = '0' else sram_data_in(15 downto 8);
   
   --
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if sram_port_a_read = '1' then
            sram_port_a_dat <= sram_data_in_byte;
         end if;
      end if;
   end process;
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if sram_port_b_read = '1' then
            sram_port_b_dat <= sram_data_in_byte;
         end if;
      end if;
   end process;
   
   sram_port_a_do <= sram_data_in_byte when sram_port_a_read = '1' else sram_port_a_dat;
   sram_port_b_do <= sram_data_in_byte when sram_port_b_read = '1' else sram_port_b_dat;
   
   -- Data out (W)
   -- 28MHz cycle is partitioned into five periods some of which will carry we signal
   
   process (CLK_HDMI)
   begin
      if rising_edge(CLK_HDMI) then
         if sram_oe_n_active = '1' and sram_we_line = "0000" then
            sram_we_line <= "1111";
            ram_we_n_o <= '0';
         else
            sram_we_line <= sram_we_line(2 downto 0) & '0';
            if sram_we_line(3 downto 1) = "111" then
               ram_we_n_o <= '0';
            else
               ram_we_n_o <= '1';
            end if;
         end if;
      end if;
   end process;
   
   -- Connect I/O signals
   
   -- make sure xst is pushing registers into io blocks
   
   ram_addr_o <= sram_addr_active;
   ram_data_o <= sram_data_active when sram_oe_n_active = '1' else (others => 'Z');
	ram_data_dir <= sram_oe_n_active;
   ram_oe_n_o <= sram_oe_n_active;
   ram_ce_n_o <= sram_cs_n_active;
   
   zxn_ram_a_di <= sram_port_a_do;
   zxn_ram_b_di <= sram_port_b_do;	
	
	----- karabas memory mapping from 4 to 2 chips
	MA(20) <= '0'; -- disable 4mb
	MA(19) <= '1' when ram_ce_n_o(3) = '0' or ram_ce_n_o(2) = '0' else '0';	-- 2nd megabyte access
	MA(18 downto 0) <= ram_addr_o(18 downto 0);
	MD <= ram_data_o when ram_data_dir = '1' else (others => 'Z');
	ram_data_i <= MD;
	MRD_N <= "00" when ram_ce_n_o /= "1111" and ram_oe_n_o = '0' else "11"; -- read both bytes
	MWR_N <= "10" when (ram_ce_n_o = "1110" or ram_ce_n_o = "1011") and ram_we_n_o = '0' else -- write lower byte
				"01" when (ram_ce_n_o = "1101" or ram_ce_n_o = "0111") and ram_we_n_o = '0' else -- write upper byte 
				"11";

   ------------------------------------------------------------
   -- AUDIO ---------------------------------------------------
   ------------------------------------------------------------

   -- tape save
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         mic_port <= zxn_audio_mic;
      end if;
   end process;

   TAPE_OUT <= mic_port;
   
  ------------------------------------------------------------
   -- VIDEO : VGA ---------------------------------------------
   ------------------------------------------------------------

   -- note: the values below are relative to the CLK period not standard VGA clock period
   
   sc_mod : entity work.scan_convert
   generic map
   (
      -- mark active area of input video
      
      cstart      =>  38*2,  -- composite sync start
      clength     => 352*2,  -- composite sync length
      
      -- output video timing
      
      hB          =>  32*2,   -- h sync
      hC          =>  40*2,   -- h back porch
      hD          => 352*2,   -- visible video (256 + both borders)
      hpad        =>   0*2,   -- create H black border

      vB          =>   2*2,   -- v sync
      vC          =>   5*2,   -- v back porch
      vD          => 284*2,   -- visible video
      vpad        =>   0*2    -- create V black border
   )
   port map
   (
      CLK         => CLK_14,
      CLK_x2      => CLK_28,

      hA          => ha_value,   -- h front porch
      I_VIDEO     => zxn_rgb,
      I_HSYNC     => zxn_rgb_hs_n,
      I_VSYNC     => zxn_rgb_vs_n,
      I_SCANLIN   => zxn_video_scanlines,
      I_BLANK_N   => zxn_rgb_cs_n,

      O_VIDEO_15  => rgb_15,     -- scanlines processed
      O_VIDEO_31  => rgb_31,     -- scanlines processed
      O_HSYNC     => hsync_out,
      O_VSYNC     => vsync_out,
      O_BLANK     => blank_out      
   );
   
   ha_value <= 48 when zxn_machine_timing(1) = '0' else 64;   -- 48k = 000 or 001, Pentagon = 100
   
   process (CLK_28)
   begin
      if falling_edge(CLK_28) then
      
         if zxn_video_scandouble_en = '0' then
         
            VGA_R <= rgb_15(8 downto 6) & rgb_15(8 downto 6) & "00";
            VGA_G <= rgb_15(5 downto 3) & rgb_15(5 downto 3) & "00";
            VGA_B <= rgb_15(2 downto 0) & rgb_15(2 downto 0) & "00";
            
            -- csync on hsync when the scandoubler is off
            
            VGA_HS <= zxn_rgb_cs_n;
            VGA_VS <= '1';
            
         else
         
            VGA_R <= rgb_31(8 downto 6) & rgb_31(8 downto 6) & "00";
            VGA_G <= rgb_31(5 downto 3) & rgb_31(5 downto 3) & "00";
            VGA_B <= rgb_31(2 downto 0) & rgb_31(2 downto 0) & "00";
            
            VGA_HS <= hsync_out;
            VGA_VS <= vsync_out;
         
         end if;
      end if;
   end process;
   
   ------------------------------------------------------------
   -- SERIAL COMMUNICATION ------------------------------------
   ------------------------------------------------------------

   -- spi sd card
   
   SD_CS_N <= zxn_spi_ss_sd0_n;

   process (CLK_CPU)
   begin
      if rising_edge(CLK_CPU) then
         SD_CLK  <= zxn_spi_sck;
         SD_DI  <= zxn_spi_mosi;
      end if;
   end process;
   
   -- uart (esp)

   UART_TX <= zxn_uart0_tx;
   zxn_uart0_rx <= UART_RX;
   
   ------------------------------------------------------------
   -- EXPANSION BUS -------------------------------------------
   ------------------------------------------------------------
   
   -- zxn_bus_en changes on rising edge of cpu clock
   -- bus cpu clock is held/floated high while the bus is disabled
   -- assumes cpu clock freq << CLK_28
   
   -- input

   zxn_bus_di <= bus_data_i_q;
   zxn_bus_int_n <= bus_int_n_i_q;
   zxn_bus_romcs_n <= bus_romcs_i_q;
   zxn_bus_wait_n <= bus_wait_n_i_q;
   zxn_bus_busreq_n <= bus_busreq_n_i_q;
   zxn_bus_iorqula_n <= bus_iorqula_n_i_q;
   
   db_expbus_nmi : entity work.asymmetrical_debounce
   generic map
   (
      INITIAL_STATE  => '1',
      COUNTER_SIZE   => 3      -- 8 * CLK_28_DEBOUNCE_EN period = ~ 74.8ms
   )
   port map
   (
      clk_i          => CLK_28,
      clk_en_i       => CLK_28_DEBOUNCE_EN,
      reset_i        => reset,
      button_i       => bus_nmi_n_i_q,
      button_o       => bus_nmi_n_i_qq
   );
   
   zxn_bus_nmi_n <= bus_nmi_n_i_qq when zxn_bus_nmi_debounce_disable = '0' else bus_nmi_n_i_q;
   
   -- output
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         o_zxn_cpu_a <= zxn_cpu_a;
         o_zxn_cpu_do <= zxn_cpu_do;
         o_zxn_cpu_mreq_n <= zxn_cpu_mreq_n;
         o_zxn_cpu_iorq_n <= zxn_cpu_iorq_n;
         o_zxn_cpu_rd_n <= zxn_cpu_rd_n;
         o_zxn_cpu_wr_n <= zxn_cpu_wr_n;
         o_zxn_cpu_m1_n <= zxn_cpu_m1_n;
         o_zxn_cpu_int_n <= zxn_cpu_int_n;
         o_zxn_cpu_busak_n <= zxn_cpu_busak_n;
         o_zxn_cpu_halt_n <= zxn_cpu_halt_n;
         o_zxn_cpu_rfsh_n <= zxn_cpu_rfsh_n;
      end if;
   end process;
   
   bus_addr_o <= (others => 'Z') when zxn_bus_en = '0' else o_zxn_cpu_a;
   bus_data_io <= (others => 'Z') when zxn_bus_en = '0' or o_zxn_cpu_rd_n = '0' or o_zxn_cpu_m1_n = '0' or o_zxn_cpu_rfsh_n = '0' else o_zxn_cpu_do;
   bus_mreq_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_mreq_n;
   bus_iorq_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_iorq_n;
   bus_rd_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_rd_n;
   bus_wr_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_wr_n;
   bus_m1_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_m1_n;
   bus_int_n_io <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_int_n;
   bus_busack_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_busak_n;
   bus_halt_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_halt_n;
   bus_rfsh_n_o <= 'Z' when zxn_bus_en = '0' else o_zxn_cpu_rfsh_n;
   
   -- clock to expansion bus

   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         bus_clk_cpu <= CLK_3M5_CONT;
      end if;
   end process;
   
   bus_clk35_o <= 'Z' when zxn_bus_en = '0' and zxn_bus_clken = '0' else bus_clk_cpu;
   
-- OBUFT_i0 : OBUFT
-- port map
-- (
--    I => CLK_3M5_CONT,
--    O => bus_clk35_o,
--    T => not (zxn_bus_en or zxn_bus_clken)
-- );

-- BUFGMUX1_i3 : BUFGMUX_1
-- generic map
-- (
--    CLK_SEL_TYPE => "ASYNC"
-- )
-- port map
-- (
--    I0 => CLK_3M5_CONT,
--    I1 => CLK_CPU,
--    S => zxn_bus_en,
--    O => zxn_bus_clk
-- );
--
-- ODDR2_i0 : ODDR2
-- generic map
-- (
--    DDR_ALIGNMENT => "NONE",
--    INIT => '1',
--    SRTYPE => "SYNC"
-- )
-- port map
-- (
--    Q => bus_clk_cpu,
--    C0 => zxn_bus_clk,
--    C1 => not zxn_bus_clk,
--    CE => '1',
--    D0 => '1',
--    D1 => '0',
--    R => '0',
--    S => '0'
-- );
-- 
-- ODDR2_i1 : ODDR2
-- generic map
-- (
--    DDR_ALIGNMENT => "NONE",
--    INIT => '1',
--    SRTYPE => "SYNC"
-- )
-- port map
-- (
--    Q => bus_clk_cpu_en_n,
--    C0 => zxn_bus_clk,
--    C1 => not zxn_bus_clk,
--    CE => '1',
--    D0 => not (zxn_bus_en or zxn_bus_clken),
--    D1 => not (zxn_bus_en or zxn_bus_clken),
--    R => '0',
--    S => '0'
-- );
--
-- OBUFT_i0 : OBUFT
-- port map
-- (
--    I => bus_clk_cpu,
--    O => bus_clk35_o,
--    T => bus_clk_cpu_en_n
-- );

   ------------------------------------------------------------
   -- ESP GPIO ------------------------------------------------
   ------------------------------------------------------------
   
   -- input
   
   zxn_esp_gpio20_i <= esp_gpio2_i_q & '0' & esp_gpio0_i_q;
   
   -- output
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         esp_gpio0_o <= zxn_esp_gpio0_o;
         esp_gpio0_en <= zxn_esp_gpio0_en_o;
      end if;
   end process;
   
   --esp_gpio2_io <= 'Z';
   ESP_BOOT_N <= 'Z' when esp_gpio0_en = '0' else esp_gpio0_o;

   ------------------------------------------------------------
   -- PI GPIO -------------------------------------------------
   ------------------------------------------------------------
   
   -- input

   zxn_pi_gpio_i <= accel_i_q;
   
   -- output
   
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         pi_gpio_o <= zxn_gpio_o;
         pi_gpio_en <= zxn_gpio_en;
      end if;
   end process;
   
   accel_io(27) <= 'Z' when pi_gpio_en(27) = '0' else pi_gpio_o(27);
   accel_io(26) <= 'Z' when pi_gpio_en(26) = '0' else pi_gpio_o(26);
   accel_io(25) <= 'Z' when pi_gpio_en(25) = '0' else pi_gpio_o(25);
   accel_io(24) <= 'Z' when pi_gpio_en(24) = '0' else pi_gpio_o(24);
   accel_io(23) <= 'Z' when pi_gpio_en(23) = '0' else pi_gpio_o(23);
   accel_io(22) <= 'Z' when pi_gpio_en(22) = '0' else pi_gpio_o(22);
   accel_io(21) <= 'Z' when pi_gpio_en(21) = '0' else pi_gpio_o(21);
   accel_io(20) <= 'Z' when pi_gpio_en(20) = '0' else pi_gpio_o(20);
   accel_io(19) <= 'Z' when pi_gpio_en(19) = '0' else pi_gpio_o(19);
   accel_io(18) <= 'Z' when pi_gpio_en(18) = '0' else pi_gpio_o(18);
   accel_io(17) <= 'Z' when pi_gpio_en(17) = '0' else pi_gpio_o(17);
   accel_io(16) <= 'Z' when pi_gpio_en(16) = '0' else pi_gpio_o(16);
   accel_io(15) <= 'Z' when pi_gpio_en(15) = '0' else pi_gpio_o(15);
   accel_io(14) <= 'Z' when pi_gpio_en(14) = '0' else pi_gpio_o(14);
   accel_io(13) <= 'Z' when pi_gpio_en(13) = '0' else pi_gpio_o(13);
   accel_io(12) <= 'Z' when pi_gpio_en(12) = '0' else pi_gpio_o(12);
   accel_io(11) <= 'Z' when pi_gpio_en(11) = '0' else pi_gpio_o(11);
   accel_io(10) <= 'Z' when pi_gpio_en(10) = '0' else pi_gpio_o(10);
   accel_io(9)  <= 'Z' when pi_gpio_en(9)  = '0' else pi_gpio_o(9);
   accel_io(8)  <= 'Z' when pi_gpio_en(8)  = '0' else pi_gpio_o(8);
   accel_io(7)  <= 'Z' when pi_gpio_en(7)  = '0' else pi_gpio_o(7);
   accel_io(6)  <= 'Z' when pi_gpio_en(6)  = '0' else pi_gpio_o(6);
   accel_io(5)  <= 'Z' when pi_gpio_en(5)  = '0' else pi_gpio_o(5);
   accel_io(4)  <= 'Z' when pi_gpio_en(4)  = '0' else pi_gpio_o(4);
   accel_io(3)  <= 'Z' when pi_gpio_en(3)  = '0' else pi_gpio_o(3);
   accel_io(2)  <= 'Z' when pi_gpio_en(2)  = '0' else pi_gpio_o(2);
   accel_io(1)  <= 'Z' when pi_gpio_en(1)  = '0' else pi_gpio_o(1);
   accel_io(0)  <= 'Z' when pi_gpio_en(0)  = '0' else pi_gpio_o(0);

   ------------------------------------------------------------
   -- TBBLUE / ZXNEXT -----------------------------------------
   ------------------------------------------------------------

   --  F1 = hard reset
   --  F2 = toggle scandoubler, hdmi reset
   --  F3 = toggle 50Hz / 60Hz display
   --  F4 = soft reset
   --  F5 = (temporary) expansion bus on
   --  F6 = (temporary) expansion bus off
   --  F7 = change scanline weight
   --  F8 = change cpu speed
   --  F9 = m1 button (multiface nmi)
   -- F10 = drive button (divmmc nmi)

   zxn_function_keys <= 
        kb_divmmc & 
        kb_multiface & 
        kb_cpu_speed & 
        kb_scanline & 
        "00" & 
        kb_soft_reset & 
        kb_60hz & 
        kb_scandoubler & 
        kb_hard_reset;

   zxn_buttons <= kb_divmmc & kb_multiface;
      
      zxnext : entity work.zxnext
   generic map
   (
      g_machine_id         => g_machine_id,
      g_version            => g_version,
      g_sub_version        => g_sub_version
   )
   port map
   (
      -- CLOCK
      
      i_CLK_28             => CLK_28,
      i_CLK_28_n           => CLK_28_n,
      i_CLK_14             => CLK_14,
      i_CLK_7              => CLK_7,
      i_CLK_CPU            => CLK_CPU,
      i_CLK_PSG_EN         => CLK_28_PSG_EN,
      
      o_CPU_SPEED          => zxn_cpu_speed,
      o_CPU_CONTEND        => zxn_clock_contend,
      o_CPU_CLK_LSB        => zxn_clock_lsb,
      
      -- RESET

      i_RESET_HARD         => reset_hard,
      i_RESET_SOFT         => reset_soft,
      
      o_RESET_SOFT         => zxn_reset_soft,
      o_RESET_HARD         => zxn_reset_hard,
      o_RESET_PERIPHERAL   => zxn_reset_peripheral,
      
      -- FLASH BOOT
      
      o_FLASH_BOOT         => zxn_flashboot,
      o_CORE_ID            => zxn_coreid,
      
      -- SPECIAL KEYS

      i_SPKEY_FUNCTION     => zxn_function_keys,
      i_SPKEY_BUTTONS      => zxn_buttons,
      
      -- MEMBRANE KEYBOARD
      
      o_KBD_CANCEL         => zxn_cancel_extended_entries,
      
      o_KBD_ROW            => zxn_key_row,
      i_KBD_COL            => zxn_key_col,
      
      i_KBD_EXTENDED_KEYS  => zxn_extended_keys,
      
      -- PS/2 KEYBOARD SETUP
      
      o_KEYMAP_ADDR        => zxn_keymap_addr,
      o_KEYMAP_DATA        => zxn_keymap_dat,
      o_KEYMAP_WE          => zxn_keymap_we,
      
      -- JOYSTICK
      
      i_JOY_LEFT           => zxn_joy_left,
      i_JOY_RIGHT          => zxn_joy_right,

      o_JOY_IO_MODE        => zxn_joy_io_mode_en,
      o_JOY_IO_MODE_LR     => zxn_joy_io_mode_lr,
      o_JOY_IO_MODE_PIN_7  => zxn_joy_io_mode_pin_7,
      
      -- MOUSE
      
      i_MOUSE_X            => zxn_mouse_x,
      i_MOUSE_Y            => zxn_mouse_y,
      i_MOUSE_BUTTON       => zxn_mouse_button,
      i_MOUSE_WHEEL        => zxn_mouse_wheel(3 downto 0),
      
      o_PS2_MODE           => zxn_ps2_mode,
      o_MOUSE_CONTROL      => zxn_mouse_control,
      
      -- I2C
      
      i_I2C_SCL_n          => zxn_i2c_scl_n_i,
      i_I2C_SDA_n          => zxn_i2c_sda_n_i,
      
      o_I2C_SCL_n          => zxn_i2c_scl_n_o,
      o_I2C_SDA_n          => zxn_i2c_sda_n_o,
      
      -- SPI

      o_SPI_SS_FLASH_n     => zxn_spi_ss_flash_n,
      o_SPI_SS_SD1_n       => zxn_spi_ss_sd1_n,
      o_SPI_SS_SD0_n       => zxn_spi_ss_sd0_n,

      o_SPI_SCK            => zxn_spi_sck,
      o_SPI_MOSI           => zxn_spi_mosi,
      
      i_SPI_SD_MISO        => SD_DO,
      i_SPI_FLASH_MISO     => '1',
      
      -- UART
      
      i_UART0_RX           => zxn_uart0_rx,
      o_UART0_TX           => zxn_uart0_tx,
      
      -- VIDEO
      -- synchronized to i_CLK_14
      
      o_RGB                => zxn_rgb,
      o_RGB_CS_n           => zxn_rgb_cs_n,
      o_RGB_VS_n           => zxn_rgb_vs_n,
      o_RGB_HS_n           => zxn_rgb_hs_n,
      o_RGB_VB_n           => zxn_rgb_vb_n,
      o_RGB_HB_n           => zxn_rgb_hb_n,
      
      o_VIDEO_50_60        => zxn_video_50_60,
      o_VIDEO_SCANLINES    => zxn_video_scanlines,
      o_VIDEO_SCANDOUBLE   => zxn_video_scandouble_en,
      
      o_VIDEO_MODE         => zxn_video_mode,                     -- VGA 0-6, HDMI
      o_MACHINE_TIMING     => zxn_machine_timing,                 -- video timing: 00X = 48k, 010 = 128k, 011 = +3, 100 = pentagon
      
      o_HDMI_RESET         => open,
      
      -- AUDIO
      
      o_AUDIO_HDMI_AUDIO_EN => zxn_hdmi_audio,

      o_AUDIO_SPEAKER_EN   => zxn_speaker_en,
      o_AUDIO_SPEAKER_BEEP => zxn_speaker_beep,
      
      i_AUDIO_EAR          => ear_port_i_q,
      o_AUDIO_MIC          => zxn_tape_mic,

      o_AUDIO_SPEAKER_EAR  => zxn_audio_ear,
      o_AUDIO_SPEAKER_MIC  => zxn_audio_mic,
      
      o_AUDIO_L            => zxn_audio_L_pre,
      o_AUDIO_R            => zxn_audio_R_pre,

      -- EXTERNAL SRAM (synchronized to i_CLK_28)
      -- memory transactions complete in one cycle, data read is registered but available asap
      
      -- Port A is read/write and highest priority (CPU)
      
      o_RAM_A_ADDR         => zxn_ram_a_addr,
      o_RAM_A_REQ          => zxn_ram_a_req,
      o_RAM_A_RD           => zxn_ram_a_rd,
      i_RAM_A_DI           => zxn_ram_a_di,
      o_RAM_A_DO           => zxn_ram_a_do,
      
      -- Port B is read only (LAYER 2)
      
      o_RAM_B_ADDR         => zxn_ram_b_addr,
      o_RAM_B_REQ_T        => zxn_ram_b_req_t,
      i_RAM_B_DI           => zxn_ram_b_di,
      
      -- EXPANSION BUS
      
      o_BUS_ADDR           => zxn_cpu_a,
      i_BUS_DI             => zxn_bus_di,
      o_BUS_DO             => zxn_cpu_do,
      o_BUS_MREQ_n         => zxn_cpu_mreq_n,
      o_BUS_IORQ_n         => zxn_cpu_iorq_n,
      o_BUS_RD_n           => zxn_cpu_rd_n,
      o_BUS_WR_n           => zxn_cpu_wr_n,
      o_BUS_M1_n           => zxn_cpu_m1_n,
      i_BUS_WAIT_n         => zxn_bus_wait_n,
      i_BUS_NMI_n          => zxn_bus_nmi_n,
      i_BUS_INT_n          => zxn_bus_int_n,
      o_BUS_INT_n          => zxn_cpu_int_n,
      i_BUS_BUSREQ_n       => zxn_bus_busreq_n,
      o_BUS_BUSAK_n        => zxn_cpu_busak_n,
      o_BUS_HALT_n         => zxn_cpu_halt_n,
      o_BUS_RFSH_n         => zxn_cpu_rfsh_n,
      
      i_BUS_ROMCS_n        => zxn_bus_romcs_n,
      i_BUS_IORQULA_n      => zxn_bus_iorqula_n,
      
      o_BUS_EN             => zxn_bus_en,
      o_BUS_CLKEN          => zxn_bus_clken,

      o_BUS_NMI_DEBOUNCE_DISABLE  => zxn_bus_nmi_debounce_disable,
      
      -- ESP GPIO
      
      i_ESP_GPIO_20        => zxn_esp_gpio20_i,
      
      o_ESP_GPIO_0         => zxn_esp_gpio0_o,
      o_ESP_GPIO_0_EN      => zxn_esp_gpio0_en_o,

      -- PI GPIO
      
      i_GPIO               => zxn_pi_gpio_i,
      
      o_GPIO               => zxn_gpio_o,
      o_GPIO_EN            => zxn_gpio_en
   );


----------- Karabas units ----------------

-- MCU
U_MCU: entity work.mcu
port map(
	CLK => clk_28,
	N_RESET => not areset,
	
	MCU_MOSI => MCU_MOSI,
	MCU_MISO => MCU_MISO,
	MCU_SCK => MCU_SCK,
	MCU_SS => MCU_CS_N,
	
	MS_X => hid_ms_x,
	MS_Y => hid_ms_y,
	MS_Z => hid_ms_z,
	MS_B => hid_ms_b,
	MS_UPD => hid_ms_upd,
	
	KB_STATUS => hid_kb_status,
	KB_DAT0 => hid_kb_dat0,
	KB_DAT1 => hid_kb_dat1,
	KB_DAT2 => hid_kb_dat2,
	KB_DAT3 => hid_kb_dat3,
	KB_DAT4 => hid_kb_dat4,
	KB_DAT5 => hid_kb_dat5,
	
	JOY_L => joy_l,
	JOY_R => joy_r,
	
	RTC_A =>  "11111111", -- todo: emulate i2c clock :)
	RTC_DI => "11111111",
	RTC_DO => open,
	RTC_CS => '0',
	RTC_WR_N => '1',
	
	ROMLOADER_ACTIVE => open,
	ROMLOAD_ADDR => open,
	ROMLOAD_DATA => open,
	ROMLOAD_WR => open,
	
	SOFTSW_COMMAND => softsw_command,	
	OSD_COMMAND => osd_command,
	
	BUSY => mcu_busy
	
);

U_HID: entity work.hid_parser
port map (
	CLK => clk_28,
	RESET => areset,	

	-- hid keyboard input
	KB_STATUS => hid_kb_status,
	KB_DAT0 => hid_kb_dat0,
	KB_DAT1 => hid_kb_dat1,
	KB_DAT2 => hid_kb_dat2,
	KB_DAT3 => hid_kb_dat3,
	KB_DAT4 => hid_kb_dat4,
	KB_DAT5 => hid_kb_dat5,	

	-- joy inputs
	JOY_TYPE_L => "000", -- todo
	JOY_TYPE_R => "000",
	JOY_L => joy_l,
	JOY_R => joy_r,
	
	-- matrix
	A => zxn_key_row,	
	KB_DO => kb_do, 
	EXT_KEYS => zxn_extended_keys,
	
	-- keyboard type Profi XT = "00" / Spectrum = "01" / Next = "11"
	KB_TYPE => "11",
	
	-- outputs
	JOY_DO => open, -- todo: kempston

	KEYCODE => open
);

zxn_key_col <= kb_do(4 downto 0);

zxn_joy_left <= joy_l(11 downto 1);
zxn_joy_right <= joy_r(11 downto 1);

U_SW: entity work.soft_switches
port map (
	CLK => clk_28,
	
	SOFTSW_COMMAND => softsw_command,

    HARD_RESET => kb_hard_reset, -- F1
    SCANDOUBLER => kb_scandoubler, -- F2
    VGA_60HZ => kb_60hz, -- F3
    SOFT_RESET => kb_soft_reset, -- F4
    SCANLINE => kb_scanline, -- F7
    CPU_SPEED => kb_cpu_speed, -- F8
    MULTIFACE => kb_multiface, -- F9
    DIVMMC => kb_divmmc -- F10
);

-- Translate mouse events to absolute coordinates

U_MS: entity work.cursor
port map(
	CLK => CLK_28,
	RESET => areset,
	
	-- inputs from usb hid mouse
	MS_X => hid_ms_x,
	MS_Y => hid_ms_y,
	MS_Z => hid_ms_z,
	MS_B => hid_ms_b,
	MS_UPD => hid_ms_upd,
	
	-- output absoulte coords
	OUT_X => ms_x,
	OUT_Y => ms_y,
	OUT_Z => ms_z,
	OUT_B => ms_b
	
);

ms_present <= '1';

zxn_mouse_x <= ms_x;
zxn_mouse_y <= ms_y;
zxn_mouse_wheel <= "0000" & ms_z;
zxn_mouse_button <= ms_b;

-- Audio dac

U_DAC: entity work.PCM5102
port map (
	clk => CLK_28,
	left => "000" & zxn_audio_L_pre,
	right => "000" & zxn_audio_R_pre,
	din => DAC_DAT,
	bck => DAC_BCK,
	lrck => DAC_LRCK
);
DAC_MUTE <= '1';

-- CF
WA <= "000";
WCS_N <= "11";
WRD_N <= '1';
WWR_N <= '1';
WRESET_N <= '1';

-- FDC
FDC_SIDE_N <= '0';
FDC_DRIVE <= "00";
FDC_MOTOR <= '0';
FDC_WDATA <= '0';
FDC_WGATE <= '0';
FDC_STEP <= '0';
FDC_DIR <= '0';

-- SDRAM
SDR_BA <= "00";
SDR_A <= (others => '0');
SDR_CLK <= '0';
SDR_DQM <= "00";
SDR_WE_N <= '1';
SDR_CAS_N <= '1';
SDR_RAS_N <= '1';

-- FT812
FT_SPI_CS_N <= '1';
FT_SPI_SCK <= '0';
FT_OE_N <= '1';

---- V_CLK buf
VCLK_buf: ODDR2
port map(
	Q => V_CLK, -- pixel clock for video dac
	C0 => CLK_28,
	C1 => not CLK_28,
	D0 => '1',
	D1 => '0'
);

-- beeper
BEEPER <= zxn_speaker_beep;

end architecture;


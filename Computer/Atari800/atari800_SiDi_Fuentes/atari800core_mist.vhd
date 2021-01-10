--------------------------------------------------------------------------- -- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

ENTITY atari800core_mist IS 
	PORT
	(
		CLOCK_27 :  IN  STD_LOGIC_VECTOR(1 downto 0);

		VGA_VS :  OUT  STD_LOGIC;
		VGA_HS :  OUT  STD_LOGIC;
		VGA_B :  OUT  STD_LOGIC_VECTOR(5 DOWNTO 0);
		VGA_G :  OUT  STD_LOGIC_VECTOR(5 DOWNTO 0);
		VGA_R :  OUT  STD_LOGIC_VECTOR(5 DOWNTO 0);
		
		AUDIO_L : OUT std_logic;
		AUDIO_R : OUT std_logic;

		SDRAM_BA :  OUT  STD_LOGIC_VECTOR(1 downto 0);
		SDRAM_nCS :  OUT  STD_LOGIC;
		SDRAM_nRAS :  OUT  STD_LOGIC;
		SDRAM_nCAS :  OUT  STD_LOGIC;
		SDRAM_nWE :  OUT  STD_LOGIC;
		SDRAM_DQMH :  OUT  STD_LOGIC;
		SDRAM_DQML :  OUT  STD_LOGIC;
		SDRAM_CLK :  OUT  STD_LOGIC;
		SDRAM_CKE :  OUT  STD_LOGIC;
		SDRAM_A :  OUT  STD_LOGIC_VECTOR(12 DOWNTO 0);
		SDRAM_DQ :  INOUT  STD_LOGIC_VECTOR(15 DOWNTO 0);

		LED : OUT std_logic;
		
		UART_TX :  OUT  STD_LOGIC;
		UART_RX :  IN  STD_LOGIC;
		
		SPI_DO :  INOUT  STD_LOGIC;
		SPI_DI :  IN  STD_LOGIC;
		SPI_SCK :  IN  STD_LOGIC;
		SPI_SS2 :  IN  STD_LOGIC;		
		SPI_SS3 :  IN  STD_LOGIC;		
		SPI_SS4 :  IN  STD_LOGIC;
		CONF_DATA0 :  IN  STD_LOGIC -- AKA SPI_SS5
	);
END atari800core_mist;

ARCHITECTURE vhdl OF atari800core_mist IS 

component hq_dac
port (
  reset :in std_logic;
  clk :in std_logic;
  clk_ena : in std_logic;
  pcm_in : in std_logic_vector(19 downto 0);
  dac_out : out std_logic
);
end component;

COMPONENT rgb2ypbpr
PORT (
        red     :        IN std_logic_vector(5 DOWNTO 0);
        green   :        IN std_logic_vector(5 DOWNTO 0);
        blue    :        IN std_logic_vector(5 DOWNTO 0);
        y       :        OUT std_logic_vector(5 DOWNTO 0);
        pb      :        OUT std_logic_vector(5 DOWNTO 0);
        pr      :        OUT std_logic_vector(5 DOWNTO 0)
        );
END COMPONENT;

component user_io
	GENERIC(
		STRLEN : in integer := 0
	);
	PORT(
		-- conf_str? how to do in vhdl...

		-- mist spi to firmware
		SPI_CLK : in std_logic;
		SPI_SS_IO : in std_logic;
		SPI_MISO : out std_logic;
		SPI_MOSI : in std_logic;

		-- joysticks
		JOYSTICK_0 : out std_logic_vector(5 downto 0);
		JOYSTICK_1 : out std_logic_vector(5 downto 0);
		JOYSTICK_ANALOG_0 : out std_logic_vector(15 downto 0);
		JOYSTICK_ANALOG_1 : out std_logic_vector(15 downto 0);
		BUTTONS : out std_logic_vector(1 downto 0);
		SWITCHES : out std_logic_vector(1 downto 0);
		STATUS : out std_logic_vector(7 downto 0); -- what is this?

		-- ps2
		PS2_CLK : in std_logic; --12-16khz
		PS2_KBD_CLK : out std_logic;
		PS2_KBD_DATA : out std_logic;

		-- serial (one way?)
		SERIAL_DATA : in std_logic_vector(7 downto 0);
		SERIAL_STROBE : in std_logic;

		-- connection to sd card emulation
		sd_lba : in std_logic_vector(31 downto 0);
		sd_rd : in std_logic;
		sd_wr : in std_logic;
		sd_ack : out std_logic;
		sd_conf : in std_logic;
		sd_sdhc : in std_logic;
		sd_dout : out std_logic_vector(7 downto 0);
		sd_dout_strobe : out std_logic;
		sd_din : in std_logic_vector(7 downto 0);
		sd_din_strobe : out std_logic
	  );
	end component;

	component sd_card
	PORT (
		-- link to user_io for io controller
		io_lba : out std_logic_vector(31 downto 0);
		io_rd : out std_logic;
		io_wr : out std_logic;
		io_ack : in std_logic;
		io_conf : out std_logic;
		io_sdhc : out std_logic;
		
		-- data coming in from io controller
		io_din : in std_logic_vector(7 downto 0);
		io_din_strobe : in std_logic;
		
		-- data going out to io controller
		io_dout : out std_logic_vector(7 downto 0);
		io_dout_strobe : in std_logic;
		
		-- configuration input
		allow_sdhc : in std_logic;
	
		sd_cs : in std_logic;
		sd_sck : in std_logic;
		sd_sdi : in std_logic;
		sd_sdo : out std_logic
	); 
	end component;

  signal AUDIO_L_PCM : std_logic_vector(15 downto 0);
  signal AUDIO_R_PCM : std_logic_vector(15 downto 0);

  signal VGA_VS_RAW : std_logic;
  signal VGA_HS_RAW : std_logic;
  signal VGA_CS_RAW : std_logic;

  signal RESET_n : std_logic;
  signal CLK : std_logic;
  signal CLK_SDRAM : std_logic;

  signal CLK_PLL1 : std_logic; -- cascaded to get better pal clock
  signal PLL1_LOCKED : std_logic;

  SIGNAL PS2_CLK : std_logic;
  SIGNAL PS2_DAT : std_logic;
  SIGNAL	CONSOL_OPTION_RAW :  STD_LOGIC;
  SIGNAL	CONSOL_OPTION :  STD_LOGIC;
  SIGNAL	CONSOL_SELECT_RAW :  STD_LOGIC;
  SIGNAL	CONSOL_SELECT :  STD_LOGIC;
  SIGNAL	CONSOL_START_RAW :  STD_LOGIC;
  SIGNAL	CONSOL_START :  STD_LOGIC;
  SIGNAL FKEYS : std_logic_vector(11 downto 0);

  signal capslock_pressed : std_logic;
  signal capsheld_next : std_logic;
  signal capsheld_reg : std_logic;
  
  signal spi_miso_io : std_logic;

  signal mist_buttons : std_logic_vector(1 downto 0);
  signal mist_switches : std_logic_vector(1 downto 0);

  signal		JOY1 :  STD_LOGIC_VECTOR(5 DOWNTO 0);
  signal		JOY2 :  STD_LOGIC_VECTOR(5 DOWNTO 0);
  signal		JOY1_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
  signal		JOY2_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
  signal joy_still : std_logic;

  signal		JOY1X : std_logic_vector(7 downto 0);
  signal		JOY1Y : std_logic_vector(7 downto 0);
  signal		JOY2X : std_logic_vector(7 downto 0);
  signal		JOY2Y : std_logic_vector(7 downto 0);

  SIGNAL	KEYBOARD_RESPONSE :  STD_LOGIC_VECTOR(1 DOWNTO 0);
  SIGNAL	KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);
  signal atari_keyboard : std_logic_vector(63 downto 0);

  signal SDRAM_REQUEST : std_logic;
  signal SDRAM_REQUEST_COMPLETE : std_logic;
  signal SDRAM_READ_ENABLE :  STD_LOGIC;
  signal SDRAM_WRITE_ENABLE : std_logic;
  signal SDRAM_ADDR : STD_LOGIC_VECTOR(22 DOWNTO 0);
  signal SDRAM_DO : STD_LOGIC_VECTOR(31 DOWNTO 0);
  signal SDRAM_DI : STD_LOGIC_VECTOR(31 DOWNTO 0);
  signal SDRAM_WIDTH_8bit_ACCESS : std_logic;
  signal SDRAM_WIDTH_16bit_ACCESS : std_logic;
  signal SDRAM_WIDTH_32bit_ACCESS : std_logic;

  signal SDRAM_REFRESH : std_logic;
  
  signal SDRAM_RESET_N : std_logic;

	-- dma/virtual drive
	signal DMA_ADDR_FETCH : std_logic_vector(23 downto 0);
	signal DMA_WRITE_DATA : std_logic_vector(31 downto 0);
	signal DMA_FETCH : std_logic;
	signal DMA_32BIT_WRITE_ENABLE : std_logic;
	signal DMA_16BIT_WRITE_ENABLE : std_logic;
	signal DMA_8BIT_WRITE_ENABLE : std_logic;
	signal DMA_READ_ENABLE : std_logic;
	signal DMA_MEMORY_READY : std_logic;
	signal DMA_MEMORY_DATA : std_logic_vector(31 downto 0);

	signal ZPU_ADDR_ROM : std_logic_vector(15 downto 0);
	signal ZPU_ROM_DATA :  std_logic_vector(31 downto 0);

	signal ZPU_OUT1 : std_logic_vector(31 downto 0);
	signal ZPU_OUT2 : std_logic_vector(31 downto 0);
	signal ZPU_OUT3 : std_logic_vector(31 downto 0);
	signal ZPU_OUT4 : std_logic_vector(31 downto 0);
	signal ZPU_OUT6 : std_logic_vector(31 downto 0);

	signal zpu_pokey_enable : std_logic;
	signal zpu_sio_txd : std_logic;
	signal zpu_sio_rxd : std_logic;
	signal zpu_sio_command : std_logic;
	SIGNAL ASIO_CLOCKOUT : std_logic;

	-- system control from zpu
	signal ram_select : std_logic_vector(2 downto 0);
	signal reset_atari : std_logic;
	signal pause_atari : std_logic;
	SIGNAL speed_6502 : std_logic_vector(5 downto 0);
	signal turbo_vblank_only : std_logic;
	signal emulated_cartridge_select: std_logic_vector(5 downto 0);
	signal key_type : std_logic;
	signal atari800mode : std_logic;

	-- connection to sd card emulation
	signal sd_lba : std_logic_vector(31 downto 0);
	signal sd_rd : std_logic;
	signal sd_wr : std_logic;
	signal sd_ack : std_logic;
	signal sd_conf : std_logic;
	signal sd_sdhc : std_logic;
	signal sd_dout : std_logic_vector(7 downto 0);
	signal sd_dout_strobe : std_logic;
	signal sd_din : std_logic_vector(7 downto 0);
	signal sd_din_strobe : std_logic;

	signal mist_sd_sdo : std_logic;
	signal mist_sd_sck : std_logic;
	signal mist_sd_sdi : std_logic;
	signal mist_sd_cs : std_logic;

	-- ps2
	signal SLOW_PS2_CLK : std_logic; -- around 16KHz
	signal PS2_KEYS : STD_LOGIC_VECTOR(511 downto 0);
	signal PS2_KEYS_NEXT : STD_LOGIC_VECTOR(511 downto 0);

	-- scandoubler
	signal half_scandouble_enable_reg : std_logic;
	signal half_scandouble_enable_next : std_logic;
	signal VIDEO_B : std_logic_vector(7 downto 0);

	-- turbo freezer!
	signal freezer_enable : std_logic;
	signal freezer_activate: std_logic;

	-- paddles
	signal paddle_mode_next : std_logic;
	signal paddle_mode_reg : std_logic;

	-- video settings
	signal pal : std_logic;
	signal scandouble : std_logic;
	signal scanlines : std_logic;
	signal csync : std_logic;
	signal video_mode : std_logic_vector(2 downto 0);
	signal ypbpr : std_logic;

	-- pll reconfig
	signal CLK_RECONFIG_PLL : std_logic;
	signal CLK_RECONFIG_PLL_LOCKED : std_logic;

	-- ypbpr
	signal SCANDOUBLE_B :  STD_LOGIC_VECTOR(5 DOWNTO 0);
	signal SCANDOUBLE_G :  STD_LOGIC_VECTOR(5 DOWNTO 0);
	signal SCANDOUBLE_R :  STD_LOGIC_VECTOR(5 DOWNTO 0);
	signal vga_y_o      : std_logic_vector(5 downto 0);
	signal vga_pb_o     : std_logic_vector(5 downto 0);
	signal vga_pr_o     : std_logic_vector(5 downto 0);

BEGIN 
-- hack for paddles
	process(clk,RESET_N)
	begin
		if (RESET_N = '0') then
			paddle_mode_reg <= '0';
		elsif (clk'event and clk='1') then
			paddle_mode_reg <= paddle_mode_next;
		end if;
	end process;

	process(paddle_mode_reg, joy1, joy2)
	begin
		joy1_n <= (others=>'1');
		joy2_n <= (others=>'1');

		if (paddle_mode_reg = '1') then
			joy1_n <= "111"&not(joy1(4)&joy1(5)); --FLRDU
			joy2_n <= "111"&not(joy2(4)&joy2(5));
		else
			joy1_n <= not(joy1(4 downto 0));
			joy2_n <= not(joy2(4 downto 0));
		end if;
	end process;

	paddle_mode_next <= paddle_mode_reg xor (not(ps2_keys(16#11F#)) and ps2_keys_next(16#11F#)); -- left windows key

-- mist spi io
	spi_do <= spi_miso_io when CONF_DATA0 ='0' else 'Z';

my_user_io : user_io
	PORT map(
	   SPI_CLK => SPI_SCK,
	   SPI_SS_IO => CONF_DATA0,
	   SPI_MISO => SPI_miso_io,
	   SPI_MOSI => SPI_DI,
		JOYSTICK_0 => joy2,
		JOYSTICK_1 => joy1,
		JOYSTICK_ANALOG_0(15 downto 8) => joy2x,
		JOYSTICK_ANALOG_0(7 downto 0) => joy2y,
		JOYSTICK_ANALOG_1(15 downto 8) => joy1x,
		JOYSTICK_ANALOG_1(7 downto 0) => joy1y,
		BUTTONS => mist_buttons,
		SWITCHES => mist_switches,
		STATUS => open,

		PS2_CLK => SLOW_PS2_CLK,
		PS2_KBD_CLK => ps2_clk,
		PS2_KBD_DATA => ps2_dat,
	
		SERIAL_DATA => (others=>'0'),
		SERIAL_STROBE => '0',

		sd_lba => sd_lba,
		sd_rd => sd_rd,
		sd_wr => sd_wr,
		sd_ack => sd_ack,
		sd_conf => sd_conf,
		sd_sdhc => sd_sdhc,
		sd_dout => sd_dout,
		sd_dout_strobe => sd_dout_strobe,
		sd_din => sd_din,
		sd_din_strobe => sd_din_strobe
	  );

my_sd_card : sd_card
	PORT map (
		io_lba => sd_lba,
		io_rd => sd_rd,
		io_wr => sd_wr,
		io_ack => sd_ack,
		io_conf => sd_conf,
		io_sdhc => sd_sdhc,
		
		io_din => sd_dout,
		io_din_strobe => sd_dout_strobe,
		
		io_dout => sd_din,
		io_dout_strobe => sd_din_strobe,
		
		allow_sdhc => '1',
	
		sd_cs => mist_sd_cs,
		sd_sck => mist_sd_sck,
		sd_sdi => mist_sd_sdi,
		sd_sdo => mist_sd_sdo
	); 
	  
-- PS2 to pokey
keyboard_map1 : entity work.ps2_to_atari800
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,
		PS2_CLK => ps2_clk,
		PS2_DAT => ps2_dat,

 		INPUT => zpu_out4,

 		ATARI_KEYBOARD_OUT => atari_keyboard,

		KEY_TYPE => key_type,
		
		KEYBOARD_SCAN => KEYBOARD_SCAN,
		KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,

		CONSOL_START => CONSOL_START_RAW,
		CONSOL_SELECT => CONSOL_SELECT_RAW,
		CONSOL_OPTION => CONSOL_OPTION_RAW,
		
		FKEYS => FKEYS,
		FREEZER_ACTIVATE => freezer_activate,
		
		PS2_KEYS_NEXT_OUT => ps2_keys_next,
		PS2_KEYS => ps2_keys
	);

CONSOL_START <= CONSOL_START_RAW or (mist_buttons(1) and not(joy1_n(4)));
joy_still <= joy1_n(3) and joy1_n(2) and joy1_n(1) and joy1_n(0);
CONSOL_SELECT <= CONSOL_SELECT_RAW or (mist_buttons(1) and joy1_n(4) and not(joy_still));
CONSOL_OPTION <= CONSOL_OPTION_RAW or (mist_buttons(1) and joy1_n(4) and joy_still);
	 
dac_left : hq_dac
port map
(
  reset => not(reset_n),
  clk => clk,
  clk_ena => '1',
  pcm_in => AUDIO_L_PCM&"0000",
  dac_out => audio_l
);

dac_right : hq_dac
port map
(
  reset => not(reset_n),
  clk => clk,
  clk_ena => '1',
  pcm_in => AUDIO_R_PCM&"0000",
  dac_out => audio_r
);

reconfig_pll : entity work.pll_reconfig -- This only exists to generate reset!!
PORT MAP(inclk0 => CLOCK_27(0),
		 c0 => CLK_RECONFIG_PLL,
		 locked => CLK_RECONFIG_PLL_LOCKED);

	pll_switcher : work.switch_pal_ntsc
	    GENERIC MAP
	    (
	        CLOCKS => 4,
		SYNC_ON => 1
	    )
	    PORT MAP
	    (
	        RECONFIG_CLK => CLK_RECONFIG_PLL,
	        RESET_N => CLK_RECONFIG_PLL_LOCKED,
	
	        PAL => PAL,
	
	        INPUT_CLK => CLOCK_27(0),
	        PLL_CLKS(0) => CLK_SDRAM,
	        PLL_CLKS(1) => CLK,
	        PLL_CLKS(2) => SDRAM_CLK,
		PLL_CLKS(3) => SLOW_PS2_CLK,
	
		RESET_N_OUT => RESET_N
	    );

atarixl_simple_sdram1 : entity work.atari800core_simple_sdram
	GENERIC MAP
	(
		cycle_length => 32,
		internal_rom => 0,
		internal_ram => 0,
		video_bits => 8,
		palette => 0
	)
	PORT MAP
	(
		CLK => CLK,
		RESET_N => RESET_N and SDRAM_RESET_N and not(reset_atari),

		VIDEO_VS => VGA_VS_RAW,
		VIDEO_HS => VGA_HS_RAW,
		VIDEO_CS => VGA_CS_RAW,
		VIDEO_B => VIDEO_B,
		VIDEO_G => open,
		VIDEO_R => open,

		AUDIO_L => AUDIO_L_PCM,
		AUDIO_R => AUDIO_R_PCM,

		JOY1_n => JOY1_n(4)&JOY1_n(0)&JOY1_n(1)&JOY1_n(2)&JOY1_n(3),
		JOY2_n => JOY2_n(4)&JOY2_n(0)&JOY2_n(1)&JOY2_n(2)&JOY2_n(3),

		PADDLE0 => signed(joy1x),
		PADDLE1 => signed(joy1y),
		PADDLE2 => signed(joy2x),
		PADDLE3 => signed(joy2y),

		KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
		KEYBOARD_SCAN => KEYBOARD_SCAN,

		SIO_COMMAND => zpu_sio_command,
		SIO_RXD => zpu_sio_txd,
		SIO_TXD => zpu_sio_rxd,
		SIO_CLOCKOUT => ASIO_CLOCKOUT,

		CONSOL_OPTION => CONSOL_OPTION,
		CONSOL_SELECT => CONSOL_SELECT,
		CONSOL_START => CONSOL_START,

		SDRAM_REQUEST => SDRAM_REQUEST,
		SDRAM_REQUEST_COMPLETE => SDRAM_REQUEST_COMPLETE,
		SDRAM_READ_ENABLE => SDRAM_READ_ENABLE,
		SDRAM_WRITE_ENABLE => SDRAM_WRITE_ENABLE,
		SDRAM_ADDR => SDRAM_ADDR,
		SDRAM_DO => SDRAM_DO,
		SDRAM_DI => SDRAM_DI,
		SDRAM_32BIT_WRITE_ENABLE => SDRAM_WIDTH_32bit_ACCESS,
		SDRAM_16BIT_WRITE_ENABLE => SDRAM_WIDTH_16bit_ACCESS,
		SDRAM_8BIT_WRITE_ENABLE => SDRAM_WIDTH_8bit_ACCESS,
		SDRAM_REFRESH => SDRAM_REFRESH,

		DMA_FETCH => dma_fetch,
		DMA_READ_ENABLE => dma_read_enable,
		DMA_32BIT_WRITE_ENABLE => dma_32bit_write_enable,
		DMA_16BIT_WRITE_ENABLE => dma_16bit_write_enable,
		DMA_8BIT_WRITE_ENABLE => dma_8bit_write_enable,
		DMA_ADDR => dma_addr_fetch,
		DMA_WRITE_DATA => dma_write_data,
		MEMORY_READY_DMA => dma_memory_ready,
		DMA_MEMORY_DATA => dma_memory_data, 

   		RAM_SELECT => ram_select,
		PAL => PAL,
		HALT => pause_atari,
		THROTTLE_COUNT_6502 => speed_6502,
		TURBO_VBLANK_ONLY => turbo_vblank_only,
		emulated_cartridge_select => emulated_cartridge_select,
		freezer_enable => freezer_enable,
		freezer_activate => freezer_activate
	);

sdram_adaptor : entity work.sdram_statemachine
GENERIC MAP(ADDRESS_WIDTH => 22,
			AP_BIT => 10,
			COLUMN_WIDTH => 8,
			ROW_WIDTH => 12
			)
PORT MAP(CLK_SYSTEM => CLK,
		 CLK_SDRAM => CLK_SDRAM,
		 RESET_N =>  RESET_N,
		 READ_EN => SDRAM_READ_ENABLE,
		 WRITE_EN => SDRAM_WRITE_ENABLE,
		 REQUEST => SDRAM_REQUEST,
		 BYTE_ACCESS => SDRAM_WIDTH_8BIT_ACCESS,
		 WORD_ACCESS => SDRAM_WIDTH_16BIT_ACCESS,
		 LONGWORD_ACCESS => SDRAM_WIDTH_32BIT_ACCESS,
		 REFRESH => SDRAM_REFRESH,
		 ADDRESS_IN => SDRAM_ADDR,
		 DATA_IN => SDRAM_DI,
		 SDRAM_DQ => SDRAM_DQ,
		 COMPLETE => SDRAM_REQUEST_COMPLETE,
		 SDRAM_BA0 => SDRAM_BA(0),
		 SDRAM_BA1 => SDRAM_BA(1),
		 SDRAM_CKE => SDRAM_CKE,
		 SDRAM_CS_N => SDRAM_nCS,
		 SDRAM_RAS_N => SDRAM_nRAS,
		 SDRAM_CAS_N => SDRAM_nCAS,
		 SDRAM_WE_N => SDRAM_nWE,
		 SDRAM_ldqm => SDRAM_DQML,
		 SDRAM_udqm => SDRAM_DQMH,
		 DATA_OUT => SDRAM_DO,
		 SDRAM_ADDR => SDRAM_A(11 downto 0),
		 reset_client_n => SDRAM_RESET_N
		 );
		 
SDRAM_A(12) <= '0';
--SDRAM_REFRESH <= '0'; -- TODO

-- Until SDRAM enabled... TODO
--SDRAM_nCS <= '1';
--SDRAM_DQ <= (others=>'Z');

--SDRAM_CKE <= '1';		 
LED <= zpu_sio_rxd;

--VGA_HS <= not(VGA_HS_RAW xor VGA_VS_RAW);
--VGA_VS <= not(VGA_VS_RAW);

	process(clk,RESET_N,SDRAM_RESET_N,reset_atari)
	begin
		if ((RESET_N and SDRAM_RESET_N and not(reset_atari))='0') then
			half_scandouble_enable_reg <= '0';
		elsif (clk'event and clk='1') then
			half_scandouble_enable_reg <= half_scandouble_enable_next;
		end if;
	end process;

	half_scandouble_enable_next <= not(half_scandouble_enable_reg);

	scandoubler1: entity work.scandoubler
	GENERIC MAP
	(
		video_bits=>6
	)
	PORT MAP
	( 
		CLK => CLK,
		RESET_N => RESET_N and SDRAM_RESET_N and not(reset_atari),
		
		VGA => scandouble,
		COMPOSITE_ON_HSYNC => csync or ypbpr,

		colour_enable => half_scandouble_enable_reg,
		doubled_enable => '1',
		scanlines_on => scanlines,
		
		-- GTIA interface
		pal => PAL,
		colour_in => VIDEO_B,
		vsync_in => VGA_VS_RAW,
		hsync_in => VGA_HS_RAW,
		csync_in => VGA_CS_RAW,
		
		-- TO TV...
		R => SCANDOUBLE_R,
		G => SCANDOUBLE_G,
		B => SCANDOUBLE_B,
		
		VSYNC => VGA_VS,
		HSYNC => VGA_HS
	);

rgb2component: rgb2ypbpr
port map (
        red => SCANDOUBLE_R,
        green => SCANDOUBLE_G,
        blue => SCANDOUBLE_B,
        y => vga_y_o,
        pb => vga_pb_o,
        pr => vga_pr_o
);

VGA_R <= vga_pr_o when ypbpr='1' else SCANDOUBLE_R;
VGA_G <= vga_y_o  when ypbpr='1' else SCANDOUBLE_G;
VGA_B <= vga_pb_o when ypbpr='1' else SCANDOUBLE_B;

zpu: entity work.zpucore
	GENERIC MAP
	(
		platform => 1,
		spi_clock_div => 16,	-- 28MHz/2. Max for SD cards is 25MHz...
		nMHz_clock_div => 27,
		memory => 8192
	)
	PORT MAP
	(
		-- standard...
		CLK => CLK,
		RESET_N => RESET_N and sdram_reset_n,

		-- dma bus master (with many waitstates...)
		ZPU_ADDR_FETCH => dma_addr_fetch,
		ZPU_DATA_OUT => dma_write_data,
		ZPU_FETCH => dma_fetch,
		ZPU_32BIT_WRITE_ENABLE => dma_32bit_write_enable,
		ZPU_16BIT_WRITE_ENABLE => dma_16bit_write_enable,
		ZPU_8BIT_WRITE_ENABLE => dma_8bit_write_enable,
		ZPU_READ_ENABLE => dma_read_enable,
		ZPU_MEMORY_READY => dma_memory_ready,
		ZPU_MEMORY_DATA => dma_memory_data, 

		-- rom bus master
		-- data on next cycle after addr
		ZPU_ADDR_ROM => zpu_addr_rom,
		ZPU_ROM_DATA => zpu_rom_data,
	
		ZPU_ROM_WREN => open,

		-- nmhz clock
		CLK_nMHz => CLOCK_27(0),

		-- spi master
		ZPU_SPI_DI => mist_sd_sdo,
		ZPU_SPI_CLK => mist_sd_sck,
		ZPU_SPI_DO => mist_sd_sdi,
		ZPU_SPI_SELECT0 => mist_sd_cs,
		ZPU_SPI_SELECT1 => open,

		-- SIO
		-- Ditto for speaking to Atari, we have a built in Pokey
		ZPU_POKEY_ENABLE => zpu_pokey_enable,
		ZPU_SIO_TXD => zpu_sio_txd,
		ZPU_SIO_RXD => zpu_sio_rxd,
		ZPU_SIO_COMMAND => zpu_sio_command,
		ZPU_SIO_CLK => ASIO_CLOCKOUT,

		-- external control
		-- switches etc. sector DMA blah blah.
		ZPU_IN1 => X"000"&
			"00"&
			(atari_keyboard(28))&ps2_keys(16#5A#)&ps2_keys(16#174#)&ps2_keys(16#16B#)&ps2_keys(16#172#)&ps2_keys(16#175#)& -- (esc)FLRDU
				(FKEYS(11) or (mist_buttons(0) and not(joy1_n(4))))&(FKEYS(10) or (mist_buttons(0) and joy1_n(4) and joy_still))&(FKEYS(9) or (mist_buttons(0) and joy1_n(4) and not(joy_still)))&FKEYS(8 downto 0),
		ZPU_IN2 => X"00000000",
		ZPU_IN3 => atari_keyboard(31 downto 0),
		ZPU_IN4 => atari_keyboard(63 downto 32),

		-- ouputs - e.g. Atari system control, halt, throttle, rom select
		ZPU_OUT1 => zpu_out1,
		ZPU_OUT2 => zpu_out2,
		ZPU_OUT3 => zpu_out3,
		ZPU_OUT4 => zpu_out4,
		ZPU_OUT6 => zpu_out6 --video mode
	);

	pause_atari <= zpu_out1(0);
	reset_atari <= zpu_out1(1);
	speed_6502 <= zpu_out1(7 downto 2);
	ram_select <= zpu_out1(10 downto 8);
	atari800mode <= zpu_out1(11);
	emulated_cartridge_select <= zpu_out1(22 downto 17);
	freezer_enable <= zpu_out1(25);
	key_type <= zpu_out1(26);

	turbo_vblank_only <= zpu_out1(31);

	video_mode <= zpu_out6(2 downto 0);
	PAL <= zpu_out6(4);
	scanlines <= zpu_out6(5);
	csync <= zpu_out6(6);

process(video_mode)
begin
	SCANDOUBLE <= '0';
	YPBPR <= '0';

	-- original RGB
	-- scandoubled RGB (works on some vga devices...)
	-- ypbpr
	-- scandoubled ypbpr

	case video_mode is
		when "000" =>
		when "001" =>
			SCANDOUBLE <= '1';
		when "010" => 
			YPBPR <= '1';
		when "011" =>
			SCANDOUBLE <= '1';
			YPBPR <= '1';
		when "100" =>
			-- not supported
		when "101" =>
			-- not supported
		when "110" => -- composite
			-- not supported

		when others =>
	end case;
end process;

	zpu_rom1: entity work.zpu_rom
	port map(
	        clock => clk,
	        address => zpu_addr_rom(14 downto 2),
	        q => zpu_rom_data
	);

enable_179_clock_div_zpu_pokey : entity work.enable_divider
	generic map (COUNT=>32) -- cycle_length
	port map(clk=>clk,reset_n=>reset_n,enable_in=>'1',enable_out=>zpu_pokey_enable);

END vhdl;

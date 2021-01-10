---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
USE ieee.math_real.log2;
USE ieee.math_real.ceil;

LIBRARY work;

ENTITY zpucore IS 
	GENERIC
	(
		platform : integer := 1; -- So ROM can detect which type of system...
		spi_clock_div : integer := 4;  -- see notes on zpu_config_regs
		memory : integer := 4096; -- up to 32K allowed
		usb : integer := 0;
		nMHz_clock_div : integer
	);
	PORT
	(
		-- standard...
		CLK : in std_logic;
		RESET_N : in std_logic;

		-- dma bus master (with many waitstates...)
		ZPU_ADDR_FETCH : out std_logic_vector(23 downto 0);
		ZPU_DATA_OUT : out std_logic_vector(31 downto 0);
		ZPU_FETCH : out std_logic;
		ZPU_32BIT_WRITE_ENABLE : out std_logic;
		ZPU_16BIT_WRITE_ENABLE : out std_logic;
		ZPU_8BIT_WRITE_ENABLE : out std_logic;
		ZPU_READ_ENABLE : out std_logic;
		ZPU_MEMORY_READY : in std_logic;
		ZPU_MEMORY_DATA : in std_logic_vector(31 downto 0);

		-- rom bus master
		-- data on next cycle after addr
		ZPU_ADDR_ROM : out std_logic_vector(15 downto 0);
		ZPU_ROM_DATA : in std_logic_vector(31 downto 0);
		ZPU_ROM_WREN : out std_logic;

		-- change clock support
		ZPU_PLL_WRITE : out std_logic;
		ZPU_PLL_DATA : out std_logic_vector(31 downto 0);
		ZPU_PLL_ADDR : out std_logic_vector(7 downto 2);

		-- spi master
		-- Too painful to bit bang spi from zpu, so we have a hardware master in here
		--ZPU_SD_DAT0 :  IN  STD_LOGIC;
		--ZPU_SD_CLK :  OUT  STD_LOGIC;
		--ZPU_SD_CMD :  OUT  STD_LOGIC;
		--ZPU_SD_DAT3 :  OUT  STD_LOGIC;
		ZPU_SPI_DI :  IN  STD_LOGIC;
		ZPU_SPI_CLK :  OUT  STD_LOGIC;
		ZPU_SPI_DO :  OUT  STD_LOGIC;
		ZPU_SPI_SELECT0 :  OUT  STD_LOGIC;
		ZPU_SPI_SELECT1 :  OUT  STD_LOGIC;

		-- SIO
		-- Ditto for speaking to Atari, we have a built in Pokey
		ZPU_POKEY_ENABLE : in std_logic; -- if run at 1.79MHz we can use standard dividers...
		ZPU_SIO_TXD : out std_logic;
		ZPU_SIO_RXD : in std_logic;
		ZPU_SIO_COMMAND : in std_logic;
		ZPU_SIO_CLK : in std_logic;

		-- external control
		-- switches etc. sector DMA blah blah.
		ZPU_IN1 : in std_logic_vector(31 downto 0);
		ZPU_IN2 : in std_logic_vector(31 downto 0);
		ZPU_IN3 : in std_logic_vector(31 downto 0);
		ZPU_IN4 : in std_logic_vector(31 downto 0);

		-- ouputs - e.g. Atari system control, halt, throttle, rom select
		ZPU_OUT1 : out std_logic_vector(31 downto 0);
		ZPU_OUT2 : out std_logic_vector(31 downto 0);
		ZPU_OUT3 : out std_logic_vector(31 downto 0);
		ZPU_OUT4 : out std_logic_vector(31 downto 0);
		ZPU_OUT5 : out std_logic_vector(31 downto 0);
		ZPU_OUT6 : out std_logic_vector(31 downto 0);
		ZPU_OUT7 : out std_logic_vector(31 downto 0);
		ZPU_OUT8 : out std_logic_vector(31 downto 0);

		-- nMHz clock, for timer. Divided by n before use.
		CLK_nMHz : in std_logic;

		-- USB host
		CLK_USB : in std_logic := '0';
	
		USBWireVPin :in std_logic_vector(usb-1 downto 0) := (others=>'0');
		USBWireVMin :in std_logic_vector(usb-1 downto 0) := (others=>'0');
		USBWireVPout :out std_logic_vector(usb-1 downto 0);
		USBWireVMout :out std_logic_vector(usb-1 downto 0);
		USBWireOE_n :out std_logic_vector(usb-1 downto 0);

		-- I2C (400k)
		i2c0_sda_in : in std_logic := '1';
		i2c0_scl_in : in std_logic := '1';
		i2c0_sda_wen : out std_logic;
		i2c0_scl_wen : out std_logic;
		
		i2c1_sda_in : in std_logic := '1';
		i2c1_scl_in : in std_logic := '1';
		i2c1_sda_wen : out std_logic;
		i2c1_scl_wen : out std_logic		
	);
END zpucore;

ARCHITECTURE vhdl OF zpucore IS 
	signal ZPU_PAUSE : std_logic;
	signal ZPU_RESET : std_logic;

	signal ZPU_DO : std_logic_vector(31 downto 0);

	signal ZPU_ADDR_ROM_RAM : std_logic_vector(15 downto 0);

	signal ZPU_RAM_DATA : std_logic_vector(31 downto 0);
	signal ZPU_STACK_WRITE : std_logic_vector(3 downto 0);

	signal ZPU_CONFIG_DO : std_logic_vector(31 downto 0);
	signal ZPU_CONFIG_WRITE_ENABLE : std_logic;
	signal ZPU_CONFIG_READ_ENABLE : std_logic;

	signal ZPU_SD_DMA_ADDR : std_logic_vector(15 downto 0);
	signal ZPU_SD_DMA_DATA : std_logic_vector(7 downto 0);
	signal ZPU_SD_DMA_WRITE : std_logic;
	signal ZPU_SD_DMA_WRITE_BITS : std_logic_vector(3 downto 0);

	signal ZPU_ADDR_ROM_RAM_DMA : std_logic_vector(15 downto 0);
	signal ZPU_DO_DMA : std_logic_vector(31 downto 0);
	signal ZPU_STACK_WRITE_DMA : std_logic_vector(3 downto 0);

	constant memory_bits: integer := integer(ceil(log2(real(memory))));
BEGIN 

ZPU_RESET <= not(reset_n);
zpu_and_glue : entity work.zpu_glue
PORT MAP(CLK => CLK,
		 RESET => ZPU_RESET,
		 PAUSE => ZPU_PAUSE,
		 MEMORY_READY => ZPU_MEMORY_READY,
		 ZPU_CONFIG_DI => ZPU_CONFIG_DO,
		 ZPU_DI => ZPU_MEMORY_DATA,
		 ZPU_RAM_DI => ZPU_RAM_DATA,
		 ZPU_ROM_DI => ZPU_ROM_DATA,
		 MEMORY_FETCH => ZPU_FETCH,
		 ZPU_READ_ENABLE => ZPU_READ_ENABLE,
		 ZPU_32BIT_WRITE_ENABLE => ZPU_32BIT_WRITE_ENABLE,
		 ZPU_16BIT_WRITE_ENABLE => ZPU_16BIT_WRITE_ENABLE,
		 ZPU_8BIT_WRITE_ENABLE => ZPU_8BIT_WRITE_ENABLE,
		 ZPU_CONFIG_WRITE => ZPU_CONFIG_WRITE_ENABLE,
		 ZPU_CONFIG_READ => ZPU_CONFIG_READ_ENABLE,
		 ZPU_ADDR_FETCH => ZPU_ADDR_FETCH,
		 ZPU_ADDR_ROM_RAM => ZPU_ADDR_ROM_RAM,
		 ZPU_DO => ZPU_DO,
		 ZPU_STACK_WRITE => ZPU_STACK_WRITE,
		 ZPU_ROM_WREN => ZPU_ROM_WREN);

config_regs : entity work.zpu_config_regs
GENERIC MAP (
	platform => platform,
	spi_clock_div => spi_clock_div,
	usb => usb,
	nmhz_clock_div => nmhz_clock_div
)
PORT MAP (
	CLK => CLK,
	RESET_N => RESET_N,
	
	POKEY_ENABLE => ZPU_POKEY_ENABLE,
	
	ADDR => ZPU_ADDR_ROM_RAM(12 DOWNTO 2),
	CPU_DATA_IN => ZPU_DO,
	WR_EN => ZPU_CONFIG_WRITE_ENABLE,
	RD_EN => ZPU_CONFIG_READ_ENABLE,
	
	IN1 => ZPU_IN1,
	IN2 => ZPU_IN2,
	IN3 => ZPU_IN3,
	IN4 => ZPU_IN4,
	
	OUT1 => ZPU_OUT1,
	OUT2 => ZPU_OUT2,
	OUT3 => ZPU_OUT3,
	OUT4 => ZPU_OUT4,
	OUT5 => ZPU_OUT5,
	OUT6 => ZPU_OUT6,
	OUT7 => ZPU_OUT7,
	OUT8 => ZPU_OUT8,

	PLL_WRITE => ZPU_PLL_WRITE,
	PLL_DATA => ZPU_PLL_DATA,
	PLL_ADDR => ZPU_PLL_ADDR,
	
	SPI_DI => ZPU_SPI_DI,
	SPI_CLK => ZPU_SPI_CLK,
	SPI_DO => ZPU_SPI_DO,
	SPI_SELECT0 => ZPU_SPI_SELECT0,
	SPI_SELECT1 => ZPU_SPI_SELECT1,

	--SPI_DI => ZPU_SD_DAT0,
	--SPI_CLK => ZPU_SD_CLK,
	--SPI_DO => ZPU_SD_CMD,
	--SPI_SELECT0 => ZPU_SD_DAT3,
	--SPI_SELECT1 => ZPU_SD_DAT3,

	SIO_DATA_IN => ZPU_SIO_TXD,
	SIO_DATA_OUT => ZPU_SIO_RXD,
	SIO_COMMAND => ZPU_SIO_COMMAND,
	SIO_CLK_OUT => ZPU_SIO_CLK,

	sd_addr => ZPU_SD_DMA_ADDR,
	sd_data => ZPU_SD_DMA_DATA,
	sd_write => ZPU_SD_DMA_WRITE,
	
	DATA_OUT => ZPU_CONFIG_DO,
	PAUSE_ZPU => ZPU_PAUSE,

	CLK_nMHz => CLK_nMHz,

	CLK_USB => CLK_USB,
	
	USBWireVPin => USBWireVPin,
	USBWireVMin => USBWireVMin,
	USBWireVPout => USBWireVPout,
	USBWireVMout => USBWireVMout,
	USBWireOE_n => USBWireOE_n,

	i2c0_sda_in => i2c0_sda_in,
	i2c0_scl_in => i2c0_scl_in,
	i2c0_sda_wen => i2c0_sda_wen,
	i2c0_scl_wen => i2c0_scl_wen,
	i2c1_sda_in => i2c1_sda_in,
	i2c1_scl_in => i2c1_scl_in,
	i2c1_sda_wen => i2c1_sda_wen,
	i2c1_scl_wen => i2c1_scl_wen	
	);

decode_addr1 : entity work.complete_address_decoder
	generic map(width=>2)
	port map (addr_in=>ZPU_SD_DMA_ADDR(1 downto 0), addr_decoded=>ZPU_SD_DMA_WRITE_BITS);

process(ZPU_DO, ZPU_ADDR_ROM_RAM, ZPU_STACK_WRITE, ZPU_SD_DMA_ADDR, ZPU_SD_DMA_DATA, ZPU_SD_DMA_WRITE, ZPU_SD_DMA_WRITE_BITS)
begin
	ZPU_DO_DMA <= ZPU_DO;
	ZPU_ADDR_ROM_RAM_DMA <= ZPU_ADDR_ROM_RAM;
	ZPU_STACK_WRITE_DMA <= ZPU_STACK_WRITE;

	if (ZPU_SD_DMA_WRITE = '1') then
		ZPU_DO_DMA <= ZPU_SD_DMA_DATA&ZPU_SD_DMA_DATA&ZPU_SD_DMA_DATA&ZPU_SD_DMA_DATA;
		ZPU_ADDR_ROM_RAM_DMA <= ZPU_SD_DMA_ADDR(15 downto 2)&"00";
		ZPU_STACK_WRITE_DMA <= ZPU_SD_DMA_WRITE_BITS(0)&ZPU_SD_DMA_WRITE_BITS(1)&ZPU_SD_DMA_WRITE_BITS(2)&ZPU_SD_DMA_WRITE_BITS(3);
	end if;
	
end process;

ram_31_24 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => memory_bits-2,
		SPACE => memory/4,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE_DMA(3),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM_DMA(memory_bits-1 DOWNTO 2),
		data => ZPU_DO_DMA(31 DOWNTO 24),
		q => ZPU_RAM_DATA(31 DOWNTO 24)
	);

ram23_16 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => memory_bits-2,
		SPACE => memory/4,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE_DMA(2),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM_DMA(memory_bits-1 DOWNTO 2),
		data => ZPU_DO_DMA(23 DOWNTO 16),
		q => ZPU_RAM_DATA(23 DOWNTO 16)
	);

ram_15_8 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => memory_bits-2,
		SPACE => memory/4,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE_DMA(1),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM_DMA(memory_bits-1 DOWNTO 2),
		data => ZPU_DO_DMA(15 DOWNTO 8),
		q => ZPU_RAM_DATA(15 DOWNTO 8)
	);

ram_7_0 : entity work.generic_ram_infer
	GENERIC MAP
	(
		ADDRESS_WIDTH => memory_bits-2,
		SPACE => memory/4,
		DATA_WIDTH => 8
	)
	PORT MAP
	(
		we => ZPU_STACK_WRITE_DMA(0),
		clock => CLK,
		address => ZPU_ADDR_ROM_RAM_DMA(memory_bits-1 DOWNTO 2),
		data => ZPU_DO_DMA(7 DOWNTO 0),
		q => ZPU_RAM_DATA(7 DOWNTO 0)
	);

	-- OUTPUT
	ZPU_ADDR_ROM <= ZPU_ADDR_ROM_RAM;
	ZPU_DATA_OUT <= ZPU_DO;

end vhdl;

----------------------------------------------------------------------------------
-- Command Processor module
-- Created 2019-03-02 by jp17033
----------------------------------------------------------------------------------
-- Changelog:
-- 2019-03-02: Created cmdProc (jp17033)
----------------------------------------------------------------------------------

-- 190304: Added libraries
library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;

-- 190304: Defined entity
entity cmdProc is
	port (
		-- Ports with no links to any other modules
		clk:		in	std_logic;
		reset:		in	std_logic;					-- synchronous reset
		
		-- Ports linked to data processor            
		dataReady:	in	std_logic;
		byte:		in	std_logic_vector(7 downto 0);
		maxIndex:	in	BCD_ARRAY_TYPE(2 downto 0);
		dataResults:	in	CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);	-- index 3 holds the peak
		seqDone:	in	std_logic;
		start:		out	std_logic;					-- goes high to signal data transfer
		numWords_bcd:	out	BCD_ARRAY_TYPE(2 downto 0);
		
		-- Ports linked to Rx
		rxDone:		in	std_logic;					-- data succesfully read (active high)
		rcvDataReg:	out	std_logic_vector(7 downto 0);			-- received data
		dataValid:	out	std_logic;					-- data ready to be read (called dataReady in Rx.VHD)
		setOE:		out	std_logic;					-- overrun error (active high)
		setFE:		out	std_logic;					-- frame error (active high)
			    
		-- Ports linked to Tx
		READY:		in	STD_LOGIC;					-- equivalent to txDone
		SEND:		out	STD_LOGIC;					-- equivalent to txNow
		DATA:		out	STD_LOGIC_VECTOR (7 downto 0)
	);
end cmdProc;

-- 190304: Added arch - TBC
architecture cmdProc_arch of cmdProc is
-- Component declaration of dataConsume
component dataConsume
	port (
		clk:		in	std_logic;
		reset:		in	std_logic; -- synchronous reset
		start:		in	std_logic; -- goes high to signal data transfer
		numWords_bcd:	in	BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn:		in	std_logic;
		data:		in	std_logic_vector(7 downto 0);
		ctrlOut:	out	std_logic;
		dataReady:	out	std_logic;
		byte:		out	std_logic_vector(7 downto 0);
		seqDone:	out	std_logic;
		maxIndex:	out	BCD_ARRAY_TYPE(2 downto 0);
		dataResults:	out	CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak
	);
end component;

-- Component declaration of Rx
component UART_RX_CTRL
	port (
		RxD:		in	std_logic;					-- serial data in
		sysclk:		in	std_logic;					-- system clock
		reset:		in	std_logic;					-- synchronous reset
		rxDone:		in	std_logic;					-- data succesfully read (active high)
		rcvDataReg:	out	std_logic_vector(7 downto 0);			-- received data
		dataReady:	out	std_logic;					-- data ready to be read
		setOE:		out	std_logic;					-- overrun error (active high)
		setFE:		out	std_logic					-- frame error (active high)
	);
end component;

-- Component declaration of Tx
component UART_TX_CTRL 
	port (
		SEND:		in	STD_LOGIC;
		DATA: 		in	STD_LOGIC_VECTOR (7 downto 0);
		CLK:		in	STD_LOGIC;
		READY:		out	STD_LOGIC;
		UART_TX:	out	STD_LOGIC
	);
end component;


begin

-- Port mapping of dataProcessor
dataProcessor: dataConsume
port map(
	clk => clk,
	reset => reset,
	
	y => D(7 downto 0), 
	dirup => '0' -- Either this or GND - recheck required
);
--    delay_CtrlIn: process(clk)     
--    begin
--        if rising_edge(clk) then

--        end if;
--    end process;
    
end cmdProc_arch;

----------------------------------------------------------------------------------
-- Command Processor module
-- Created 2019-03-02 by jp17033
----------------------------------------------------------------------------------
-- Changelog:
-- 2019-03-02: Created cmdProc (jp17033)
----------------------------------------------------------------------------------

-- 190304: Added libraries
-- 190320: Updated Vivado version
library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;
--use IEEE.numeric_std.ALL;

-- 190304: Defined entity
entity cmdProc is
port (
	-- Generic clock/reset
    clk:            in      std_logic;
    reset:          in      std_logic;
    -- I/O of Rx module
    rxData:         in      std_logic_vector (7 downto 0);
	rxNow:          in      std_logic; -- Same as "valid" in diagram
    ovErr:          in      std_logic; 
    framErr:        in      std_logic;
    rxdone:         out     std_logic; -- Same as "done" in diagram
    -- I/O of Tx module
    txdone:         in      std_logic;
    txnow:          out     std_logic;
    txData:         out     std_logic_vector (7 downto 0);
    -- I/O of data module
    dataReady:      in      std_logic;
    byte:           in      std_logic_vector(7 downto 0);
    maxIndex:       in      BCD_ARRAY_TYPE(2 downto 0);
    dataResults:    in      CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone:        in      std_logic;
    start:          out     std_logic;
    numWords_bcd:   out     BCD_ARRAY_TYPE(2 downto 0)
    );
end cmdProc;
-- 190304: Added arch - TBC
architecture cmdProc_behav of cmdProc is
-- Component declaration of dataConsume
    TYPE state_type IS (
        INIT, valid_A, valid_1, valid_2, 
        TRANSMIT_putty_n, putty_n, 
        TRANSMIT_putty_r, putty_r, 
        cmd_ANNN_seqDone, cmd_ANNN_runPush, 
        cmd_ANNN_buffer, cmd_ANNN_outputty
        ); -- List your states here 
	SIGNAL curState, nextState : state_type;
	SIGNAL processed : BIT; -- registered input signal
	SIGNAL rxData_reg, data_gen: std_logic_vector(7 downto 0); -- Stores rxData into FF
	--SIGNAL num1, num2, num3: std_logic_vector(7 downto 0); --  Stores numbers inputted
--	SIGNAL en_count_byte: BIT; -- ENABLE input for counter 
--	SIGNAL count_byte: INTEGER := 0; --BCD_ARRAY_TYPE(2 downto 0):= ("0000", "0000", "0000"); -- counter integers for bytes retrieved
--	SIGNAL bcd_integer, bcd_2, bcd_1, bcd_0: INTEGER; -- Equivalent integer
--	SIGNAL num_bcd: BCD_ARRAY_TYPE(2 downto 0) := ("0000", "0000", "0000"); -- Stores the same value as numWords_bcd, but can be read
	SIGNAL ANNN_dataResults: char_array_type(56 downto 0);
	SIGNAL ANNN_indexMax: BCD_ARRAY_TYPE(2 downto 0);
begin
	-- 190310: IDEA - instead of using processed FF, output invalid data instead?
	-- 190311:	Sequence working! (sans L & P)
	
	-- FF for storing incoming rxData - used in checking for next clock cycle whether same data
	PROCESS (clk, rxData)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
			rxData_reg <= rxData;
		END IF;
	END PROCESS;
	
	-- FF for storing whether data processed
	-- Also stores dataResult and peak index
	PROCESS (clk, curState, seqDone)--, dataResults, maxIndex)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
			IF (seqDone = '1') THEN -- 0
				processed <= '1';
			END IF;
		END IF;
	END PROCESS;
	----------------------------------------
	seq_state : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' THEN
			curState <= INIT;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- seq
	-----------------------------------------------------
	combi_nextState : PROCESS (curState, rxNow, rxData, rxData_reg, processed, processed, txDone, dataReady, byte) --, count_byte, num_bcd, bcd_integer, bcd_2, bcd_1, bcd_0)
		variable v_rxDone, v_txNow, v_start: std_logic; -- variable for rxDone
		variable v_dataTx: std_logic_vector(7 downto 0);
	BEGIN
		-- assign defaults at the beginning to avoid having to assign in every branch
		--txDone := '0';
		v_rxDone := '0'; -- Default value of rxDone
		v_txNow := '0';
		v_start := '0';
		v_dataTx := byte;
		CASE curState IS
			WHEN INIT => --(sig_rxNow = '1') and 
				IF (rxNow = '1') and ((rxData = "01000001") or (rxData = "01100001")) THEN
					v_rxDone := '1';
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;
 
			WHEN valid_A => 
				IF (rxData /= rxData_reg) and (
				        (rxData = "00110000") OR (rxData = "00110001") OR
				        (rxData = "00110010") OR (rxData = "00110011") OR 
				        (rxData = "00110100") OR (rxData = "00110101") OR 
				        (rxData = "00110110") OR (rxData = "00110111") OR 
				        (rxData = "00111000") OR (rxData = "00111001")
				        ) THEN
					numWords_bcd(2) <= rxData(3 downto 0);
					v_rxDone := '1';
					nextState <= valid_1;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					v_rxDone := '1';
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;

			WHEN valid_1 =>
				IF (rxData = rxData_reg) THEN
					nextState <= valid_1;
				ELSIF (rxData /= rxData_reg) and (
				        (rxData = "00110000") OR (rxData = "00110001") OR 
				        (rxData = "00110010") OR (rxData = "00110011") OR 
				        (rxData = "00110100") OR (rxData = "00110101") OR 
				        (rxData = "00110110") OR (rxData = "00110111") OR 
				        (rxData = "00111000") OR (rxData = "00111001")
				        ) THEN
					numWords_bcd(1) <= rxData(3 downto 0);
					v_rxDone := '1';
					nextState <= valid_2;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					v_rxDone := '1';
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;

			WHEN valid_2 =>
				IF (rxData = rxData_reg) THEN
					nextState <= valid_2;
				ELSIF (rxData /= rxData_reg) and (
				        (rxData = "00110000") OR (rxData = "00110001") OR 
				        (rxData = "00110010") OR (rxData = "00110011") OR 
				        (rxData = "00110100") OR (rxData = "00110101") OR 
				        (rxData = "00110110") OR (rxData = "00110111") OR 
				        (rxData = "00111000") OR (rxData = "00111001")
				        ) THEN
					numWords_bcd(0) <= rxData(3 downto 0);
					v_rxDone := '1';
					--processed <= '0';
					nextState <= putty_n;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					v_rxDone := '1';
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;
				
			-- Breaks line feed & return new line (given valid commands)
--			WHEN TRANSMIT_putty_n =>
--				nextState <= putty_n;
			WHEN putty_n =>
				v_txNow := '1';
				v_rxDone := '1';
				v_dataTx := "00001010";
				IF (txdone = '1') then
					nextState <= putty_r;
				else
					nextState <= putty_n;
				END IF;
--			WHEN TRANSMIT_putty_r =>
--				nextState <= putty_r;
			WHEN putty_r =>
				--v_txNow := '1';
				v_rxDone := '1';
				v_dataTx := "00001101";
				IF (txdone = '1') then
					nextState <= cmd_ANNN_seqDone;
				else
					nextState <= putty_r;
				END IF;
					
			WHEN cmd_ANNN_SeqDone =>
				IF (processed = '0') THEN
					v_start := '1';
					v_rxDone := '1';
					nextState <= cmd_ANNN_buffer; --cmd_ANNN_runPush;
				ELSE
					nextState <= cmd_ANNN_outputty;
				END IF;
			
--			when TRANSMIT_Tx_byte =>
--				v_txNow := '1';
--				v_rxDone := '1';
--				nextState <= cmd_ANNN_runPush;
			WHEN cmd_ANNN_buffer =>
			     IF (txDone = '0') then
			         v_txNow := '1';
                     nextState <= cmd_ANNN_runPush;
                 else
                        nextState <= cmd_ANNN_buffer;
                   end if;
			
			WHEN cmd_ANNN_runPush =>
				IF (txdone = '1') then
					nextState <= cmd_ANNN_seqDone;
				ELSE
					nextState <= cmd_ANNN_runPush;
				END IF;
				
			WHEN cmd_ANNN_outputty =>
				-- TODO: Add code
				nextState <= INIT;
			---------------------------------
			WHEN OTHERS => 
				nextState <= INIT;
		END CASE;
		start <= v_start;
		rxDone <= v_rxDone;
		txNow <= v_txNow;
		IF (dataReady = '1') then
			txdata <= v_dataTx;
		END IF;
	END PROCESS; -- combi_nextState
	-----------------------------------------------------
--	set_TXRX: PROCESS(curState)
--	BEGIN
--		IF (curState = TRANSMIT_putty_n) or (curState = TRANSMIT_putty_r) or (curState = TRANSMIT_Tx_byte) THEN
--			txNow <= '1';
--			rxDone <= '1';
--		END IF;
--	END PROCESS;
	-----------------------------------------------------
--	echo: PROCESS(rxData, curState, txdone, rxData)
--	BEGIN
--		if ((curState = INIT) or (curState = valid_A) or (curState = valid_1) or (curState = valid_2)) and (txNow = '1') THEN
--			txdata <= rxData; -- Prints ASCII
--		END IF;
--	END PROCESS;
--	-----------------------------------------------------
--	proc_ANNN_pushSTART: PROCESS(curState, seqDone)
--	BEGIN
--		start <= '0';
--		IF (curState = cmd_ANNN_SeqDone) and (seqDone = '0') THEN
--			start <= '1';
--		END IF;
--	END PROCESS;
	-----------------------------------------------------
--	proc_ANNN_pushTX: PROCESS(curState, txdone, byte, dataReady)--, dataReady)
--	BEGIN
--		IF (curState = cmd_ANNN_runPush) and (txdone = '1') THEN -- and (dataReady = '1') then
--			txdata <= byte; -- Outputs byte to screen (currently in dev)
--		END IF;
--	END PROCESS;
	-----------------------------------------------------
--	putty_NR: PROCESS(curState, txdone)
--	BEGIN
--		IF (txdone = '1') THEN
--			if (curState = putty_n) THEN
--				txdata <= "00001010"; -- Prints ASCII
--			ELSIF (curState = putty_r) THEN
--				txdata <= "00001101";
--			END IF;
--		END IF;
--	END PROCESS;
	-----------------------------------------------------    
end cmdProc_behav;
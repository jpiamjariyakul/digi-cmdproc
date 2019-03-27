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
use IEEE.numeric_std.ALL;

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
    TYPE state_type IS (INIT, valid_A, valid_1, valid_2, 
    	putty_n_wait, putty_n_txNow, putty_r_wait, putty_r_txNow, 
    	putty_nr_1_wait, putty_nr_1_txnow,
    	putty_eq_1_wait, putty_eq_1_txnow,
    	putty_nr_2_wait, putty_nr_2_txnow,
    	cmd_ANNN_seqDone, cmd_ANNN_runPush, TRANSMIT_Tx_byte, cmd_ANNN_outputty,
    	INIT_idle, INIT_wait, INIT_txnow, INIT_check,
		valid_A_idle, valid_A_wait, valid_A_txnow, valid_A_check,
		valid_1_idle, valid_1_wait, valid_1_txnow, valid_1_check,
		valid_2_idle, valid_2_wait, valid_2_txnow, valid_2_check,
    	putty_ANNN_wait, putty_ANNN_txnow, 
    	putty_nr_3_wait, putty_nr_3_txnow,
    	putty_eq_2_wait, putty_eq_2_txnow,
    	putty_nr_4_wait, putty_nr_4_txnow,
    	cmd_ANNN_wait, cmd_ANNN_data, cmd_ANNN_txNow,
    	cmd_ANNN_convert,
    	cmd_ANNN_txNow_1, cmd_ANNN_runPush_1,
    	cmd_ANNN_txNow_2, cmd_ANNN_runPush_2); -- List your states here 
	SIGNAL curState, nextState : state_type;
	SIGNAL processed : std_logic; -- registered input signal
	SIGNAL rxData_reg, data_gen: std_logic_vector(7 downto 0); -- Stores rxData into FF
	--SIGNAL num1, num2, num3: std_logic_vector(7 downto 0); --  Stores numbers inputted
--	SIGNAL en_count_byte: BIT; -- ENABLE input for counter 
--	SIGNAL count_byte: INTEGER := 0; --BCD_ARRAY_TYPE(2 downto 0):= ("0000", "0000", "0000"); -- counter integers for bytes retrieved
--	SIGNAL bcd_integer, bcd_2, bcd_1, bcd_0: INTEGER; -- Equivalent integer
--	SIGNAL num_bcd: BCD_ARRAY_TYPE(2 downto 0) := ("0000", "0000", "0000"); -- Stores the same value as numWords_bcd, but can be read
	SIGNAL count_nr, count_eq: INTEGER := 0;
	SIGNAL en_count_nr, en_count_eq: std_logic; -- ENABLE inputs for counter 
	--SIGNAL ANNN_dataResults: char_array_type(56 downto 0);
	--SIGNAL ANNN_indexMax: BCD_ARRAY_TYPE(2 downto 0);
	SIGNAL ANNN_dataTx: std_logic_vector(15 downto 0);
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
			curState <= INIT_idle;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- seq
	-----------------------------------------------------
	combi_nextState : PROCESS (curState, rxNow, rxData, rxData_reg, 
			processed, processed, txDone, dataReady, byte, ANNN_dataTx,
			count_nr, count_eq) --, count_byte, num_bcd, bcd_integer, bcd_2, bcd_1, bcd_0)
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
			WHEN INIT_idle =>
				IF (rxNow = '1') THEN
					nextState <= INIT_wait;
				ELSE
					nextState <= INIT_idle;
				END IF;
			WHEN INIT_wait =>
				IF (txdone = '1') then
					nextState <= INIT_txnow;
				ELSE
					nextState <= INIT_wait;
				END IF;
			WHEN INIT_txnow =>
				v_dataTx := rxData;
				IF (txDone = '1') THEN
					v_txNow := '1';
					v_rxDone := '1';
					nextState <= INIT_check;
				ELSE
					nextState <= INIT_txnow;
				END IF;
			WHEN INIT_check =>
				IF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A_idle;
				ELSE
					nextState <= INIT_idle;
				END IF;
				
			---------------------------------------
			WHEN valid_A_idle =>
				IF (rxNow = '1') THEN
					nextState <= valid_A_wait;
				ELSE
					nextState <= valid_A_idle;
				END IF;
			WHEN valid_A_wait =>
				IF (txdone = '1') then
					nextState <= valid_A_txnow;
				ELSE
					nextState <= valid_A_wait;
				END IF;
			WHEN valid_A_txnow =>
				v_dataTx := rxData;
				IF (txDone = '1') THEN
					v_txNow := '1';
					v_rxDone := '1';
					nextState <= valid_A_check;
				ELSE
					nextState <= valid_A_txnow;
				END IF;
			WHEN valid_A_check =>
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					numWords_bcd(2) <= rxData(3 downto 0);
					--v_rxDone := '1';
					nextState <= valid_1_idle;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					--v_rxDone := '1';
					nextState <= valid_A_idle;
				ELSE
					nextState <= INIT_idle;
				END IF;
			---------------------------------
			WHEN valid_1_idle =>
				IF (rxNow = '1') THEN
					nextState <= valid_1_wait;
				ELSE
					nextState <= valid_1_idle;
				END IF;
			WHEN valid_1_wait =>
				IF (txdone = '1') then
					nextState <= valid_1_txnow;
				ELSE
					nextState <= valid_1_wait;
				END IF;
			WHEN valid_1_txnow =>
				v_dataTx := rxData;
				IF (txDone = '1') THEN
					v_txNow := '1';
					v_rxDone := '1';
					nextState <= valid_1_check;
				ELSE
					nextState <= valid_1_txnow;
				END IF;
			WHEN valid_1_check =>
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					numWords_bcd(1) <= rxData(3 downto 0);
					--v_rxDone := '1';
					nextState <= valid_2_idle;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					--v_rxDone := '1';
					nextState <= valid_A_idle;
				ELSE
					nextState <= INIT_idle;
				END IF;
				---------------------------------
				WHEN valid_2_idle =>
					IF (rxNow = '1') THEN
						nextState <= valid_2_wait;
					ELSE
						nextState <= valid_2_idle;
					END IF;
				WHEN valid_2_wait =>
					IF (txdone = '1') then
						nextState <= valid_2_txnow;
					ELSE
						nextState <= valid_2_wait;
					END IF;
				WHEN valid_2_txnow =>
					v_dataTx := rxData;
					IF (txDone = '1') THEN
						v_txNow := '1';
						v_rxDone := '1';
						nextState <= valid_2_check;
					ELSE
						nextState <= valid_2_txnow;
					END IF;
				WHEN valid_2_check =>
					IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
						numWords_bcd(1) <= rxData(3 downto 0);
						--v_rxDone := '1';
						nextState <= putty_nr_1_wait;
					ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
						--v_rxDone := '1';
						nextState <= valid_A_idle;
					ELSE
						nextState <= INIT_idle;
					END IF;
			---------------------------------------
			-- Newline after command accepted
			WHEN putty_nr_1_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_1_txnow;
				ELSE
					nextState <= putty_nr_1_wait;
				END IF;

			WHEN putty_nr_1_txnow =>
				v_dataTx := "00001010";
				IF (count_nr > 1) THEN
				--ELSE
					v_dataTx := "00001101";
				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= putty_eq_1_wait;
					else
						nextState <= putty_nr_1_wait;
					end if;
				ELSE
					nextState <= putty_nr_1_txnow;
				END IF;
			---------------------------------------
			-- Dividing line after command accepted
			WHEN putty_eq_1_wait =>
				IF (txdone = '1') then
					nextState <= putty_eq_1_txnow;
				ELSE
					nextState <= putty_eq_1_wait;
				END IF;

			WHEN putty_eq_1_txnow =>
				v_dataTx := "00111101";				
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_eq > 4) then
						nextState <= putty_nr_2_wait;
					else
						nextState <= putty_eq_1_wait;
					end if;
				ELSE
					nextState <= putty_eq_1_txnow;
				END IF;
			---------------------------------------
			-- Newline before bitstream begins
			WHEN putty_nr_2_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_2_txnow;
				ELSE
					nextState <= putty_nr_2_wait;
				END IF;
			WHEN putty_nr_2_txnow =>
				v_dataTx := "00001010";
				IF (count_nr > 1) THEN
					v_dataTx := "00001101";
				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= cmd_ANNN_wait;
					else
						nextState <= putty_nr_2_wait;
					end if;
				ELSE
					nextState <= putty_nr_2_txnow;
				END IF;
			---------------------------------------
			---------------------------------------
			WHEN cmd_ANNN_wait =>
				IF (txdone = '1') then
					v_start := '1';
					nextState <= cmd_ANNN_txNow_1; --cmd_ANNN_data;
				else
					nextState <= cmd_ANNN_wait;
				END IF;
				
			WHEN cmd_ANNN_txNow_1 => --cmd_ANNN_data =>
				IF (dataReady = '1') THEN
					CASE byte(7 downto 4) is
						WHEN "0000" => v_dataTx := "00110000";
						WHEN "0001" => v_dataTx := "00110001";
						WHEN "0010" => v_dataTx := "00110010";
						WHEN "0011" => v_dataTx := "00110011";
						WHEN "0100" => v_dataTx := "00110100";
						WHEN "0101" => v_dataTx := "00110101";
						WHEN "0110" => v_dataTx := "00110110";
						WHEN "0111" => v_dataTx := "00110111";
						WHEN "1000" => v_dataTx := "00111000";
						WHEN "1001" => v_dataTx := "00111001";
							------------------------------
						WHEN "1010" => v_dataTx := "01100001";
						WHEN "1011" => v_dataTx := "01100010";
						WHEN "1100" => v_dataTx := "01100011";
						WHEN "1101" => v_dataTx := "01100100";
						WHEN "1110" => v_dataTx := "01100101";
						WHEN "1111" => v_dataTx := "01100110";
						WHEN others => v_dataTx := "00000000";
					END CASE;
					v_txNow := '1';
					nextState <= cmd_ANNN_txNow_2;--cmd_ANNN_runPush_1;--cmd_ANNN_txNow_1;--cmd_ANNN_txNow;
				ELSE
					nextState <= cmd_ANNN_txNow_1;--cmd_ANNN_data;
				END IF;
			
--			WHEN cmd_ANNN_convert =>
--				CASE byte(7 downto 4) is
--					WHEN "0000" =>
--						v_dataTx := "00110000";
--					WHEN "0001" =>
--						v_dataTx := "00110001";
--					WHEN "0010" =>
--						v_dataTx := "00110010";
--					WHEN "0011" =>
--						v_dataTx := "00110011";
--					WHEN "0100" =>
--						v_dataTx := "00110100";
--					WHEN "0101" =>
--						v_dataTx := "00110101";
--					WHEN "0110" =>
--						v_dataTx := "00110110";
--					WHEN "0111" =>
--						v_dataTx := "00110111";
--					WHEN "1000" =>
--						v_dataTx := "00111000";
--					WHEN "1001" =>
--						v_dataTx := "00111001";
--						------------------------------
--					WHEN "1010" =>
--						v_dataTx := "01100001";
--					WHEN "1011" =>
--						v_dataTx := "01100010";
--					WHEN "1100" =>
--						v_dataTx := "01100011";
--					WHEN "1101" =>
--						v_dataTx := "01100100";
--					WHEN "1110" =>
--						v_dataTx := "01100101";
--					WHEN "1111" =>
--						v_dataTx := "01100110";
--					WHEN others => v_dataTx := "00000000";
--				END CASE;
				
--				nextState <= cmd_ANNN_txNow_1;
				
--			WHEN cmd_ANNN_txNow_1 =>
--				IF (txdone = '1') THEN
--					v_txNow := '1';
--					nextState <= cmd_ANNN_runPush_1;
--				ELSE
--					nextState <= cmd_ANNN_txNow_1;
--				END IF;
					
--			WHEN cmd_ANNN_runPush_1 =>
----				CASE byte(7 downto 4) is
----					WHEN "0000" => v_dataTx := "00110000";
----					WHEN "0001" => v_dataTx := "00110001";
----					WHEN "0010" => v_dataTx := "00110010";
----					WHEN "0011" => v_dataTx := "00110011";
----					WHEN "0100" => v_dataTx := "00110100";
----					WHEN "0101" => v_dataTx := "00110101";
----					WHEN "0110" => v_dataTx := "00110110";
----					WHEN "0111" => v_dataTx := "00110111";
----					WHEN "1000" => v_dataTx := "00111000";
----					WHEN "1001" => v_dataTx := "00111001";
----						------------------------------
----					WHEN "1010" => v_dataTx := "01100001";
----					WHEN "1011" => v_dataTx := "01100010";
----					WHEN "1100" => v_dataTx := "01100011";
----					WHEN "1101" => v_dataTx := "01100100";
----					WHEN "1110" => v_dataTx := "01100101";
----					WHEN "1111" => v_dataTx := "01100110";
----					WHEN others => v_dataTx := "00000000";
----				END CASE;
--				IF (txdone = '1') then
--					nextState <= cmd_ANNN_txNow_2;
--				ELSE
--					nextState <= cmd_ANNN_runPush_1;
--				END IF;
				
			WHEN cmd_ANNN_txNow_2 => --cmd_ANNN_data =>
				IF (dataReady = '1') THEN
					CASE byte(3 downto 0) is
						WHEN "0000" => v_dataTx := "00110000";
						WHEN "0001" => v_dataTx := "00110001";
						WHEN "0010" => v_dataTx := "00110010";
						WHEN "0011" => v_dataTx := "00110011";
						WHEN "0100" => v_dataTx := "00110100";
						WHEN "0101" => v_dataTx := "00110101";
						WHEN "0110" => v_dataTx := "00110110";
						WHEN "0111" => v_dataTx := "00110111";
						WHEN "1000" => v_dataTx := "00111000";
						WHEN "1001" => v_dataTx := "00111001";
							------------------------------
						WHEN "1010" => v_dataTx := "01100001";
						WHEN "1011" => v_dataTx := "01100010";
						WHEN "1100" => v_dataTx := "01100011";
						WHEN "1101" => v_dataTx := "01100100";
						WHEN "1110" => v_dataTx := "01100101";
						WHEN "1111" => v_dataTx := "01100110";
						WHEN others => v_dataTx := "00000000";
					END CASE;
					v_txNow := '1';
					nextState <= putty_ANNN_wait;--cmd_ANNN_runPush_2;--cmd_ANNN_txNow_1;--cmd_ANNN_txNow;
				ELSE
					nextState <= cmd_ANNN_txNow_2;--cmd_ANNN_data;
				END IF;
					
--			WHEN cmd_ANNN_runPush_2 =>
--				CASE byte(3 downto 0) is
--					WHEN "0000" => v_dataTx := "00110000";
--					WHEN "0001" => v_dataTx := "00110001";
--					WHEN "0010" => v_dataTx := "00110010";
--					WHEN "0011" => v_dataTx := "00110011";
--					WHEN "0100" => v_dataTx := "00110100";
--					WHEN "0101" => v_dataTx := "00110101";
--					WHEN "0110" => v_dataTx := "00110110";
--					WHEN "0111" => v_dataTx := "00110111";
--					WHEN "1000" => v_dataTx := "00111000";
--					WHEN "1001" => v_dataTx := "00111001";
--						------------------------------
--					WHEN "1010" => v_dataTx := "01100001";
--					WHEN "1011" => v_dataTx := "01100010";
--					WHEN "1100" => v_dataTx := "01100011";
--					WHEN "1101" => v_dataTx := "01100100";
--					WHEN "1110" => v_dataTx := "01100101";
--					WHEN "1111" => v_dataTx := "01100110";
--					WHEN others => v_dataTx := "00000000";
--				END CASE;
--				IF (txdone = '1') then
--					nextState <= cmd_ANNN_wait;
--				ELSE
--					nextState <= cmd_ANNN_runPush_2;
--				END IF;
				
			---------------------------------------
			WHEN putty_ANNN_wait =>
				IF (txdone = '1') then
					nextState <= putty_ANNN_txnow;
				ELSE
					nextState <= putty_ANNN_wait;
				END IF;

			WHEN putty_ANNN_txnow =>
				v_dataTx := "00100000";
				IF (txdone = '1') then
					v_txNow := '1';
					nextState <= cmd_ANNN_wait;
				ELSE
					nextState <= putty_ANNN_txnow;
				END IF;
			---------------------------------------
			---------------------------------------
			-- Newline after bitstream ended
			WHEN putty_nr_3_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_3_txnow;
				ELSE
					nextState <= putty_nr_3_wait;
				END IF;

			WHEN putty_nr_3_txnow =>
				v_dataTx := "00001010";
				IF (count_nr > 1) THEN
				--ELSE
					v_dataTx := "00001101";
				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= putty_eq_2_wait;
					else
						nextState <= putty_nr_3_wait;
					end if;
				ELSE
					nextState <= putty_nr_3_txnow;
				END IF;
			---------------------------------------
			-- Dividing line after bitstream ended
			WHEN putty_eq_2_wait =>
				IF (txdone = '1') then
					nextState <= putty_eq_2_txnow;
				ELSE
					nextState <= putty_eq_2_wait;
				END IF;
			WHEN putty_eq_2_txnow =>
				v_dataTx := "00111101";				
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_eq > 4) then
						nextState <= putty_nr_4_wait;
					else
						nextState <= putty_eq_2_wait;
					end if;
				ELSE
					nextState <= putty_eq_2_txnow;
				END IF;
			---------------------------------------
			-- Newline before outputting final values
			WHEN putty_nr_4_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_4_txnow;
				ELSE
					nextState <= putty_nr_4_wait;
				END IF;
			WHEN putty_nr_4_txnow =>
				v_dataTx := "00001010";
				IF (count_nr > 1) THEN
					v_dataTx := "00001101";
				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= cmd_ANNN_outputty;
					else
						nextState <= putty_nr_4_wait;
					end if;
				ELSE
					nextState <= putty_nr_4_txnow;
				END IF;
			
			---------------------------------------
			---------------------------------------
				
			WHEN cmd_ANNN_outputty =>
				v_start := '1';
				-- TODO: Add code
				nextState <= INIT;
			---------------------------------
			WHEN OTHERS => 
				nextState <= INIT;
		END CASE;
		start <= v_start;
		rxDone <= v_rxDone;
		txNow <= v_txNow;
		--IF (dataReady = '1') or (curState = putty_n_txnow) or (curState = putty_n_txnow) then
		IF
			(curState /= cmd_ANNN_txnow_1) and
			(dataReady = '1')
		THEN
			txdata <= v_dataTx;
		END IF;
	END PROCESS; -- combi_nextState
	-----------------------------------------------------
	
--	PROCESS(curState, dataReady, TxDone)
--	BEGIN
--		IF (curState = ) and (dataReady = '1') and (txdone = '1') then
--			txdata <= v_dataTx;
--		END IF;
--	END PROCESS:
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
--	putty_NR: PROCESS(rxData, curState, txdone, rxData)
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
	 --Counter for 0s
	counter: PROCESS (curState, reset, clk, en_count_nr, en_count_eq)--, en_count, curState)
	BEGIN
		IF reset = '1' THEN -- active high reset
			count_nr <= 0;
			count_eq <= 0;
		ELSIF clk'EVENT AND clk = '1' THEN
			IF (curState = putty_nr_1_wait) or (curState = putty_nr_1_txnow) or (curState = putty_nr_2_wait) or (curState = putty_nr_2_txnow) then --en_count = '1' THEN
				-- Counter for 1s only counts in bit_1s state & when registered input is 1
				if ((curState = putty_nr_1_wait) or (curState = putty_nr_2_wait)) and (en_count_nr = '1') then
					count_nr <= count_nr + 1;
				else
					count_nr <= count_nr;
				end if;
			else
				count_nr <= 0;
			END IF;
			IF (curState = putty_eq_1_wait) or (curState = putty_eq_1_txnow) THEN
				IF (curState = putty_eq_1_wait) and (en_count_eq = '1') then
					count_eq <= count_eq + 1;
				else
					count_eq <= count_eq;
				end if;
			else
				count_eq <= 0;
			END IF;
		END IF;
	END PROCESS;
	
	enable : PROCESS (reset, clk, curState, nextState)
	BEGIN
		en_count_nr <= '0';
		en_count_eq <= '0';
		IF ((curState = putty_nr_1_wait) and (nextState /= putty_nr_1_wait)) or ((curState = putty_nr_2_wait) and (nextState /= putty_nr_2_wait)) then --en_count = '1' THEN
			-- Counter for 1s only counts in bit_1s state & when registered input is 1
			en_count_nr <= '1';
		END IF;
		IF (curState = putty_eq_1_wait) and (nextState /= putty_eq_1_wait) THEN
			en_count_eq <= '1';
		END IF;
	END PROCESS;
end cmdProc_behav;
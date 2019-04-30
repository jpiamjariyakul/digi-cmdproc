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
    TYPE state_type IS (INIT,
    	INIT_idle, INIT_check,
    	valid_A_idle, valid_A_check,
    	valid_1_idle, valid_1_check,
    	valid_2_idle, valid_2_check,
    	putty_nr_1_wait, putty_nr_1_tx,
    	putty_eq_1_wait, putty_eq_1_tx,
    	putty_nr_2_wait, putty_nr_2_tx,
    	cmd_wait,
    	cmd_ANNN_dataReady, 
    	cmd_ANNN_buffer_1, cmd_ANNN_tx_1, 
    	cmd_ANNN_buffer_2, cmd_ANNN_tx_2,
    	--putty_ANNN_wait, putty_ANNN_tx,
    	cmd_L_buffer_1, cmd_L_tx_1, 
    	cmd_L_buffer_2, cmd_L_tx_2,
    	cmd_P_buffer_char_1, cmd_P_tx_char_1,
    	cmd_P_buffer_char_2, cmd_P_tx_char_2,
    	--putty_space_P,
    	cmd_P_buffer_bcd_2, cmd_P_tx_bcd_2,
    	cmd_P_buffer_bcd_1, cmd_P_tx_bcd_1,
    	cmd_P_buffer_bcd_0, cmd_P_tx_bcd_0,
    	putty_space, 
    	cmd_ANNN_checkSeq, cmd_L_checkSeq, --cmd_P_checkSeq,
    	putty_nr_3_wait, putty_nr_3_tx,
    	putty_eq_2_wait, putty_eq_2_tx, 
    	putty_nr_4_wait, putty_nr_4_tx,
    	cmd_ANNN_outputty); -- List your states here 
	SIGNAL curState, nextState : state_type;
	SIGNAL processed : std_logic := '0'; -- registered input signal
	SIGNAL s_dataTx: std_logic_vector(7 downto 0); -- Stores rxData into FF --rxData_reg, 
	SIGNAL count_nr, count_eq, count_L: INTEGER := 0;
	SIGNAL en_count_nr, en_count_eq, en_count_L: std_logic; -- ENABLE inputs for counter
	SIGNAL ANNN_dataTx, L_dataTx, P_dataTx: std_logic_vector(15 downto 0);
	SIGNAL P_dataTx_p_2, P_dataTx_p_1, P_dataTx_p_0: std_logic_vector(7 downto 0);
	SIGNAL out_indexMax: BCD_ARRAY_TYPE(2 downto 0);
	SIGNAL out_dataResults: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
	SIGNAL s_curChoice: std_logic_vector(7 downto 0); -- Stores choice (A, P, or L)
begin
--	rxReg: PROCESS (clk, rxData)
--	BEGIN
--		IF clk'EVENT AND clk = '1' THEN
--			rxData_reg <= rxData;
--		END IF;
--	END PROCESS;
	
	-- FF for storing whether data processed
	-- Also stores dataResult and peak index
	ff_process: PROCESS (clk, curState, seqDone)--, dataResults, maxIndex)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
			IF (seqDone = '1') THEN -- 0
				processed <= '1';
			ELSIF (curState = putty_nr_1_wait) then
				processed <= '0';
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
	combi_nextState : PROCESS (curState, rxNow, rxData, --rxData_reg, 
			processed, txDone, dataReady, ANNN_dataTx, --byte,
			count_nr, count_eq, s_dataTx) --, count_byte, num_bcd, bcd_integer, bcd_2, bcd_1, bcd_0)
		variable v_rxDone, v_txNow, v_start: std_logic; -- variable for rxDone
		--variable v_dataTx: std_logic_vector(7 downto 0);
	BEGIN
		-- assign defaults at the beginning to avoid having to assign in every branch
		v_rxDone := '0'; -- Default value of rxDone
		v_txNow := '0';
		v_start := '0';
		CASE curState IS
			-- Echoes whatever is typed to putty terminal
--			WHEN INIT =>
--				nextState <= INIT_idle;
				
			WHEN INIT_idle =>
				IF (rxNow = '1') THEN
					--s_dataTx <= rxData;
					IF (txDone = '1') THEN
						v_txNow := '1';
						v_rxDone := '1';
						nextState <= INIT_check;
					ELSE
						nextState <= INIT_idle;
					END IF;
				ELSE
					nextState <= INIT_idle;
				END IF;
			-- Checks for inputs a/A, or l/L or p/P
			WHEN INIT_check =>
				IF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A_idle; 
				-- 'l' or "L"
				ELSIF ((rxData = "01001100") or (rxData = "01101100") or (rxData = "01010000") or (rxData = "01110000")) and (processed = '1') THEN
					nextState <= putty_nr_1_wait;
				ELSE
					nextState <= INIT_idle;
				END IF;
			---------------------------------------
			-- Echoes whatever is typed to putty terminal
			WHEN valid_A_idle =>
				IF (rxNow = '1') THEN
					--s_dataTx <= rxData;
					IF (txDone = '1') THEN
						v_rxDone := '1';
						v_txNow := '1';
						nextState <= valid_A_check;
					ELSE
						nextState <= valid_A_idle;
					END IF;
				ELSE
					nextState <= valid_A_idle;
				END IF;
			-- Checks for a numeric input
			WHEN valid_A_check =>
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					--numWords_bcd(2) <= rxData(3 downto 0);
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
					--s_dataTx <= rxData;
					IF (txDone = '1') THEN
						v_rxDone := '1';
						v_txNow := '1';
						nextState <= valid_1_check;
					ELSE
						nextState <= valid_1_idle;
					END IF;
				ELSE
					nextState <= valid_1_idle;
				END IF;
			WHEN valid_1_check =>
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					--numWords_bcd(1) <= rxData(3 downto 0);
					nextState <= valid_2_idle;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A_idle;
				ELSE
					nextState <= INIT_idle;
				END IF;
			---------------------------------
			WHEN valid_2_idle =>
				IF (rxNow = '1') THEN
					--s_dataTx <= rxData;
					IF (txDone = '1') THEN
						v_rxDone := '1';
						v_txNow := '1';
						nextState <= valid_2_check;
					ELSE
						nextState <= valid_2_idle;
					END IF;
				ELSE
					nextState <= valid_2_idle;
				END IF;
			WHEN valid_2_check =>
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					--numWords_bcd(0) <= rxData(3 downto 0);
					nextState <= putty_nr_1_wait;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A_idle;
				ELSE
					nextState <= INIT_idle;
				END IF;
			---------------------------------------
			-- Newline after command accepted
			-- Waits until txdone is high
			WHEN putty_nr_1_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_1_tx;
				ELSE
					nextState <= putty_nr_1_wait;
				END IF;
			-- Sets output corresponding to counter & passes it to Tx
			WHEN putty_nr_1_tx =>
--				s_dataTx <= "00001010";
--				IF (count_nr > 1) THEN
--					s_dataTx <= "00001101";
--				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= putty_eq_1_wait;
					else
						nextState <= putty_nr_1_wait;
					end if;
				ELSE
					nextState <= putty_nr_1_tx;
				END IF;
			---------------------------------------
			-- Dividing line after command accepted
			-- Wait for txDone to be high
			WHEN putty_eq_1_wait =>
				IF (txdone = '1') then
					nextState <= putty_eq_1_tx;
				ELSE
					nextState <= putty_eq_1_wait;
				END IF;
			-- Outputs '=' 5 times
			WHEN putty_eq_1_tx =>
				--s_dataTx <= "00111101";
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_eq > 4) then
						nextState <= putty_nr_2_wait;
					else
						nextState <= putty_eq_1_wait;
					end if;
				ELSE
					nextState <= putty_eq_1_tx;
				END IF;
			---------------------------------------
			-- Newline before bitstream begins
			WHEN putty_nr_2_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_2_tx;
				ELSE
					nextState <= putty_nr_2_wait;
				END IF;
			WHEN putty_nr_2_tx =>
--				s_dataTx <= "00001010";
--				IF (count_nr > 1) THEN
--					s_dataTx <= "00001101";
--				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= cmd_wait;
					else
						nextState <= putty_nr_2_wait;
					end if;
				ELSE
					nextState <= putty_nr_2_tx;
				END IF;
			---------------------------------------
			---------------------------------------
			WHEN cmd_wait =>
				IF (txdone = '1') then
					if s_CurChoice = "01000001" then
						v_start := '1';
						nextState <= cmd_ANNN_dataReady;
					elsif s_CurChoice = "01001100" then
						nextState <= cmd_L_buffer_1;
					elsif s_CurChoice = "01010000" then
						nextState <= cmd_P_buffer_char_1;
					end if;
				else
					nextState <= cmd_wait;
				END IF;
			-------------------------
				
			WHEN cmd_ANNN_dataReady => --cmd_ANNN_data =>
				IF (dataReady = '1') THEN
					nextState <= cmd_ANNN_buffer_1;
				ELSE
					nextState <= cmd_ANNN_dataReady;--cmd_ANNN_txNow_1;--cmd_ANNN_data;
				END IF;
			-- Outputs first nibble of byte as ascii
			-- Waits for txDone to be high, then setting output
			WHEN cmd_ANNN_buffer_1 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(15 downto 8);
					v_txNow := '1';
					nextState <= cmd_ANNN_tx_1; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_ANNN_buffer_1;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_ANNN_tx_1 =>
				if (txDone = '1') then
					nextState <= cmd_ANNN_buffer_2;
				ELSE
					nextState <= cmd_ANNN_tx_1;
				END IF;
			-- Outputs second nibble as ascii
			-- Waits for txDone to be high, then setting output
			WHEN cmd_ANNN_buffer_2 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(7 downto 0);
					v_txNow := '1';
					nextState <= cmd_ANNN_tx_2; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_ANNN_buffer_2;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_ANNN_tx_2 =>
				if (txDone = '1') then
					nextState <= putty_space; --putty_ANNN_wait;
				ELSE
					nextState <= cmd_ANNN_tx_2;
				END IF;
			---------------------------------------
			---------------------------------------
			
			-- Outputs first nibble of byte as ascii
			-- Waits for txDone to be high, then setting output
			WHEN cmd_L_buffer_1 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(15 downto 8);
					v_txNow := '1';
					nextState <= cmd_L_tx_1; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_L_buffer_1;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_L_tx_1 =>
				if (txDone = '1') then
					nextState <= cmd_L_buffer_2;
				ELSE
					nextState <= cmd_L_tx_1;
				END IF;
			-- Outputs second nibble as ascii
			-- Waits for txDone to be high, then setting output
			WHEN cmd_L_buffer_2 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(7 downto 0);
					v_txNow := '1';
					nextState <= cmd_L_tx_2; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_L_buffer_2;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_L_tx_2 =>
				if (txDone = '1') then
					nextState <= putty_space; --putty_ANNN_wait;
				ELSE
					nextState <= cmd_L_tx_2;
				END IF;
			---------------------------------------
			---------------------------------------
			
			-- Outputs first nibble of byte as ascii
			-- Waits for txDone to be high, then setting output
			WHEN cmd_P_buffer_char_1 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(15 downto 8);
					v_txNow := '1';
					nextState <= cmd_P_tx_char_1; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_P_buffer_char_1;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_P_tx_char_1 =>
				if (txDone = '1') then
					nextState <= cmd_P_buffer_char_2;
				ELSE
					nextState <= cmd_P_tx_char_1;
				END IF;
			-- Outputs second nibble as ascii
			-- Waits for txDone to be high, then setting output
			WHEN cmd_P_buffer_char_2 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(7 downto 0);
					v_txNow := '1';
					nextState <= cmd_P_tx_char_2; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_P_buffer_char_2;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_P_tx_char_2 =>
				if (txDone = '1') then
					nextState <= putty_space; --putty_ANNN_wait;
				ELSE
					nextState <= cmd_P_tx_char_2;
				END IF;
--			WHEN putty_space_P =>
----				s_dataTx <= "00100000";
--				IF (txdone = '1') then
--					v_txNow := '1';
--					nextState <= cmd_P_buffer_bcd_2;
--				ELSE
--					nextState <= putty_space_P;--putty_ANNN_tx;
--				END IF;
			WHEN cmd_P_buffer_bcd_2 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(7 downto 0);
					v_txNow := '1';
					nextState <= cmd_P_tx_bcd_2; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_P_buffer_bcd_2;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_P_tx_bcd_2 =>
				if (txDone = '1') then
					nextState <= cmd_P_buffer_bcd_1; --putty_ANNN_wait;
				ELSE
					nextState <= cmd_P_tx_bcd_2;
				END IF;
				--------------
			WHEN cmd_P_buffer_bcd_1 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(7 downto 0);
					v_txNow := '1';
					nextState <= cmd_P_tx_bcd_1; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_P_buffer_bcd_1;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_P_tx_bcd_1 =>
				if (txDone = '1') then
					nextState <= cmd_P_buffer_bcd_0; --putty_ANNN_wait;
				ELSE
					nextState <= cmd_P_tx_bcd_1;
				END IF;
				--------------
			WHEN cmd_P_buffer_bcd_0 =>
				if (txDone = '1') then
					--s_dataTx <= ANNN_dataTx(7 downto 0);
					v_txNow := '1';
					nextState <= cmd_P_tx_bcd_0; --cmd_ANNN_runPush_1;
				ELSE
					nextState <= cmd_P_buffer_bcd_0;
				END IF;
			-- Waits for txDone to be high again before proceeding
			WHEN cmd_P_tx_bcd_0 =>
				if (txDone = '1') then
					nextState <= putty_nr_3_wait; --putty_ANNN_wait;
				ELSE
					nextState <= cmd_P_tx_bcd_0;
				END IF;
--			WHEN cmd_P_buffer_bcd =>
--				if (txDone = '1') then
--					--s_dataTx <= ANNN_dataTx(7 downto 0);
--					v_txNow := '1';
--					nextState <= cmd_P_tx_bcd; --cmd_ANNN_runPush_1;
--				ELSE
--					nextState <= cmd_P_buffer_bcd;
--				END IF;
--			-- Waits for txDone to be high again before proceeding
--			WHEN cmd_P_tx_bcd =>
--				if (txDone = '1') then
--					nextState <= cmd_P_checkSeq; --putty_ANNN_wait;
--				ELSE
--					nextState <= cmd_P_tx_bcd;
--				END IF;
--			WHEN cmd_P_checkSeq =>
--				IF (count_P >= 2) then
--					nextState <= putty_nr_3_wait;
--				else
--					nextState <= cmd_P_buffer_bcd;
--				end if;
			
			---------------------------------------
			---------------------------------------
			---------------------------------------
--			WHEN putty_ANNN_wait =>
--				IF (txdone = '1') then
--					nextState <= putty_ANNN_tx;
--				ELSE
--					nextState <= putty_ANNN_wait;
--				END IF;
			WHEN putty_space =>
--				s_dataTx <= "00100000";
				IF (txdone = '1') then
					v_txNow := '1';
					if s_CurChoice = "01000001" then
						nextState <= cmd_ANNN_checkSeq;
					elsif s_CurChoice = "01001100" then
						nextState <= cmd_L_checkSeq;
					elsif s_CurChoice = "01010000" then
						nextState <= cmd_P_buffer_bcd_2;
					end if;
					--nextState <= cmd_ANNN_checkSeq;
				ELSE
					nextState <= putty_space;--putty_ANNN_tx;
				END IF;
			WHEN cmd_ANNN_checkSeq =>
				IF (processed = '1') then
					nextState <= putty_nr_3_wait;
				else
					nextState <= cmd_wait;
				end if;
			WHEN cmd_L_checkSeq =>
				IF (count_L >= 6) then
					nextState <= putty_nr_3_wait;
				else
					nextState <= cmd_wait;
				end if;
			---------------------------------------
			---------------------------------------
			-- Newline after bitstream ended
			WHEN putty_nr_3_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_3_tx;
				ELSE
					nextState <= putty_nr_3_wait;
				END IF;
			WHEN putty_nr_3_tx =>
--				s_dataTx <= "00001010";
--				IF (count_nr > 1) THEN
--				--ELSE
--					s_dataTx <= "00001101";
--				END IF;
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= putty_eq_2_wait;
					else
						nextState <= putty_nr_3_wait;
					end if;
				ELSE
					nextState <= putty_nr_3_tx;
				END IF;
			---------------------------------------
			-- Dividing line after bitstream ended
			WHEN putty_eq_2_wait =>
				IF (txdone = '1') then
					nextState <= putty_eq_2_tx;
				ELSE
					nextState <= putty_eq_2_wait;
				END IF;
			WHEN putty_eq_2_tx =>
--				s_dataTx <= "00111101";				
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_eq > 4) then
						nextState <= putty_nr_4_wait;
					else
						nextState <= putty_eq_2_wait;
					end if;
				ELSE
					nextState <= putty_eq_2_tx;
				END IF;
			---------------------------------------
			-- Newline before outputting final values
			WHEN putty_nr_4_wait =>
				IF (txdone = '1') then
					nextState <= putty_nr_4_tx;
				ELSE
					nextState <= putty_nr_4_wait;
				END IF;
			WHEN putty_nr_4_tx =>
				IF (txdone = '1') then
					v_txNow := '1';
					IF (count_nr > 1) then
						nextState <= INIT_idle;--cmd_ANNN_outputty;
					else
						nextState <= putty_nr_4_wait;
					end if;
				ELSE
					nextState <= putty_nr_4_tx;
				END IF;
			-----------------
			WHEN OTHERS => 
				nextState <= INIT_idle;
		END CASE;
		
		start <= v_start;
		rxDone <= v_rxDone;
		txNow <= v_txNow;
		txdata <= s_dataTx;
	END PROCESS; -- combi_nextState
	-----------------------------------------------------
	-- Sets signals out_indexMax and out_dataResults when seqDone
	lp_set: PROCESS(clk, curState, maxIndex, dataResults, seqDone, s_curChoice)
	begin
		IF (s_curChoice = "01000001") and (seqDone = '1') then
			out_indexMax <= maxIndex;
			out_dataResults <= dataResults;
		END IF;
	END PROCESS;
	-----------------------------------------------------
	numWords: PROCESS(curState, rxData, clk)
	begin
		IF clk'EVENT AND clk = '1' THEN
			IF (curState = valid_A_check) then
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					numWords_bcd(2) <= rxData(3 downto 0);
				END IF;
			elsif (curState = valid_1_check) then
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					numWords_bcd(1) <= rxData(3 downto 0);
				END IF;
			elsif (curState = valid_2_check) then
				IF (rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001") THEN
					numWords_bcd(0) <= rxData(3 downto 0);
				END IF;
			end if;
		end if;
	end process;
	-----------------------------------------------------
	
	choice_store: PROCESS(clk, curState, rxData, reset)
	begin
		IF 	(curState = valid_2_check) AND (
			(rxData = "00110000") OR (rxData = "00110001") OR 
			(rxData = "00110010") OR (rxData = "00110011") OR 
			(rxData = "00110100") OR (rxData = "00110101") OR 
			(rxData = "00110110") OR (rxData = "00110111") OR 
			(rxData = "00111000") OR (rxData = "00111001")) THEN
			--numWords_bcd(0) <= rxData(3 downto 0);
			s_curChoice <= "01000001";
		ELSIF (curState = INIT_check) and (processed = '1') and (
			(rxData = "01001100") or (rxData = "01101100")) THEN
			s_curChoice <= "01001100";
		ELSIF (curState = INIT_check) and (processed = '1') and (
			(rxData = "01010000") or (rxData = "01110000")) THEN
			s_curChoice <= "01010000";
		ELSIF (reset = '1') THEN
	        s_curChoice <= X"FF";
		END IF;
	end process;
	-----------------------------------------------------	
	
	-- Decoder from nibble hex literals to ascii character equivalents
	ascii_decode: PROCESS(clk, byte)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
			CASE byte(7 downto 4) is
				WHEN "0000" => ANNN_dataTx(15 downto 8) <= "00110000";
				WHEN "0001" => ANNN_dataTx(15 downto 8) <= "00110001";
				WHEN "0010" => ANNN_dataTx(15 downto 8) <= "00110010";
				WHEN "0011" => ANNN_dataTx(15 downto 8) <= "00110011";
				WHEN "0100" => ANNN_dataTx(15 downto 8) <= "00110100";
				WHEN "0101" => ANNN_dataTx(15 downto 8) <= "00110101";
				WHEN "0110" => ANNN_dataTx(15 downto 8) <= "00110110";
				WHEN "0111" => ANNN_dataTx(15 downto 8) <= "00110111";
				WHEN "1000" => ANNN_dataTx(15 downto 8) <= "00111000";
				WHEN "1001" => ANNN_dataTx(15 downto 8) <= "00111001";
					------------------------------
				WHEN "1010" => ANNN_dataTx(15 downto 8) <= "01000001";
				WHEN "1011" => ANNN_dataTx(15 downto 8) <= "01000010";
				WHEN "1100" => ANNN_dataTx(15 downto 8) <= "01000011";
				WHEN "1101" => ANNN_dataTx(15 downto 8) <= "01000100";
				WHEN "1110" => ANNN_dataTx(15 downto 8) <= "01000101";
				WHEN "1111" => ANNN_dataTx(15 downto 8) <= "01000110";
					------------------------------
				WHEN others => ANNN_dataTx(15 downto 8) <= "00000000";
			END CASE;
			CASE byte(3 downto 0) is
				WHEN "0000" => ANNN_dataTx(7 downto 0) <= "00110000";
				WHEN "0001" => ANNN_dataTx(7 downto 0) <= "00110001";
				WHEN "0010" => ANNN_dataTx(7 downto 0) <= "00110010";
				WHEN "0011" => ANNN_dataTx(7 downto 0) <= "00110011";
				WHEN "0100" => ANNN_dataTx(7 downto 0) <= "00110100";
				WHEN "0101" => ANNN_dataTx(7 downto 0) <= "00110101";
				WHEN "0110" => ANNN_dataTx(7 downto 0) <= "00110110";
				WHEN "0111" => ANNN_dataTx(7 downto 0) <= "00110111";
				WHEN "1000" => ANNN_dataTx(7 downto 0) <= "00111000";
				WHEN "1001" => ANNN_dataTx(7 downto 0) <= "00111001";
					------------------------------
				WHEN "1010" => ANNN_dataTx(7 downto 0) <= "01000001";
				WHEN "1011" => ANNN_dataTx(7 downto 0) <= "01000010";
				WHEN "1100" => ANNN_dataTx(7 downto 0) <= "01000011";
				WHEN "1101" => ANNN_dataTx(7 downto 0) <= "01000100";
				WHEN "1110" => ANNN_dataTx(7 downto 0) <= "01000101";
				WHEN "1111" => ANNN_dataTx(7 downto 0) <= "01000110";
				WHEN others => ANNN_dataTx(7 downto 0) <= "00000000";
			END CASE;
			
		END IF;
	END PROCESS;
	----------------------------
	-- Decoder from nibble hex literals to ascii character equivalents
	ascii_decode_L: PROCESS(clk, out_dataResults, count_L)
	BEGIN
		IF (clk'EVENT AND clk = '1') and (count_L < 7) THEN
			CASE out_dataResults(count_L)(7 downto 4) is
				WHEN "0000" => L_dataTx(15 downto 8) <= "00110000";
				WHEN "0001" => L_dataTx(15 downto 8) <= "00110001";
				WHEN "0010" => L_dataTx(15 downto 8) <= "00110010";
				WHEN "0011" => L_dataTx(15 downto 8) <= "00110011";
				WHEN "0100" => L_dataTx(15 downto 8) <= "00110100";
				WHEN "0101" => L_dataTx(15 downto 8) <= "00110101";
				WHEN "0110" => L_dataTx(15 downto 8) <= "00110110";
				WHEN "0111" => L_dataTx(15 downto 8) <= "00110111";
				WHEN "1000" => L_dataTx(15 downto 8) <= "00111000";
				WHEN "1001" => L_dataTx(15 downto 8) <= "00111001";
					------------------------------
				WHEN "1010" => L_dataTx(15 downto 8) <= "01000001";
				WHEN "1011" => L_dataTx(15 downto 8) <= "01000010";
				WHEN "1100" => L_dataTx(15 downto 8) <= "01000011";
				WHEN "1101" => L_dataTx(15 downto 8) <= "01000100";
				WHEN "1110" => L_dataTx(15 downto 8) <= "01000101";
				WHEN "1111" => L_dataTx(15 downto 8) <= "01000110";
					------------------------------
				WHEN others => L_dataTx(15 downto 8) <= "00000000";
			END CASE;
			CASE out_dataResults(count_L)(3 downto 0) is
				WHEN "0000" => L_dataTx(7 downto 0) <= "00110000";
				WHEN "0001" => L_dataTx(7 downto 0) <= "00110001";
				WHEN "0010" => L_dataTx(7 downto 0) <= "00110010";
				WHEN "0011" => L_dataTx(7 downto 0) <= "00110011";
				WHEN "0100" => L_dataTx(7 downto 0) <= "00110100";
				WHEN "0101" => L_dataTx(7 downto 0) <= "00110101";
				WHEN "0110" => L_dataTx(7 downto 0) <= "00110110";
				WHEN "0111" => L_dataTx(7 downto 0) <= "00110111";
				WHEN "1000" => L_dataTx(7 downto 0) <= "00111000";
				WHEN "1001" => L_dataTx(7 downto 0) <= "00111001";
					------------------------------
				WHEN "1010" => L_dataTx(7 downto 0) <= "01000001";
				WHEN "1011" => L_dataTx(7 downto 0) <= "01000010";
				WHEN "1100" => L_dataTx(7 downto 0) <= "01000011";
				WHEN "1101" => L_dataTx(7 downto 0) <= "01000100";
				WHEN "1110" => L_dataTx(7 downto 0) <= "01000101";
				WHEN "1111" => L_dataTx(7 downto 0) <= "01000110";
				WHEN others => L_dataTx(7 downto 0) <= "00000000";
			END CASE;
		END IF;
	END PROCESS;
	------------------------------------------------------
	----------------------------
	-- Decoder from nibble hex literals to ascii character equivalents
	ascii_decode_P: PROCESS(clk, out_dataResults)
	BEGIN
		IF (clk'EVENT AND clk = '1') THEN
			CASE out_dataResults(3)(7 downto 4) is
				WHEN "0000" => P_dataTx(15 downto 8) <= "00110000";
				WHEN "0001" => P_dataTx(15 downto 8) <= "00110001";
				WHEN "0010" => P_dataTx(15 downto 8) <= "00110010";
				WHEN "0011" => P_dataTx(15 downto 8) <= "00110011";
				WHEN "0100" => P_dataTx(15 downto 8) <= "00110100";
				WHEN "0101" => P_dataTx(15 downto 8) <= "00110101";
				WHEN "0110" => P_dataTx(15 downto 8) <= "00110110";
				WHEN "0111" => P_dataTx(15 downto 8) <= "00110111";
				WHEN "1000" => P_dataTx(15 downto 8) <= "00111000";
				WHEN "1001" => P_dataTx(15 downto 8) <= "00111001";
					------------------------------
				WHEN "1010" => P_dataTx(15 downto 8) <= "01000001";
				WHEN "1011" => P_dataTx(15 downto 8) <= "01000010";
				WHEN "1100" => P_dataTx(15 downto 8) <= "01000011";
				WHEN "1101" => P_dataTx(15 downto 8) <= "01000100";
				WHEN "1110" => P_dataTx(15 downto 8) <= "01000101";
				WHEN "1111" => P_dataTx(15 downto 8) <= "01000110";
					------------------------------
				WHEN others => P_dataTx(15 downto 8) <= "00000000";
			END CASE;
			CASE out_dataResults(3)(3 downto 0) is
				WHEN "0000" => P_dataTx(7 downto 0) <= "00110000";
				WHEN "0001" => P_dataTx(7 downto 0) <= "00110001";
				WHEN "0010" => P_dataTx(7 downto 0) <= "00110010";
				WHEN "0011" => P_dataTx(7 downto 0) <= "00110011";
				WHEN "0100" => P_dataTx(7 downto 0) <= "00110100";
				WHEN "0101" => P_dataTx(7 downto 0) <= "00110101";
				WHEN "0110" => P_dataTx(7 downto 0) <= "00110110";
				WHEN "0111" => P_dataTx(7 downto 0) <= "00110111";
				WHEN "1000" => P_dataTx(7 downto 0) <= "00111000";
				WHEN "1001" => P_dataTx(7 downto 0) <= "00111001";
					------------------------------
				WHEN "1010" => P_dataTx(7 downto 0) <= "01000001";
				WHEN "1011" => P_dataTx(7 downto 0) <= "01000010";
				WHEN "1100" => P_dataTx(7 downto 0) <= "01000011";
				WHEN "1101" => P_dataTx(7 downto 0) <= "01000100";
				WHEN "1110" => P_dataTx(7 downto 0) <= "01000101";
				WHEN "1111" => P_dataTx(7 downto 0) <= "01000110";
				WHEN others => P_dataTx(7 downto 0) <= "00000000";
			END CASE;
			CASE out_indexMax(2) is
				WHEN "0000" => P_dataTx_p_2(7 downto 0) <= "00110000";
				WHEN "0001" => P_dataTx_p_2(7 downto 0) <= "00110001";
				WHEN "0010" => P_dataTx_p_2(7 downto 0) <= "00110010";
				WHEN "0011" => P_dataTx_p_2(7 downto 0) <= "00110011";
				WHEN "0100" => P_dataTx_p_2(7 downto 0) <= "00110100";
				WHEN "0101" => P_dataTx_p_2(7 downto 0) <= "00110101";
				WHEN "0110" => P_dataTx_p_2(7 downto 0) <= "00110110";
				WHEN "0111" => P_dataTx_p_2(7 downto 0) <= "00110111";
				WHEN "1000" => P_dataTx_p_2(7 downto 0) <= "00111000";
				WHEN "1001" => P_dataTx_p_2(7 downto 0) <= "00111001";
					------------------------------
				WHEN others => P_dataTx_p_2(7 downto 0) <= "00000000";
			END CASE;
			CASE out_indexMax(1) is
				WHEN "0000" => P_dataTx_p_1(7 downto 0) <= "00110000";
				WHEN "0001" => P_dataTx_p_1(7 downto 0) <= "00110001";
				WHEN "0010" => P_dataTx_p_1(7 downto 0) <= "00110010";
				WHEN "0011" => P_dataTx_p_1(7 downto 0) <= "00110011";
				WHEN "0100" => P_dataTx_p_1(7 downto 0) <= "00110100";
				WHEN "0101" => P_dataTx_p_1(7 downto 0) <= "00110101";
				WHEN "0110" => P_dataTx_p_1(7 downto 0) <= "00110110";
				WHEN "0111" => P_dataTx_p_1(7 downto 0) <= "00110111";
				WHEN "1000" => P_dataTx_p_1(7 downto 0) <= "00111000";
				WHEN "1001" => P_dataTx_p_1(7 downto 0) <= "00111001";
					------------------------------
				WHEN others => P_dataTx_p_1(7 downto 0) <= "00000000";
			END CASE;
			CASE out_indexMax(0) is
				WHEN "0000" => P_dataTx_p_0(7 downto 0) <= "00110000";
				WHEN "0001" => P_dataTx_p_0(7 downto 0) <= "00110001";
				WHEN "0010" => P_dataTx_p_0(7 downto 0) <= "00110010";
				WHEN "0011" => P_dataTx_p_0(7 downto 0) <= "00110011";
				WHEN "0100" => P_dataTx_p_0(7 downto 0) <= "00110100";
				WHEN "0101" => P_dataTx_p_0(7 downto 0) <= "00110101";
				WHEN "0110" => P_dataTx_p_0(7 downto 0) <= "00110110";
				WHEN "0111" => P_dataTx_p_0(7 downto 0) <= "00110111";
				WHEN "1000" => P_dataTx_p_0(7 downto 0) <= "00111000";
				WHEN "1001" => P_dataTx_p_0(7 downto 0) <= "00111001";
					------------------------------
				WHEN others => P_dataTx_p_0(7 downto 0) <= "00000000";
			END CASE;
		END IF;
	END PROCESS;
	------------------------------------------------------
	dataTx_set: PROCESS(clk, reset, curState, ANNN_dataTx, rxData, rxNow, txDone, count_nr)
	begin
		IF clk'EVENT AND clk='1' THEN
			IF (reset = '1') or ((curState = putty_nr_4_tx) and ((txdone = '1') and (count_nr > 1))) THEN
	        	s_dataTx <= X"FF"; -- assign a HEX value to std_logic_vector
			elsif ((curState = INIT_idle) or (curState = valid_A_idle) or (curState = valid_1_idle) or (curState = valid_2_idle)) and (rxNow = '1') then
				s_dataTx <= rxData;
			elsif (curState = putty_nr_1_tx) or (curState = putty_nr_2_tx) or (curState = putty_nr_3_tx) or (curState = putty_nr_4_tx) then
				IF (count_nr > 1) THEN
					s_dataTx <= "00001101";
				else
					s_dataTx <= "00001010";
				END IF;
			elsif (curState = putty_eq_1_tx) or (curState = putty_eq_2_tx) then
				s_dataTx <= "00111101";
			elsif (curState = cmd_ANNN_buffer_1) and (txDone = '1') then
				s_dataTx <= ANNN_dataTx(15 downto 8);
			elsif (curState = cmd_ANNN_buffer_2) and (txDone = '1') then
				s_dataTx <= ANNN_dataTx(7 downto 0);
			--------
			elsif (curState = putty_space) then
				s_dataTx <= "00100000";
			--------
			elsif (curState = cmd_L_buffer_1) then
				s_dataTx <= L_dataTx(15 downto 8);
			elsif (curState = cmd_L_buffer_2) then
				s_dataTx <= L_dataTx(7 downto 0);
			--------
			elsif (curState = cmd_P_buffer_char_1) then
				s_dataTx <= P_dataTx(15 downto 8);
			elsif (curState = cmd_P_buffer_char_2) then
				s_dataTx <= P_dataTx(7 downto 0);
			elsif (curState = cmd_P_buffer_bcd_2) then
				s_dataTx <= P_dataTx_p_2;
			elsif (curState = cmd_P_buffer_bcd_1) then
				s_dataTx <= P_dataTx_p_1;
			elsif (curState = cmd_P_buffer_bcd_0) then
				s_dataTx <= P_dataTx_p_0;
--			else
--				s_dataTx <= "11111111";
			END IF;
		END IF;
	END PROCESS;
	------------------------------------------------------
	--Counter for 0s
	counter: PROCESS (curState, reset, clk, en_count_nr, en_count_eq)
	BEGIN
		IF reset = '1' THEN -- active high reset
			count_nr <= 0;
			count_eq <= 0;
			count_L <= 0;
			--count_P <= 0;
		ELSIF clk'EVENT AND clk = '1' THEN
			-- Counter for line feed & carriage return
			IF (curState = putty_nr_1_wait) or (curState = putty_nr_1_tx) or 
				(curState = putty_nr_2_wait) or (curState = putty_nr_2_tx) or
				(curState = putty_nr_3_wait) or (curState = putty_nr_3_tx) or
				(curState = putty_nr_4_wait) or (curState = putty_nr_4_tx) 
				then --en_count = '1' THEN
				-- Counter for 1s only counts in bit_1s state & when registered input is 1
				if ((curState = putty_nr_1_wait) or (curState = putty_nr_2_wait) or 
						(curState = putty_nr_3_wait) or (curState = putty_nr_4_wait)) 
						and (en_count_nr = '1') then
					count_nr <= count_nr + 1;
				else
					count_nr <= count_nr;
				end if;
			else
				count_nr <= 0;
			END IF;
			-- Counter for "="
			IF (curState = putty_eq_1_wait) or (curState = putty_eq_1_tx) or 
				(curState = putty_eq_2_wait) or (curState = putty_eq_2_tx) THEN
				IF ((curState = putty_eq_1_wait) or (curState = putty_eq_2_wait)) and (en_count_eq = '1') then
					count_eq <= count_eq + 1;
				else
					count_eq <= count_eq;
				end if;
			else
				count_eq <= 0;
			END IF;
			-- Counter for 'L' & seven bytes
			IF 	(curState = cmd_wait) or 
				(curState = cmd_L_buffer_1) or 
				(curState = cmd_L_tx_1) or 
				(curState = cmd_L_buffer_2) or 
				(curState = cmd_L_tx_2) or
				(curState = putty_space) or 
				(curState = cmd_L_checkSeq) THEN
				IF (curState = cmd_L_checkSeq) and (en_count_L = '1') then
					count_L <= count_L + 1;
				else
					count_L <= count_L;
				end if;
			else
				count_L <= 0;
			END IF;
--			-- Counter for three digits of BCD peak
--			IF 	(curState = cmd_P_buffer_bcd) or 
--				(curState = cmd_P_tx_bcd) or
--				(curState = putty_space) or 
--				(curState = cmd_P_checkSeq) THEN
--				IF (curState = cmd_P_checkSeq) and (en_count_P = '1') then
--					count_P <= count_P + 1;
--				else
--					count_P <= count_P;
--				end if;
--			else
--				count_P <= 0;
--			END IF;
		END IF;
	END PROCESS;
	------------------------------------------------------
	enable : PROCESS (reset, clk, curState, nextState)
	BEGIN
		en_count_nr <= '0';
		en_count_eq <= '0';
		en_count_L <= '0';
--		en_count_P <= '0';
		IF ((curState = putty_nr_1_wait) and (nextState /= putty_nr_1_wait)) or 
			((curState = putty_nr_2_wait) and (nextState /= putty_nr_2_wait)) or
			((curState = putty_nr_3_wait) and (nextState /= putty_nr_3_wait)) or
			((curState = putty_nr_4_wait) and (nextState /= putty_nr_4_wait))
			then --en_count = '1' THEN
			-- Counter for 1s only counts in bit_1s state & when registered input is 1
			en_count_nr <= '1';
		END IF;
		IF ((curState = putty_eq_1_wait) and (nextState /= putty_eq_1_wait)) or ((curState = putty_eq_2_wait) and (nextState /= putty_eq_2_wait)) THEN
			en_count_eq <= '1';
		END IF;
		IF (curState = cmd_L_checkSeq) and (nextState /= cmd_L_checkSeq) then
			en_count_L <= '1';
		end if;
--		IF (curState = cmd_P_checkSeq) and (nextState /= cmd_P_checkSeq) then
--			en_count_P <= '1';
--		end if;
	END PROCESS;
end cmdProc_behav;
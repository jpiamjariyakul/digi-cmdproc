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
use IEEE.numeric_std.ALL;

-- 190304: Defined entity
entity cmdProc is
port (
	-- Generic clock/reset
    clk:            in      std_logic;
    reset:          in      std_logic;
    -- I/O of Rx module
    rxdone:         out     std_logic; -- Same as "done" in diagram
    rxData:         in      std_logic_vector (7 downto 0);
	rxNow:          in      std_logic; -- Same as "valid" in diagram
    ovErr:          in      std_logic; 
    framErr:        in      std_logic;
    -- I/O of Tx module
    txnow:          out     std_logic;
    txData:         out     std_logic_vector (7 downto 0);
    txdone:         in      std_logic;
    -- I/O of data module
    start:          out     std_logic;
    numWords_bcd:   out     BCD_ARRAY_TYPE(2 downto 0);
    dataReady:      in      std_logic;
    byte:           in      std_logic_vector(7 downto 0);
    maxIndex:       in      BCD_ARRAY_TYPE(2 downto 0);
    dataResults:    in      CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone:        in      std_logic
    );
end cmdProc;
-- 190304: Added arch - DONE!
architecture cmdProc_behav of cmdProc is
-- Component declaration of dataConsume
    TYPE state_type IS (INIT, dataValid, valid_A, valid_1, valid_2, dataANNN); -- List your states here 
	SIGNAL curState, nextState : state_type;
	SIGNAL processed : BIT; -- registered input signal
	SIGNAL rxData_reg: std_logic_vector(7 downto 0); -- Stores rxData into FF
	--SIGNAL num1, num2, num3: std_logic_vector(7 downto 0); --  Stores numbers inputted
	SIGNAL en_count_byte: BIT; -- ENABLE input for counter 
	--SIGNAL count_byte: INTEGER := 0; -- counter integers for bytes retrieved
	SIGNAL count_byte: INTEGER := 0; --BCD_ARRAY_TYPE(2 downto 0):= ("0000", "0000", "0000"); -- counter integers for bytes retrieved
	SIGNAL bcd_integer, bcd_2, bcd_1, bcd_0: INTEGER; -- Equivalent integer
	SIGNAL num_bcd: BCD_ARRAY_TYPE(2 downto 0) := ("0000", "0000", "0000"); -- Stores the same value as numWords_bcd, but can be read
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
	PROCESS (clk, curState, rxData_reg)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN
			IF (curState = valid_2) and (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0
				processed <= '1';
			END IF;
		END IF;
	END PROCESS;
	
--	PROCESS (clk, curState, num_bcd, bcd_integer, bcd_2, bcd_1, bcd_0)
--	BEGIN
--		IF clk'EVENT AND clk = '1' THEN
--			bcd_2 <= to_integer(unsigned(num_bcd(2)));
--			bcd_1 <= to_integer(unsigned(num_bcd(1)));
--			bcd_0 <= to_integer(unsigned(num_bcd(0)));
--			bcd_integer <= (100 * bcd_2) + (10 * bcd_1) + bcd_0;
--		END IF;
--	END PROCESS;
	----------------------------------------
	combi_nextState : PROCESS (curState, rxNow, rxData, processed, count_byte, num_bcd, bcd_integer, bcd_2, bcd_1, bcd_0)
		variable v_rxDone: std_logic; -- variable for rxDone
	BEGIN
		v_rxDone := '0'; -- Default value of rxDone
		CASE curState IS
--			WHEN INIT =>
--				IF (rxnow = '1') THEN
--					nextState <= dataValid;
--				ELSE
--					nextState <= INIT;
--				END IF;
			
			WHEN INIT => --(sig_rxNow = '1') and 
				IF (rxNow = '1') and ((rxData = "01000001") or (rxData = "01100001")) THEN
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;
 
			WHEN valid_A => 
				IF (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0
					num_bcd(2) <= rxData(3 downto 0);
					numWords_bcd(2) <= num_bcd(2);
					nextState <= valid_1;
					--ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
						--nextState <= INIT;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;

			WHEN valid_1 =>
				IF (rxData = rxData_reg) THEN
					nextState <= valid_1;
				ELSIF (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0
					num_bcd(1) <= rxData(3 downto 0);
					numWords_bcd(1) <= num_bcd(1);
					nextState <= valid_2;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;

			WHEN valid_2 =>
				IF (rxData = rxData_reg) THEN
					nextState <= valid_2;
				ELSIF (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0
					num_bcd(0) <= rxData(3 downto 0);
					numWords_bcd(0) <= num_bcd(0);
					
					-- Converts total value into BCD
					bcd_2 <= to_integer(unsigned(num_bcd(2)));
					bcd_1 <= to_integer(unsigned(num_bcd(1)));
					bcd_0 <= to_integer(unsigned(num_bcd(0)));
					bcd_integer <= (100 * bcd_2) + (10 * bcd_1) + bcd_0;
					
					v_rxDone := '1'; -- Sets rxDone high for 1 clkCycle
					nextState <= dataANNN;
				ELSIF (rxData = "01000001") or (rxData = "01100001") THEN
					nextState <= valid_A;
				ELSE
					nextState <= INIT;
				END IF;
				-- Question 15: Added an "others" statement to case selection
				-- Given such, when an invalid encoding is given, the program jumps its state to INIT
			WHEN dataANNN =>
				-- TODO: Compare numWords_bcd w/ count_byte
				IF (count_byte < (bcd_integer - 1)) THEN
					nextState <= dataANNN;
				ELSE
					nextState <= INIT;
				END IF;
			WHEN OTHERS => 
				nextState <= INIT;
		END CASE;
		rxDone <= v_rxDone;
	END PROCESS; -- combi_nextState
	-----------------------------------------------------
	seq_state : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' THEN
			curState <= INIT;
		ELSIF clk'EVENT AND clk = '1' THEN
			curState <= nextState;
		END IF;
	END PROCESS; -- seq
	-----------------------------------------------------
	run_ANNN: PROCESS(curState, seqDone, count_byte, bcd_integer) -- Used for linking data processing
	BEGIN
	-- 190316-01: Began coding for aNNN (Jay)
	-- Default values for "start"
		start <= '0';
		if (curState = valid_2) and (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN
			start <= '1'; -- starts data retrieval
		elsif (curState = dataANNN) and (seqDone = '1') then
			start <= '1'; -- stops data retrieval
		end if;
	END PROCESS;
	-----------------------------------------------------
	-- Enable for counter
	enable_byte : PROCESS (reset, clk, count_byte, bcd_integer)
	BEGIN
		en_count_byte <= '0'; -- assign default value
		--IF (curState = valid_2) and (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN
		IF (curState = dataANNN) AND (count_byte < (bcd_integer - 1)) THEN
			en_count_byte <= '1';
		END IF;
	END PROCESS;
	-----------------------------------------------------
	-- Counter for bytes processed
	counter_byte : PROCESS (reset, clk, en_count_byte)
	BEGIN
		IF reset = '0' THEN -- active high reset
			count_byte <= 0; --("0000", "0000", "0000");
		ELSIF clk'EVENT AND clk = '1' THEN
			IF en_count_byte = '1' THEN
				-- Counter for 0s only counts in INIT or bit_0s states & when registered input is 0
				count_byte <= count_byte + 1;
			ELSE
				-- Counter resets to 0 when registered input is not 0
				count_byte <= 0;
			END IF;
		END IF;
	END PROCESS;
	-----------------------------------------------------
	run_LP: PROCESS (curState, processed) -- Use this to process/list data
	BEGIN
		--y <= '0'; -- assign default value
		-- rxData is P or p, and processed
		IF (processed = '1') and ((rxData = "01010000") or (rxData = "01110000")) THEN
			--y <= '1';
		-- rxData is L or l, and processed
		ELSIF (processed = '1') and ((rxData = "01001100") or (rxData = "01101100")) THEN
		
		END IF;
	END PROCESS; -- combi_output
    --Test2
end cmdProc_behav;

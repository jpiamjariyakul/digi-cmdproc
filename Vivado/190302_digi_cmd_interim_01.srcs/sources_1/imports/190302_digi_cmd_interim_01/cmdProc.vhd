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
    clk:            in      std_logic;
    reset:          in      std_logic;
    rxnow:          in      std_logic;
    rxData:         in      std_logic_vector (7 downto 0);
    txData:         out     std_logic_vector (7 downto 0);
    rxdone:         out     std_logic;
    ovErr:          in      std_logic;
    framErr:        in      std_logic;
    txnow:          out     std_logic;
    txdone:         in      std_logic;
    start:          out     std_logic;
    numWords_bcd:   out     BCD_ARRAY_TYPE(2 downto 0);
    dataReady:      in      std_logic;
    byte:           in      std_logic_vector(7 downto 0);
    maxIndex:       in      BCD_ARRAY_TYPE(2 downto 0);
    dataResults:    in      CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone:        in      std_logic
    );
end cmdProc;

-- 190304: Added arch - TBC
architecture cmdProc_behav of cmdProc is
-- Component declaration of dataConsume
    TYPE state_type IS (INIT, bit_0s, HOLD, bit_1s); -- List your states here 
	SIGNAL curState, nextState : state_type;
	SIGNAL x_reg : BIT; -- registered input signal
	SIGNAL en_count_0, en_count_1 : BIT; -- ENABLE inputs for counter 
	SIGNAL count_0, count_1 : INTEGER := 0; -- counter integers for 0s and 1s

begin

    
end cmdProc_behav;

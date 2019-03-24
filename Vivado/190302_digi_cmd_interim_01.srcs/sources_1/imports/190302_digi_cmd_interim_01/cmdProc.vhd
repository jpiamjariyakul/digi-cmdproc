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

clk: in std_logic;

reset: in std_logic;

rxnow: in std_logic;

rxData: in std_logic_vector (7 downto 0);

txData: out std_logic_vector (7 downto 0);

rxdone: out std_logic;

ovErr: in std_logic;

framErr: in std_logic;

txnow: out std_logic;

txdone: in std_logic;

start: out std_logic;

numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);

dataReady: in std_logic;

byte: in std_logic_vector(7 downto 0);

maxIndex: in BCD_ARRAY_TYPE(2 downto 0);

dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);

seqDone: in std_logic

);

end cmdProc;

-- 190304: Added arch - TBC

architecture cmdProc_behav of cmdProc is

-- Component declaration of dataConsume

TYPE state_type IS (INIT, valid_A, valid_1, valid_2); -- List your states here 

SIGNAL curState, nextState : state_type;

SIGNAL processed : BIT; -- registered input signal

SIGNAL rxData_reg: std_logic_vector(7 downto 0); -- Stores rxData into FF

--SIGNAL num1, num2, num3: std_logic_vector(7 downto 0); -- Stores numbers inputted

--SIGNAL en_count_0, en_count_1 : BIT; -- ENABLE inputs for counter 

--SIGNAL count_0, count_1 : INTEGER := 0; -- counter integers for 0s and 1s

begin

-- 190310: IDEA - instead of using processed FF, output invalid data instead?

-- 190311: Sequence working! (sans L & P)

-- FF for storing incoming rxData - used in checking for next clock cycle whether same data

PROCESS (clk, rxData)

BEGIN

IF clk'EVENT AND clk = '1' THEN

rxData_reg <= rxData;

END IF;

END PROCESS;

-- FF for storing whether data processed

PROCESS (clk, curState, rxData_reg, rxData)

BEGIN

IF clk'EVENT AND clk = '1' THEN

IF (curState = valid_2) and (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0

processed <= '1';

END IF;

END IF;

END PROCESS;

----------------------------------------

combi_nextState : PROCESS (curState, rxData, processed, rxData_reg, nextState, rxData, start)

BEGIN

CASE curState IS

start = '0';

WHEN INIT => 
start = '1';

IF (rxData = "01000001") or (rxData = "01100001") THEN

nextState <= valid_A;

ELSE

nextState <= INIT;

END IF;


WHEN valid_A => 
start = '1';

IF (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0

numWords_bcd(2) <= rxData(3 downto 0);

nextState <= valid_1;

ELSIF (rxData = "01000001") or (rxData = "01100001") THEN

nextState <= valid_A;

ELSE

nextState <= INIT;

END IF;


WHEN valid_1 =>
start = '1';

IF (rxData = rxData_reg) THEN

nextState <= valid_1;

ELSIF (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0

numWords_bcd(1) <= rxData(3 downto 0);

nextState <= valid_2;

ELSIF (rxData = "01000001") or (rxData = "01100001") THEN

nextState <= valid_A;

ELSE

nextState <= INIT;

END IF;


WHEN valid_2 => 
start = '1';

IF (rxData = rxData_reg) THEN

nextState <= valid_2;

ELSIF (rxData /= rxData_reg) and ((rxData = "00110000") OR (rxData = "00110001") OR (rxData = "00110010") OR (rxData = "00110011") OR (rxData = "00110100") OR (rxData = "00110101") OR (rxData = "00110110") OR (rxData = "00110111") OR (rxData = "00111000") OR (rxData = "00111001")) THEN -- 0

numWords_bcd(0) <= rxData(3 downto 0);

nextState <= INIT;

ELSIF (rxData = "01000001") or (rxData = "01100001") THEN

nextState <= valid_A;

ELSE

nextState <= INIT;

END IF;

-- Question 15: Added an "others" statement to case selection

-- Given such, when an invalid encoding is given, the program jumps its state to INIT

WHEN OTHERS => 

nextState <= INIT;

END CASE;

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

run_ANNN: PROCESS(curState) -- Used for linking data processing

BEGIN

END PROCESS;

-----------------------------------------------------

run_LP: PROCESS (curState, processed, seqDone) -- Use this to process/list data

BEGIN

y <= '0'; -- assign default value

-- rxData is P or p, and processed

IF (processed = '1') and ((rxData = "01010000") or (rxData = "01110000")) THEN
  --  seqDone = '1';
    --rising clock edge 1
  --  dataResults(0 7 downto 4)(0 3 downto 0);
    --rising clock edge 2
  --  dataResults(1 7 downto 4)(2 3 downto 0);
    --rising clock edge 3
  --  dataResults(3 7 downto 4)(3 3 downto 0);
    --rising clock edge 4
  --  dataResults(4 7 downto 4)(4 3 downto 0);
    --rising clock edge 5
  --  dataResults(5 7 downto 4)(5 3 downto 0);
    --rising clock edge 6
  --  dataResults(6 7 downto 4)(6 3 downto 0);
    --rising clock edge 7
  --  dataResults(7 7 downto 4)(7 3 downto 0);
    --rising clock edge 8
 --   dataResults(8 7 downto 4)(8 3 downto 0);


-- rxData is L or l, and processed

ELSIF (processed = '1') and ((rxData = "01001100") or (rxData = "01101100")) THEN
  --  seqDone = '1';
  --  maxIndex(0 downto 3);


END IF;

END PROCESS; -- combi_output

end cmdProc_behav



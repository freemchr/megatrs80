----------------------------------------------------------------------------------
-- TRS-80 for MEGA65 (taken from the X68000 port, MegaX68000)
--
-- Check-only declarations of the Xilinx UNISIM primitives used by the design,
-- so that the complete MEGA65 design can be analyzed and elaborated with GHDL
-- (CORE/sim/check_design.sh). The primitives are left unbound (black boxes).
-- Compile into library "unisim".
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package vcomponents is

   component BUFG is
      port (O : out std_ulogic; I : in std_ulogic);
   end component;

   component OBUFDS is
      generic (CAPACITANCE : string := "DONT_CARE"; IOSTANDARD : string := "DEFAULT"; SLEW : string := "SLOW");
      port (O : out std_ulogic; OB : out std_ulogic; I : in std_ulogic);
   end component;

   component IOBUF is
      generic (DRIVE : integer := 12; IOSTANDARD : string := "DEFAULT"; SLEW : string := "SLOW");
      port (O : out std_ulogic; IO : inout std_ulogic; I : in std_ulogic; T : in std_ulogic);
   end component;

   component ODDR is
      generic (DDR_CLK_EDGE : string := "OPPOSITE_EDGE"; INIT : bit := '0'; SRTYPE : string := "SYNC");
      port (Q : out std_ulogic; C : in std_ulogic; CE : in std_ulogic; D1 : in std_ulogic; D2 : in std_ulogic;
            R : in std_ulogic := 'L'; S : in std_ulogic := 'L');
   end component;

   component IDDR is
      generic (DDR_CLK_EDGE : string := "OPPOSITE_EDGE"; INIT_Q1 : bit := '0'; INIT_Q2 : bit := '0'; SRTYPE : string := "SYNC");
      port (Q1 : out std_ulogic; Q2 : out std_ulogic; C : in std_ulogic; CE : in std_ulogic; D : in std_ulogic;
            R : in std_ulogic := 'L'; S : in std_ulogic := 'L');
   end component;

   component IDELAYCTRL is
      generic (SIM_DEVICE : string := "7SERIES");
      port (RDY : out std_ulogic; REFCLK : in std_ulogic; RST : in std_ulogic);
   end component;

   component IDELAYE2 is
      generic (CINVCTRL_SEL : string := "FALSE"; DELAY_SRC : string := "IDATAIN";
               HIGH_PERFORMANCE_MODE : string := "FALSE"; IDELAY_TYPE : string := "FIXED";
               IDELAY_VALUE : integer := 0; PIPE_SEL : string := "FALSE";
               REFCLK_FREQUENCY : real := 200.0; SIGNAL_PATTERN : string := "DATA");
      port (CNTVALUEOUT : out std_logic_vector(4 downto 0); DATAOUT : out std_ulogic;
            C : in std_ulogic; CE : in std_ulogic; CINVCTRL : in std_ulogic;
            CNTVALUEIN : in std_logic_vector(4 downto 0); DATAIN : in std_ulogic; IDATAIN : in std_ulogic;
            INC : in std_ulogic; LD : in std_ulogic; LDPIPEEN : in std_ulogic; REGRST : in std_ulogic);
   end component;

   component OSERDESE2 is
      generic (DATA_RATE_OQ : string := "DDR"; DATA_RATE_TQ : string := "DDR"; DATA_WIDTH : integer := 4;
               INIT_OQ : bit := '0'; INIT_TQ : bit := '0'; SERDES_MODE : string := "MASTER";
               SRVAL_OQ : bit := '0'; SRVAL_TQ : bit := '0'; TBYTE_CTL : string := "FALSE";
               TBYTE_SRC : string := "FALSE"; TRISTATE_WIDTH : integer := 4);
      port (OFB : out std_ulogic; OQ : out std_ulogic; SHIFTOUT1 : out std_ulogic; SHIFTOUT2 : out std_ulogic;
            TBYTEOUT : out std_ulogic; TFB : out std_ulogic; TQ : out std_ulogic;
            CLK : in std_ulogic; CLKDIV : in std_ulogic;
            D1 : in std_ulogic; D2 : in std_ulogic; D3 : in std_ulogic; D4 : in std_ulogic;
            D5 : in std_ulogic; D6 : in std_ulogic; D7 : in std_ulogic; D8 : in std_ulogic;
            OCE : in std_ulogic; RST : in std_ulogic; SHIFTIN1 : in std_ulogic; SHIFTIN2 : in std_ulogic;
            T1 : in std_ulogic; T2 : in std_ulogic; T3 : in std_ulogic; T4 : in std_ulogic;
            TBYTEIN : in std_ulogic; TCE : in std_ulogic);
   end component;

   component PLLE2_BASE is
      generic (BANDWIDTH : string := "OPTIMIZED"; CLKFBOUT_MULT : integer := 5; CLKFBOUT_PHASE : real := 0.0;
               CLKIN1_PERIOD : real := 0.0;
               CLKOUT0_DIVIDE : integer := 1; CLKOUT0_DUTY_CYCLE : real := 0.5; CLKOUT0_PHASE : real := 0.0;
               CLKOUT1_DIVIDE : integer := 1; CLKOUT1_DUTY_CYCLE : real := 0.5; CLKOUT1_PHASE : real := 0.0;
               CLKOUT2_DIVIDE : integer := 1; CLKOUT2_DUTY_CYCLE : real := 0.5; CLKOUT2_PHASE : real := 0.0;
               CLKOUT3_DIVIDE : integer := 1; CLKOUT3_DUTY_CYCLE : real := 0.5; CLKOUT3_PHASE : real := 0.0;
               CLKOUT4_DIVIDE : integer := 1; CLKOUT4_DUTY_CYCLE : real := 0.5; CLKOUT4_PHASE : real := 0.0;
               CLKOUT5_DIVIDE : integer := 1; CLKOUT5_DUTY_CYCLE : real := 0.5; CLKOUT5_PHASE : real := 0.0;
               DIVCLK_DIVIDE : integer := 1; REF_JITTER1 : real := 0.010; STARTUP_WAIT : string := "FALSE");
      port (CLKFBOUT : out std_ulogic; CLKOUT0 : out std_ulogic; CLKOUT1 : out std_ulogic; CLKOUT2 : out std_ulogic;
            CLKOUT3 : out std_ulogic; CLKOUT4 : out std_ulogic; CLKOUT5 : out std_ulogic; LOCKED : out std_ulogic;
            CLKFBIN : in std_ulogic; CLKIN1 : in std_ulogic; PWRDWN : in std_ulogic; RST : in std_ulogic);
   end component;

   component MMCME2_BASE is
      generic (BANDWIDTH : string := "OPTIMIZED"; CLKFBOUT_MULT_F : real := 5.0; CLKFBOUT_PHASE : real := 0.0;
               CLKIN1_PERIOD : real := 0.0;
               CLKOUT0_DIVIDE_F : real := 1.0; CLKOUT0_DUTY_CYCLE : real := 0.5; CLKOUT0_PHASE : real := 0.0;
               CLKOUT1_DIVIDE : integer := 1; CLKOUT1_DUTY_CYCLE : real := 0.5; CLKOUT1_PHASE : real := 0.0;
               CLKOUT2_DIVIDE : integer := 1; CLKOUT2_DUTY_CYCLE : real := 0.5; CLKOUT2_PHASE : real := 0.0;
               CLKOUT3_DIVIDE : integer := 1; CLKOUT3_DUTY_CYCLE : real := 0.5; CLKOUT3_PHASE : real := 0.0;
               CLKOUT4_CASCADE : boolean := FALSE;
               CLKOUT4_DIVIDE : integer := 1; CLKOUT4_DUTY_CYCLE : real := 0.5; CLKOUT4_PHASE : real := 0.0;
               CLKOUT5_DIVIDE : integer := 1; CLKOUT5_DUTY_CYCLE : real := 0.5; CLKOUT5_PHASE : real := 0.0;
               CLKOUT6_DIVIDE : integer := 1; CLKOUT6_DUTY_CYCLE : real := 0.5; CLKOUT6_PHASE : real := 0.0;
               DIVCLK_DIVIDE : integer := 1; REF_JITTER1 : real := 0.0; STARTUP_WAIT : boolean := FALSE);
      port (CLKFBOUT : out std_ulogic; CLKFBOUTB : out std_ulogic;
            CLKOUT0 : out std_ulogic; CLKOUT0B : out std_ulogic; CLKOUT1 : out std_ulogic; CLKOUT1B : out std_ulogic;
            CLKOUT2 : out std_ulogic; CLKOUT2B : out std_ulogic; CLKOUT3 : out std_ulogic; CLKOUT3B : out std_ulogic;
            CLKOUT4 : out std_ulogic; CLKOUT5 : out std_ulogic; CLKOUT6 : out std_ulogic; LOCKED : out std_ulogic;
            CLKFBIN : in std_ulogic; CLKIN1 : in std_ulogic; PWRDWN : in std_ulogic; RST : in std_ulogic);
   end component;

   component MMCME2_ADV is
      generic (BANDWIDTH : string := "OPTIMIZED"; CLKFBOUT_MULT_F : real := 5.0; CLKFBOUT_PHASE : real := 0.0;
               CLKFBOUT_USE_FINE_PS : boolean := FALSE;
               CLKIN1_PERIOD : real := 0.0; CLKIN2_PERIOD : real := 0.0;
               CLKOUT0_DIVIDE_F : real := 1.0; CLKOUT0_DUTY_CYCLE : real := 0.5; CLKOUT0_PHASE : real := 0.0;
               CLKOUT0_USE_FINE_PS : boolean := FALSE;
               CLKOUT1_DIVIDE : integer := 1; CLKOUT1_DUTY_CYCLE : real := 0.5; CLKOUT1_PHASE : real := 0.0;
               CLKOUT1_USE_FINE_PS : boolean := FALSE;
               CLKOUT2_DIVIDE : integer := 1; CLKOUT2_DUTY_CYCLE : real := 0.5; CLKOUT2_PHASE : real := 0.0;
               CLKOUT2_USE_FINE_PS : boolean := FALSE;
               CLKOUT3_DIVIDE : integer := 1; CLKOUT3_DUTY_CYCLE : real := 0.5; CLKOUT3_PHASE : real := 0.0;
               CLKOUT3_USE_FINE_PS : boolean := FALSE;
               CLKOUT4_CASCADE : boolean := FALSE;
               CLKOUT4_DIVIDE : integer := 1; CLKOUT4_DUTY_CYCLE : real := 0.5; CLKOUT4_PHASE : real := 0.0;
               CLKOUT4_USE_FINE_PS : boolean := FALSE;
               CLKOUT5_DIVIDE : integer := 1; CLKOUT5_DUTY_CYCLE : real := 0.5; CLKOUT5_PHASE : real := 0.0;
               CLKOUT5_USE_FINE_PS : boolean := FALSE;
               CLKOUT6_DIVIDE : integer := 1; CLKOUT6_DUTY_CYCLE : real := 0.5; CLKOUT6_PHASE : real := 0.0;
               CLKOUT6_USE_FINE_PS : boolean := FALSE;
               COMPENSATION : string := "ZHOLD"; DIVCLK_DIVIDE : integer := 1;
               IS_CLKINSEL_INVERTED : bit := '0'; IS_PSEN_INVERTED : bit := '0'; IS_PSINCDEC_INVERTED : bit := '0';
               IS_PWRDWN_INVERTED : bit := '0'; IS_RST_INVERTED : bit := '0';
               REF_JITTER1 : real := 0.0; REF_JITTER2 : real := 0.0;
               SS_EN : string := "FALSE"; SS_MODE : string := "CENTER_HIGH"; SS_MOD_PERIOD : integer := 10000;
               STARTUP_WAIT : boolean := FALSE);
      port (CLKFBOUT : out std_ulogic; CLKFBOUTB : out std_ulogic; CLKFBSTOPPED : out std_ulogic;
            CLKINSTOPPED : out std_ulogic;
            CLKOUT0 : out std_ulogic; CLKOUT0B : out std_ulogic; CLKOUT1 : out std_ulogic; CLKOUT1B : out std_ulogic;
            CLKOUT2 : out std_ulogic; CLKOUT2B : out std_ulogic; CLKOUT3 : out std_ulogic; CLKOUT3B : out std_ulogic;
            CLKOUT4 : out std_ulogic; CLKOUT5 : out std_ulogic; CLKOUT6 : out std_ulogic;
            DO : out std_logic_vector(15 downto 0); DRDY : out std_ulogic; LOCKED : out std_ulogic;
            PSDONE : out std_ulogic;
            CLKFBIN : in std_ulogic; CLKIN1 : in std_ulogic; CLKIN2 : in std_ulogic; CLKINSEL : in std_ulogic;
            DADDR : in std_logic_vector(6 downto 0); DCLK : in std_ulogic; DEN : in std_ulogic;
            DI : in std_logic_vector(15 downto 0); DWE : in std_ulogic;
            PSCLK : in std_ulogic; PSEN : in std_ulogic; PSINCDEC : in std_ulogic; PWRDWN : in std_ulogic;
            RST : in std_ulogic);
   end component;

end package vcomponents;

---------------------------------------------------------------------------------------------------------
-- TRS-80 for MEGA65
--
-- MEGA65 keyboard to TRS-80 keyboard matrix
--
-- Runs in the clock domain of the core.
--
-- MiSTer2MEGA65 provides a very simple and generic interface to the MEGA65 keyboard:
-- kb_key_num_i is running through the key numbers 0 to 79 with a frequency of 1 kHz, i.e. the whole
-- keyboard is scanned 1000 times per second. kb_key_pressed_n_i is already debounced and signals
-- low active, if a certain key is being pressed right now.
--
-- The TRS-80 Model I keyboard is an 8 x 8 matrix at $3800 (address line A0 .. A7 = row,
-- data bit = column, high active):
--
--    row 0: @ A B C D E F G           row 4: 0 1 2 3 4 5 6 7
--    row 1: H I J K L M N O           row 5: 8 9 : ; , - . /
--    row 2: P Q R S T U V W           row 6: ENTER CLEAR BREAK UP DOWN LEFT RIGHT SPACE
--    row 3: X Y Z                     row 7: SHIFT
--
-- The shifted digits and the ", < . > / ?" keys of the MEGA65 are the same as on the TRS-80, so
-- the keys are mapped by their labels:
--
--    MEGA65                   TRS-80
--    @ : ; , - . /            @ : ; , - . /
--    * + =                    Shift + :  Shift + ;  Shift + -   (shift is forced)
--    Return                   ENTER
--    Clr/Home, Tab            CLEAR
--    Run/Stop, Esc            BREAK
--    Cursor keys              arrow keys
--    Inst/Del, left arrow     LEFT (backspace)
--    up arrow (symbol key)    UP
--    Ctrl                     Shift + DOWN (like the MiSTer core)
--
-- The matrix is transferred to the TRS-80 core row by row over the ps2_key port of the core (see
-- CORE/vhdl/trs80/keyboard_matrix.vhd): matrix_o(10 downto 8) = row, matrix_o(7 downto 0) = keys.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
-- TRS-80 port 2026, licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m65_keyboard is
   port (
      clk_main_i           : in  std_logic;               -- core clock

      -- Interface to the MEGA65 keyboard
      key_num_i            : in  integer range 0 to 79;   -- cycles through all MEGA65 keys
      key_pressed_n_i      : in  std_logic;               -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- TRS-80 keyboard matrix, one row per clock cycle
      matrix_o             : out std_logic_vector(10 downto 0)
   );
end entity m65_keyboard;

architecture synthesis of m65_keyboard is

-- MEGA65 key codes that kb_key_num_i is using while
-- kb_key_pressed_n_i is signalling (low active) which key is pressed
constant m65_ins_del       : integer := 0;
constant m65_return        : integer := 1;
constant m65_horz_crsr     : integer := 2;   -- means cursor right in C64 terminology
constant m65_f7            : integer := 3;
constant m65_f1            : integer := 4;
constant m65_f3            : integer := 5;
constant m65_f5            : integer := 6;
constant m65_vert_crsr     : integer := 7;   -- means cursor down in C64 terminology
constant m65_3             : integer := 8;
constant m65_w             : integer := 9;
constant m65_a             : integer := 10;
constant m65_4             : integer := 11;
constant m65_z             : integer := 12;
constant m65_s             : integer := 13;
constant m65_e             : integer := 14;
constant m65_left_shift    : integer := 15;
constant m65_5             : integer := 16;
constant m65_r             : integer := 17;
constant m65_d             : integer := 18;
constant m65_6             : integer := 19;
constant m65_c             : integer := 20;
constant m65_f             : integer := 21;
constant m65_t             : integer := 22;
constant m65_x             : integer := 23;
constant m65_7             : integer := 24;
constant m65_y             : integer := 25;
constant m65_g             : integer := 26;
constant m65_8             : integer := 27;
constant m65_b             : integer := 28;
constant m65_h             : integer := 29;
constant m65_u             : integer := 30;
constant m65_v             : integer := 31;
constant m65_9             : integer := 32;
constant m65_i             : integer := 33;
constant m65_j             : integer := 34;
constant m65_0             : integer := 35;
constant m65_m             : integer := 36;
constant m65_k             : integer := 37;
constant m65_o             : integer := 38;
constant m65_n             : integer := 39;
constant m65_plus          : integer := 40;
constant m65_p             : integer := 41; 
constant m65_l             : integer := 42;
constant m65_minus         : integer := 43;
constant m65_dot           : integer := 44;
constant m65_colon         : integer := 45;
constant m65_at            : integer := 46;
constant m65_comma         : integer := 47;
constant m65_gbp           : integer := 48;
constant m65_asterisk      : integer := 49;
constant m65_semicolon     : integer := 50;
constant m65_clr_home      : integer := 51;
constant m65_right_shift   : integer := 52;
constant m65_equal         : integer := 53;
constant m65_arrow_up      : integer := 54;  -- symbol, not cursor
constant m65_slash         : integer := 55;
constant m65_1             : integer := 56;
constant m65_arrow_left    : integer := 57;  -- symbol, not cursor
constant m65_ctrl          : integer := 58;
constant m65_2             : integer := 59;
constant m65_space         : integer := 60;
constant m65_mega          : integer := 61;
constant m65_q             : integer := 62;
constant m65_run_stop      : integer := 63;
constant m65_no_scrl       : integer := 64;
constant m65_tab           : integer := 65;
constant m65_alt           : integer := 66;
constant m65_help          : integer := 67;
constant m65_f9            : integer := 68;
constant m65_f11           : integer := 69;
constant m65_f13           : integer := 70;
constant m65_esc           : integer := 71;
constant m65_capslock      : integer := 72;
constant m65_up_crsr       : integer := 73;  -- cursor up
constant m65_left_crsr     : integer := 74;  -- cursor left
constant m65_restore       : integer := 75;

signal key_pressed_n : std_logic_vector(79 downto 0) := (others => '1');

type rows_t is array (0 to 7) of std_logic_vector(7 downto 0);
signal rows          : rows_t;
signal row           : unsigned(2 downto 0) := (others => '0');

begin

   keyboard_state : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         key_pressed_n(key_num_i) <= key_pressed_n_i;
      end if;
   end process keyboard_state;

   matrix : process (all)
      -- high active: is the MEGA65 key pressed?
      impure function k(n : integer) return std_logic is
      begin
         return not key_pressed_n(n);
      end function k;
      variable force_shift : std_logic;
   begin
      force_shift := k(m65_asterisk) or k(m65_plus) or k(m65_equal) or k(m65_ctrl);

      rows(0) <= k(m65_g) & k(m65_f) & k(m65_e) & k(m65_d) & k(m65_c) & k(m65_b) & k(m65_a) & k(m65_at);
      rows(1) <= k(m65_o) & k(m65_n) & k(m65_m) & k(m65_l) & k(m65_k) & k(m65_j) & k(m65_i) & k(m65_h);
      rows(2) <= k(m65_w) & k(m65_v) & k(m65_u) & k(m65_t) & k(m65_s) & k(m65_r) & k(m65_q) & k(m65_p);
      rows(3) <= "00000" & k(m65_z) & k(m65_y) & k(m65_x);
      rows(4) <= k(m65_7) & k(m65_6) & k(m65_5) & k(m65_4) & k(m65_3) & k(m65_2) & k(m65_1) & k(m65_0);
      rows(5) <= k(m65_slash) &                                   -- /
                 k(m65_dot) &                                     -- .
                 (k(m65_minus) or k(m65_equal)) &                 -- - (Shift: =)
                 k(m65_comma) &                                   -- ,
                 (k(m65_semicolon) or k(m65_plus)) &              -- ; (Shift: +)
                 (k(m65_colon) or k(m65_asterisk)) &              -- : (Shift: *)
                 k(m65_9) & k(m65_8);
      rows(6) <= k(m65_space) &                                   -- SPACE
                 k(m65_horz_crsr) &                               -- RIGHT
                 (k(m65_left_crsr) or k(m65_ins_del) or k(m65_arrow_left)) & -- LEFT
                 (k(m65_vert_crsr) or k(m65_ctrl)) &              -- DOWN
                 (k(m65_up_crsr) or k(m65_arrow_up)) &            -- UP
                 (k(m65_run_stop) or k(m65_esc)) &                -- BREAK
                 (k(m65_clr_home) or k(m65_tab)) &                -- CLEAR
                 k(m65_return);                                   -- ENTER
      rows(7) <= "0000000" & (k(m65_left_shift) or k(m65_right_shift) or force_shift);
   end process matrix;

   transfer : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         row      <= row + 1;
         matrix_o <= std_logic_vector(row) & rows(to_integer(row));
      end if;
   end process transfer;

end architecture synthesis;

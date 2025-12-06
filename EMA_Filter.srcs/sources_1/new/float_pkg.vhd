library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package float_pkg is
  type float32 is record
    sign     : std_logic;
    exponent : std_logic_vector(7 downto 0);
    mantissa : std_logic_vector(22 downto 0);
  end record float32;
end package;

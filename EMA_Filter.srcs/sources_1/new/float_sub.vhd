library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.float_pkg.all;

entity float_sub is
  Port (
    a, b  : in float32;
    res   : out float32
  );
end float_sub;

architecture Behavioral of float_sub is

begin

process(a, b)
  begin
    res.sign     <= a.sign; -- assume both same sign for simplicity
    res.exponent <= a.exponent; -- assume same exponent
    res.mantissa <= std_logic_vector(unsigned(a.mantissa) - unsigned(b.mantissa));
end process;

end Behavioral;

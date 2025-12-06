library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.float_pkg.all;

entity float_mul is
  Port (
    a, b  : in float32;
    res   : out float32
  );
end float_mul;

architecture Behavioral of float_mul is

begin

process(a, b)

variable mult_result : unsigned(45 downto 0);

  begin
    res.sign     <= a.sign xor b.sign;
    res.exponent <= std_logic_vector(unsigned(a.exponent) + unsigned(b.exponent) - 127);
    mult_result := unsigned(a.mantissa) * unsigned(b.mantissa);
    res.mantissa <= std_logic_vector(mult_result(45 downto 23));
end process;

end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.float_pkg.all;

entity tb_EMA is
end;

architecture sim of tb_EMA is
  signal clk, rst : std_logic := '0';
  signal x_t, alpha, EMA_curr : float32;
begin
  uut: entity work.ema_filter
    port map(clk => clk, rst => rst, x_t => x_t, alpha => alpha, EMA_curr => EMA_curr);

  clk <= not clk after 10 ns;

  process
  begin
    rst <= '1'; wait for 20 ns;
    rst <= '0';
    
    alpha <= (sign=>'0', exponent=>"01111110", mantissa=>(others=>'0')); -- ~0.5
    x_t  <= (sign=>'0', exponent=>"01111111", mantissa=>(others=>'0')); -- ~1.0
    wait for 40 ns;

    x_t  <= (sign=>'0', exponent=>"10000000", mantissa=>(others=>'0')); -- ~2.0
    wait for 40 ns;

    x_t  <= (sign=>'0', exponent=>"10000001", mantissa=>(others=>'0')); -- ~4.0
    wait for 40 ns;

    wait;
  end process;

end architecture;

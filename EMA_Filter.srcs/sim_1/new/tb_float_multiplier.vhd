library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_float_multiplier is
end tb_float_multiplier;

architecture Behavioral of tb_float_multiplier is

    component float_multiplier is
        Port (
            aclk                    : in  std_logic;
            aresetn                 : in  std_logic;
            s_axis_a_tvalid         : in  std_logic;
            s_axis_a_tready         : out std_logic;
            s_axis_a_tdata          : in  std_logic_vector(31 downto 0);
            s_axis_b_tvalid         : in  std_logic;
            s_axis_b_tready         : out std_logic;
            s_axis_b_tdata          : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid    : out std_logic;
            m_axis_result_tready    : in  std_logic;
            m_axis_result_tdata     : out std_logic_vector(31 downto 0)
        );
    end component;

    signal aclk                : std_logic := '0';
    signal aresetn             : std_logic := '0';

    signal s_a_valid, s_b_valid : std_logic := '0';
    signal s_a_ready, s_b_ready : std_logic := '0';
    signal s_a_data, s_b_data   : std_logic_vector(31 downto 0) := (others => '0');

    signal m_valid, m_ready     : std_logic := '0';
    signal m_data               : std_logic_vector(31 downto 0) := (others => '0');

    constant CLK_PERIOD : time := 10 ns;

begin

    DUT: float_multiplier
        port map (
            aclk => aclk,
            aresetn => aresetn,
            s_axis_a_tvalid => s_a_valid,
            s_axis_a_tready => s_a_ready,
            s_axis_a_tdata  => s_a_data,
            s_axis_b_tvalid => s_b_valid,
            s_axis_b_tready => s_b_ready,
            s_axis_b_tdata  => s_b_data,
            m_axis_result_tvalid => m_valid,
            m_axis_result_tready => m_ready,
            m_axis_result_tdata  => m_data
        );

    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD / 2;
        aclk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_proc : process
    begin
        aresetn <= '0';
        wait for 20 ns;
        aresetn <= '1';
        wait for 10 ns;

        -- Example 1: 29.9 * 1.0 = 29.9 (0x41ef3333)
        -- a = 0x41ef3333
        -- b = 0x3f800000
        s_a_data <= x"41ef3333";
        s_b_data <= x"3f800000";
        s_a_valid <= '1';
        s_b_valid <= '1';
        m_ready <= '1';
        wait for 40 ns;

        -- Example 2: 0.5 * 2.0 = 1.0 (0x3f800000)
        -- a = 0x3f000000  (0.5)
        -- b = 0x40000000  (2.0)
        s_a_data <= x"3f000000";
        s_b_data <= x"40000000";
        s_a_valid <= '1';
        s_b_valid <= '1';
        wait for 40 ns;

        -- Example 3: 10.0 * 10.0 = 100.0 (0x42c80000)
        -- a = 0x41200000
        -- b = 0x41200000
        s_a_data <= x"41200000";
        s_b_data <= x"41200000";
        s_a_valid <= '1';
        s_b_valid <= '1';
        wait for 40 ns;

        -- Example 4: -1.0 * 3.0 = -3.0 (0xc0400000)
        -- a = 0xbf800000
        -- b = 0x40400000
        s_a_data <= x"bf800000";
        s_b_data <= x"40400000";
        s_a_valid <= '1';
        s_b_valid <= '1';
        wait for 40 ns;

        s_a_valid <= '0';
        s_b_valid <= '0';

        wait for 100 ns;
        wait;
    end process;

end Behavioral;

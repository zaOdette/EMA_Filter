library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_float_subtractor is
end tb_float_subtractor;

architecture Behavioral of tb_float_subtractor is

    component float_subtractor is
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

    DUT: float_subtractor
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

        -- Example 1: 1.5 - 2.5 = -1.0 (0xbf800000)
        s_a_data <= x"3fc00000";  -- 1.5
        s_b_data <= x"40200000";  -- 2.5
        s_a_valid <= '1';
        s_b_valid <= '1';
        m_ready <= '1';
        wait for 40 ns;
        
        -- Example 2: 2.0 - 1.0 = 1.0 (0x3f800000)
--        s_a_data <= x"40000000";  -- 2.0
--        s_b_data <= x"3f800000";  -- 1.0
--        s_a_valid <= '1';
--        s_b_valid <= '1';
--        m_ready <= '1';
--        wait for 40 ns;
        
        -- Example 3: 1.37 - 1.32 = 0.05 (0x3d4ccccd)
--        s_a_data <= x"3faf5c29";  -- 1.37
--        s_b_data <= x"3fa8f5c3";  -- 1.32
--        s_a_valid <= '1';
--        s_b_valid <= '1';
--        m_ready <= '1';
--        wait for 40 ns;

        s_a_valid <= '0';
        s_b_valid <= '0';
        wait for 100 ns;

        wait;
    end process;

end Behavioral;

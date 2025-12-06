library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ema_filter is
end tb_ema_filter;

architecture Behavioral of tb_ema_filter is

    component ema_filter is
        Port (
            aclk          : in std_logic;
            aresetn       : in std_logic;
            alpha_val     : in std_logic_vector(31 downto 0);
            s_axis_tvalid : in std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in std_logic_vector(31 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';
    
    signal alpha   : std_logic_vector(31 downto 0) := (others => '0');
    
    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_data  : std_logic_vector(31 downto 0) := (others => '0');
    
    signal m_valid : std_logic;
    signal m_ready : std_logic := '1'; -- Always ready to read output
    signal m_data  : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    DUT: ema_filter
        port map (
            aclk => aclk,
            aresetn => aresetn,
            alpha_val => alpha,
            s_axis_tvalid => s_valid,
            s_axis_tready => s_ready,
            s_axis_tdata => s_data,
            m_axis_tvalid => m_valid,
            m_axis_tready => m_ready,
            m_axis_tdata => m_data
        );

    clk_process : process
    begin
        aclk <= '0'; wait for CLK_PERIOD/2;
        aclk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stim_proc : process
    begin
        aresetn <= '0';
        alpha <= x"3f000000"; -- Set alpha = 0.5
        wait for 100 ns;
        aresetn <= '1';
        
        wait for 100 ns; 

        -- Send 1st sample: 10.0 (0x41200000)
        -- a * 10.0 + (1 - a) * 0.0 = 5.0 (0x40a00000)
        s_valid <= '1';
        s_data <= x"41200000";
        
        -- Wait for handshake
        wait until rising_edge(aclk) and s_ready = '1';
        s_valid <= '0'; -- Data sent
        
        -- Wait for processing to finish
        wait for 500 ns;

        -- Send 2nd sample: 10.0 (x41200000)
        -- a * 10.00 + (1 - a) * 5.0 = 5.0 + 2.5 = 7.5 (0x40f00000)
        s_valid <= '1';
        s_data <= x"41200000";
        
        -- Wait for handshake
        wait until rising_edge(aclk) and s_ready = '1';
        s_valid <= '0';
        
        -- Wait for processing to finish
        wait for 500 ns;

        -- Send 3rd sample: 10.0 (x41200000)
        -- a * 10.00 + (1 - a) * 7.5 = 5.0 + 3.75 = 8.75 (0x410c0000)
        s_valid <= '1';
        s_data <= x"41200000";
        
        -- Wait for handshake
        wait until rising_edge(aclk) and s_ready = '1';
        s_valid <= '0';

        wait;
    end process;

end Behavioral;
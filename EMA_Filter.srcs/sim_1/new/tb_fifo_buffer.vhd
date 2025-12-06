library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_fifo_buffer is
end tb_fifo_buffer;

architecture Behavioral of tb_fifo_buffer is

    component fifo_buffer is
        Port (
            aclk          : in std_logic;
            aresetn       : in std_logic;
            s_axis_tvalid : in std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in std_logic_vector(31 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';
    
    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_data  : std_logic_vector(31 downto 0) := (others => '0');
    
    signal m_valid : std_logic;
    signal m_ready : std_logic := '0';
    signal m_data  : std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    DUT: fifo_buffer
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => s_valid,
            s_axis_tready => s_ready,
            s_axis_tdata  => s_data,
            m_axis_tvalid => m_valid,
            m_axis_tready => m_ready,
            m_axis_tdata  => m_data
        );

    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc : process
    begin
        aresetn <= '0';
        wait for 50 ns;
        aresetn <= '1';
        wait for 10 ns;

        -- Setup 1st value
        s_valid <= '1';
        s_data  <= x"11111111";
        
        -- Wait for handshake
        wait until rising_edge(aclk) and s_ready = '1';
        
        -- Change to 2nd value immediately after handshake
        s_data  <= x"22222222";
        
        -- Wait for handshake
        wait until rising_edge(aclk) and s_ready = '1';

        -- Change to 3rd value immediately after handshake
        s_data  <= x"33333333";
        
        -- Wait for handshake
        wait until rising_edge(aclk) and s_ready = '1';

        -- Stop writing
        s_valid <= '0';

        -- Read data
        m_ready <= '1';
        
        wait for 100 ns;
        wait;
    end process;

end Behavioral;
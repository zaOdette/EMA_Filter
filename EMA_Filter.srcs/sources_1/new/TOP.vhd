library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TOP is
    Port (
        clk         : in  std_logic;
        reset_btn   : in  std_logic;
        uart_rx_pin : in  std_logic;
        sw          : in  std_logic_vector(15 downto 0);
        cat         : out std_logic_vector(6 downto 0);
        an          : out std_logic_vector(3 downto 0)
    );
end TOP;

architecture Behavioral of TOP is

    component axi_UART is
        Port (
            aclk          : in  std_logic;
            aresetn       : in  std_logic;
            rx_serial_pin : in  std_logic;
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;

    component ema_filter is
        Port (
            aclk          : in  std_logic;
            aresetn       : in  std_logic;
            alpha_val     : in  std_logic_vector(31 downto 0);
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;
    
    component SSD is
    Port (
        aclk          : in  std_logic;
        aresetn       : in  std_logic;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(31 downto 0);
        display_sel   : in  std_logic;
        cat           : out std_logic_vector(6 downto 0);
        an            : out std_logic_vector(3 downto 0)
    );
    end component;

    signal aresetn : std_logic;
    
    signal alpha_config : std_logic_vector(31 downto 0);
    
    -- UART -> Filter
    signal uart_valid : std_logic;
    signal uart_ready : std_logic;
    signal uart_data  : std_logic_vector(31 downto 0);
    
    -- Filter -> Display
    signal result_valid : std_logic;
    signal result_ready : std_logic;
    signal result_data  : std_logic_vector(31 downto 0);
    
    signal slow_clk : std_logic := '0';
    signal clk_divider : std_logic := '0';

begin

    -- CLOCK DIVIDER (100 MHz -> 50 MHz)
    process(clk)
    begin
        if rising_edge(clk) then
            clk_divider <= not clk_divider;
        end if;
    end process;
    
    slow_clk <= clk_divider;

    aresetn <= not reset_btn; -- active LOW for AXI logic
    
    process(sw)
    begin
        if sw(0) = '1' then
            alpha_config <= x"3f000000"; -- alpha = 0.5
        elsif sw(1) = '1' then
            alpha_config <= x"3e800000"; -- alpha = 0.25
        elsif sw(2) = '1' then
            alpha_config <= x"3e000000"; -- alpha = 0.125
        else
            alpha_config <= x"3d800000"; -- alpha = 0.0625
        end if;
    end process;

    RX_MODULE : axi_UART
    port map (
        aclk          => slow_clk,
        aresetn       => aresetn,
        rx_serial_pin => uart_rx_pin,
        m_axis_tvalid => uart_valid,
        m_axis_tready => uart_ready,
        m_axis_tdata  => uart_data
    );

    FILTER_MODULE : ema_filter
    port map (
        aclk          => slow_clk,
        aresetn       => aresetn,
        alpha_val     => alpha_config,
        s_axis_tvalid => uart_valid,
        s_axis_tready => uart_ready,
        s_axis_tdata  => uart_data,
        m_axis_tvalid => result_valid,
        m_axis_tready => result_ready,
        m_axis_tdata  => result_data
    );
    
    SSD_MODULE : SSD
    port map (
        aclk          => slow_clk,
        aresetn       => aresetn,
        s_axis_tvalid => result_valid,
        s_axis_tready => result_ready,
        s_axis_tdata  => result_data,
        display_sel   => sw(15),
        cat           => cat,
        an            => an
    );

end Behavioral;
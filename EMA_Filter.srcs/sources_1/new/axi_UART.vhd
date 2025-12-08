library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_UART is
    Port (
        aclk            : in  std_logic;
        aresetn         : in  std_logic;
        rx_serial_pin   : in  std_logic;
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        m_axis_tdata    : out std_logic_vector(31 downto 0)
    );
end axi_UART;

architecture Behavioral of axi_UART is

    -- UART CONFIGURATION (50MHz / 9600 baud = 5208 ticks)
    constant CLKS_PER_BIT : integer := 5208;

    type rx_state_type is (S_IDLE, S_START_BIT, S_DATA_BITS, S_STOP_BIT, S_PACKET_CHECK);
    signal state : rx_state_type := S_IDLE;

    signal clk_count : integer range 0 to CLKS_PER_BIT := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal rx_byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_done : std_logic := '0';

    -- Packet assembly (4 Bytes -> 1 Float)
    signal byte_counter : integer range 0 to 4 := 0;
    signal assembly_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_out    : std_logic := '0';

begin
    m_axis_tvalid <= valid_out;
    m_axis_tdata  <= assembly_reg;

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= S_IDLE;
                clk_count <= 0;
                bit_index <= 0;
                byte_counter <= 0;
                valid_out <= '0';
                assembly_reg <= (others => '0');
            else
                
                -- UART RECEIVER FSM (Reads 1 Byte at a time)
                case state is
                    -- Wait for START BIT (line goes low)
                    when S_IDLE =>
                        byte_done <= '0';
                        if rx_serial_pin = '0' then
                            clk_count <= 0;
                            state <= S_START_BIT;
                        end if;

                    -- Check middle of START BIT to confirm it's real
                    when S_START_BIT =>
                        if clk_count = (CLKS_PER_BIT / 2) then
                            if rx_serial_pin = '0' then
                                clk_count <= 0;
                                state <= S_DATA_BITS;
                            else
                                state <= S_IDLE; -- False start
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    -- Sample 8 Data Bits
                    when S_DATA_BITS =>
                        if clk_count = CLKS_PER_BIT then
                            clk_count <= 0;
                            rx_byte(bit_index) <= rx_serial_pin; -- Sample LSB first
                            
                            if bit_index = 7 then
                                bit_index <= 0;
                                state <= S_STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    -- Wait for STOP BIT (High)
                    when S_STOP_BIT =>
                        if clk_count = CLKS_PER_BIT then
                            state <= S_PACKET_CHECK;
                            clk_count <= 0;
                        else
                            clk_count <= clk_count + 1;
                        end if;

                    -- PACKET ASSEMBLER (Groups 4 Bytes into 1 Float)
                    when S_PACKET_CHECK =>
                        -- We have a new valid byte in 'rx_byte'
                        
                        -- Shift the new byte into the assembly register (Big Endian Shift)
                        -- Example: [BB] -> [BB 00] -> [BB CC 00] ...
                        assembly_reg <= assembly_reg(23 downto 0) & rx_byte;
                        
                        -- Increment byte counter
                        if byte_counter = 3 then
                            byte_counter <= 0;
                            valid_out <= '1'; -- We have a full 32-bit float now
                        else
                            byte_counter <= byte_counter + 1;
                        end if;
                        
                        state <= S_IDLE;

                end case;

                -- AXI HANDSHAKE RESET
                -- If we asserted Valid, and the Downstream (EMA) asserted Ready,
                -- we drop Valid and wait for the next packet.
                if valid_out = '1' and m_axis_tready = '1' then
                    valid_out <= '0';
                end if;

            end if;
        end if;
    end process;
end Behavioral;
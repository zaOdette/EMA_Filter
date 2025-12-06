library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_buffer is
    generic (
        DEPTH : integer := 16
    );
    Port (
        aclk          : in  std_logic;
        aresetn       : in  std_logic;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(31 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(31 downto 0)
    );
end fifo_buffer;

architecture Behavioral of fifo_buffer is

    type fifo_array is array (0 to DEPTH-1) of std_logic_vector(31 downto 0);
    signal mem : fifo_array := (others => (others => '0'));

    signal wr_ptr : integer range 0 to DEPTH-1 := 0;
    signal rd_ptr : integer range 0 to DEPTH-1 := 0;
    signal count  : integer range 0 to DEPTH := 0;

    signal full_reg  : std_logic := '0';
    signal empty_reg : std_logic := '1';

begin
    -- Ready if not full
    s_axis_tready <= not full_reg;
    -- Valid if not empty
    m_axis_tvalid <= not empty_reg;
    -- Data is always available at the output if not empty
    m_axis_tdata  <= mem(rd_ptr);

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count <= 0;
                full_reg <= '0';
                empty_reg <= '1';
            else
                -- Write logic
                if (s_axis_tvalid = '1' and full_reg = '0') then
                    mem(wr_ptr) <= s_axis_tdata;
                    if wr_ptr = DEPTH-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;

                -- Read logic
                if (m_axis_tready = '1' and empty_reg = '0') then
                    if rd_ptr = DEPTH-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;

                -- Count & Flags logic
                -- Case 1: Write only
                -- If sender has data and the fifo has space
                if (s_axis_tvalid = '1' and full_reg = '0') and not (m_axis_tready = '1' and empty_reg = '0') then
                    count <= count + 1;
                    empty_reg <= '0'; -- Just added, so definitel not empty
                    if count = DEPTH-1 then
                        full_reg <= '1';
                    end if;
                -- Case 2: Read only
                -- If receiver is ready and the fifo is not empty
                elsif not (s_axis_tvalid = '1' and full_reg = '0') and (m_axis_tready = '1' and empty_reg = '0') then
                    count <= count - 1;
                    full_reg <= '0'; -- Just removed, so definitely not full
                    if count = 1 then
                        empty_reg <= '1';
                    end if;
                -- Case 3: Read AND Write same cycle
                -- Count stays the same, full/empty flags stay the same
                elsif (s_axis_tvalid = '1' and full_reg = '0') and (m_axis_tready = '1' and empty_reg = '0') then
                    -- Pointers move (handled above), but count remains constant.
                    null; 
                end if;
                
            end if;
        end if;
    end process;

end Behavioral;
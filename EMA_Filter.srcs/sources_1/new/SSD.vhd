library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SSD is
    Port (
        aclk          : in  std_logic;
        aresetn       : in  std_logic;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(31 downto 0);
        display_sel   : in  std_logic; -- Control switch (upper/lower 16 bits)
        cat           : out std_logic_vector(6 downto 0);  -- Cathodes (a-g)
        an            : out std_logic_vector(3 downto 0)   -- Anodes (digit select)
    );
end SSD;

architecture Behavioral of SSD is

    signal stored_data : std_logic_vector(31 downto 0) := (others => '0'); -- holds the last VALID value received
    signal display_value : std_logic_vector(15 downto 0); -- muxed data (16 bits)
    signal refresh_counter : unsigned(19 downto 0) := (others => '0');
    signal digit_select    : std_logic_vector(1 downto 0); -- anode
    signal hex_digit       : std_logic_vector(3 downto 0); -- cathode

begin

    s_axis_tready <= '1'; -- always ready to accept new data
    
    -- Valid data acceptance
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                stored_data <= (others => '0');
            else
                -- only update internal register if data is VALID
                if s_axis_tvalid = '1' then
                    stored_data <= s_axis_tdata;
                end if;
            end if;
        end if;
    end process;
    
    display_value <= stored_data(31 downto 16) when display_sel = '0' else stored_data(15 downto 0);

    -- Refresh rate
    process(aclk)
    begin
        if rising_edge(aclk) then
            refresh_counter <= refresh_counter + 1;
        end if;
    end process;

    -- Top 2 bits to select which digit is active
    digit_select <= std_logic_vector(refresh_counter(19 downto 18));

    -- Anode activation & Digit selection
    process(digit_select, display_value)
    begin
        case digit_select is
            when "00" =>
                an <= "1110"; -- Rightmost digit
                hex_digit <= display_value(3 downto 0);
            when "01" =>
                an <= "1101"; -- Middle right digit
                hex_digit <= display_value(7 downto 4);
            when "10" =>
                an <= "1011"; -- Middle left digit
                hex_digit <= display_value(11 downto 8);
            when "11" =>
                an <= "0111"; -- Leftmost digit
                hex_digit <= display_value(15 downto 12);
            when others =>
                an <= "1111";
                hex_digit <= "0000";
        end case;
    end process;

    -- Cathode decoder
    process(hex_digit)
    begin
        case hex_digit is
            when "0000" => cat <= "1000000"; -- 0
            when "0001" => cat <= "1111001"; -- 1
            when "0010" => cat <= "0100100"; -- 2
            when "0011" => cat <= "0110000"; -- 3
            when "0100" => cat <= "0011001"; -- 4
            when "0101" => cat <= "0010010"; -- 5
            when "0110" => cat <= "0000010"; -- 6
            when "0111" => cat <= "1111000"; -- 7
            when "1000" => cat <= "0000000"; -- 8
            when "1001" => cat <= "0010000"; -- 9
            when "1010" => cat <= "0001000"; -- A
            when "1011" => cat <= "0000011"; -- b
            when "1100" => cat <= "1000110"; -- C
            when "1101" => cat <= "0100001"; -- d
            when "1110" => cat <= "0000110"; -- E
            when "1111" => cat <= "0001110"; -- F
            when others => cat <= "1111111"; -- Off
        end case;
    end process;

end Behavioral;
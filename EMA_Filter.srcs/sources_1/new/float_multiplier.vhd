library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity float_multiplier is
    Port (
        aclk                 : in  std_logic;
        aresetn              : in  std_logic;
        s_axis_a_tvalid      : in  std_logic;
        s_axis_a_tready      : out std_logic;
        s_axis_a_tdata       : in  std_logic_vector(31 downto 0);
        s_axis_b_tvalid      : in  std_logic;
        s_axis_b_tready      : out std_logic;
        s_axis_b_tdata       : in  std_logic_vector(31 downto 0);
        m_axis_result_tvalid : out std_logic;
        m_axis_result_tready : in  std_logic;
        m_axis_result_tdata  : out std_logic_vector(31 downto 0)
    );
end float_multiplier;

architecture Behavioral of float_multiplier is

    -- FSM states
    type state_type is (S_READ, S_WRITE);
    signal state : state_type := S_READ;
    
    signal inputs_valid : std_logic := '0';
    
    signal result : std_logic_vector(31 downto 0) := (others => '0');
    
begin

    inputs_valid         <= s_axis_a_tvalid and s_axis_b_tvalid;
    s_axis_a_tready      <= '1' when (state = S_READ) else '0';
    s_axis_b_tready      <= '1' when (state = S_READ) else '0';
    m_axis_result_tvalid <= '1' when (state = S_WRITE) else '0';
    m_axis_result_tdata  <= result;

    process(aclk)
        variable sign_a, sign_b, sign_res : std_logic;
        variable exp_a, exp_b             : unsigned(7 downto 0);
        variable exp_sum                  : unsigned(8 downto 0); -- 9 bits to check overflow
        variable exp_res                  : unsigned(7 downto 0);
        variable mant_a, mant_b           : unsigned(22 downto 0);
        variable mant_a_ext, mant_b_ext   : unsigned(23 downto 0);
        variable mant_product             : unsigned(47 downto 0);
        variable mant_norm                : unsigned(22 downto 0);
    begin
    
        if rising_edge(aclk) then
            if aresetn = '0' then
                state  <= S_READ;
                result <= (others => '0');
            else
                case state is
                    when S_READ =>
                        if inputs_valid = '1' then
                            -- Check for zero inputs (otherwise it will overflow)
                            if (unsigned(s_axis_a_tdata(30 downto 0)) = 0) or (unsigned(s_axis_b_tdata(30 downto 0)) = 0) then
                                result <= (others => '0'); -- Result is clean zero
                            else
                                -- Decode IEEE float
                                sign_a := s_axis_a_tdata(31);
                                sign_b := s_axis_b_tdata(31);
                                exp_a  := unsigned(s_axis_a_tdata(30 downto 23));
                                exp_b  := unsigned(s_axis_b_tdata(30 downto 23));
                                mant_a := unsigned(s_axis_a_tdata(22 downto 0));
                                mant_b := unsigned(s_axis_b_tdata(22 downto 0));

                                -- Normalize mantissas (implicit leading 1)
                                mant_a_ext := "1" & mant_a;
                                mant_b_ext := "1" & mant_b;

                                -- Multiply
                                mant_product := mant_a_ext * mant_b_ext;

                                -- Add exponents
                                exp_sum := resize(exp_a, 9) + resize(exp_b, 9);

                                -- Subtract bias with underflow check
                                if exp_sum < 127 then
                                    -- Underflow (number too small) => 0
                                    exp_res := (others => '0');
                                    mant_norm := (others => '0');
                                else
                                    exp_sum := exp_sum - 127;
                                    
                                    -- Normalize
                                    if mant_product(47) = '1' then
                                        mant_norm := unsigned(mant_product(46 downto 24));
                                        exp_sum   := exp_sum + 1;
                                    else
                                        mant_norm := unsigned(mant_product(45 downto 23));
                                    end if;

                                    -- Overflow check
                                    if exp_sum > 254 then 
                                        exp_res := "11111111"; -- Infinity
                                        mant_norm := (others => '0');
                                    else
                                        exp_res := resize(exp_sum, 8);
                                    end if;
                                end if;
                                
                                -- Sign
                                sign_res := sign_a xor sign_b;
                                
                                -- Assemble result
                                result <= sign_res & std_logic_vector(exp_res) & std_logic_vector(mant_norm);
                            end if;
                            
                            -- Move to WRITE state
                            state <= S_WRITE;
                        end if;

                    when S_WRITE =>
                        if m_axis_result_tready = '1' then
                            state <= S_READ;
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
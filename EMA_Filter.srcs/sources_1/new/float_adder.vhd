library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity float_adder is
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
end float_adder;

architecture Behavioral of float_adder is

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
        variable exp_res                  : unsigned(8 downto 0); -- 9 bits to check overflow
        variable mant_a, mant_b           : unsigned(22 downto 0);
        variable mant_a_ext, mant_b_ext   : unsigned(23 downto 0);
        variable aligned_a, aligned_b     : unsigned(23 downto 0);
        variable mant_sum                 : unsigned(24 downto 0);
        variable mant_res                 : std_logic_vector(22 downto 0);
        variable exp_diff                 : integer range 0 to 255;
    begin
    
        if rising_edge(aclk) then
            if aresetn = '0' then
                state  <= S_READ;
                result <= (others => '0');
            else
                case state is
                    when S_READ =>
                        if inputs_valid = '1' then
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

                            -- Align exponents
                            if exp_a > exp_b then
                                exp_diff := to_integer(exp_a - exp_b);
                                if exp_diff < 24 then
                                    aligned_a := mant_a_ext;
                                    aligned_b := shift_right(mant_b_ext, exp_diff);
                                else
                                    aligned_a := mant_a_ext;
                                    aligned_b := (others => '0');
                                end if;
                                exp_res := resize(exp_a, 9);
                            else
                                exp_diff := to_integer(exp_b - exp_a);
                                if exp_diff < 24 then
                                    aligned_a := shift_right(mant_a_ext, exp_diff);
                                    aligned_b := mant_b_ext;
                                else
                                    aligned_a := (others => '0');
                                    aligned_b := mant_b_ext;
                                end if;
                                exp_res := resize(exp_b, 9);
                            end if;

                            -- Add mantissas (same sign only)
                            if sign_a = sign_b then
                                mant_sum := ('0' & aligned_a) + ('0' & aligned_b);
                                sign_res := sign_a;
                            else
                                -- Basic placeholder for different signs
                                mant_sum := (others => '0'); 
                                sign_res := '0';
                            end if;

                            -- Normalize
                            if mant_sum(24) = '1' then
                                -- Overflow: shift right, increment exponent
                                mant_res := std_logic_vector(mant_sum(23 downto 1));
                                exp_res  := exp_res + 1;
                            else
                                mant_res := std_logic_vector(mant_sum(22 downto 0));
                            end if;

                            -- Overflow check
                            if exp_res > 254 then
                                result <= sign_res & "11111110" & "11111111111111111111111"; -- max float (approx. 3.4e38)
                            else
                                result <= sign_res & std_logic_vector(exp_res(7 downto 0)) & mant_res; -- Assemble good result
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ema_filter is
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
end ema_filter;

architecture Behavioral of ema_filter is

    -- FIFO
    component fifo_buffer is
        generic ( DEPTH : integer := 16 );
        Port (
            aclk, aresetn : in std_logic;
            s_axis_tvalid : in std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata : in std_logic_vector(31 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in std_logic;
            m_axis_tdata : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Math components
    component float_adder is
        Port (
            aclk, aresetn : in std_logic;
            s_axis_a_tvalid, s_axis_b_tvalid : in std_logic;
            s_axis_a_tready, s_axis_b_tready : out std_logic;
            s_axis_a_tdata, s_axis_b_tdata   : in std_logic_vector(31 downto 0);
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tready : in std_logic;
            m_axis_result_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;

    component float_multiplier is
        Port (
            aclk, aresetn : in std_logic;
            s_axis_a_tvalid, s_axis_b_tvalid : in std_logic;
            s_axis_a_tready, s_axis_b_tready : out std_logic;
            s_axis_a_tdata, s_axis_b_tdata   : in std_logic_vector(31 downto 0);
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tready : in std_logic;
            m_axis_result_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;

    component float_subtractor is
        Port (
            aclk, aresetn : in std_logic;
            s_axis_a_tvalid, s_axis_b_tvalid : in std_logic;
            s_axis_a_tready, s_axis_b_tready : out std_logic;
            s_axis_a_tdata, s_axis_b_tdata   : in std_logic_vector(31 downto 0);
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tready : in std_logic;
            m_axis_result_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- FIFO Signals
    signal fifo_in_valid, fifo_in_ready : std_logic;
    signal fifo_in_data : std_logic_vector(31 downto 0);
    
    signal fifo_out_valid, fifo_out_ready : std_logic;
    signal fifo_out_data : std_logic_vector(31 downto 0);

    -- Subtractor (1 - alpha)
    signal sub_start, sub_done_valid : std_logic;
    signal sub_in_ready : std_logic;
    signal sub_res : std_logic_vector(31 downto 0);
    signal one_minus_alpha_reg : std_logic_vector(31 downto 0); -- Stores result (1 - alpha)
    
    -- Multiplier A (input * alpha)
    signal mult_a_start, mult_a_done_valid : std_logic;
    signal mult_a_in_ready : std_logic;
    signal mult_a_res : std_logic_vector(31 downto 0);

    -- Multiplier B (EMA * (1 - alpha))
    signal mult_b_start, mult_b_done_valid : std_logic;
    signal mult_b_in_ready : std_logic;
    signal mult_b_res : std_logic_vector(31 downto 0);

    -- Adder (MultiplierA + MultiplierB)
    signal add_start, add_done_valid : std_logic;
    signal add_in_ready : std_logic;
    signal add_res : std_logic_vector(31 downto 0);

    -- Registers
    signal ema_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal const_one : std_logic_vector(31 downto 0) := x"3f800000"; -- 1.0

    -- FSM State
    type state_type is (S_INIT_SUB_START, S_INIT_SUB_WAIT, S_IDLE, 
                        S_CALC_MULTS_START, S_CALC_MULTS_WAIT, 
                        S_CALC_ADD_START, S_CALC_ADD_WAIT, 
                        S_UPDATE_Output);
    signal state : state_type := S_INIT_SUB_START;

begin

    -- Input FIFO
    FIFO_IN : fifo_buffer
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tready => s_axis_tready,
        s_axis_tdata => s_axis_tdata,
        m_axis_tvalid => fifo_in_valid,
        m_axis_tready => fifo_in_ready,
        m_axis_tdata => fifo_in_data
    );

    -- Output FIFO
    FIFO_OUT : fifo_buffer
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_tvalid => fifo_out_valid,
        s_axis_tready => fifo_out_ready,
        s_axis_tdata => fifo_out_data,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tready => m_axis_tready,
        m_axis_tdata => m_axis_tdata
    );

    -- Math components
    -- 1.0 - alpha
    COMP_SUB : float_subtractor
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_a_tvalid => sub_start,
        s_axis_a_tready => sub_in_ready,
        s_axis_a_tdata => const_one,
        s_axis_b_tvalid => sub_start,
        s_axis_b_tready => open,
        s_axis_b_tdata => alpha_val,
        m_axis_result_tvalid => sub_done_valid,
        m_axis_result_tready => '1',
        m_axis_result_tdata => sub_res
    );

    -- input * alpha
    COMP_MULT_A : float_multiplier
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_a_tvalid => mult_a_start,
        s_axis_a_tready => mult_a_in_ready,
        s_axis_a_tdata => fifo_in_data,
        s_axis_b_tvalid => mult_a_start,
        s_axis_b_tready => open,
        s_axis_b_tdata => alpha_val,
        m_axis_result_tvalid => mult_a_done_valid,
        m_axis_result_tready => '1',
        m_axis_result_tdata => mult_a_res
    );

    -- EMA_Reg * (1 - alpha)
    COMP_MULT_B : float_multiplier
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_a_tvalid => mult_b_start,
        s_axis_a_tready => mult_b_in_ready,
        s_axis_a_tdata => ema_reg,
        s_axis_b_tvalid => mult_b_start,
        s_axis_b_tready => open,
        s_axis_b_tdata => one_minus_alpha_reg,
        m_axis_result_tvalid => mult_b_done_valid,
        m_axis_result_tready => '1',
        m_axis_result_tdata => mult_b_res
    );

    -- Add the two results
    COMP_ADD : float_adder
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_a_tvalid => add_start,
        s_axis_a_tready => add_in_ready,
        s_axis_a_tdata => mult_a_res,
        s_axis_b_tvalid => add_start,
        s_axis_b_tready => open,
        s_axis_b_tdata => mult_b_res,
        m_axis_result_tvalid => add_done_valid,
        m_axis_result_tready => '1',
        m_axis_result_tdata => add_res
    );

    -- Control FSM
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= S_INIT_SUB_START;
                ema_reg <= (others => '0');
                one_minus_alpha_reg <= (others => '0');
                
                -- Reset triggers
                sub_start <= '0';
                mult_a_start <= '0';
                mult_b_start <= '0';
                add_start <= '0';
                fifo_in_ready <= '0';
                fifo_out_valid <= '0';
            else
                case state is
                    -- Initialization (1 - alpha)
                    when S_INIT_SUB_START =>
                        sub_start <= '1';
                        -- Wait for handshake (component ready to accept)
                        if sub_in_ready = '1' then 
                            state <= S_INIT_SUB_WAIT;
                        end if;

                    when S_INIT_SUB_WAIT =>
                        sub_start <= '0';
                        if sub_done_valid = '1' then
                            one_minus_alpha_reg <= sub_res;
                            state <= S_IDLE;
                        end if;

                    -- Processing loop
                    when S_IDLE =>
                        -- Wait for valid input data
                        if fifo_in_valid = '1' then
                            if unsigned(fifo_in_data(30 downto 23)) > 150 then
                                fifo_in_ready <= '1';
                                state <= S_IDLE;
                            else
                                -- Trigger both multipliers
                                mult_a_start <= '1';
                                mult_b_start <= '1';
                            
                                -- Tell FIFO the data is taken
                                fifo_in_ready <= '1';
                                state <= S_CALC_MULTS_START;
                            end if;
                        end if;

                    when S_CALC_MULTS_START =>
                        -- Wait for multipliers to accept inputs
                        if mult_a_in_ready = '1' and mult_b_in_ready = '1' then
                            fifo_in_ready <= '0'; -- Data consumed
                            state <= S_CALC_MULTS_WAIT;
                        end if;

                    when S_CALC_MULTS_WAIT =>
                        mult_a_start <= '0';
                        mult_b_start <= '0';
                        
                        -- Wait for both results to be valid
                        if mult_a_done_valid = '1' and mult_b_done_valid = '1' then
                            add_start <= '1';
                            state <= S_CALC_ADD_START;
                        end if;

                    when S_CALC_ADD_START =>
                        if add_in_ready = '1' then
                            state <= S_CALC_ADD_WAIT;
                        end if;

                    when S_CALC_ADD_WAIT =>
                        add_start <= '0';
                        if add_done_valid = '1' then
                            -- Update feedback register (recursion)
                            ema_reg <= add_res;
                            
                            -- Prepare output
                            fifo_out_data <= add_res;
                            fifo_out_valid <= '1';
                            
                            state <= S_UPDATE_Output;
                        end if;

                    when S_UPDATE_Output =>
                        -- Wait for output FIFO to accept
                        if fifo_out_ready = '1' then
                            fifo_out_valid <= '0';
                            state <= S_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
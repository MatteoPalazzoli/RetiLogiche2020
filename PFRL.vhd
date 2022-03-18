--------------------------------------------------
--| Palazzoli Matteo - c.p. 10614119             |
--| Prova Finale Reti Logiche a.a. 2020/2021     |
--| prof. Gianluca Palermo                       |
--------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
use IEEE.numeric_std.ALL;

-- entity declaration
entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
type state is (
    IDLE,               -- wait for i_start signal
    GET_R,              -- ask RAM for R
    GET_C,              -- ask RAM for C
    SET_R,              -- save R and ask for first pixel (assuming it exists - if not, value will be 0)
    SET_C,              -- save C and ask for second pixel (assuming it exists - if not, value will be 0)
    CALC_GET,           -- calculate partial max, min, delta, shift; ask for next data
    WAITING,            -- wait 
    SET,                -- set new pixel value
    READING,            -- re-ask for data
    DONE                -- wait for start = 0;
    );

-- constants
constant ROW_ADDR : std_logic_vector(15 downto 0) := "0000000000000000";
constant COL_ADDR : std_logic_vector(15 downto 0) := "0000000000000001";
constant FIRST_ADDR : std_logic_vector(15 downto 0) := "0000000000000010";
constant SECOND_ADDR : std_logic_vector(15 downto 0) := "0000000000000011";
constant ZERO_DATA : std_logic_vector(7 downto 0) := "00000000";
constant FULL_DATA : std_logic_vector( 7 downto 0) := "11111111";

-- signals
signal current_state, next_state : state := IDLE;
signal R, next_R, C, next_C : std_logic_vector(7 downto 0) := ZERO_DATA;
signal first_free_addr, next_first_free_addr : std_logic_vector(15 downto 0) := FIRST_ADDR;
signal address, next_address, work_addr, next_work_addr : std_logic_vector(15 downto 0) := ROW_ADDR;
signal max, next_max, delta, next_delta : std_logic_vector(7 downto 0) := ZERO_DATA;
signal min, next_min : std_logic_vector(7 downto 0) := FULL_DATA;
signal shift, next_shift  : std_logic_vector(3 downto 0) := "0000";

signal o_done_next, o_en_next, o_we_next : std_logic := '0';
signal o_data_next : std_logic_vector(7 downto 0) := ZERO_DATA;
signal o_address_next : std_logic_vector(15 downto 0) := ROW_ADDR;

begin
-- registers
registers : process(i_clk, i_rst)
begin
    -- asyncronous reset
    if i_rst = '1' then
        R <= ZERO_DATA;
        C <= ZERO_DATA;
        first_free_addr <= FIRST_ADDR;
        min <= FULL_DATA;      --set to max possible value
        max <= ZERO_DATA;
        delta <= ZERO_DATA;
        shift <= "0000";
        address <= ROW_ADDR;
        work_addr <= ROW_ADDR;
        
        o_done <= '0';
        o_en <= '0';
        o_we <= '0';
        o_address <= ROW_ADDR;
        o_data <= ZERO_DATA;
        
        current_state <= IDLE;
        
    -- setting new as current
    elsif rising_edge(i_clk) then
        R <= next_R;
        C <= next_C;
        first_free_addr <= next_first_free_addr;
        max <= next_max;
        min <= next_min;
        delta <= next_delta;
        shift <= next_shift;
        address <= next_address;
        work_addr <= next_work_addr;
        
        current_state <= next_state;
        
        o_done <= o_done_next;
        o_en <= o_en_next;
        o_we <= o_we_next;
        o_address <= o_address_next;
        o_data <= o_data_next;
    end if;
end process;

lambda_delta : process (current_state, i_start, i_data, R, C, first_free_addr, max, min, delta, shift, address, work_addr)
    -- process variables declaration
    variable t_max, t_min : unsigned(7 downto 0);
    variable temp : unsigned(15 downto 0);
    variable shift_value : natural range 0 to 8;
    variable lut_in : std_logic_vector(7 downto 0);
begin
    -- initialising outputs and nexts to avoid inferred latches
    o_address_next <= ROW_ADDR;
    o_en_next <= '0';
    o_we_next <= '0';
    o_done_next <= '0';
    o_data_next <= ZERO_DATA;
    
    next_R <= R;
    next_C <= C;
    next_first_free_addr <= first_free_addr;
    next_max <= max;
    next_min <= min;
    next_delta <= delta;
    next_shift <= shift;
    next_address <= address;
    next_work_addr <= work_addr;
    next_state <= current_state;
    
    -- state case
    case current_state is
        when IDLE =>
            if i_start='1' then
                next_state <= GET_R;
            else
                next_state <= IDLE;
            end if;
            
        when GET_R =>
            o_en_next <= '1';
            o_address_next <= ROW_ADDR;
            next_address <= ROW_ADDR;
            next_state <= GET_C;
            
        when GET_C =>
            o_en_next <= '1';
            o_address_next <= COL_ADDR;
            next_address <= COL_ADDR;
            next_state <= SET_R;
                    
        when SET_R =>
            if i_data = ZERO_DATA then
                o_done_next <= '1';
                next_state <= DONE;
            else
                next_R <= i_data;
                next_address <= FIRST_ADDR;
                o_address_next <= FIRST_ADDR;
                next_work_addr <= COL_ADDR;
                o_en_next <= '1';
                next_state <= SET_C;
            end if;
            
        when SET_C =>
            if i_data = ZERO_DATA then
                o_done_next <= '1';
                next_state <= DONE;
            else
                next_C <= i_data;
                temp := unsigned(R) * unsigned(i_data);
                temp := temp + to_unsigned(2, 16);
                next_first_free_addr <= std_logic_vector(temp);
                next_address <= SECOND_ADDR;
                next_work_addr <= FIRST_ADDR;
                o_address_next <= SECOND_ADDR;
                o_en_next <= '1';
                next_state <= CALC_GET;
            end if;
            
        when CALC_GET =>
            if work_addr < first_free_addr then
                if i_data > max or i_data < min then
                    t_max := unsigned(max);
                    t_min := unsigned(min);
                    if i_data > max then
                        next_max <= i_data;
                        t_max := unsigned(i_data);
                    end if;
                    if i_data < min then
                        next_min <= i_data;
                        t_min := unsigned(i_data);
                    end if;
                    next_delta <= std_logic_vector(t_max - t_min);
                    -- lut_in is delta+1, so it belongs to range [1, 256].
                    -- however, to mantain lut_in's lenght = 8 bits, if delta = 255 lut_in will be codified to 0.
                    if std_logic_vector(t_max - t_min) = FULL_DATA then
                        lut_in := ZERO_DATA;
                    else
                        lut_in := std_logic_vector(t_max - t_min + to_unsigned(1, 8));
                    end if;
                    if lut_in(7) = '1' then
                        next_shift <= "0001";
                    elsif lut_in(6) = '1' then
                        next_shift <= "0010";
                    elsif lut_in(5) = '1' then
                        next_shift <= "0011";
                    elsif lut_in(4) = '1' then
                        next_shift <= "0100";
                    elsif lut_in(3) = '1' then
                        next_shift <= "0101";
                    elsif lut_in(2) = '1' then
                        next_shift <= "0110";
                    elsif lut_in(1) = '1' then
                        next_shift <= "0111";
                    elsif lut_in(0) = '1' then
                        next_shift <= "1000";
                    elsif lut_in(0) = '0' then
                        next_shift <= "0000";
                    end if;
                end if;
                next_address <= std_logic_vector(unsigned(address) + to_unsigned(1, 16));
                next_work_addr <= std_logic_vector(unsigned(work_addr) + to_unsigned(1, 16));
                o_address_next <= std_logic_vector(unsigned(address) + to_unsigned(1, 16));
                o_en_next <= '1';
                next_state <= CALC_GET;
            else
                next_address <= FIRST_ADDR;
                next_work_addr <= FIRST_ADDR;
                o_address_next <= FIRST_ADDR;
                o_en_next <= '1';
                next_state <= WAITING;
            end if;
            
        when WAITING =>
            o_en_next <= '1';
            next_state <= SET;
        
        when SET =>
            if work_addr < first_free_addr then
                shift_value := to_integer(unsigned(shift));
                temp := "00000000" & (unsigned(i_data) - unsigned(min));
                temp := shift_left(temp, shift_value);
                if temp < to_unsigned(256, 16) then
                    o_data_next <= std_logic_vector(temp(7 downto 0));
                else
                    o_data_next <= std_logic_vector(to_unsigned(255, 8));
                end if;
                o_address_next <= std_logic_vector(unsigned(work_addr) + unsigned(first_free_addr) - to_unsigned(2, 16));
                o_en_next <= '1';
                o_we_next <= '1';
                next_state <= READING;
            else
                next_state <= DONE;
            end if;
        
        when READING =>
            next_work_addr <= std_logic_vector(unsigned(work_addr)+ to_unsigned(1, 16));
            o_address_next <= std_logic_vector(unsigned(work_addr)+ to_unsigned(1, 16));
            o_en_next <= '1';
            next_state <= WAITING;
            
        when DONE =>
            o_en_next <= '0';
            o_done_next <= '1';
            next_max <= ZERO_DATA;
            next_min <= FULL_DATA;
            next_delta <= ZERO_DATA;
            next_shift <= "0000";
            if i_start = '1' then
                next_state <= DONE;
            else
                next_state <= IDLE;
            end if;
    end case;
end process;

end Behavioral;
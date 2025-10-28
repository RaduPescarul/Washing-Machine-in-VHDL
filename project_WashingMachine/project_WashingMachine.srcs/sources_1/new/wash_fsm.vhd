library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wash_program_fsm is
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        start_program : in STD_LOGIC;
        pulse_1s : in STD_LOGIC;
        temp : in STD_LOGIC_VECTOR(1 downto 0);
        prewash : in STD_LOGIC;
        extra_rinse : in STD_LOGIC;
        door_closed : in STD_LOGIC;
        params_valid : in STD_LOGIC;
        total_time : in STD_LOGIC_VECTOR(15 downto 0);

        program_running : out STD_LOGIC;
        door_locked : out STD_LOGIC;
        program_done : out STD_LOGIC;
        current_phase : out STD_LOGIC_VECTOR(3 downto 0);
        time_remaining : out STD_LOGIC_VECTOR(15 downto 0);

        water_inlet : out STD_LOGIC;
        water_outlet : out STD_LOGIC;
        heater_on : out STD_LOGIC;
        motor_speed : out STD_LOGIC_VECTOR(1 downto 0)
    );
end wash_program_fsm;

architecture Behavioral of wash_program_fsm is
    type state_type is (
        IDLE,
        PREWASH_FILL, PREWASH_HEAT, PREWASH_WASH, PREWASH_DRAIN,
        MAIN_FILL, MAIN_HEAT, MAIN_WASH, MAIN_DRAIN,
        RINSE_FILL, RINSE_WASH, RINSE_DRAIN,
        EXTRA_RINSE_FILL, EXTRA_RINSE_WASH, EXTRA_RINSE_DRAIN,
        SPIN,
        DOOR_UNLOCK_DELAY,
        COMPLETE
    );

    signal current_state : state_type := IDLE;
    signal phase_timer : unsigned(15 downto 0) := (others => '0');
    signal total_time_remaining : unsigned(15 downto 0) := (others => '0');
    
    -- ADD: Edge detection for start_program button
    signal start_program_prev : STD_LOGIC := '0';
    signal start_program_edge : STD_LOGIC := '0';

    constant C_FILL_TIME      : unsigned(15 downto 0) := to_unsigned(2, 16);
    constant C_DRAIN_TIME     : unsigned(15 downto 0) := to_unsigned(2, 16);
    constant C_PREWASH_TIME   : unsigned(15 downto 0) := to_unsigned(3, 16);
    constant C_MAIN_WASH_TIME : unsigned(15 downto 0) := to_unsigned(5, 16);
    constant C_RINSE_TIME     : unsigned(15 downto 0) := to_unsigned(3, 16);
    constant C_SPIN_TIME      : unsigned(15 downto 0) := to_unsigned(3, 16);
    constant C_UNLOCK_DELAY   : unsigned(15 downto 0) := to_unsigned(60, 16);
    
    -- heating time constants based on temperature
    signal heating_time : unsigned(15 downto 0);

begin
    -- calculate heating time based on temperature
    process(temp)
    begin
        case temp is
            when "00" => heating_time <= to_unsigned(3, 16);   -- 30 C: 3 seconds
            when "01" => heating_time <= to_unsigned(5, 16);   -- 40 C: 5 seconds
            when "10" => heating_time <= to_unsigned(9, 16);   -- 60 C: 9 seconds
            when "11" => heating_time <= to_unsigned(15, 16);  -- 90 C: 15 seconds
            when others => heating_time <= to_unsigned(3, 16);
        end case;
    end process;

    -- ADD: Edge detection process
    process(clk, reset)
    begin
        if reset = '1' then
            start_program_prev <= '0';
            start_program_edge <= '0';
        elsif rising_edge(clk) then
            start_program_prev <= start_program;
            start_program_edge <= start_program and not start_program_prev;
        end if;
    end process;

    -- FIXED: Main FSM process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
            phase_timer <= (others => '0');
            total_time_remaining <= (others => '0');
        elsif rising_edge(clk) then
            
            -- FIXED: Handle IDLE state separately (outside pulse_1s)
            case current_state is
                when IDLE =>
                    -- FIXED: Use edge detection and check every clock cycle
                    if start_program_edge = '1' and door_closed = '1' and params_valid = '1' then
                        total_time_remaining <= unsigned(total_time);
                        if prewash = '1' then
                            current_state <= PREWASH_FILL;
                            phase_timer <= C_FILL_TIME;
                        else
                            current_state <= MAIN_FILL;
                            phase_timer <= C_FILL_TIME;
                        end if;
                    end if;

                when COMPLETE =>
                    -- FIXED: Check door status every clock cycle for immediate response
                    if door_closed = '0' then 
                        current_state <= IDLE; 
                    end if;

                -- FIXED: All other states only operate on 1-second pulse
                when others =>
                    if pulse_1s = '1' then
                        -- Countdown timers
                        if phase_timer > 0 then
                            phase_timer <= phase_timer - 1;
                        end if;

                        if total_time_remaining > 0 then
                            total_time_remaining <= total_time_remaining - 1;
                        end if;

                        -- State transitions
                        case current_state is
                            when PREWASH_FILL => 
                                if phase_timer = 0 then 
                                    current_state <= PREWASH_HEAT; 
                                    phase_timer <= heating_time;
                                end if;
                                
                            when PREWASH_HEAT => 
                                if phase_timer = 0 then
                                    current_state <= PREWASH_WASH;
                                    phase_timer <= C_PREWASH_TIME;
                                end if;

                            when PREWASH_WASH => 
                                if phase_timer = 0 then 
                                    current_state <= PREWASH_DRAIN; 
                                    phase_timer <= C_DRAIN_TIME; 
                                end if;
                                
                            when PREWASH_DRAIN => 
                                if phase_timer = 0 then 
                                    current_state <= MAIN_FILL; 
                                    phase_timer <= C_FILL_TIME; 
                                end if;

                            when MAIN_FILL => 
                                if phase_timer = 0 then 
                                    current_state <= MAIN_HEAT; 
                                    phase_timer <= heating_time;
                                end if;
                                
                            when MAIN_HEAT => 
                                if phase_timer = 0 then
                                    current_state <= MAIN_WASH;
                                    phase_timer <= C_MAIN_WASH_TIME;
                                end if;

                            when MAIN_WASH => 
                                if phase_timer = 0 then 
                                    current_state <= MAIN_DRAIN; 
                                    phase_timer <= C_DRAIN_TIME; 
                                end if;
                                
                            when MAIN_DRAIN => 
                                if phase_timer = 0 then 
                                    current_state <= RINSE_FILL; 
                                    phase_timer <= C_FILL_TIME; 
                                end if;

                            when RINSE_FILL => 
                                if phase_timer = 0 then 
                                    current_state <= RINSE_WASH; 
                                    phase_timer <= C_RINSE_TIME; 
                                end if;
                                
                            when RINSE_WASH => 
                                if phase_timer = 0 then 
                                    current_state <= RINSE_DRAIN; 
                                    phase_timer <= C_DRAIN_TIME; 
                                end if;
                                
                            when RINSE_DRAIN =>
                                if phase_timer = 0 then
                                    if extra_rinse = '1' then
                                        current_state <= EXTRA_RINSE_FILL;
                                        phase_timer <= C_FILL_TIME;
                                    else
                                        current_state <= SPIN;
                                        phase_timer <= C_SPIN_TIME;
                                    end if;
                                end if;

                            when EXTRA_RINSE_FILL => 
                                if phase_timer = 0 then 
                                    current_state <= EXTRA_RINSE_WASH; 
                                    phase_timer <= C_RINSE_TIME; 
                                end if;
                                
                            when EXTRA_RINSE_WASH => 
                                if phase_timer = 0 then 
                                    current_state <= EXTRA_RINSE_DRAIN; 
                                    phase_timer <= C_DRAIN_TIME; 
                                end if;
                                
                            when EXTRA_RINSE_DRAIN => 
                                if phase_timer = 0 then 
                                    current_state <= SPIN; 
                                    phase_timer <= C_SPIN_TIME; 
                                end if;

                            when SPIN => 
                                if phase_timer = 0 then 
                                    current_state <= DOOR_UNLOCK_DELAY; 
                                    phase_timer <= C_UNLOCK_DELAY; 
                                end if;
                                
                            when DOOR_UNLOCK_DELAY => 
                                if phase_timer = 0 then 
                                    current_state <= COMPLETE; 
                                end if;
                                
                            when COMPLETE => 
                                -- FIXED: Check door status every clock cycle, not just on pulse_1s
                                null; -- Do nothing in pulse_1s for COMPLETE state
                                
                            when others => 
                                current_state <= IDLE;
                        end case;
                    end if;
            end case;
        end if;
    end process;

    -- Outputs
    program_running <= '1' when (current_state /= IDLE and current_state /= COMPLETE) else '0';
    door_locked <= '1' when (current_state /= IDLE and current_state /= COMPLETE) else '0';
    program_done <= '1' when (current_state = DOOR_UNLOCK_DELAY or current_state = COMPLETE) else '0';
    time_remaining <= std_logic_vector(total_time_remaining);

    -- phase encoding
    with current_state select current_phase <=
        "0000" when IDLE,
        "0001" when PREWASH_FILL,
        "0010" when PREWASH_HEAT,
        "0011" when PREWASH_WASH,
        "0100" when PREWASH_DRAIN,
        "0101" when MAIN_FILL,
        "0110" when MAIN_HEAT,
        "0111" when MAIN_WASH,
        "1000" when MAIN_DRAIN,
        "1001" when RINSE_FILL,
        "1010" when RINSE_WASH,
        "1011" when RINSE_DRAIN,
        "1100" when EXTRA_RINSE_FILL,
        "1101" when EXTRA_RINSE_WASH,
        "1110" when EXTRA_RINSE_DRAIN,
        "1111" when SPIN,
        "0000" when others;

    -- Process control outputs
    water_inlet <= '1' when (current_state = PREWASH_FILL or 
                             current_state = MAIN_FILL or 
                             current_state = RINSE_FILL or 
                             current_state = EXTRA_RINSE_FILL) else '0';
                             
    water_outlet <= '1' when (current_state = PREWASH_DRAIN or 
                              current_state = MAIN_DRAIN or 
                              current_state = RINSE_DRAIN or 
                              current_state = EXTRA_RINSE_DRAIN) else '0';
                              
    heater_on <= '1' when (current_state = PREWASH_HEAT or 
                           current_state = MAIN_HEAT) else '0';

    -- Motor speed control
    with current_state select motor_speed <=
        "01" when PREWASH_WASH,      -- 60 rpm equivalent
        "01" when MAIN_WASH,         -- 60 rpm equivalent  
        "10" when RINSE_WASH,        -- 120 rpm equivalent
        "10" when EXTRA_RINSE_WASH,  -- 120 rpm equivalent
        "11" when SPIN,              -- Selected high speed
        "00" when others;            -- motor off

end Behavioral;

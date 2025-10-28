library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity washing_machine_controller is
    Port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;

        btnu : in STD_LOGIC;      -- start program
        btnl : in STD_LOGIC;      -- select mode
        btnr : in STD_LOGIC;      -- on/off washing machine

        sw : in STD_LOGIC_VECTOR(10 downto 0);

        led : out STD_LOGIC_VECTOR(10 downto 0);

        seg : out STD_LOGIC_VECTOR(6 downto 0);
        an : out STD_LOGIC_VECTOR(3 downto 0)
    );
end washing_machine_controller;

architecture Behavioral of washing_machine_controller is

    component MPG
        Port (
            btn : in STD_LOGIC;
            clk : in STD_LOGIC;
            en : out STD_LOGIC
        );
    end component;

    component clock_divider
        Generic (
            DIVIDE_BY : integer := 100000000
        );
        Port (
            clk_in : in STD_LOGIC;
            reset : in STD_LOGIC;
            clk_out : out STD_LOGIC;
            pulse_1s : out STD_LOGIC
        );
    end component;

    component wash_program_fsm
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
    end component;

    component mode_selector
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            machine_on : in STD_LOGIC;
            select_btn : in STD_LOGIC;
            mode : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

    component parameter_controller
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            mode : in STD_LOGIC_VECTOR(2 downto 0);
            switches : in STD_LOGIC_VECTOR(10 downto 0);
            temp : out STD_LOGIC_VECTOR(1 downto 0);
            speed : out STD_LOGIC_VECTOR(1 downto 0);
            prewash : out STD_LOGIC;
            extra_rinse : out STD_LOGIC;
            params_valid : out STD_LOGIC
        );
    end component;

    component time_calculator
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            temp : in STD_LOGIC_VECTOR(1 downto 0);
            speed : in STD_LOGIC_VECTOR(1 downto 0);
            prewash : in STD_LOGIC;
            extra_rinse : in STD_LOGIC;
            calculate : in STD_LOGIC;
            total_time : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    component seven_segment_controller
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            time_value : in STD_LOGIC_VECTOR(15 downto 0);
            seg : out STD_LOGIC_VECTOR(6 downto 0);
            an : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

    signal btnu_debounced, btnl_debounced, btnr_debounced : STD_LOGIC := '0';
    signal machine_on, prewash, extra_rinse, params_valid : STD_LOGIC := '0';
    signal temp : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal speed : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal mode : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal total_time, time_remaining, display_time : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal program_running, door_locked, program_done, door_closed : STD_LOGIC := '0';
    signal pulse_1s : STD_LOGIC := '0';
    signal current_phase : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal water_inlet, water_outlet, heater_on : STD_LOGIC := '0';
    signal motor_speed : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal led_control : STD_LOGIC_VECTOR(10 downto 0) := (others => '0');
    signal machine_power_on : STD_LOGIC := '0';

    attribute KEEP : string;
    attribute KEEP of water_inlet : signal is "TRUE";
    attribute KEEP of water_outlet : signal is "TRUE";
    attribute KEEP of heater_on : signal is "TRUE";
    attribute KEEP of motor_speed : signal is "TRUE";

begin

    door_closed <= sw(0);

    -- clock divider for 1-second pulses
    -- for simulation use: 100000 for faster timing
    clk_div: clock_divider 
        generic map (DIVIDE_BY => 100000000)  -- we could change to 100000 for simulation
        port map (
            clk_in => clk, 
            reset => rst, 
            clk_out => open, 
            pulse_1s => pulse_1s
        );

    mpg_btnu: MPG port map (btn => btnu, clk => clk, en => btnu_debounced);
    mpg_btnl: MPG port map (btn => btnl, clk => clk, en => btnl_debounced);
    mpg_btnr: MPG port map (btn => btnr, clk => clk, en => btnr_debounced);

    -- Machine power control process
    process(clk, rst)
    begin
        if rst = '1' then 
            machine_power_on <= '0';
        elsif rising_edge(clk) then
            -- toggle power with BTNR
            if btnr_debounced = '1' then 
                machine_power_on <= not machine_power_on; 
            end if;
            
            -- force machine off if door opens while not running
            if door_closed = '0' and program_running = '0' then 
                machine_power_on <= '0';
            end if;
        end if;
    end process;

    -- machine is on when power is on 
    machine_on <= machine_power_on;

    mode_sel: mode_selector port map (
        clk => clk, 
        reset => rst, 
        machine_on => machine_on, 
        select_btn => btnl_debounced, 
        mode => mode
    );

    param_ctrl: parameter_controller port map (
        clk => clk, 
        reset => rst, 
        mode => mode, 
        switches => sw,
        temp => temp, 
        speed => speed, 
        prewash => prewash,
        extra_rinse => extra_rinse, 
        params_valid => params_valid
    );

    time_calc: time_calculator port map (
        clk => clk, 
        reset => rst, 
        temp => temp, 
        speed => speed,
        prewash => prewash, 
        extra_rinse => extra_rinse,
        calculate => params_valid, 
        total_time => total_time
    );

    wash_fsm: wash_program_fsm port map (
        clk => clk, 
        reset => rst, 
        start_program => btnu_debounced,
        pulse_1s => pulse_1s, 
        temp => temp, 
        prewash => prewash,
        extra_rinse => extra_rinse, 
        door_closed => door_closed,
        params_valid => params_valid, 
        total_time => total_time,
        program_running => program_running, 
        door_locked => door_locked,
        program_done => program_done, 
        current_phase => current_phase,
        time_remaining => time_remaining, 
        water_inlet => water_inlet,
        water_outlet => water_outlet, 
        heater_on => heater_on,
        motor_speed => motor_speed
    );

    -- display time logic: show remaining time when running, total time when not running
    display_time <= time_remaining when program_running = '1' else total_time;

    seven_seg: seven_segment_controller port map (
        clk => clk, 
        reset => rst, 
        time_value => display_time,
        seg => seg, 
        an => an
    );

  -- LED control process - Fixed LED0 assignment order
    process(clk, rst)
    begin
        if rst = '1' then
            led_control <= (others => '0');
        elsif rising_edge(clk) then
            -- Initialize all LEDs to off FIRST
            led_control <= (others => '0');
            
            -- THEN set the specific LEDs (after initialization)
            -- LED 0 always shows door closed status
            led_control(0) <= sw(0);
            
            -- LED 1 shows door locked status when program is running
            led_control(1) <= door_locked;
            
            -- Only show parameter LEDs when machine is on
            if machine_on = '1' then
                case mode is
                    when "000" =>  -- manual mode, LEDs follow switches
                        led_control(2) <= sw(2);   -- 30 C
                        led_control(3) <= sw(3);   -- 40 C
                        led_control(4) <= sw(4);   -- 60 C
                        led_control(5) <= sw(5);   -- 90 C
                        led_control(6) <= sw(6);   -- 800rpm
                        led_control(7) <= sw(7);   -- 1000rpm
                        led_control(8) <= sw(8);   -- 1200rpm
                        led_control(9) <= sw(9);   -- prewash
                        led_control(10) <= sw(10); -- extra rinse
                        
                    when "001" =>  -- quick wash: 30 C, 1200rpm, no extras
                        led_control(2) <= '1';     -- 30 C (SW2)
                        led_control(8) <= '1';     -- 1200rpm (SW8)
                        
                    when "010" =>  -- shirts: 60 C, 800rpm, no extras
                        led_control(4) <= '1';     -- 60 C (SW4)
                        led_control(6) <= '1';     -- 800rpm (SW6)
                        
                    when "011" =>  -- dark colors: 40 C, 1000rpm, extra rinse
                        led_control(3) <= '1';     -- 40 C (SW3)
                        led_control(7) <= '1';     -- 1000rpm (SW7)
                        led_control(10) <= '1';    -- extra rinse (SW10)
                        
                    when "100" =>  -- dirty laundry: 40 C, 1000rpm, prewash
                        led_control(3) <= '1';     -- 40 C (SW3)
                        led_control(7) <= '1';     -- 1000rpm (SW7)
                        led_control(9) <= '1';     -- prewash (SW9)
                        
                    when "101" =>  -- antiallergic: 90 C, 1200rpm, extra rinse
                        led_control(5) <= '1';     -- 90 C (SW5)
                        led_control(8) <= '1';     -- 1200rpm (SW8)
                        led_control(10) <= '1';    -- extra rinse (SW10)
                        
                    when others =>  -- default to manual behavior
                        led_control(2) <= sw(2);
                        led_control(3) <= sw(3);
                        led_control(4) <= sw(4);
                        led_control(5) <= sw(5);
                        led_control(6) <= sw(6);
                        led_control(7) <= sw(7);
                        led_control(8) <= sw(8);
                        led_control(9) <= sw(9);
                        led_control(10) <= sw(10);
                end case;
            end if;
        end if;
    end process;
    led <= led_control;

end Behavioral;

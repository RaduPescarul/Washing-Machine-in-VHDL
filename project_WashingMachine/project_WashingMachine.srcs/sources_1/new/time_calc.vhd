library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity time_calculator is
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
end time_calculator;

architecture Behavioral of time_calculator is
    signal calculated_time : unsigned(15 downto 0) := (others => '0');
begin
    process(clk, reset)
        variable temp_time : unsigned(15 downto 0);
        variable speed_time : unsigned(15 downto 0);
        variable time_sum  : unsigned(15 downto 0);
    begin
        if reset = '1' then
            calculated_time <= (others => '0');
        elsif rising_edge(clk) then
            if calculate = '1' then
                time_sum := to_unsigned(60, 16); -- 1 minute base

                -- heating time based on temperature
                case temp is
                    when "00" => temp_time := to_unsigned(5, 16);   -- 30 C
                    when "01" => temp_time := to_unsigned(10, 16);  -- 40 C
                    when "10" => temp_time := to_unsigned(15, 16);  -- 60 C
                    when "11" => temp_time := to_unsigned(20, 16);  -- 90 C
                    when others => temp_time := to_unsigned(5, 16);
                end case;

                time_sum := time_sum + temp_time; -- main heating time

                -- speed adjustment (higher speed = slightly longer spin time)
                case speed is
                    when "00" => speed_time := to_unsigned(0, 16);   -- 800 rpm 
                    when "01" => speed_time := to_unsigned(2, 16);   -- 1000 rpm (+2 sec)
                    when "10" => speed_time := to_unsigned(5, 16);   -- 1200 rpm (+5 sec)
                    when others => speed_time := to_unsigned(0, 16);
                end case;

                time_sum := time_sum + speed_time;

                --prewash
                if prewash = '1' then
                    time_sum := time_sum + temp_time + to_unsigned(15, 16);
                end if;

                -- extra rinse
                if extra_rinse = '1' then
                    time_sum := time_sum + to_unsigned(10, 16);
                end if;

        --final time
                calculated_time <= time_sum;
            end if;
        end if;
    end process;

    total_time <= std_logic_vector(calculated_time);
end Behavioral;

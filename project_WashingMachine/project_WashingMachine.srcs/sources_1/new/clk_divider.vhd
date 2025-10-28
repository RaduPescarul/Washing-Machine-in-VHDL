library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- takes a fast clock and makes it slower
-- like turning 100mhz into 1hz (once per second)
entity clock_divider is
    Generic (
        DIVIDE_BY : integer := 100000000
    );
    Port (
        clk_in : in STD_LOGIC;
        reset : in STD_LOGIC;
        clk_out : out STD_LOGIC;
        pulse_1s : out STD_LOGIC
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal counter : unsigned(26 downto 0) := (others => '0');  -- 27 bits can handle   100M
    signal clk_div : STD_LOGIC := '0';
    signal pulse_reg : STD_LOGIC := '0';
begin
    process(clk_in, reset)
    begin
        if reset = '1' then
            counter <= (others => '0');
            clk_div <= '0';
            pulse_reg <= '0';
        elsif rising_edge(clk_in) then
            pulse_reg <= '0'; 
            
            -- divide_by-1 because we count from 0 (like 0,1,2...99,999,999 = 100 million counts)
            if counter >= to_unsigned(DIVIDE_BY-1, 27) then
                counter <= (others => '0');
                clk_div <= not clk_div;
                pulse_reg <= '1';  -- geerate pulse
            else
            -- counter hasn't reached limit yet, so just add 1 to it
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    clk_out <= clk_div;
    pulse_1s <= pulse_reg;
end Behavioral;
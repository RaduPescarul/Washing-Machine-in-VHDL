library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_segment_controller is
    Port (
        clk        : in STD_LOGIC;
        reset      : in STD_LOGIC;
        time_value : in STD_LOGIC_VECTOR(15 downto 0);
        seg        : out STD_LOGIC_VECTOR(6 downto 0);
        an         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end seven_segment_controller;

architecture Behavioral of seven_segment_controller is
    signal refresh_counter : unsigned(19 downto 0) := (others => '0'); --counts continuously at 100MHz clock speed
    signal digit_select     : unsigned(1 downto 0) := (others => '0');
  --  "00 rightmost digit (seconds ones)
   -- "01" seconds tens
   -- "10" minutes ones
  --  "11" leftmost digit (minutes tens)
    signal current_digit    : STD_LOGIC_VECTOR(3 downto 0) := "0000";

    signal min_tens, min_ones, sec_tens, sec_ones : STD_LOGIC_VECTOR(3 downto 0);

--d is a decimal digit 
    function digit_to_7seg (d : STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
    begin
        case d is
            when "0000" => return "1000000";  -- 0
            when "0001" => return "1111001";  -- 1
            when "0010" => return "0100100";  -- 2
            when "0011" => return "0110000";  -- 3
            when "0100" => return "0011001";  -- 4
            when "0101" => return "0010010";  -- 5
            when "0110" => return "0000010";  -- 6
            when "0111" => return "1111000";  -- 7
            when "1000" => return "0000000";  -- 8
            when "1001" => return "0010000";  -- 9
            when others => return "1111111";  -- blank
        end case;
    end function;

begin

    -- convert time_value (in seconds) to minutes and seconds
    process(clk, reset)
        variable minutes, seconds : unsigned(15 downto 0);
        variable time_val : unsigned(15 downto 0);
    begin
        if reset = '1' then
            min_tens <= (others => '0');
            min_ones <= (others => '0');
            sec_tens <= (others => '0');
            sec_ones <= (others => '0');
        elsif rising_edge(clk) then
            time_val := unsigned(time_value);
            
            if time_val = 0 then
                --00:00 when time is zero
                min_tens <= "0000";
                min_ones <= "0000";
                sec_tens <= "0000";
                sec_ones <= "0000";
            elsif time_val > 5999 then
                -- max display: 99:59
                min_tens <= "1001";  -- 9
                min_ones <= "1001";  -- 9
                sec_tens <= "0101";  -- 5
                sec_ones <= "1001";  -- 9
            else
                minutes := time_val / 60;  --for minutes 
                seconds := time_val mod 60; --seconds

                -- individual digits
                min_tens <= std_logic_vector(to_unsigned(to_integer(minutes / 10), 4)); --converts for eveery digit
                min_ones <= std_logic_vector(to_unsigned(to_integer(minutes mod 10), 4));
                sec_tens <= std_logic_vector(to_unsigned(to_integer(seconds / 10), 4));
                sec_ones <= std_logic_vector(to_unsigned(to_integer(seconds mod 10), 4));
            end if;
        end if;
    end process;

    -- refresh counter and digit selection for 4-digit display
    process(clk, reset)
    begin
        if reset = '1' then
            refresh_counter <= (others => '0');
            digit_select <= (others => '0');
            
        elsif rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
            --update digit selection every 100MHz
            if refresh_counter(15 downto 0) = x"FFFF" then
                if digit_select = "11" then
                    digit_select <= "00";
                else
                    digit_select <= digit_select + 1;
                end if;
            end if;
        end if;
    end process;

    --  multiplexer for 4-digit display
    process(digit_select, min_tens, min_ones, sec_tens, sec_ones)
    begin
        an <= "1111";  -- default: all off
        current_digit <= "1111";  

        case digit_select is
            when "00" => 
                an <= "1110"; 
                current_digit <= sec_ones;  -- rightmost digit 
            when "01" => 
                an <= "1101"; 
                current_digit <= sec_tens;  -- seconds tens
            when "10" => 
                an <= "1011"; 
                current_digit <= min_ones;  -- minutes ones
            when "11" => 
                an <= "0111"; 
                current_digit <= min_tens;  -- leftmost digit (minutes tens)
            when others => 
                an <= "1111"; 
                current_digit <= "1111";
        end case;
    end process;

    seg <= digit_to_7seg(current_digit);

end Behavioral;
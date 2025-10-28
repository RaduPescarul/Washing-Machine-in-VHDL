library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_controller is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        mode         : in  STD_LOGIC_VECTOR(2 downto 0);
        switches     : in  STD_LOGIC_VECTOR(10 downto 0);
        temp         : out STD_LOGIC_VECTOR(1 downto 0);
        speed        : out STD_LOGIC_VECTOR(1 downto 0);
        prewash      : out STD_LOGIC;
        extra_rinse  : out STD_LOGIC;
        params_valid : out STD_LOGIC
    );
end parameter_controller;

architecture Behavioral of parameter_controller is
    signal temp_internal       : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal speed_internal      : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal prewash_internal    : STD_LOGIC := '0';
    signal extra_rinse_internal : STD_LOGIC := '0';
    signal temp_valid          : STD_LOGIC := '0';
    signal speed_valid         : STD_LOGIC := '0';
    
  -- how many temperature and speed switches are active
    signal temp_switch_count : integer range 0 to 4;
    signal speed_switch_count : integer range 0 to 3;

begin

  --count active switches
 -- manual mode operation by ensuring the user selects exactly one temperature and one speed switch
    process(switches)
        variable temp_count : integer range 0 to 4;
        variable speed_count : integer range 0 to 3;
    begin
        -- count temperature switches (SW2, SW3, SW4, SW5)
        temp_count := 0;
        if switches(2) = '1' then temp_count := temp_count + 1; end if;
        if switches(3) = '1' then temp_count := temp_count + 1; end if;
        if switches(4) = '1' then temp_count := temp_count + 1; end if;
        if switches(5) = '1' then temp_count := temp_count + 1; end if;
        temp_switch_count <= temp_count;
        
      --count speed switches (SW6, SW7, SW8)
        speed_count := 0;
        if switches(6) = '1' then speed_count := speed_count + 1; end if;
        if switches(7) = '1' then speed_count := speed_count + 1; end if;
        if switches(8) = '1' then speed_count := speed_count + 1; end if;
        speed_switch_count <= speed_count;
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            temp_internal        <= "00";
            speed_internal       <= "00";
            prewash_internal     <= '0';
            extra_rinse_internal <= '0';
            temp_valid           <= '0';
            speed_valid          <= '0';

        elsif rising_edge(clk) then
            temp_valid  <= '0';
            speed_valid <= '0';

            case mode is
                when "000" => 
                    --only allow ONE switch to be active
                    if temp_switch_count = 1 then
                        temp_valid <= '1';
                        if switches(2) = '1' then
                            temp_internal <= "00";  -- 30 C 
                        elsif switches(3) = '1' then
                            temp_internal <= "01";  -- 40 C 
                        elsif switches(4) = '1' then
                            temp_internal <= "10";  -- 60 C 
                        elsif switches(5) = '1' then
                            temp_internal <= "11";  -- 90 C
                        end if;
                    else
                        temp_valid <= '0';
                    end if;

                    -- ONE switch to be active
                    if speed_switch_count = 1 then
                        speed_valid <= '1';
                        if switches(6) = '1' then
                            speed_internal <= "00";  -- 800 rpm 
                        elsif switches(7) = '1' then
                            speed_internal <= "01";  -- 1000 rpm 
                        elsif switches(8) = '1' then
                            speed_internal <= "10";  -- 1200 rpm
                        end if;
                    else
                        speed_valid <= '0';
                    end if;

                    -- optional features 
                    prewash_internal     <= switches(9);   --SW9
                    extra_rinse_internal <= switches(10);  -- SW10

                when "001" =>  -- quick wash: 30 C, 1200rpm, no extras
                    temp_internal        <= "00";  -- 30 C
                    speed_internal       <= "10";  -- 1200rpm
                    prewash_internal     <= '0';
                    extra_rinse_internal <= '0';
                    temp_valid           <= '1';
                    speed_valid          <= '1';

                when "010" =>  -- shirts: 60 C, 800rpm, no extras
                    temp_internal        <= "10";  -- 60 C
                    speed_internal       <= "00";  -- 800rpm
                    prewash_internal     <= '0';
                    extra_rinse_internal <= '0';
                    temp_valid           <= '1';
                    speed_valid          <= '1';

                when "011" =>  -- drk colors: 40 C, 1000rpm, extra rinse
                    temp_internal        <= "01";  -- 40 C
                    speed_internal       <= "01";  -- 1000rpm
                    prewash_internal     <= '0';
                    extra_rinse_internal <= '1';
                    temp_valid           <= '1';
                    speed_valid          <= '1';

                when "100" =>  -- dirty laundry: 40 C, 1000rpm, prewash
                    temp_internal        <= "01";  -- 40 C
                    speed_internal       <= "01";  -- 1000rpm
                    prewash_internal     <= '1';
                    extra_rinse_internal <= '0';
                    temp_valid           <= '1';
                    speed_valid          <= '1';

                when "101" =>  -- antiallergic: 90 C, 1200rpm, extra rinse
                    temp_internal        <= "11";  -- 90 C
                    speed_internal       <= "10";  -- 1200rpm
                    prewash_internal     <= '0';
                    extra_rinse_internal <= '1';
                    temp_valid           <= '1';
                    speed_valid          <= '1';

                when others =>
                    temp_internal        <= "00";
                    speed_internal       <= "00";
                    prewash_internal     <= '0';
                    extra_rinse_internal <= '0';
                    temp_valid           <= '0';
                    speed_valid          <= '0';
            end case;
        end if;
    end process;

    temp         <= temp_internal;
    speed        <= speed_internal;
    prewash      <= prewash_internal;
    extra_rinse  <= extra_rinse_internal;
    params_valid <= temp_valid and speed_valid;

end Behavioral;
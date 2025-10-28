library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mode_selector is
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        machine_on : in STD_LOGIC;
        select_btn : in STD_LOGIC;
        mode : out STD_LOGIC_VECTOR(2 downto 0)
    );
end mode_selector;

architecture Behavioral of mode_selector is
    signal current_mode : STD_LOGIC_VECTOR(2 downto 0) := "000";
begin

    process(clk, reset)
    begin
        if reset = '1' then
            current_mode <= "000"; 
        elsif rising_edge(clk) then
            if machine_on = '0' then
                current_mode <= "000";  
            elsif select_btn = '1' then
                -- modes: Manual-> Quick wash-> Shirts->Dark colors->Dirty laundry->Antiallergic-> Manual
                case current_mode is
                  when "000" => current_mode <= "001";  -- manual (000) -> quick wash (001)
                when "001" => current_mode <= "010";  -- quick wash (001) -> shirts (010)
                when "010" => current_mode <= "011";  -- shirts (010) -> dark colors (011)
                when "011" => current_mode <= "100";  -- dark colors (011) -> dirty laundry (100)
                when "100" => current_mode <= "101";  -- dirty laundry (100) -> antiallergic (101)
                when "101" => current_mode <= "000";  -- antiallergic (101) -> manual (000)
                when others => current_mode <= "000"; -- default to manual
                end case;
            end if;
        end if;
    end process;
    
    mode <= current_mode;

end Behavioral;
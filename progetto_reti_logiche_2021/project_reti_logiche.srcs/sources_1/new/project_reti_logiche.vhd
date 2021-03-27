----------------------------------------------------------------------------------
-- Description: Prova finale di reti logiche 2021
--
-- Author: Margherita Musumeci - 10600069 - 907435
-- Author: Matteo Oldani - 10620207 - 910756
-- 
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port ( i_clk : in std_logic;
           i_rst : in std_logic;
           i_start : in std_logic;
           i_data : in std_logic_vector(7 downto 0);
           o_address : out std_logic_vector(15 downto 0);
           o_done : out std_logic;
           o_en : out std_logic;
           o_we : out std_logic;
           o_data : out std_logic_vector(7 downto 0)
           );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    --tutti i possibili stati che la macchina può assumere
    type type_state is (START,
						ENABLE_LETTURA_RAM,
						WAIT_RAM,
						LEGGI_COLONNE,
						LEGGI_RIGHE,
						CALCOLA_MAX_MIN,
						INIZIALIZZA_VARIABILI,
						CALCOLA_NUOVO_PIXEL,
						SCRIVI_IN_MEMORIA,
						DONE,
						RESET);
    signal next_state: type_state;
    signal address_read : std_logic_vector(15 downto 0) := (others => '0');
    signal address_write : std_logic_vector(15 downto 0) := (others => '0');
	
begin

    stato_prossimo : process(i_clk, i_rst)
    
    variable delta : unsigned(8 downto 0) := (others => '0'); --differenza max - min
    variable shift : unsigned(3 downto 0) := (others => '0'); --di quante posizioni mi devo spostare
    variable temp : unsigned(15 downto 0) := (others => '0'); --pixel ricalcolato
    variable max : unsigned(7 downto 0) := (others => '0');
    variable min : unsigned(7 downto 0) := (others => '1');
    variable colonne : unsigned(7 downto 0) := (others => '0'); --numero di colonne, può andare da 0 a 128 quindi per ora ho messo 8 bit
    variable righe : unsigned(7 downto 0) := (others => '0'); --numero di righe, può andare da 0 a 128 quindi per ora ho messo 8 bit
    variable log: unsigned(3 downto 0) := (others => '0'); --risultato del logaritmo
    variable esp: unsigned(9 downto 0) := "0000000001"; --variabile ausiliaria al calcolo del logaritmo
    variable count : unsigned(15 downto 0) := (others => '0'); --righe * colonne
    variable scelta_lettura : std_logic; --per capire se siamo nella lettura per stabilire max o min oppure se siamo nella lettura per modificare, 0 max/min 1 altro
    
    begin
        if (i_rst = '1') then
            address_read <= "0000000000000000";
            address_write <="0000000000000000";
            o_address <= "0000000000000000";
            o_data <= "00000000";
            o_en <= '0';
            o_we <= '0';
            o_done <= '0';
            next_state <= START; 
        end if;
		
        if (rising_edge(i_clk)) then
        case next_state is
        
            when START =>
                if (i_start='1') then
                    address_read <= "0000000000000000";
                    address_write <="0000000000000000";
                    o_address <= "0000000000000000";
                    o_data <= "00000000";
                    o_en <= '0';
                    o_we <= '0';
                    o_done <= '0';
					--scelta di reinizializzare tutti i valori qua, e non nello stato di reset, 
					--dettata dal fatto che il segnale asicnrono i_rst può essere chiamao in qualunque momento della computazione
					delta := "000000000";
					shift := "0000";
					temp := "0000000000000000";
					max := "00000000";
					min := "11111111";
					colonne := "00000000";
					righe := "00000000";
					log := "0000";
					esp := "0000000001";
					count := "0000000000000000";
					scelta_lettura := '0';
                    next_state <= ENABLE_LETTURA_RAM;
                else
                    next_state <= START;
                end if;
                
            when ENABLE_LETTURA_RAM =>
                o_en <= '1';
                o_address <= address_read; --imposto dove deve leggere la ram
                next_state <= WAIT_RAM; --stato di attesa per la lettura da ram
               
            when WAIT_RAM =>
                o_en <= '0';
                if(address_read = "0000000000000000") then 
                    next_state <= LEGGI_COLONNE;
                else if(address_read = "0000000000000001") then
                    next_state <= LEGGI_RIGHE;
                else
                    --scelta di che tipo di lettura si tratta
                    if(scelta_lettura = '0') then
                        next_state <= CALCOLA_MAX_MIN;
                    else 
                        next_state <= CALCOLA_NUOVO_PIXEL;
                    end if;
                end if;
                end if;
                address_read <= std_logic_vector(UNSIGNED(address_read) + 1);
                   
            when LEGGI_COLONNE =>
                colonne := UNSIGNED(i_data);
                next_state <= ENABLE_LETTURA_RAM;

            when LEGGI_RIGHE =>
                righe := UNSIGNED(i_data);
                count := righe * colonne;
                --se l'immagine è vuota non devo fare nulla
                if(count = 0) then 
                    next_state <= DONE;
                else
                    next_state <= ENABLE_LETTURA_RAM;
                end if;
                
            when CALCOLA_MAX_MIN =>
                --verifico massimo 
                if(max < UNSIGNED(i_data)) then
                    max := UNSIGNED(i_data);
                end if;
                --verifico minimo 
                if(min > UNSIGNED(i_data)) then
                    min := UNSIGNED(i_data);
                end if;
                count := count - 1;
                --se ho finito di contare devo prepararmi alla lettura per modifica
                if(count = 0) then 
                    next_state <= INIZIALIZZA_VARIABILI;
                else
                    next_state <= ENABLE_LETTURA_RAM;
                end if;
                  
            when INIZIALIZZA_VARIABILI =>
                count := righe * colonne;
                delta := resize(max-min, 9);
                delta := delta + 1;
                --calcolo log 
                for i in 0 to 9 loop 
                    if( esp > delta) then 
                        log := to_unsigned(i, 4) - 1; 
                        exit; 
                    end if;
				esp := resize(shift_left(esp, 1), 10); --cambiato da un * 2
				
                end loop;
                shift := 8 - log;
                scelta_lettura := '1';
                address_read <= "0000000000000010"; --mi rimetto dopo le dimensioni per leggere di nuovo tutto
                address_write <= std_logic_vector( 2 + count); --mi metto dopo l'immagine originale per potere scrivere
                next_state <= ENABLE_LETTURA_RAM;
                
            when CALCOLA_NUOVO_PIXEL => 
                --applicazione dell'algoritmo della specifica
                temp := "0000000000000000"; --reinizializzo temp
                temp := resize((UNSIGNED(i_data) - min), 16); 
                temp := resize(shift_left(temp, TO_INTEGER(shift)), 16);
                
                if(temp < 255) then 
                    o_data <= std_logic_vector(resize(temp, 8)); --se siamo minori di 255 comunque la resize non mi fa perfere informazioni        
                else 
                    o_data <= "11111111"; --scrivo 255
                end if;
                o_address <= address_write; 
                o_en <= '1';
                o_we <= '1';
                next_state <= SCRIVI_IN_MEMORIA;
               
            when SCRIVI_IN_MEMORIA =>
                address_write <= std_logic_vector(UNSIGNED(address_write) + 1);
                o_we <= '0';
                o_en <= '0';
				count := count - 1;
                if(count = 0) then 
                    next_state <= DONE;
				else 
				next_state <= ENABLE_LETTURA_RAM; 
                end if;
				
			when DONE =>
                o_done <= '1';
                next_state <= RESET;

            when RESET =>
                if (i_start = '0') then
                    o_done <= '0';
                    o_en <= '0';
                    o_we <= '0';
                    next_state <= START;
                end if;
		end case;
        end if;
    end process;  
	
end Behavioral;

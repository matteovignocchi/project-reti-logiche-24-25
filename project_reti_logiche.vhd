library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;



entity project_reti_logiche is
    port (
        i_clk : in std_logic;   
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);
        
        o_done : out std_logic;
        
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );


end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_type is (IDLE, 
                        DONE, 
                        COLLECTING_DATA_1, 
                        COLLECTING_DATA_2, 
                        FLTR_3, 
                        FLTR_5, 
                        NORM_3, 
                        NORM_5, 
                        READ_1, 
                        READ_2,
                        READ_3,
                        OUTPUT_0, 
                        OUTPUT_1, 
                        OUTPUT_2); 
    signal state : state_type;
    signal input_address : std_logic_vector (15 downto 0);
    signal output_address: std_logic_vector (15 downto 0);
    signal output_data: std_logic_vector ( 7 downto 0 );
    type byte_array is array (natural range <>) of signed (7 downto 0); 
    
begin

process(i_clk, i_rst)
    variable coeff_3 : byte_array(0 to 6);
    variable coeff_5 : byte_array(0 to 6);
    variable shift_array : byte_array ( 0 to 6);
   
    variable address_counter : integer range 0 to 17;
    variable data_counter : integer range 0 to 17;
    variable flag : boolean;
    
    variable K_hi : unsigned ( 7 downto 0);
    variable K_lo : unsigned ( 7 downto 0);
    variable K : integer range 0 to 65535;
    variable S : unsigned (7 downto 0);
    variable index_3 : integer range 0 to 6;
    variable index_5 : integer range 0 to 6;        
    variable input_counter : integer;
    variable read_counter : integer;
    variable head_zero : integer range 0 to 4;
    variable tail_zero : integer range 0 to 3;

    variable sum_tmp  : integer;
    variable norm_tmp : integer;
    variable tmp4, tmp6, tmp8, tmp10 : integer;
    
    variable sum_index : integer;



    begin
    if i_rst = '1' then
   

        --SIGNALS
        o_done <= '0';
        o_mem_we <= '0';
        o_mem_en <= '0';
    
        --ADDRESSES
        input_address <= (others => '0');
        output_address <= (others => '0');
   
        --COUNTERES AND FLAG
        input_counter := 0;
        read_counter := 0;
        address_counter := 0;
        data_counter := 0; 
        flag := false;
        
        
        --S K AND COEFFICENT FOR THE FILTER
        S := (others => '0');
        K := 0;
        coeff_3 := (others => (others => '0'));
        coeff_5 := (others => (others => '0'));
        index_3 := 0;
        index_5 := 0;
        tail_zero := 0;
        head_zero := 0;
        
        -- TEMPS
        sum_tmp := 0;
        norm_tmp := 0;
        tmp4 := 0;
        tmp6 := 0;
        tmp8 := 0;
        tmp10 := 0;
        
     
        
        --ARRAY FOR THE INPUT DATA
        shift_array := (others => (others=> '0'));
        
        output_data <= (others => '0');
        
        state <= IDLE;
    elsif rising_edge(i_clk) then 
        
          
        case state is 
            when IDLE =>
 
                if  i_start = '1' then
                    input_counter := 0;
                    flag := false;
                    index_3 := 0;
                    index_5 := 0;
                    shift_array := (others => (others=> '0'));
                    
                    address_counter := 0;
                    data_counter := 0;
                    read_counter := 0;
                    tail_zero := 0;
                    head_zero:= 0;
                    sum_tmp := 0;
                    norm_tmp := 0;
                    tmp4 := 0;
                    tmp6 := 0;
                    tmp8 := 0;
                    tmp10 := 0;
                    
                    output_data <= ( others => '0');
                        
                    input_address <= i_add;
                    state <= COLLECTING_DATA_1;    
                end if;
                      
            when COLLECTING_DATA_1 =>
                o_mem_addr <= std_logic_vector(unsigned(input_address) + to_unsigned(address_counter, 16));
                o_mem_en <= '1';
                o_mem_we <= '0';
                state <= COLLECTING_DATA_2;
                
            when COLLECTING_DATA_2 =>
                if flag = false then
                    flag   := true;
                    if address_counter < 17 then
                    address_counter := address_counter + 1;       
                    state <= COLLECTING_DATA_1;
                    else
                        null;
                    end if;
                else
                    case data_counter is
                        when 0 =>
                            K_hi := unsigned(i_mem_data);
                         when 1 =>
                            K_lo := unsigned(i_mem_data);
                            K:= to_integer(unsigned(K_hi & K_lo));
                        when 2 =>
                            S := unsigned(i_mem_data);
                            if S(0) = '0' then
                                head_zero := 2;
                                tail_zero := 2;
                            else
                                head_zero := 3;
                                tail_zero := 3;
                            end if;
                        when 3 => coeff_3(0) := signed(i_mem_data);
                        when 4 => coeff_3(1) := signed(i_mem_data);
                        when 5 => coeff_3(2) := signed(i_mem_data);
                        when 6 => coeff_3(3) := signed(i_mem_data);
                        when 7 => coeff_3(4) := signed(i_mem_data);
                        when 8 => coeff_3(5) := signed(i_mem_data);
                        when 9 => coeff_3(6) := signed(i_mem_data);
                        when 10 => coeff_5(0) := signed(i_mem_data);
                        when 11 => coeff_5(1) := signed(i_mem_data);
                        when 12 => coeff_5(2) := signed(i_mem_data);
                        when 13 => coeff_5(3) := signed(i_mem_data);
                        when 14 => coeff_5(4) := signed(i_mem_data);
                        when 15 => coeff_5(5) := signed(i_mem_data);
                        when 16 => coeff_5(6) := signed(i_mem_data);
                        when 17 => output_address <= std_logic_vector(unsigned(input_address) + to_unsigned(17,16) + to_unsigned(K,16));
                state <= READ_1;
                end case;

                if data_counter < 17 then
                    data_counter := data_counter + 1;
                if address_counter < 17 then
                    address_counter := address_counter + 1;  
                end if;
                state <= COLLECTING_DATA_1;
            end if;
        end if;
                
           
              
        when READ_1 =>
            if K = 0 then
                o_mem_en <= '0';
                o_mem_we <= '0';
                o_done   <= '1';
                state    <= DONE;
             else
                o_mem_en   <= '1';
                o_mem_we   <= '0';
                o_mem_addr <= std_logic_vector(unsigned(input_address) + to_unsigned(17,16) + to_unsigned(read_counter,16));
        
                state <= READ_2;
            end if;
             
        when READ_2 =>
        
            o_mem_en <= '0';
            o_mem_we <= '0';
            state<= READ_3;
   
                
        when READ_3 =>
            shift_array(0) := shift_array(1);
            shift_array(1) := shift_array(2);
            shift_array(2) := shift_array(3);
            shift_array(3) := shift_array(4);
            shift_array(4) := shift_array(5);
            shift_array(5) := shift_array(6);

            if read_counter < K then
                shift_array(6) := signed(i_mem_data); 
                read_counter := read_counter + 1;
            elsif tail_zero > 0 then
                shift_array(6) := (others => '0');
                tail_zero := tail_zero - 1;
            else
                shift_array(6) := (others => '0');
            end if;

            o_mem_en <= '0';
            o_mem_we <= '0';


            if head_zero > 0 then
                head_zero := head_zero - 1;
                state <= READ_1;
            else
                o_mem_en <='0';


                if S(0) = '0' then
                    state <= FLTR_3;
                else
                    state <= FLTR_5;
                end if;
            end if; 
            when FLTR_3 =>
            
               sum_tmp := 0;
               for k in 1 to 5 loop
                  sum_index := k + 1;  
                 
                  sum_tmp := sum_tmp + to_integer(coeff_3(k)) * to_integer(shift_array(sum_index));
                end loop;

                state <= NORM_3;
                
            when FLTR_5 =>
                 sum_tmp := 0;
                 for k in 0 to 6 loop
                  sum_index := k + 1;  -- centro a SA(4)
                  if (sum_index >= 0) and (sum_index <= 6) then
                    sum_tmp := sum_tmp + to_integer(coeff_5(k)) * to_integer(shift_array(sum_index));
                  end if;  
                end loop;
                 state <= NORM_5;
                 
            when NORM_3 =>
                o_mem_en <= '0';
                tmp4  := to_integer( shift_right (to_signed (sum_tmp, 18 ), 4));
 
                if tmp4  < 0 then 
                    tmp4  := tmp4  + 1; 
                end if;
                tmp6  := to_integer( shift_right (to_signed (sum_tmp, 18 ), 6));
                if tmp6  < 0 then 
                    tmp6  := tmp6  + 1; 
                end if;
                tmp8  := to_integer( shift_right (to_signed (sum_tmp, 18 ), 8));
                if tmp8  < 0 then 
                    tmp8  := tmp8  + 1; 
                end if;
                tmp10  := to_integer( shift_right (to_signed (sum_tmp, 18 ), 10));
                if tmp10 < 0 then 
                    tmp10 := tmp10 + 1; 
                end if;

                
                norm_tmp :=  tmp4 + tmp6 + tmp8 +tmp10;

                if norm_tmp > 127 then
                    output_data <= std_logic_vector(to_signed(127, 8));
                elsif norm_tmp < -128 then
                    output_data <= std_logic_vector(to_signed(-128, 8));
                else
                    output_data <= std_logic_vector(to_signed(norm_tmp, 8));
                end if;
                state <= OUTPUT_0;

            when NORM_5 =>
                o_mem_en <= '0';
                tmp6  := to_integer( shift_right (to_signed (sum_tmp, 18 ), 6));
                if tmp6  < 0 then 
                    tmp6  := tmp6  + 1; 
                end if;
                
                tmp10  := to_integer( shift_right (to_signed (sum_tmp, 18 ), 10));
                if tmp10 < 0 then 
                    tmp10 := tmp10 + 1; 
                end if;
                
                
                norm_tmp :=  tmp6 + tmp10;
                if norm_tmp > 127 then
                    output_data <= std_logic_vector(to_signed(127, 8));
                elsif norm_tmp < -128 then
                    output_data <= std_logic_vector(to_signed(-128, 8));
                else
                    output_data <= std_logic_vector(to_signed(norm_tmp, 8));
                end if;
                state <= OUTPUT_0;

                
            when OUTPUT_0 =>

               o_mem_addr <= std_logic_vector(unsigned(output_address) + to_unsigned(input_counter, 16) );
                o_mem_data <= output_data;
                state <= OUTPUT_1;
                
            when OUTPUT_1 =>
                o_mem_we <= '1';
                o_mem_en <= '1';
                

                state <= OUTPUT_2;
                
            when OUTPUT_2 =>
                o_mem_we <= '0';
                o_mem_en <= '0';
                
                if input_counter = (K -1 ) then
                    state <= DONE;
                    o_done <= '1';
                    
                else 
                    input_counter := input_counter +1;
                    state <= READ_1;
                end if;
                
            when DONE =>
                o_mem_we <= '0';
                o_mem_en <= '0';
                
                if i_start = '0' then
                    o_done <= '0';
                    state <= IDLE;
                end if;
            
            when others =>
                    state <= IDLE;  
        end case;
    end if;
end process;
    


end Behavioral;
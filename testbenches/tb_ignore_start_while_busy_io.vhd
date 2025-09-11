-- tb_ignore_start_while_busy_io.vhd  (VHDL-2008) -- Corner: START glitch mentre busy
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale)
entity rams_sp_wf_glitch is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_glitch is
  type ram_t is array(0 to 65535) of std_logic_vector(7 downto 0);
  signal RAM: ram_t := (others => (others => '0'));
begin
  process(clk) begin
    if rising_edge(clk) then
      if en='1' then
        if we='1' then
          RAM(to_integer(unsigned(addr))) <= di;
          do <= di after 2 ns;
        else
          do <= RAM(to_integer(unsigned(addr))) after 2 ns;
        end if;
      end if;
    end if;
  end process;
end architecture;

-- ======================= TESTBENCH =======================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity tb_ignore_start_while_busy_io is end tb_ignore_start_while_busy_io;

architecture tb of tb_ignore_start_while_busy_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#2800#,16);
  constant ONE16    : unsigned(15 downto 0) := to_unsigned(1,16);

  -- DUT I/F
  signal i_clk,i_rst,i_start : std_logic := '0';
  signal i_add  : std_logic_vector(15 downto 0) := (others=>'0');
  signal o_done : std_logic;
  signal o_mem_addr: std_logic_vector(15 downto 0);
  signal i_mem_data: std_logic_vector(7 downto 0);
  signal o_mem_data: std_logic_vector(7 downto 0);
  signal o_mem_we,o_mem_en: std_logic;

  -- MUX TB/DUT -> RAM
  signal sel_tb              : std_logic := '0';
  signal tb_en,tb_we         : std_logic := '0';
  signal tb_addr             : std_logic_vector(15 downto 0) := (others=>'0');
  signal tb_di               : std_logic_vector(7 downto 0)  := (others=>'0');

  signal ram_en,ram_we       : std_logic := '0';
  signal ram_addr            : std_logic_vector(15 downto 0);
  signal ram_di,ram_do       : std_logic_vector(7 downto 0);

  -- helper: K in due byte
  function msb(x:natural) return integer is begin return (x/256) mod 256; end;
  function lsb(x:natural) return integer is begin return x mod 256; end;

  -- writer TB (ramo TB del MUX)
  procedure ram_write_tb(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; addr:in unsigned(15 downto 0); val:in integer
  ) is
  begin
    p_sel_tb<='1'; p_tb_en<='1'; p_tb_we<='1';
    p_tb_addr<=std_logic_vector(addr);
    p_tb_di  <=std_logic_vector(to_signed(val,8));
    wait until rising_edge(p_clk);
    p_tb_en<='0'; p_tb_we<='0'; p_sel_tb<='0';
  end procedure;

  -- scrive preambolo + C1..C14 (coefficienti fissi da specifica)
  procedure write_preamble_and_coeff(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; base:in unsigned(15 downto 0); Kval: in integer; Sval: in integer
  ) is
    variable a : unsigned(15 downto 0);
  begin
    a := base;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,msb(Kval)); a:=a+ONE16; -- K1
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,lsb(Kval)); a:=a+ONE16; -- K2
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,Sval);      a:=a+ONE16; -- S
    -- C1..C7 (ordine-3): 0,-1,8,0,-8,1,0
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 8); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-8); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    -- C8..C14 (ordine-5): 1,-9,45,0,-45,9,-1
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-9);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 45); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-45); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 9);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1);  a:=a+ONE16;
  end procedure;

  -- pattern W deterministici (senza array)
  function w_runA(i: integer) return integer is  -- per ordine-3
    variable p : integer := i mod 12;
  begin
    case p is
      when 0  => return 10;
      when 1  => return -8;
      when 2  => return 6;
      when 3  => return -4;
      when 4  => return 3;
      when 5  => return -2;
      when 6  => return 1;
      when 7  => return 0;
      when 8  => return 15;
      when 9  => return -15;
      when 10 => return 20;
      when others => return -20;
    end case;
  end function;

  function w_runB(i: integer) return integer is  -- per ordine-5
    variable p : integer := i mod 14;
  begin
    case p is
      when 0  => return 5;
      when 1  => return -5;
      when 2  => return 7;
      when 3  => return -7;
      when 4  => return 9;
      when 5  => return -9;
      when 6  => return 11;
      when 7  => return -11;
      when 8  => return 13;
      when 9  => return -13;
      when 10 => return 0;
      when 11 => return 4;
      when 12 => return -4;
      when others => return 0;
    end case;
  end function;

begin
  -- clock
  i_clk <= not i_clk after CLK_PER/2;

  -- MUX verso RAM
  ram_en   <= tb_en   when sel_tb='1' else o_mem_en;
  ram_we   <= tb_we   when sel_tb='1' else o_mem_we;
  ram_addr <= tb_addr when sel_tb='1' else o_mem_addr;
  ram_di   <= tb_di   when sel_tb='1' else o_mem_data;
  i_mem_data <= ram_do;

  -- istanze
  u_ram: entity work.rams_sp_wf_glitch
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stim + proprietà: glitch START ignorati durante busy
  stim: process
    constant K_A : integer := 24;  -- run A (ordine-3)
    constant K_B : integer := 28;  -- run B (ordine-5)

    variable out_base : unsigned(15 downto 0);
    variable wr_cnt  : integer;
    variable first_wr_addr, prev_wr_addr : integer;
    variable saw_after_done, dropped : boolean;

    variable addr_cursor : unsigned(15 downto 0);
    variable v : integer;
    variable cyc : integer;
  begin
    ----------------------------------------------------------------
    -- RUN A: S(0)=0 (ordine-3) con glitch START mentre o_done=0
    ----------------------------------------------------------------
    -- reset e preload
    i_rst  <='1'; i_start<='0'; i_add<=std_logic_vector(BASE_ADD);
    wait for 40 ns;
    write_preamble_and_coeff(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD,K_A,0);

    -- carica W
    addr_cursor := BASE_ADD + to_unsigned(17,16);
    for i in 0 to K_A-1 loop
      v := w_runA(i);
      ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk, addr_cursor, v);
      addr_cursor := addr_cursor + ONE16;
    end loop;

    -- rilascia reset, start
    wait until rising_edge(i_clk); i_rst<='0';
    out_base := BASE_ADD + to_unsigned(17+K_A,16);
    wait until rising_edge(i_clk); i_start<='1';
    wait until rising_edge(i_clk); i_start<='0';  -- impulso di start

    -- monitor + iniezione glitch
    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;
    cyc := 0;

    while o_done='0' loop
      wait until rising_edge(i_clk);
      cyc := cyc + 1;

      -- GLITCH: ogni 7 cicli forza i_start='1' per 1 ciclo (mentre busy)
      if (cyc mod 7) = 0 then
        i_start <= '1';
      else
        i_start <= '0';
      end if;

      -- proprietà su write
      if o_mem_en='1' and o_mem_we='1' then
        assert unsigned(o_mem_addr) >= out_base
          report "Write before ADD+17+K (run A)" severity failure;
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        elsif wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes (run A)" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- fine run: porta START a 0 stabile e controlla handshake
    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    assert dropped report "DONE did not drop after START=0 (run A)" severity failure;
    assert not saw_after_done report "Writes after DONE=1 (run A)" severity failure;
    assert first_wr_addr = to_integer(out_base) report "First write != ADD+17+K (run A)" severity failure;
    assert wr_cnt = K_A report "Number of writes != K (run A)" severity failure;

    ----------------------------------------------------------------
    -- RUN B: S(0)=1 (ordine-5) con glitch START mentre o_done=0
    ----------------------------------------------------------------
    -- reset e preload
    i_rst  <='1'; i_start<='0';
    wait for 40 ns;
    write_preamble_and_coeff(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD,K_B,1);

    -- carica W
    addr_cursor := BASE_ADD + to_unsigned(17,16);
    for i in 0 to K_B-1 loop
      v := w_runB(i);
      ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk, addr_cursor, v);
      addr_cursor := addr_cursor + ONE16;
    end loop;

    -- rilascia reset, start
    wait until rising_edge(i_clk); i_rst<='0';
    out_base := BASE_ADD + to_unsigned(17+K_B,16);
    wait until rising_edge(i_clk); i_start<='1';
    wait until rising_edge(i_clk); i_start<='0';

    -- monitor + glitch
    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;
    cyc := 0;

    while o_done='0' loop
      wait until rising_edge(i_clk);
      cyc := cyc + 1;

      if (cyc mod 5) = 0 then  -- glitch più frequenti
        i_start <= '1';
      else
        i_start <= '0';
      end if;

      if o_mem_en='1' and o_mem_we='1' then
        assert unsigned(o_mem_addr) >= out_base
          report "Write before ADD+17+K (run B)" severity failure;
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        elsif wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes (run B)" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- handshake
    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    assert dropped report "DONE did not drop after START=0 (run B)" severity failure;
    assert not saw_after_done report "Writes after DONE=1 (run B)" severity failure;
    assert first_wr_addr = to_integer(out_base) report "First write != ADD+17+K (run B)" severity failure;
    assert wr_cnt = K_B report "Number of writes != K (run B)" severity failure;

    report "tb_ignore_start_while_busy_io OK" severity note;
    wait;
  end process;
end architecture;

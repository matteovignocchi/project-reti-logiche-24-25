-- tb_k_small_edges_io.vhd  (VHDL-2008) -- Corner: K = 1, 2, 3  -- versione senza array
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale)
entity rams_sp_wf_kedges is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_kedges is
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
entity tb_k_small_edges_io is end tb_k_small_edges_io;

architecture tb of tb_k_small_edges_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#2600#,16);
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
  function msb(x:natural) return integer is
  begin
    return (x/256) mod 256;
  end function;
  function lsb(x:natural) return integer is
  begin
    return x mod 256;
  end function;

  -- writer TB (ramo TB del mux)
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

  -- scrive preambolo (K1,K2,S) + C1..C14 (numeri letterali) + W0..W2 a seconda di Kval
  procedure preload_all_KS_noarray(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; base:in unsigned(15 downto 0);
    Kval: in integer; Sval: in integer; W0: in integer; W1: in integer; W2: in integer
  ) is
    variable a : unsigned(15 downto 0);
  begin
    a := base;
    -- K1,K2,S
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,msb(Kval)); a:=a+ONE16; -- K1
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,lsb(Kval)); a:=a+ONE16; -- K2
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,Sval);      a:=a+ONE16; -- S
    -- C1..C7 (ordine-3)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16; -- C1
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1); a:=a+ONE16; -- C2
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 8); a:=a+ONE16; -- C3
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16; -- C4
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-8); a:=a+ONE16; -- C5
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1); a:=a+ONE16; -- C6
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16; -- C7
    -- C8..C14 (ordine-5)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1);  a:=a+ONE16; -- C8
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-9);  a:=a+ONE16; -- C9
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 45); a:=a+ONE16; -- C10
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0);  a:=a+ONE16; -- C11
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-45); a:=a+ONE16; -- C12
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 9);  a:=a+ONE16; -- C13
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1);  a:=a+ONE16; -- C14
    -- W (solo i primi Kval valori)
    if Kval >= 1 then
      ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,W0); a:=a+ONE16;
    end if;
    if Kval >= 2 then
      ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,W1); a:=a+ONE16;
    end if;
    if Kval >= 3 then
      ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,W2); a:=a+ONE16;
    end if;
  end procedure;

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
  u_ram: entity work.rams_sp_wf_kedges
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stim + proprietà per K=1,2,3 (nessun array)
  stim: process
    variable out_base : unsigned(15 downto 0);
    variable wr_cnt  : integer;
    variable first_wr_addr, prev_wr_addr : integer;
    variable saw_after_done, dropped : boolean;

    procedure run_one_case(Kv: in integer; Sval: in integer; W0: in integer; W1: in integer; W2: in integer) is
    begin
      -- reset e ADD
      i_rst  <='1';
      i_start<='0';
      i_add  <= std_logic_vector(BASE_ADD);
      wait for 40 ns;

      -- preload per questo K (senza array)
      preload_all_KS_noarray(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD,Kv,Sval,W0,W1,W2);

      -- rilascia reset e avvia
      wait until rising_edge(i_clk); i_rst<='0';
      out_base := BASE_ADD + to_unsigned(17+Kv,16);
      wait until rising_edge(i_clk); i_start<='1';

      -- monitor fino a DONE
      wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;
      while o_done='0' loop
        wait until rising_edge(i_clk);
        if o_mem_en='1' and o_mem_we='1' then
          -- non scrivere prima della base
          assert unsigned(o_mem_addr) >= out_base
            report "Write before ADD+17+K" severity failure;

          -- cattura prima write e contiguità
          wr_cnt := wr_cnt + 1;
          if first_wr_addr = -1 then
            first_wr_addr := to_integer(unsigned(o_mem_addr));
          elsif wr_cnt > 1 then
            assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
              report "Non-contiguous writes" severity failure;
          end if;
          prev_wr_addr := to_integer(unsigned(o_mem_addr));
        end if;
      end loop;

      -- handshake: START a 0, DONE deve scendere
      i_start<='0'; dropped:=false;
      for t in 0 to 1023 loop
        wait until rising_edge(i_clk);
        if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
        if o_done='0' then dropped:=true; exit; end if;
      end loop;

      -- check finali per questo K
      assert dropped report "DONE did not drop after START=0" severity failure;
      assert not saw_after_done report "Writes after DONE=1" severity failure;
      assert first_wr_addr = to_integer(out_base) report "First write != ADD+17+K" severity failure;
      assert wr_cnt = Kv report "Number of writes != K" severity failure;
    end procedure;

  begin
    -- RUN A: K=1, S LSB=0 (ordine-3)  -- W = (7)
    run_one_case(1, 0, 7, 0, 0);

    -- RUN B: K=2, S LSB=1 (ordine-5)  -- W = (5, -5)
    run_one_case(2, 1, 5, -5, 0);

    -- RUN C: K=3, S LSB=0 (ordine-3)  -- W = (10, -10, 20)
    run_one_case(3, 0, 10, -10, 20);

    report "tb_k_small_edges_io OK" severity note;
    wait;
  end process;
end architecture;

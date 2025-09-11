-- tb_minK_edges_io.vhd  (VHDL-2008)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale, nome univoco)
entity rams_sp_wf_minio is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_minio is
  type ram_t is array(0 to 65535) of std_logic_vector(7 downto 0);
  signal RAM: ram_t := (others=>(others=>'0'));
begin
  process(clk) begin
    if rising_edge(clk) then
      if en='1' then
        if we='1' then RAM(to_integer(unsigned(addr)))<=di; do<=di after 2 ns;
        else do<=RAM(to_integer(unsigned(addr))) after 2 ns; end if;
      end if;
    end if;
  end process;
end architecture;

library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity tb_minK_edges_io is end tb_minK_edges_io;

architecture tb of tb_minK_edges_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#1400#,16);
  constant ONE16    : unsigned(15 downto 0) := to_unsigned(1,16);

  -- DUT I/F
  signal i_clk,i_rst,i_start : std_logic := '0';
  signal i_add  : std_logic_vector(15 downto 0) := (others=>'0');
  signal o_done : std_logic;
  signal o_mem_addr: std_logic_vector(15 downto 0);
  signal i_mem_data: std_logic_vector(7 downto 0);
  signal o_mem_data: std_logic_vector(7 downto 0);
  signal o_mem_we,o_mem_en: std_logic;

  -- RAM mux per TB
  signal sel_tb, ram_en, ram_we : std_logic := '0';
  signal ram_addr : std_logic_vector(15 downto 0);
  signal ram_di, ram_do : std_logic_vector(7 downto 0);
  signal tb_en, tb_we : std_logic := '0';
  signal tb_addr : std_logic_vector(15 downto 0) := (others=>'0');
  signal tb_di   : std_logic_vector(7 downto 0)  := (others=>'0');

  -- dati minimi
  type int_arr is array(natural range <>) of integer;
  constant K  : natural := 7;  -- minimo ammesso
  constant W  : int_arr := ( 101, -86, -12, 41, 87, -123, -127 );
  constant C3 : int_arr := (0,-1,8,0,-8,1,0);
  constant C5 : int_arr := (1,-9,45,0,-45,9,-1);

  -- helper
  function msb(x:natural) return integer is begin return (x/256) mod 256; end;
  function lsb(x:natural) return integer is begin return x mod 256; end;

  -- write comoda (XSim-safe)
  procedure ram_write(
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
begin
  -- clock
  i_clk <= not i_clk after CLK_PER/2;

  -- RAM mux
  ram_en   <= tb_en   when sel_tb='1' else o_mem_en;
  ram_we   <= tb_we   when sel_tb='1' else o_mem_we;
  ram_addr <= tb_addr when sel_tb='1' else o_mem_addr;
  ram_di   <= tb_di   when sel_tb='1' else o_mem_data;
  i_mem_data <= ram_do;

  -- istanze
  u_ram: entity work.rams_sp_wf_minio
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stimolo + check SPEC
  stim: process
    variable a       : unsigned(15 downto 0);
    variable out_base: unsigned(15 downto 0);
    variable wr_cnt  : integer;
    variable first_wr_addr, prev_wr_addr : integer;
    variable saw_after_done, dropped : boolean;
  begin
    -- reset
    i_rst<='1'; wait for 80 ns; i_rst<='0';
    i_add <= std_logic_vector(BASE_ADD);

    -- preambolo (17B) + W(K): [K1][K2][S][C1..C14][W0..W(K-1)]
    a := BASE_ADD;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,msb(K)); a:=a+ONE16;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,lsb(K)); a:=a+ONE16;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,0);      a:=a+ONE16; -- S LSB=0 ? ordine 3
    for i in 0 to 6 loop  ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C3(i)); a:=a+ONE16; end loop; -- C1..C7
    for i in 0 to 6 loop  ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C5(i)); a:=a+ONE16; end loop; -- C8..C14
    for i in 0 to K-1 loop ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,W(i));  a:=a+ONE16; end loop;

    out_base := BASE_ADD + to_unsigned(17+K,16);  -- base scrittura risultati (SPEC)

    -- start
    wait until rising_edge(i_clk); i_start<='1';

    -- tracking scritture
    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;

    -- fino a DONE=1
    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        else
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "WRITE non contigue" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- ACK (SPEC: DONE resta alto finché START non torna 0)
    i_start<='0';
    dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      -- non si deve più scrivere dopo DONE
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then
        saw_after_done := true;
      end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    -- asserzioni finali
    assert dropped report "DONE non è sceso entro 1024 cicli dopo START=0" severity failure;
    assert not saw_after_done report "WRITE dopo DONE=1" severity failure;
    assert first_wr_addr = to_integer(out_base)
      report "Prima WRITE != ADD+17+K (base errata)" severity failure;
    assert wr_cnt = K report "Numero di scritture risultati diverso da K" severity failure;

    report "tb_minK_edges_io OK" severity note;
    wait;
  end process;
end architecture;

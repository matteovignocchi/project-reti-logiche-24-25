-- tb_k_zero_io.vhd (VHDL-2008) -- Caso K=0: nessuna scrittura attesa
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

entity rams_sp_wf_k0 is
  port(clk:in std_logic; we:in std_logic; en:in std_logic;
       addr:in std_logic_vector(15 downto 0);
       di:in std_logic_vector(7 downto 0);
       do:out std_logic_vector(7 downto 0));
end entity;
architecture beh of rams_sp_wf_k0 is
  type ram_t is array(0 to 65535) of std_logic_vector(7 downto 0);
  signal RAM: ram_t := (others=>(others=>'0'));
begin
  process(clk) begin
    if rising_edge(clk) then
      if en='1' then
        if we='1' then RAM(to_integer(unsigned(addr)))<=di; do<=di after 2 ns;
        else             do<=RAM(to_integer(unsigned(addr))) after 2 ns; end if;
      end if;
    end if;
  end process;
end architecture;

library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity tb_k_zero_io is end tb_k_zero_io;

architecture tb of tb_k_zero_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#4300#,16);
  constant ONE16    : unsigned(15 downto 0) := to_unsigned(1,16);

  -- DUT I/F
  signal i_clk,i_rst,i_start : std_logic := '0';
  signal i_add  : std_logic_vector(15 downto 0) := (others=>'0');
  signal o_done : std_logic;
  signal o_mem_addr: std_logic_vector(15 downto 0);
  signal i_mem_data: std_logic_vector(7 downto 0);
  signal o_mem_data: std_logic_vector(7 downto 0);
  signal o_mem_we,o_mem_en: std_logic;

  -- RAM mux
  signal sel_tb,tb_en,tb_we : std_logic := '0';
  signal tb_addr: std_logic_vector(15 downto 0) := (others=>'0');
  signal tb_di  : std_logic_vector(7 downto 0)  := (others=>'0');

  signal ram_en,ram_we : std_logic := '0';
  signal ram_addr: std_logic_vector(15 downto 0);
  signal ram_di,ram_do: std_logic_vector(7 downto 0);

  -- helper
  function msb(x:natural) return integer is begin return (x/256) mod 256; end;
  function lsb(x:natural) return integer is begin return x mod 256; end;

  procedure ram_write_tb(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; addr:in unsigned(15 downto 0); val:in integer) is
  begin
    p_sel_tb<='1'; p_tb_en<='1'; p_tb_we<='1';
    p_tb_addr<=std_logic_vector(addr);
    p_tb_di  <=std_logic_vector(to_signed(val,8));
    wait until rising_edge(p_clk);
    p_tb_en<='0'; p_tb_we<='0'; p_sel_tb<='0';
  end procedure;

  procedure write_preamble_and_coeff(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; base:in unsigned(15 downto 0); Kval: in integer; Sval: in integer) is
    variable a : unsigned(15 downto 0);
  begin
    a := base;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,msb(Kval)); a:=a+ONE16; -- K1 (0)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,lsb(Kval)); a:=a+ONE16; -- K2 (0)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,0);         a:=a+ONE16; -- S (LSB irrilevante qui)
    -- C1..C7 (ord-3)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 8); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-8); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    -- C8..C14 (ord-5)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-9);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 45); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-45); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 9);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1);  a:=a+ONE16;
  end procedure;

begin
  i_clk <= not i_clk after CLK_PER/2;

  ram_en   <= tb_en   when sel_tb='1' else o_mem_en;
  ram_we   <= tb_we   when sel_tb='1' else o_mem_we;
  ram_addr <= tb_addr when sel_tb='1' else o_mem_addr;
  ram_di   <= tb_di   when sel_tb='1' else o_mem_data;
  i_mem_data <= ram_do;

  u_ram: entity work.rams_sp_wf_k0
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  stim: process
    constant KVAL : integer := 0;
    variable wr_cnt : integer;
    variable saw_after_done, dropped : boolean;
    variable out_base : unsigned(15 downto 0);
  begin
    -- reset, preload (K=0)
    i_rst<='1'; i_start<='0'; i_add<=std_logic_vector(BASE_ADD); wait for 40 ns;
    write_preamble_and_coeff(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD,KVAL,0);

    -- nessun W da scrivere (K=0)

    -- start
    wait until rising_edge(i_clk); i_rst<='0';
    out_base := BASE_ADD + to_unsigned(17+KVAL,16); -- = BASE_ADD+17 (solo per completezza)
    wait until rising_edge(i_clk); i_start<='1';
    wait until rising_edge(i_clk); i_start<='0';

    wr_cnt := 0;

    -- monitora fino a DONE
    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        wr_cnt := wr_cnt + 1;
      end if;
    end loop;

    -- handshake: DONE deve scendere quando START=0
    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    -- check: zero write, niente dopo DONE
    assert wr_cnt = 0 report "Sono avvenute WRITE nonostante K=0" severity failure;
    assert dropped report "DONE non sceso dopo START=0" severity failure;
    assert not saw_after_done report "WRITE dopo DONE=1" severity failure;

    report "tb_k_zero_io OK" severity note;
    wait;
  end process;
end architecture;

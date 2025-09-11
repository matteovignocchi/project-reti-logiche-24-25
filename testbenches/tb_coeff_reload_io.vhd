-- tb_coeff_reload_io.vhd  (VHDL-2008)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale, nome univoco)
entity rams_sp_wf_coeffio is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_coeffio is
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
entity tb_coeff_reload_io is end tb_coeff_reload_io;

architecture tb of tb_coeff_reload_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#1500#,16);
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

  -- dati
  type int_arr is array(natural range <>) of integer;
  constant K  : natural := 24;
  -- W moderati (evita saturazioni estreme)
  constant W  : int_arr := (
     20,-15,12,-10,  8, -6,  5, -4,
      3, -2,  1,  0, -1,  2, -3,  4,
     -5,  6, -7,  9, -8, 10, -9, 11
  );
  -- Set coefficienti #1 (SPEC-like)
  constant C3a : int_arr := (0,-1,8,0,-8,1,0);
  constant C5a : int_arr := (1,-9,45,0,-45,9,-1);
  -- Set coefficienti #2 (diversi ma within [-128,127])
  constant C3b : int_arr := (0,-2,10,0,-10,2,0);
  constant C5b : int_arr := (2,-18,50,0,-50,18,-2);

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
  u_ram: entity work.rams_sp_wf_coeffio
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stimolo + check SPEC + confronto run#1 vs run#2 (coeff diversi)
  stim: process
    variable a       : unsigned(15 downto 0);
    variable out_base: unsigned(15 downto 0);

    -- tracking scritture (run#1)
    variable wr_cnt1  : integer; variable first_wr_addr1, prev_wr_addr1 : integer;
    variable saw_after_done1, dropped1 : boolean;
    -- tracking scritture (run#2)
    variable wr_cnt2  : integer; variable first_wr_addr2, prev_wr_addr2 : integer;
    variable saw_after_done2, dropped2 : boolean;

    -- capture dei risultati direttamente dai dati scritti (evito letture RAM)
    type res_arr is array(0 to K-1) of integer;
    variable R1, R2 : res_arr;
    variable idx1, idx2 : integer;

    -- util
    function any_diff(a,b:res_arr) return boolean is
    begin
      for i in a'range loop
        if a(i) /= b(i) then return true; end if;
      end loop;
      return false;
    end function;

  begin
    -- reset
    i_rst<='1'; wait for 80 ns; i_rst<='0';
    i_add <= std_logic_vector(BASE_ADD);
    out_base := BASE_ADD + to_unsigned(17+K,16);

    ------------------------------------------------------------
    -- RUN #1 : S=0 (ordine 3), C = C3a/C5a
    ------------------------------------------------------------
    a := BASE_ADD;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,msb(K)); a:=a+ONE16;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,lsb(K)); a:=a+ONE16;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,0);      a:=a+ONE16; -- S LSB=0 ? ordine 3
    for i in 0 to 6 loop  ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C3a(i)); a:=a+ONE16; end loop;
    for i in 0 to 6 loop  ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C5a(i)); a:=a+ONE16; end loop;
    for i in 0 to K-1 loop ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,W(i));  a:=a+ONE16; end loop;

    -- start run#1
    wait until rising_edge(i_clk); i_start<='1';

    wr_cnt1 := 0; first_wr_addr1 := -1; prev_wr_addr1 := -999; saw_after_done1 := false;
    idx1 := 0;

    -- monitora fino a DONE=1
    loop
      wait until rising_edge(i_clk);
      if o_done='1' then exit; end if;

      if o_mem_en='1' and o_mem_we='1' then
        -- proprietà I/O
        wr_cnt1 := wr_cnt1 + 1;
        if first_wr_addr1 = -1 then
          first_wr_addr1 := to_integer(unsigned(o_mem_addr));
        else
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr1 + 1
            report "WRITE non contigue (run#1)" severity failure;
        end if;
        prev_wr_addr1 := to_integer(unsigned(o_mem_addr));

        -- cattura risultato scritto
        if idx1 < K then
          R1(idx1) := to_integer(signed(o_mem_data));
          idx1 := idx1 + 1;
        end if;
      end if;
    end loop;

    -- ACK run#1 (DONE resta alto finché START torna 0)
    i_start<='0';
    dropped1:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done1 := true; end if;
      if o_done='0' then dropped1:=true; exit; end if;
    end loop;

    -- check finali run#1
    assert dropped1 report "DONE non è sceso (run#1)" severity failure;
    assert not saw_after_done1 report "WRITE dopo DONE (run#1)" severity failure;
    assert first_wr_addr1 = to_integer(out_base)
      report "Prima WRITE != ADD+17+K (run#1)" severity failure;
    assert wr_cnt1 = K report "Numero WRITEs != K (run#1)" severity failure;

    ------------------------------------------------------------
    -- RUN #2 : S=0 (ordine 3), C = C3b/C5b (senza reset)
    ------------------------------------------------------------
    a := BASE_ADD;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,msb(K)); a:=a+ONE16;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,lsb(K)); a:=a+ONE16;
    ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,0);      a:=a+ONE16; -- stesso ordine
    for i in 0 to 6 loop  ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C3b(i)); a:=a+ONE16; end loop;
    for i in 0 to 6 loop  ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C5b(i)); a:=a+ONE16; end loop;
    for i in 0 to K-1 loop ram_write(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,W(i));  a:=a+ONE16; end loop;

    -- start run#2
    wait until rising_edge(i_clk); i_start<='1';

    wr_cnt2 := 0; first_wr_addr2 := -1; prev_wr_addr2 := -999; saw_after_done2 := false;
    idx2 := 0;

    -- monitora fino a DONE=1
    loop
      wait until rising_edge(i_clk);
      if o_done='1' then exit; end if;

      if o_mem_en='1' and o_mem_we='1' then
        wr_cnt2 := wr_cnt2 + 1;
        if first_wr_addr2 = -1 then
          first_wr_addr2 := to_integer(unsigned(o_mem_addr));
        else
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr2 + 1
            report "WRITE non contigue (run#2)" severity failure;
        end if;
        prev_wr_addr2 := to_integer(unsigned(o_mem_addr));

        if idx2 < K then
          R2(idx2) := to_integer(signed(o_mem_data));
          idx2 := idx2 + 1;
        end if;
      end if;
    end loop;

    -- ACK run#2
    i_start<='0';
    dropped2:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done2 := true; end if;
      if o_done='0' then dropped2:=true; exit; end if;
    end loop;

    -- check finali run#2
    assert dropped2 report "DONE non è sceso (run#2)" severity failure;
    assert not saw_after_done2 report "WRITE dopo DONE (run#2)" severity failure;
    assert first_wr_addr2 = to_integer(out_base)
      report "Prima WRITE != ADD+17+K (run#2)" severity failure;
    assert wr_cnt2 = K report "Numero WRITEs != K (run#2)" severity failure;

    -- confronto tra run (solo proprietà: con C diversi ? risultati diversi)
    assert any_diff(R1,R2) report "Coefficients reload had no effect (R1==R2)" severity failure;

    report "tb_coeff_reload_io OK" severity note;
    wait;
  end process;
end architecture;

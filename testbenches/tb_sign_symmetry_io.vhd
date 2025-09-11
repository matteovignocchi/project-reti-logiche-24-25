-- tb_sign_symmetry_io.vhd  (VHDL-2008) -- Corner: simmetria di segno (normaliz + saturazione)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale)
entity rams_sp_wf_ssym is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_ssym is
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
entity tb_sign_symmetry_io is end tb_sign_symmetry_io;

architecture tb of tb_sign_symmetry_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#2300#,16);
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

  -- dati
  type int_arr is array(natural range <>) of integer;
  constant K  : natural := 24;

  -- W con ampiezze varie (alcuni possono saturare con l'ordine-5)
  constant W  : int_arr := (
     50, -40, 35, -28,  26, -22,  18, -16,
     14, -12, 10,  -8,   6,  -5,   4,  -3,
      2,  -1,  0,  15, -30,  60, -60,  45
  );

  -- Coefficienti da specifica: si scrivono sempre C1..C14; il DUT seleziona in base a S(0)
  constant C3 : int_arr := (0,-1,8,0,-8,1,0);
  constant C5 : int_arr := (1,-9,45,0,-45,9,-1);

  -- helper
  function msb(x:natural) return integer is begin return (x/256) mod 256; end;
  function lsb(x:natural) return integer is begin return x mod 256; end;
  function iabs(x:integer) return integer is begin if x<0 then return -x; else return x; end if; end;

  -- writer TB (usa ramo TB del mux)
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

  -- preload con S definito e segno W controllato (+1 o -1)
  procedure preload_with_S_and_sign(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; base:in unsigned(15 downto 0); Sval: in integer; wsign: in integer
  ) is
    variable a : unsigned(15 downto 0);
    variable v : integer;
  begin
    a := base;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,msb(K)); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,lsb(K)); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,Sval);   a:=a+ONE16;  -- S (LSB=1 -> ordine 5)
    for i in 0 to 6 loop ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,C3(i)); a:=a+ONE16; end loop; -- C1..C7
    for i in 0 to 6 loop ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,C5(i)); a:=a+ONE16; end loop; -- C8..C14
    for i in 0 to K-1 loop
      v := W(i) * wsign;
      if v > 127 then v := 127; end if;  -- clamp a 8 bit signed
      if v < -128 then v := -128; end if;
      ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,v);
      a:=a+ONE16;
    end loop;
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
  u_ram: entity work.rams_sp_wf_ssym
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stim + proprietà di simmetria
  stim: process
    subtype byte_t is integer range -128 to 127;
    type res_arr is array(0 to K-1) of byte_t;

    variable out_base : unsigned(15 downto 0);

    variable wr_cnt  : integer;
    variable first_wr_addr, prev_wr_addr : integer;
    variable saw_after_done, dropped : boolean;

    variable idxP, idxN : integer;
    variable RP, RN : res_arr;  -- risultati run positivo e negativo

    -- check helper per una coppia (pos, neg)
    procedure check_pair(p,n: integer) is
      variable ok : boolean;
      variable sum : integer;
    begin
      ok := false;
      -- casi di saturazione ammessi
      if (p = 127 and (n = -127 or n = -128)) then
        ok := true;
      elsif (p = -128 and n = 127) then
        ok := true;
      elsif (n = 127 and (p = -127 or p = -128)) then
        ok := true;
      elsif (n = -128 and p = 127) then
        ok := true;
      else
        -- relazione ~antisimmetrica entro 1 LSB: p + n ~ 0
        sum := p + n;
        if iabs(sum) <= 1 then
          ok := true;
        end if;
      end if;
      assert ok report "Sign-symmetry failed on a sample" severity failure;
    end procedure;

  begin
    -- reset & base
    i_rst  <='1';
    i_start<='0';
    i_add  <= std_logic_vector(BASE_ADD);
    wait for 40 ns;

    out_base := BASE_ADD + to_unsigned(17+K,16);

    ----------------------------------------------------------------
    -- RUN POSITIVO (S=1 -> ordine 5, W come da vettore)
    ----------------------------------------------------------------
    preload_with_S_and_sign(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD,1, +1);

    wait until rising_edge(i_clk); i_rst<='0';
    wait until rising_edge(i_clk); i_start<='1';

    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false; idxP := 0;

    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        -- base e contiguità
        assert unsigned(o_mem_addr) >= out_base
          report "Write before ADD+17+K (run P)" severity failure;
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        elsif wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes (run P)" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));

        -- cattura risultato
        if idxP < K then
          RP(idxP) := to_integer(signed(o_mem_data));
          idxP := idxP + 1;
        else
          assert false report "Too many writes (run P)" severity failure;
        end if;
      end if;
    end loop;

    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;
    assert dropped report "DONE did not drop (run P)" severity failure;
    assert not saw_after_done report "Writes after DONE (run P)" severity failure;
    assert first_wr_addr = to_integer(out_base) report "First write != base (run P)" severity failure;
    assert wr_cnt = K report "Number of writes != K (run P)" severity failure;

    ----------------------------------------------------------------
    -- RUN NEGATIVO (S=1 -> ordine 5, W negati)
    ----------------------------------------------------------------
    i_rst<='1'; wait for 20 ns; i_rst<='0';
    preload_with_S_and_sign(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD,1, -1);

    wait until rising_edge(i_clk); i_start<='1';
    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false; idxN := 0;

    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        assert unsigned(o_mem_addr) >= out_base
          report "Write before ADD+17+K (run N)" severity failure;
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        elsif wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes (run N)" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));

        if idxN < K then
          RN(idxN) := to_integer(signed(o_mem_data));
          idxN := idxN + 1;
        else
          assert false report "Too many writes (run N)" severity failure;
        end if;
      end if;
    end loop;

    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;
    assert dropped report "DONE did not drop (run N)" severity failure;
    assert not saw_after_done report "Writes after DONE (run N)" severity failure;
    assert first_wr_addr = to_integer(out_base) report "First write != base (run N)" severity failure;
    assert wr_cnt = K report "Number of writes != K (run N)" severity failure;

    ----------------------------------------------------------------
    -- CHECK DI SIMMETRIA (sample-by-sample)
    ----------------------------------------------------------------
    for i in 0 to K-1 loop
      check_pair(RP(i), RN(i));
    end loop;

    report "tb_sign_symmetry_io OK" severity note;
    wait;
  end process;
end architecture;

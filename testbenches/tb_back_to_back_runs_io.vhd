-- tb_back_to_back_runs_io.vhd (VHDL-2008)
-- Corner: due run consecutivi senza reset aggiuntivo fra i run.
-- Verifica per ciascun run:
--  - prima WRITE = ADD+17+K
--  - esattamente K WRITE contigue
--  - nessuna WRITE dopo DONE=1
--  - DONE scende quando START torna 0
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale)
entity rams_sp_wf_b2b is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_b2b is
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
entity tb_back_to_back_runs_io is end tb_back_to_back_runs_io;

architecture tb of tb_back_to_back_runs_io is
  constant CLK_PER   : time := 20 ns;
  constant BASE1     : unsigned(15 downto 0) := to_unsigned(16#3000#,16);
  constant BASE2     : unsigned(15 downto 0) := to_unsigned(16#3100#,16);
  constant ONE16     : unsigned(15 downto 0) := to_unsigned(1,16);

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

  -- helper: split di K su due byte
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

  -- preambolo + C1..C14 (coeff da specifica), S selezionabile
  procedure write_preamble_and_coeff(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; base:in unsigned(15 downto 0); Kval: in integer; Sval: in integer
  ) is
    variable a : unsigned(15 downto 0);
  begin
    a := base;
    -- K1, K2, S
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,msb(Kval)); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,lsb(Kval)); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,Sval);      a:=a+ONE16;
    -- C1..C7 (ordine-3)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 8); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-8); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0); a:=a+ONE16;
    -- C8..C14 (ordine-5)
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 1);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-9);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 45); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 0);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-45); a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a, 9);  a:=a+ONE16;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,-1);  a:=a+ONE16;
  end procedure;

  -- sequenze W semplici (niente array)
  function w1_seq(i: integer) return integer is
    variable p : integer := i mod 12;
  begin
    case p is
      when 0=>return 12; when 1=>return -10; when 2=>return 8; when 3=>return -6;
      when 4=>return 5;  when 5=>return -4;  when 6=>return 3; when 7=>return -2;
      when 8=>return 1;  when 9=>return 0;   when 10=>return 7; when others=>return -7;
    end case;
  end function;

  function w2_seq(i: integer) return integer is
    variable p : integer := i mod 14;
  begin
    case p is
      when 0=>return 4; when 1=>return -4; when 2=>return 6; when 3=>return -6;
      when 4=>return 9; when 5=>return -9; when 6=>return 11; when 7=>return -11;
      when 8=>return 13; when 9=>return -13; when 10=>return 0; when 11=>return 2;
      when 12=>return -2; when others=>return 0;
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
  u_ram: entity work.rams_sp_wf_b2b
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stim + proprietà: due run consecutivi senza reset tra i run
  stim: process
    constant K1  : integer := 24;   -- run 1 (S LSB=0 -> ordine-3)
    constant S1  : integer := 0;
    constant K2  : integer := 31;   -- run 2 (S LSB=1 -> ordine-5)
    constant S2  : integer := 1;

    variable out_base1, out_base2 : unsigned(15 downto 0);

    -- run-local trackers
    variable wr_cnt  : integer;
    variable first_wr_addr, prev_wr_addr : integer;
    variable saw_after_done, dropped : boolean;

    -- per caricare W senza array
    variable addr_cursor : unsigned(15 downto 0);
    variable v : integer;
  begin
    ------------------------------------------------------------
    -- PRELOAD RUN 1 (con reset attivo)
    ------------------------------------------------------------
    i_rst  <='1'; i_start<='0'; i_add <= std_logic_vector(BASE1);
    wait for 40 ns;

    write_preamble_and_coeff(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE1,K1,S1);
    addr_cursor := BASE1 + to_unsigned(17,16);
    for i in 0 to K1-1 loop
      v := w1_seq(i);
      ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk, addr_cursor, v);
      addr_cursor := addr_cursor + ONE16;
    end loop;

    -- rilascia reset e avvia RUN 1
    wait until rising_edge(i_clk); i_rst<='0';
    out_base1 := BASE1 + to_unsigned(17+K1,16);
    wait until rising_edge(i_clk); i_start<='1';
    wait until rising_edge(i_clk); i_start<='0';

    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;

    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        -- mai prima della base 1
        assert unsigned(o_mem_addr) >= out_base1 report "Write before ADD+17+K (run1)" severity failure;

        -- contiguità
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        elsif wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes (run1)" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- handshake fine RUN 1
    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    assert dropped report "DONE non sceso dopo START=0 (run1)" severity failure;
    assert not saw_after_done report "WRITE dopo DONE=1 (run1)" severity failure;
    assert first_wr_addr = to_integer(out_base1) report "Prima WRITE != ADD+17+K (run1)" severity failure;
    assert wr_cnt = K1 report "Numero di scritture diverso da K (run1)" severity failure;

    ------------------------------------------------------------
    -- PRELOAD RUN 2 (senza re-assert di reset)
    -- TB scrive in RAM usando il MUX, mentre il DUT è in IDLE.
    ------------------------------------------------------------
    i_add <= std_logic_vector(BASE2);  -- nuovo indirizzo base per il secondo run

    write_preamble_and_coeff(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE2,K2,S2);
    addr_cursor := BASE2 + to_unsigned(17,16);
    for i in 0 to K2-1 loop
      v := w2_seq(i);
      ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk, addr_cursor, v);
      addr_cursor := addr_cursor + ONE16;
    end loop;

    -- avvia subito RUN 2 (no reset tra i run)
    wait until rising_edge(i_clk);
    out_base2 := BASE2 + to_unsigned(17+K2,16);
    i_start <= '1';
    wait until rising_edge(i_clk);
    i_start <= '0';

    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;

    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        -- mai prima della base 2
        assert unsigned(o_mem_addr) >= out_base2 report "Write before ADD+17+K (run2)" severity failure;

        -- contiguità
        wr_cnt := wr_cnt + 1;
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        elsif wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes (run2)" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- handshake fine RUN 2
    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    assert dropped report "DONE non sceso dopo START=0 (run2)" severity failure;
    assert not saw_after_done report "WRITE dopo DONE=1 (run2)" severity failure;
    assert first_wr_addr = to_integer(out_base2) report "Prima WRITE != ADD+17+K (run2)" severity failure;
    assert wr_cnt = K2 report "Numero di scritture diverso da K (run2)" severity failure;

    report "tb_back_to_back_runs_io OK" severity note;
    wait;
  end process;
end architecture;

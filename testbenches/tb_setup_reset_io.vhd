-- tb_setup_reset_io.vhd  (VHDL-2008) -- Corner #5: reset durante SETUP
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- RAM single-port write-first (istanza locale)
entity rams_sp_wf_sureset is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_sureset is
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
entity tb_setup_reset_io is end tb_setup_reset_io;

architecture tb of tb_setup_reset_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#2500#,16);
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
  constant K  : natural := 16;
  constant W  : int_arr := (  5,  4,  3,  2,  1, -1, -2, -3,
                              -4, -5, 10,-10, 20,-20, 30,-30 );
  constant C3 : int_arr := (0,-1,8,0,-8,1,0);
  constant C5 : int_arr := (1,-9,45,0,-45,9,-1);
  constant SVAL : integer := 0; -- LSB=0 -> ordine 3 (a piacere)

  function msb(x:natural) return integer is begin return (x/256) mod 256; end;
  function lsb(x:natural) return integer is begin return x mod 256; end;

  -- preload writer (ramo TB del MUX)
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

  -- preload completo (preambolo + C1..C14 + W)
  procedure preload_all(
    signal p_sel_tb:out std_logic; signal p_tb_en:out std_logic; signal p_tb_we:out std_logic;
    signal p_tb_addr:out std_logic_vector(15 downto 0); signal p_tb_di:out std_logic_vector(7 downto 0);
    signal p_clk:in std_logic; base:in unsigned(15 downto 0)
  ) is
    variable a : unsigned(15 downto 0);
  begin
    a := base;
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,msb(K)); a:=a+ONE16; -- K1
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,lsb(K)); a:=a+ONE16; -- K2
    ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,SVAL);   a:=a+ONE16; -- S
    for i in 0 to 6 loop ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,C3(i)); a:=a+ONE16; end loop; -- C1..C7
    for i in 0 to 6 loop ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,C5(i)); a:=a+ONE16; end loop; -- C8..C14
    for i in 0 to K-1 loop ram_write_tb(p_sel_tb,p_tb_en,p_tb_we,p_tb_addr,p_tb_di,p_clk,a,W(i));  a:=a+ONE16; end loop;
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
  u_ram: entity work.rams_sp_wf_sureset
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- Stim + proprietà: reset durante SETUP, poi run completo
  stim: process
    variable out_base : unsigned(15 downto 0);
    variable wr_cntB  : integer;
    variable first_wr_addrB, prev_wr_addrB : integer;
    variable saw_after_doneB, droppedB : boolean;

    -- setup-read monitor
    variable setup_reads : integer;
    constant TRIG_READS  : integer := 5;   -- dopo 5 letture del preambolo, reset
    variable writes_during_reset : boolean;

    -- helper addr range
    function in_setup_range(a: std_logic_vector(15 downto 0)) return boolean is
      variable au : unsigned(15 downto 0);
    begin
      au := unsigned(a);
      return (au >= BASE_ADD) and (au <= BASE_ADD + to_unsigned(16,16));
    end function;
  begin
    -- inizializza e preload
    i_rst  <='1';
    i_start<='0';
    i_add  <= std_logic_vector(BASE_ADD);
    wait for 40 ns;

    preload_all(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,BASE_ADD);

    out_base := BASE_ADD + to_unsigned(17+K,16);

    -- rilascia reset e avvia run A
    wait until rising_edge(i_clk); i_rst<='0';
    wait until rising_edge(i_clk); i_start<='1';

    -- osserva alcune letture del SETUP, poi reset
    setup_reads := 0;
    writes_during_reset := false;

    while setup_reads < TRIG_READS loop
      wait until rising_edge(i_clk);
      -- contiamo solo letture in [ADD .. ADD+16]
      if o_mem_en='1' and o_mem_we='0' and in_setup_range(o_mem_addr) then
        setup_reads := setup_reads + 1;
      end if;
    end loop;

    -- assert reset durante SETUP e porta START a 0
    i_rst   <='1';
    i_start <='0';

    -- durante il reset non devono esserci write
    for t in 0 to 15 loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        writes_during_reset := true;
      end if;
    end loop;

    -- ===== Run B dopo il reset (stesso ADD e contenuti RAM già caricati) =====
    wait until rising_edge(i_clk); i_rst<='0';
    wait until rising_edge(i_clk); i_start<='1';

    wr_cntB := 0; first_wr_addrB := -1; prev_wr_addrB := -999; saw_after_doneB := false;

    -- monitora fino a DONE=1 (run B)
    while o_done='0' loop
      wait until rising_edge(i_clk);
      if o_mem_en='1' and o_mem_we='1' then
        -- prima write deve essere a ADD+17+K
        if first_wr_addrB = -1 then
          first_wr_addrB := to_integer(unsigned(o_mem_addr));
        end if;

        -- non scrivere prima della base
        assert unsigned(o_mem_addr) >= out_base
          report "Write before ADD+17+K (run B)" severity failure;

        -- contiguità
        wr_cntB := wr_cntB + 1;
        if wr_cntB > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addrB + 1
            report "Non-contiguous writes (run B)" severity failure;
        end if;
        prev_wr_addrB := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- handshake: START a 0, DONE deve scendere
    i_start<='0'; droppedB:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_doneB:=true; end if;
      if o_done='0' then droppedB:=true; exit; end if;
    end loop;

    -- check finali
    assert not writes_during_reset report "Writes occurred while reset was asserted" severity failure;
    assert droppedB report "DONE did not drop after START=0 (run B)" severity failure;
    assert not saw_after_doneB report "Writes after DONE=1 (run B)" severity failure;
    assert first_wr_addrB = to_integer(out_base) report "First write != ADD+17+K (run B)" severity failure;
    assert wr_cntB = K report "Number of writes != K (run B)" severity failure;

    report "tb_setup_reset_io OK" severity note;
    wait;
  end process;
end architecture;

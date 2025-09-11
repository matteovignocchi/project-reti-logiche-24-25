-- tb_no_input_writes_io.vhd  (VHDL-2008, compat) -- Corner: no writes < ADD+17+K
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

-- Simple single-port RAM, write-first
entity rams_sp_wf_nowio is
  port(
    clk  : in  std_logic;
    we   : in  std_logic;
    en   : in  std_logic;
    addr : in  std_logic_vector(15 downto 0);
    di   : in  std_logic_vector(7 downto 0);
    do   : out std_logic_vector(7 downto 0)
  );
end entity;
architecture beh of rams_sp_wf_nowio is
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
entity tb_no_input_writes_io is end tb_no_input_writes_io;

architecture tb of tb_no_input_writes_io is
  constant CLK_PER  : time := 20 ns;
  constant BASE_ADD : unsigned(15 downto 0) := to_unsigned(16#2100#,16);
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

  -- data
  type int_arr is array(natural range <>) of integer;
  constant K  : natural := 16;
  constant W  : int_arr := ( 5,4,3,2,1, -1,-2,-3, -4,-5, 10,-10, 20,-20, 30,-30 );
  constant C3 : int_arr := (0,-1,8,0,-8,1,0);
  constant C5 : int_arr := (1,-9,45,0,-45,9,-1);

  function msb(x:natural) return integer is begin return (x/256) mod 256; end;
  function lsb(x:natural) return integer is begin return x mod 256; end;

  -- preload writer (through TB branch of MUX)
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

begin
  -- clock
  i_clk <= not i_clk after CLK_PER/2;

  -- MUX to RAM
  ram_en   <= tb_en   when sel_tb='1' else o_mem_en;
  ram_we   <= tb_we   when sel_tb='1' else o_mem_we;
  ram_addr <= tb_addr when sel_tb='1' else o_mem_addr;
  ram_di   <= tb_di   when sel_tb='1' else o_mem_data;
  i_mem_data <= ram_do;

  -- instances
  u_ram: entity work.rams_sp_wf_nowio
    port map(i_clk,ram_we,ram_en,ram_addr,ram_di,ram_do);

  dut: entity work.project_reti_logiche
    port map(i_clk,i_rst,i_start,i_add,o_done,o_mem_addr,i_mem_data,o_mem_data,o_mem_we,o_mem_en);

  -- STIM + SPEC properties
  stim: process
    variable a       : unsigned(15 downto 0);
    variable out_base: unsigned(15 downto 0);
    variable wr_cnt  : integer;
    variable first_wr_addr, prev_wr_addr : integer;
    variable dropped, saw_after_done : boolean;
  begin
    -- reset & set ADD
    i_rst  <='1';
    i_start<='0';
    i_add  <= std_logic_vector(BASE_ADD);
    wait for 40 ns;

    -- preload memory through TB
    a := BASE_ADD;
    ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,msb(K)); a:=a+ONE16;
    ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,lsb(K)); a:=a+ONE16;
    ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,0);      a:=a+ONE16; -- S LSB=0
    for i in 0 to 6 loop ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C3(i)); a:=a+ONE16; end loop;
    for i in 0 to 6 loop ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,C5(i)); a:=a+ONE16; end loop;
    for i in 0 to K-1 loop ram_write_tb(sel_tb,tb_en,tb_we,tb_addr,tb_di,i_clk,a,W(i));  a:=a+ONE16; end loop;

    -- release reset
    wait until rising_edge(i_clk); i_rst<='0';

    out_base := BASE_ADD + to_unsigned(17+K,16);

    -- start
    wait until rising_edge(i_clk); i_start<='1';

    wr_cnt := 0; first_wr_addr := -1; prev_wr_addr := -999; saw_after_done := false;

    -- monitor until DONE=1
    while o_done='0' loop
      wait until rising_edge(i_clk);

      if o_mem_en='1' and o_mem_we='1' then
        -- first write capture (no string concat to avoid parser issues)
        if first_wr_addr = -1 then
          first_wr_addr := to_integer(unsigned(o_mem_addr));
        end if;

        -- must not write before ADD+17+K
        assert unsigned(o_mem_addr) >= out_base
          report "Write before ADD+17+K" severity failure;

        -- contiguity
        wr_cnt := wr_cnt + 1;
        if wr_cnt > 1 then
          assert to_integer(unsigned(o_mem_addr)) = prev_wr_addr + 1
            report "Non-contiguous writes" severity failure;
        end if;
        prev_wr_addr := to_integer(unsigned(o_mem_addr));
      end if;
    end loop;

    -- ACK: START back to 0, DONE must drop
    i_start<='0'; dropped:=false;
    for t in 0 to 1023 loop
      wait until rising_edge(i_clk);
      if o_done='1' and o_mem_en='1' and o_mem_we='1' then saw_after_done:=true; end if;
      if o_done='0' then dropped:=true; exit; end if;
    end loop;

    assert dropped report "DONE did not drop after START=0" severity failure;
    assert not saw_after_done report "Writes after DONE=1" severity failure;
    assert first_wr_addr = to_integer(out_base) report "First write != ADD+17+K" severity failure;
    assert wr_cnt = K report "Number of writes != K" severity failure;

    report "tb_no_input_writes_io OK" severity note;
    wait;
  end process;
end architecture;

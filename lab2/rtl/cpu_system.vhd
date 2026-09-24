-------------------------------------------------------------------------------
-- Верхний уровень: процессорное ядро + память команд + память данных
-- (память команд и память данных - внешние по отношению к ядру компоненты).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_system is
    generic (
        PREDICT_NOT_TAKEN : boolean := true;
        IMEM_FILE         : string  := "";
        DMEM_FILE         : string  := "";
        TRACE_FILE        : string  := ""
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        halted       : out std_logic;
        dbg_addr     : in  daddr_t;
        dbg_data     : out word_t;
        dbg_regs     : out word_arr_t(0 to NREG-1);
        dbg_flags    : out flags_t;
        dbg_hazard   : out std_logic;
        cnt_cycles   : out unsigned(31 downto 0);
        cnt_retired  : out unsigned(31 downto 0);
        cnt_squashed : out unsigned(31 downto 0);
        cnt_taken    : out unsigned(31 downto 0);
        cnt_stall    : out unsigned(31 downto 0);
        dbg_retire   : out wb_bundle_t
    );
end entity;

architecture structural of cpu_system is
    signal imem_addr  : iaddr_t;
    signal imem_data  : instr_arr_t;
    signal dmem_raddr : daddr_arr_t;
    signal dmem_rdata : word_arr_t(0 to NPIPE-1);
    signal dmem_we    : std_logic_vector(0 to NPIPE-1);
    signal dmem_waddr : daddr_arr_t;
    signal dmem_wdata : word_arr_t(0 to NPIPE-1);
begin
    core : entity work.cpu_core
        generic map (PREDICT_NOT_TAKEN => PREDICT_NOT_TAKEN, TRACE_FILE => TRACE_FILE)
        port map (
            clk => clk, rst => rst,
            imem_addr => imem_addr, imem_data => imem_data,
            dmem_raddr => dmem_raddr, dmem_rdata => dmem_rdata,
            dmem_we => dmem_we, dmem_waddr => dmem_waddr, dmem_wdata => dmem_wdata,
            halted => halted, dbg_pc => open, dbg_regs => dbg_regs,
            dbg_flags => dbg_flags, dbg_hazard => dbg_hazard,
            cnt_cycles => cnt_cycles, cnt_retired => cnt_retired,
            cnt_squashed => cnt_squashed, cnt_taken => cnt_taken, cnt_stall => cnt_stall,
            dbg_retire => dbg_retire);

    im : entity work.imem
        generic map (INIT_FILE => IMEM_FILE)
        port map (addr => imem_addr, data => imem_data);

    dm : entity work.dmem
        generic map (INIT_FILE => DMEM_FILE)
        port map (clk => clk, raddr => dmem_raddr, rdata => dmem_rdata,
                  we => dmem_we, waddr => dmem_waddr, wdata => dmem_wdata,
                  dbg_addr => dbg_addr, dbg_data => dbg_data);
end architecture;

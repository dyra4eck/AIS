-------------------------------------------------------------------------------
-- Память данных: 256 слов по 16 бит.
-- NPIPE портов чтения (асинхронное чтение, ступень "вычисление результата")
-- и NPIPE портов записи (запись по фронту, ступень "запись результата").
-- При записи в один адрес из нескольких конвейеров в одном такте побеждает
-- конвейер с большим номером (более поздняя команда в программном порядке).
-- Порт dbg_* используется тестовым окружением для чтения итогового образа.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
use work.mem_init_pkg.all;

entity dmem is
    generic (INIT_FILE : string := "");
    port (
        clk      : in  std_logic;
        raddr    : in  daddr_arr_t;
        rdata    : out word_arr_t(0 to NPIPE-1);
        we       : in  std_logic_vector(0 to NPIPE-1);
        waddr    : in  daddr_arr_t;
        wdata    : in  word_arr_t(0 to NPIPE-1);
        dbg_addr : in  daddr_t;
        dbg_data : out word_t
    );
end entity;

architecture rtl of dmem is
    impure function init return word_arr_t is
        variable m : word_arr_t(0 to 2**DAW-1);
    begin
        load_image(INIT_FILE, m);
        return m;
    end function;
    signal ram : word_arr_t(0 to 2**DAW-1) := init;
begin
    process (clk)
    begin
        if rising_edge(clk) then
            for i in 0 to NPIPE-1 loop
                if we(i) = '1' then
                    ram(to_integer(waddr(i))) <= wdata(i);
                end if;
            end loop;
        end if;
    end process;

    gen : for i in 0 to NPIPE-1 generate
        rdata(i) <= ram(to_integer(raddr(i)));
    end generate;

    dbg_data <= ram(to_integer(dbg_addr));
end architecture;

-------------------------------------------------------------------------------
-- Память команд: 256 слов по 16 бит.
-- За один такт выдаёт NPIPE команд подряд, начиная с адреса addr
-- (addr, addr+1, addr+2) - по одной на каждый конвейер.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
use work.mem_init_pkg.all;

entity imem is
    generic (INIT_FILE : string := "");
    port (
        addr : in  iaddr_t;
        data : out instr_arr_t
    );
end entity;

architecture rtl of imem is
    impure function init return word_arr_t is
        variable m : word_arr_t(0 to 2**IAW-1);
    begin
        load_image(INIT_FILE, m);
        return m;
    end function;
    constant ROM : word_arr_t(0 to 2**IAW-1) := init;
begin
    gen : for i in 0 to NPIPE-1 generate
        data(i) <= ROM(to_integer(addr + i));   -- адрес по модулю 256
    end generate;
end architecture;

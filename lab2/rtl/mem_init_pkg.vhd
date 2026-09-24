-------------------------------------------------------------------------------
-- Загрузка образов памяти из текстовых файлов (только для моделирования).
-- Формат: одно 16-разрядное слово в шестнадцатеричном виде в строке,
-- начиная с адреса 0. Пустые строки и строки, начинающиеся с '#' или '-',
-- пропускаются; текст после слова игнорируется (комментарий).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;

package mem_init_pkg is
    procedure load_image(file_name : string; mem : inout word_arr_t);
end package;

package body mem_init_pkg is

    procedure load_image(file_name : string; mem : inout word_arr_t) is
        file f       : text;
        variable st  : file_open_status;
        variable l   : line;
        variable w   : word_t;
        variable ok  : boolean;
        variable a   : natural := mem'low;
        variable c   : character;
    begin
        for i in mem'range loop
            mem(i) := (others => '0');
        end loop;
        if file_name = "" then
            return;
        end if;
        file_open(st, f, file_name, read_mode);
        if st /= open_ok then
            report "cannot open " & file_name severity failure;
            return;
        end if;
        while not endfile(f) loop
            readline(f, l);
            -- пропуск ведущих пробелов
            while l'length > 0 and (l(l'left) = ' ' or l(l'left) = HT) loop
                read(l, c);
            end loop;
            next when l'length = 0;
            next when l(l'left) = '#' or l(l'left) = '-';
            hread(l, w, ok);
            assert ok report "bad word in " & file_name severity failure;
            assert a <= mem'high report file_name & ": image too large" severity failure;
            mem(a) := w;
            a := a + 1;
        end loop;
        file_close(f);
    end procedure;

end package body;

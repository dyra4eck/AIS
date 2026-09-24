-------------------------------------------------------------------------------
-- Лабораторная работа 3, вариант 7.
-- Тестовое окружение для оценки характеристик процессорного ядра из ЛР2.
--
-- Механизмы измерения:
--
-- 1. Время выполнения каждой команды. Ядро выдаёт на порт dbg_retire команды,
--    находящиеся на ступени WB, вместе с меткой tf - номером такта, в котором
--    команда была выбрана (IF). Для каждой завершённой команды k (в программном
--    порядке, т.е. по тактам и по номеру конвейера внутри такта) вычисляются:
--       F  = tf                  - такт выборки;
--       C  = текущий такт        - такт записи результата (WB);
--       L  = C - F + 1           - латентность: от выборки до записи результата;
--       S  = такт, в котором команду можно было бы выбрать без конфликтов:
--            S = F(k-1),     если k следует в памяти сразу за k-1 и k-1 была не
--                            в последнем конвейере (k попала бы в ту же группу);
--            S = F(k-1) + 1  иначе (следующая группа);
--            для первой команды S = F;
--       W  = F - S               - задержка выборки из-за конфликта по управлению;
--       T  = L + W               - время выполнения команды с учётом конфликта.
--    По каждому типу команд накапливаются количество, минимум, максимум и сумма
--    L, W, T. Подробный журнал - results/ИМЯ.РЕЖИМ.instr.csv.
--
-- 2. Время выполнения участков программы (.region в исходном тексте теста,
--    файл ИМЯ.regions): от такта выборки первого выполнения первой команды
--    участка до такта записи результата последнего выполнения последней команды:
--       T_region = C_end - F_start + 1,  N = число команд, завершённых за это
--       время (включая NOP),  IPC = N / T_region,  CPI = T_region / N.
--
-- 3. Функциональная проверка: итоговая память данных и регистры сравниваются
--    с эталонной моделью (как в ЛР2), чтобы измерения выполнялись только на
--    правильно работающей модели.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;
use work.mem_init_pkg.all;

entity tb_perf is
    generic (
        TEST_NAME         : string  := "min_all";
        TEST_DIR          : string  := "tests/build/";
        OUT_DIR           : string  := "results/";
        PREDICT_NOT_TAKEN : boolean := true;
        MAX_CYCLES        : natural := 5000
    );
end entity;

architecture sim of tb_perf is
    constant T_CLK : time := 10 ns;

    function mode_name return string is
    begin
        if PREDICT_NOT_TAKEN then return "predict"; else return "stall"; end if;
    end function;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal done       : boolean := false;
    signal halted     : std_logic;
    signal dbg_addr   : daddr_t := (others => '0');
    signal dbg_data   : word_t;
    signal dbg_regs   : word_arr_t(0 to NREG-1);
    signal dbg_flags  : flags_t;
    signal dbg_hazard : std_logic;
    signal dbg_retire : wb_bundle_t;
    signal cnt_cycles, cnt_retired, cnt_squashed, cnt_taken, cnt_stall : unsigned(31 downto 0);

    -- статистика по типам команд (индекс - код операции)
    type nat_arr is array (0 to 15) of natural;
    function op_name(op : natural) return string is
    begin
        case op is
            when 0      => return "NOP  ";
            when 1      => return "LOAD ";
            when 2      => return "STORE";
            when 3      => return "ADD  ";
            when 4      => return "SUB  ";
            when 5      => return "JL   ";
            when 15     => return "HALT ";
            when others => return "???  ";
        end case;
    end function;

    -- участки программы
    constant MAX_REG : natural := 16;
    subtype name_t is string(1 to 24);
    type region_t is record
        start_pc, end_pc : natural;
        name             : name_t;
        started          : boolean;
        f_start          : natural;
        seq_start        : natural;
        c_end            : natural;
        seq_end          : natural;
        taken_start      : natural;
        taken_end        : natural;
    end record;
    type region_arr is array (0 to MAX_REG-1) of region_t;

    function hex(w : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, w);
        return l.all;
    end function;

    -- число с фиксированной точкой: x/y с двумя знаками
    function ratio(x, y : natural) return string is
        variable q : natural;
        variable fr : natural;
    begin
        if y = 0 then return "-"; end if;
        q  := (x * 100 + y / 2) / y;
        fr := q mod 100;
        if fr < 10 then
            return integer'image(q / 100) & ".0" & integer'image(fr);
        else
            return integer'image(q / 100) & "." & integer'image(fr);
        end if;
    end function;

    function pad(s : string; n : natural) return string is
        variable r : string(1 to n) := (others => ' ');
    begin
        if s'length >= n then return s; end if;
        r(n - s'length + 1 to n) := s;
        return r;
    end function;
begin
    clk <= not clk after T_CLK/2 when not done;

    dut : entity work.cpu_system
        generic map (
            PREDICT_NOT_TAKEN => PREDICT_NOT_TAKEN,
            IMEM_FILE  => TEST_DIR & TEST_NAME & ".imem.hex",
            DMEM_FILE  => TEST_DIR & TEST_NAME & ".dmem.hex",
            TRACE_FILE => OUT_DIR & TEST_NAME & "." & mode_name & ".trace.txt")
        port map (
            clk => clk, rst => rst, halted => halted,
            dbg_addr => dbg_addr, dbg_data => dbg_data,
            dbg_regs => dbg_regs, dbg_flags => dbg_flags, dbg_hazard => dbg_hazard,
            cnt_cycles => cnt_cycles, cnt_retired => cnt_retired,
            cnt_squashed => cnt_squashed, cnt_taken => cnt_taken, cnt_stall => cnt_stall,
            dbg_retire => dbg_retire);

    process
        file fcsv, fsum : text;
        variable l      : line;
        -- регистрация команд
        variable seq    : natural := 0;
        variable first  : boolean := true;
        variable p_pc, p_slot, p_f : natural := 0;
        variable f, c, lat, s_t, w, t, op, pc : natural;
        variable cnt, t_min, t_max, t_sum, l_min, l_max, w_min, w_max, w_sum : nat_arr;
        -- участки
        variable reg    : region_arr;
        variable n_regions   : natural := 0;
        file frg        : text;
        variable st     : file_open_status;
        variable a, b   : std_logic_vector(15 downto 0);
        variable ok     : boolean;
        variable ch     : character;
        variable nm     : name_t;
        variable k      : natural;
        -- функциональная проверка
        variable expect : word_arr_t(0 to 2**DAW-1);
        variable exp_r  : word_arr_t(0 to NREG-1);
        variable errors : natural := 0;

        procedure out_line(variable ln : inout line) is
            variable dup : line;
        begin
            write(dup, ln.all);
            writeline(output, dup);
            writeline(fsum, ln);
        end procedure;
    begin
        for i in 0 to 15 loop
            cnt(i) := 0; t_min(i) := natural'high; t_max(i) := 0; t_sum(i) := 0;
            l_min(i) := natural'high; l_max(i) := 0; w_min(i) := natural'high;
            w_max(i) := 0; w_sum(i) := 0;
        end loop;

        -- чтение описания участков программы
        file_open(st, frg, TEST_DIR & TEST_NAME & ".regions", read_mode);
        if st = open_ok then
            while not endfile(frg) and n_regions < MAX_REG loop
                readline(frg, l);
                next when l'length = 0 or l(l'left) = '#';
                hread(l, a, ok);
                hread(l, b, ok);
                nm := (others => ' ');
                k := 0;
                while l'length > 0 loop
                    read(l, ch);
                    if ch /= ' ' or k > 0 then
                        if k < name_t'length then
                            k := k + 1;
                            nm(k) := ch;
                        end if;
                    end if;
                end loop;
                reg(n_regions) := (to_integer(unsigned(a)), to_integer(unsigned(b)), nm,
                              false, 0, 0, 0, 0, 0, 0);
                n_regions := n_regions + 1;
            end loop;
            file_close(frg);
        end if;

        file_open(fcsv, OUT_DIR & TEST_NAME & "." & mode_name & ".instr.csv", write_mode);
        write(l, string'("seq;cycle_wb;slot;pc;op;F_fetch;L_latency;W_wait;T_time"));
        writeline(fcsv, l);

        rst <= '1';
        wait for 2*T_CLK;
        wait until falling_edge(clk);
        rst <= '0';

        -- регистрация завершающихся команд (каждый такт, на спаде синхросигнала)
        for i in 1 to MAX_CYCLES loop
            wait until falling_edge(clk);
            exit when halted = '1';
            for s in 0 to NPIPE-1 loop
                if dbg_retire(s).valid = '1' then
                    seq := seq + 1;
                    op  := to_integer(unsigned(dbg_retire(s).op));
                    pc  := to_integer(dbg_retire(s).pc);
                    f   := to_integer(dbg_retire(s).tf);
                    c   := to_integer(cnt_cycles);
                    lat := c - f + 1;
                    if first then
                        s_t := f;
                        first := false;
                    elsif pc = p_pc + 1 and p_slot < NPIPE-1 then
                        s_t := p_f;           -- могла бы быть в той же группе
                    else
                        s_t := p_f + 1;       -- в следующей группе
                    end if;
                    w := f - s_t;
                    t := lat + w;
                    p_pc := pc; p_slot := s; p_f := f;

                    write(l, integer'image(seq) & ";" & integer'image(c) & ";" &
                             integer'image(s) & ";" & integer'image(pc) & ";" &
                             op_name(op) & ";" & integer'image(f) & ";" &
                             integer'image(lat) & ";" & integer'image(w) & ";" &
                             integer'image(t));
                    writeline(fcsv, l);

                    cnt(op) := cnt(op) + 1;
                    t_sum(op) := t_sum(op) + t;
                    w_sum(op) := w_sum(op) + w;
                    if t < t_min(op) then t_min(op) := t; end if;
                    if t > t_max(op) then t_max(op) := t; end if;
                    if lat < l_min(op) then l_min(op) := lat; end if;
                    if lat > l_max(op) then l_max(op) := lat; end if;
                    if w < w_min(op) then w_min(op) := w; end if;
                    if w > w_max(op) then w_max(op) := w; end if;

                    for r in 0 to n_regions-1 loop
                        if pc = reg(r).start_pc and not reg(r).started then
                            reg(r).started     := true;
                            reg(r).f_start     := f;
                            reg(r).seq_start   := seq;
                            reg(r).taken_start := to_integer(cnt_taken);
                        end if;
                        if pc = reg(r).end_pc and reg(r).started then
                            reg(r).c_end     := c;
                            reg(r).seq_end   := seq;
                            reg(r).taken_end := to_integer(cnt_taken);
                        end if;
                    end loop;
                end if;
            end loop;
        end loop;
        file_close(fcsv);

        -- функциональная проверка
        load_image(TEST_DIR & TEST_NAME & ".expect.hex", expect);
        for i in 0 to 2**DAW-1 loop
            dbg_addr <= to_unsigned(i, DAW);
            wait for 1 ns;
            if dbg_data /= expect(i) then
                errors := errors + 1;
                report "DM[" & integer'image(i) & "] = " & hex(dbg_data) &
                       ", expected " & hex(expect(i)) severity error;
            end if;
        end loop;
        load_image(TEST_DIR & TEST_NAME & ".regs.hex", exp_r);
        for r in 0 to NREG-1 loop
            if dbg_regs(r) /= exp_r(r) then
                errors := errors + 1;
                report "R" & integer'image(r) & " mismatch" severity error;
            end if;
        end loop;
        if halted /= '1' or dbg_hazard = '1' then
            errors := errors + 1;
        end if;

        -- отчёт
        file_open(fsum, OUT_DIR & TEST_NAME & "." & mode_name & ".perf.txt", write_mode);
        write(l, "=== " & TEST_NAME & " [" & mode_name & "]  cycles=" &
                 integer'image(to_integer(cnt_cycles)) &
                 "  retired=" & integer'image(to_integer(cnt_retired)) &
                 "  squashed=" & integer'image(to_integer(cnt_squashed)) &
                 "  taken=" & integer'image(to_integer(cnt_taken)) &
                 "  stall=" & integer'image(to_integer(cnt_stall)));
        out_line(l);
        write(l, string'("type    count  L min  L max  W min  W max  T min  T max  T avg"));
        out_line(l);
        for i in 0 to 15 loop
            if cnt(i) > 0 and i /= 15 then
                write(l, op_name(i) & pad(integer'image(cnt(i)), 8) &
                         pad(integer'image(l_min(i)), 7) & pad(integer'image(l_max(i)), 7) &
                         pad(integer'image(w_min(i)), 7) & pad(integer'image(w_max(i)), 7) &
                         pad(integer'image(t_min(i)), 7) & pad(integer'image(t_max(i)), 7) &
                         pad(ratio(t_sum(i), cnt(i)), 7));
                out_line(l);
            end if;
        end loop;
        for r in 0 to n_regions-1 loop
            if reg(r).started and reg(r).seq_end >= reg(r).seq_start then
                k := reg(r).c_end - reg(r).f_start + 1;
                write(l, "region " & reg(r).name &
                         " T=" & integer'image(k) &
                         " N=" & integer'image(reg(r).seq_end - reg(r).seq_start + 1) &
                         " IPC=" & ratio(reg(r).seq_end - reg(r).seq_start + 1, k) &
                         " CPI=" & ratio(k, reg(r).seq_end - reg(r).seq_start + 1));
                out_line(l);
            end if;
        end loop;
        if errors = 0 then
            write(l, "TEST " & TEST_NAME & " [" & mode_name & "] PASSED");
        else
            write(l, "TEST " & TEST_NAME & " [" & mode_name & "] FAILED (" &
                     integer'image(errors) & " errors)");
        end if;
        out_line(l);
        file_close(fsum);
        done <= true;
        wait;
    end process;
end architecture;

-------------------------------------------------------------------------------
-- Тестовое окружение.
--   1. Загружает образы памяти команд (TEST.imem.hex) и памяти данных
--      (TEST.dmem.hex) - через generic-параметры cpu_system.
--   2. Сбрасывает процессор и ждёт выполнения HALT (не более MAX_CYCLES тактов).
--   3. Сохраняет итоговый образ памяти данных в results/ и сравнивает его
--      с ожидаемым образом (TEST.expect.hex), а регистры - с TEST.regs.hex
--      (оба получены эталонной моделью tools/asm.py), счётчики тактов и
--      событий - с моделью времени (TEST.timing.hex); выводит статистику.
-- Итог: строка "TEST <имя> PASSED" или "TEST <имя> FAILED".
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;
use work.mem_init_pkg.all;

entity tb_cpu is
    generic (
        TEST_NAME         : string  := "t1_arith";
        TEST_DIR          : string  := "tests/build/";
        OUT_DIR           : string  := "results/";
        PREDICT_NOT_TAKEN : boolean := true;
        MAX_CYCLES        : natural := 2000
    );
end entity;

architecture sim of tb_cpu is
    constant T : time := 10 ns;

    function mode_name return string is
    begin
        if PREDICT_NOT_TAKEN then return "predict"; else return "stall"; end if;
    end function;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal done     : boolean := false;
    signal halted   : std_logic;
    signal dbg_addr : daddr_t := (others => '0');
    signal dbg_data : word_t;
    signal dbg_regs : word_arr_t(0 to NREG-1);
    signal dbg_flags : flags_t;
    signal dbg_hazard : std_logic;
    signal cnt_cycles, cnt_retired, cnt_squashed, cnt_taken, cnt_stall : unsigned(31 downto 0);

    function hex(w : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, w);
        return l.all;
    end function;
begin
    clk <= not clk after T/2 when not done;

    dut : entity work.cpu_system
        generic map (
            PREDICT_NOT_TAKEN => PREDICT_NOT_TAKEN,
            IMEM_FILE => TEST_DIR & TEST_NAME & ".imem.hex",
            DMEM_FILE => TEST_DIR & TEST_NAME & ".dmem.hex",
            TRACE_FILE => OUT_DIR & TEST_NAME & "." & mode_name & ".trace.txt")
        port map (
            clk => clk, rst => rst, halted => halted,
            dbg_addr => dbg_addr, dbg_data => dbg_data,
            dbg_regs => dbg_regs, dbg_flags => dbg_flags, dbg_hazard => dbg_hazard,
            cnt_cycles => cnt_cycles, cnt_retired => cnt_retired,
            cnt_squashed => cnt_squashed, cnt_taken => cnt_taken, cnt_stall => cnt_stall);

    process
        file fo          : text;
        variable l       : line;
        variable expect  : word_arr_t(0 to 2**DAW-1);
        variable exp_r   : word_arr_t(0 to NREG-1);
        variable exp_t   : word_arr_t(0 to 7);
        variable base    : natural;

        variable errors  : natural := 0;
        variable ok      : boolean;
        procedure check_cnt(name : string; actual : unsigned; idx : natural) is
        begin
            if actual /= unsigned(exp_t(base + idx)) then
                errors := errors + 1;
                report "counter " & name & " = " & integer'image(to_integer(actual)) &
                       ", expected " & integer'image(to_integer(unsigned(exp_t(base + idx))))
                       severity error;
            end if;
        end procedure;
    begin
        rst <= '1';
        wait for 2*T;
        wait until falling_edge(clk);
        rst <= '0';

        for i in 1 to MAX_CYCLES loop
            wait until falling_edge(clk);
            exit when halted = '1';
        end loop;

        ok := halted = '1';
        if not ok then
            report "TIMEOUT: HALT was not reached in " & integer'image(MAX_CYCLES) & " cycles"
                severity error;
        end if;

        -- итоговый образ памяти данных
        load_image(TEST_DIR & TEST_NAME & ".expect.hex", expect);
        file_open(fo, OUT_DIR & TEST_NAME & "." & mode_name & ".dmem.out.hex", write_mode);
        for a in 0 to 2**DAW-1 loop
            dbg_addr <= to_unsigned(a, DAW);
            wait for 1 ns;
            hwrite(l, dbg_data);
            if dbg_data /= expect(a) then
                errors := errors + 1;
                write(l, string'("   # MISMATCH, expected "));
                hwrite(l, expect(a));
                report "DM[" & integer'image(a) & "] = " & hex(dbg_data) &
                       ", expected " & hex(expect(a)) severity error;
            end if;
            writeline(fo, l);
        end loop;
        file_close(fo);

        -- регистры: сравнение с эталонной моделью
        load_image(TEST_DIR & TEST_NAME & ".regs.hex", exp_r);
        for r in 0 to NREG-1 loop
            if dbg_regs(r) /= exp_r(r) then
                errors := errors + 1;
                report "R" & integer'image(r) & " = " & hex(dbg_regs(r)) &
                       ", expected " & hex(exp_r(r)) severity error;
            end if;
        end loop;

        -- счётчики тактов и событий: сравнение с моделью времени
        load_image(TEST_DIR & TEST_NAME & ".timing.hex", exp_t);
        if PREDICT_NOT_TAKEN then base := 0; else base := 4; end if;
        check_cnt("cycles",   cnt_cycles,   0);
        check_cnt("squashed", cnt_squashed, 1);
        check_cnt("taken",    cnt_taken,    2);
        check_cnt("stall",    cnt_stall,    3);

        -- регистры и статистика
        write(l, string'("  registers:"));
        for r in 0 to NREG-1 loop
            write(l, string'(" R") & integer'image(r) & "=" & hex(dbg_regs(r)));
        end loop;
        writeline(output, l);
        write(l, string'("  flags: Z=") & std_logic'image(dbg_flags.z) &
                 " N=" & std_logic'image(dbg_flags.n) &
                 " V=" & std_logic'image(dbg_flags.v) &
                 " C=" & std_logic'image(dbg_flags.c));
        writeline(output, l);
        write(l, string'("  mode=") & mode_name &
                 "  cycles=" & integer'image(to_integer(cnt_cycles)) &
                 "  retired=" & integer'image(to_integer(cnt_retired)) &
                 "  squashed=" & integer'image(to_integer(cnt_squashed)) &
                 "  taken=" & integer'image(to_integer(cnt_taken)) &
                 "  stall=" & integer'image(to_integer(cnt_stall)));
        writeline(output, l);

        if dbg_hazard = '1' then
            report "test contains a data hazard (not allowed in this variant)" severity error;
            ok := false;
        end if;
        if ok and errors = 0 then
            write(l, string'("TEST ") & TEST_NAME & " [" & mode_name & "] PASSED");
        else
            write(l, string'("TEST ") & TEST_NAME & " [" & mode_name & "] FAILED (" &
                     integer'image(errors) & " mismatches)");
        end if;
        writeline(output, l);
        done <= true;
        wait;
    end process;
end architecture;

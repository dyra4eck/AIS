-------------------------------------------------------------------------------
-- Лабораторная работа 2, вариант 7
-- Суперскалярное процессорное ядро: 3 конвейера по 4 ступени.
--
--   IF  - выборка команды      : из памяти команд читаются 3 команды подряд
--                                (PC, PC+1, PC+2), по одной на конвейер;
--   OF  - выборка операнда     : декодирование, чтение регистров общего назначения;
--   EX  - вычисление результата: АЛУ (ADD/SUB), чтение памяти данных (LOAD),
--                                вычисление условия и адреса перехода (JL),
--                                обновление регистра флагов;
--   WB  - запись результата    : запись в регистры (ADD/SUB/LOAD) и
--                                в память данных (STORE).
--
-- Слот (конвейер) 0 содержит самую раннюю команду группы, слот 2 - самую позднюю.
--
-- Разрешение конфликта по управлению (выбирается generic PREDICT_NOT_TAKEN):
--
--   PREDICT_NOT_TAKEN = true  - статическое предсказание "переход не выполняется"
--       и спекулятивная выборка. Выборка продолжается с PC+3. Условие перехода
--       проверяется на ступени EX; если переход выполняется:
--         * более поздние команды той же группы на ступени EX аннулируются;
--         * группы на ступенях OF и IF (выбранные по неверному пути) сбрасываются;
--         * в PC загружается адрес перехода.
--       Потери: 0 тактов, если переход не выполняется, 2 такта - если выполняется.
--       Команды неверного пути не успевают изменить ни регистры, ни флаги,
--       ни память: все изменения состояния происходят на ступенях EX и WB.
--
--   PREDICT_NOT_TAKEN = false - приостановка выборки. Группа обрывается после
--       команды перехода, выборка следующей группы откладывается до вычисления
--       условия на ступени EX. Потери: 2 такта на каждый переход.
--
-- Флаги, изменённые более ранней командой той же группы, передаются команде JL
-- внутри ступени EX (цепочка по слотам 0 -> 1 -> 2), поэтому SUB и JL могут
-- находиться в одной группе.
--
-- Конфликты по данным (через регистры и память) в данном варианте не
-- рассматриваются: тесты составлены так, чтобы их не было. Для контроля этого
-- в модель встроен монитор (только для моделирования), выставляющий
-- dbg_hazard и выдающий сообщение, если тест всё же содержит такой конфликт.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
-- pragma translate_off
use std.textio.all;
-- pragma translate_on

entity cpu_core is
    generic (
        PREDICT_NOT_TAKEN : boolean := true;
        TRACE_FILE        : string  := ""      -- потактовая трасса конвейера ("" - нет)
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        -- память команд
        imem_addr  : out iaddr_t;
        imem_data  : in  instr_arr_t;
        -- память данных
        dmem_raddr : out daddr_arr_t;
        dmem_rdata : in  word_arr_t(0 to NPIPE-1);
        dmem_we    : out std_logic_vector(0 to NPIPE-1);
        dmem_waddr : out daddr_arr_t;
        dmem_wdata : out word_arr_t(0 to NPIPE-1);
        -- состояние
        halted     : out std_logic;
        -- отладка и статистика (для тестового окружения)
        dbg_pc       : out iaddr_t;
        dbg_regs     : out word_arr_t(0 to NREG-1);
        dbg_flags    : out flags_t;
        dbg_hazard   : out std_logic;
        cnt_cycles   : out unsigned(31 downto 0);  -- такты до останова
        cnt_retired  : out unsigned(31 downto 0);  -- завершённые команды (включая NOP)
        cnt_squashed : out unsigned(31 downto 0);  -- аннулированные команды неверного пути
        cnt_taken    : out unsigned(31 downto 0);  -- выполненные переходы
        cnt_stall    : out unsigned(31 downto 0);  -- такты приостановки выборки
        -- команды на ступени WB (завершаемые в текущем такте) с тактом выборки -
        -- для измерения времени выполнения команд в тестовом окружении
        dbg_retire   : out wb_bundle_t
    );
end entity;

architecture rtl of cpu_core is

    -- специализированные регистры
    signal pc         : iaddr_t := (others => '0');       -- программный счётчик
    signal flags      : flags_t := FLAGS_RESET;           -- регистр флагов
    -- регистры общего назначения
    signal regs       : word_arr_t(0 to NREG-1) := (others => (others => '0'));
    -- конвейерные регистры (по одному слоту на конвейер)
    signal if_of      : if_bundle_t := (others => IF_BUBBLE);
    signal of_ex      : ex_bundle_t := (others => EX_BUBBLE);
    signal ex_wb      : wb_bundle_t := (others => WB_BUBBLE);
    -- управление
    signal fetch_stop : std_logic := '0';   -- HALT прошёл EX: выборка прекращена
    signal halted_r   : std_logic := '0';   -- HALT прошёл WB: все команды завершены
    signal hazard_r   : std_logic := '0';
    -- счётчики
    signal c_cycles, c_retired, c_squashed, c_taken, c_stall : unsigned(31 downto 0)
        := (others => '0');

begin

    imem_addr <= pc;

    ports : for s in 0 to NPIPE-1 generate
        -- LOAD: адрес - значение регистра операнда2 (ступень EX)
        dmem_raddr(s) <= unsigned(of_ex(s).b(DAW-1 downto 0));
        -- STORE: запись на ступени WB
        dmem_we(s)    <= '1' when ex_wb(s).valid = '1' and ex_wb(s).op = OP_STORE else '0';
        dmem_waddr(s) <= ex_wb(s).addr;
        dmem_wdata(s) <= ex_wb(s).result;
    end generate;

    process (clk)
        variable rf        : word_arr_t(0 to NREG-1);
        variable f, fl     : flags_t;
        variable res       : word_t;
        variable wb_n      : wb_bundle_t;
        variable ex_n      : ex_bundle_t;
        variable if_n      : if_bundle_t;
        variable kill      : boolean;   -- аннулировать более поздние слоты группы на EX
        variable redirect  : boolean;   -- выполняется переход
        variable stop      : boolean;   -- HALT на EX
        variable halt_wb   : boolean;
        variable new_pc    : iaddr_t;
        variable op        : opcode_t;
        variable r1, r2    : reg_idx_t;
        variable cut       : natural;
        variable blocked   : boolean;
        variable n_ret, n_sq, n_tk : natural;
        variable hz        : boolean;
        -- pragma translate_off
        file     trace_f   : text;
        variable tl        : line;
        variable topen     : boolean := false;
        variable ev        : line;

        procedure slot(l : inout line; v : std_logic; a : iaddr_t; mark : string) is
        begin
            if v = '1' then
                write(l, mark & integer'image(to_integer(a)), right, 5);
            else
                write(l, string'("    ."));
            end if;
        end procedure;
        -- pragma translate_on
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pc         <= (others => '0');
                flags      <= FLAGS_RESET;
                regs       <= (others => (others => '0'));
                if_of      <= (others => IF_BUBBLE);
                of_ex      <= (others => EX_BUBBLE);
                ex_wb      <= (others => WB_BUBBLE);
                fetch_stop <= '0';
                halted_r   <= '0';
                hazard_r   <= '0';
                c_cycles   <= (others => '0');
                c_retired  <= (others => '0');
                c_squashed <= (others => '0');
                c_taken    <= (others => '0');
                c_stall    <= (others => '0');
            elsif halted_r = '0' then
                n_ret := 0; n_sq := 0; n_tk := 0;
                hz := false;

                ---------------------------------------------------------------
                -- WB: запись результата в регистры (STORE пишет в память через
                -- порты dmem_*). Более поздний слот имеет приоритет.
                ---------------------------------------------------------------
                rf := regs;
                halt_wb := false;
                for s in 0 to NPIPE-1 loop
                    if ex_wb(s).valid = '1' then
                        n_ret := n_ret + 1;
                        if writes_reg(ex_wb(s).op) then
                            rf(to_integer(ex_wb(s).rd)) := ex_wb(s).result;
                        end if;
                        if ex_wb(s).op = OP_HALT then
                            halt_wb := true;
                        end if;
                    end if;
                end loop;
                regs <= rf;

                ---------------------------------------------------------------
                -- EX: вычисление результата. Слоты обрабатываются в
                -- программном порядке; флаги передаются от слота к слоту.
                ---------------------------------------------------------------
                f := flags;
                kill := false; redirect := false; stop := false;
                new_pc := pc;
                for s in 0 to NPIPE-1 loop
                    wb_n(s) := WB_BUBBLE;
                    if of_ex(s).valid = '1' then
                        if kill then
                            if redirect then
                                n_sq := n_sq + 1;      -- команда после перехода в той же группе
                            end if;
                        else
                            op := of_ex(s).op;
                            wb_n(s).valid := '1';
                            wb_n(s).pc    := of_ex(s).pc;
                            wb_n(s).op    := op;
                            wb_n(s).rd    := of_ex(s).r1;
                            wb_n(s).tf    := of_ex(s).tf;
                            case op is
                                when OP_ADD | OP_SUB =>
                                    alu(op, of_ex(s).a, of_ex(s).b, res, fl);
                                    wb_n(s).result := res;
                                    f := fl;
                                when OP_LOAD =>
                                    wb_n(s).result := dmem_rdata(s);
                                when OP_STORE =>
                                    wb_n(s).result := of_ex(s).a;
                                    wb_n(s).addr   := unsigned(of_ex(s).b(DAW-1 downto 0));
                                when OP_JL =>
                                    if is_less(f) then
                                        kill     := true;
                                        redirect := true;
                                        new_pc   := of_ex(s).target;
                                        n_tk     := n_tk + 1;
                                    end if;
                                when OP_HALT =>
                                    kill := true;
                                    stop := true;
                                when others =>
                                    null;                -- NOP
                            end case;

                            -- pragma translate_off
                            -- монитор: конфликт по данным через память
                            if op = OP_LOAD then
                                for j in 0 to NPIPE-1 loop
                                    if (ex_wb(j).valid = '1' and ex_wb(j).op = OP_STORE and
                                        ex_wb(j).addr = unsigned(of_ex(s).b(DAW-1 downto 0))) or
                                       (j < s and wb_n(j).valid = '1' and wb_n(j).op = OP_STORE and
                                        wb_n(j).addr = unsigned(of_ex(s).b(DAW-1 downto 0))) then
                                        hz := true;
                                        report "DATA HAZARD (memory): LOAD at pc=" &
                                               integer'image(to_integer(of_ex(s).pc)) &
                                               " reads a cell that is not yet written"
                                               severity error;
                                    end if;
                                end loop;
                            end if;
                            -- pragma translate_on
                        end if;
                    end if;
                end loop;
                flags <= f;
                ex_wb <= wb_n;

                ---------------------------------------------------------------
                -- OF: декодирование и выборка операндов из регистров
                -- (значения, записываемые в этом такте на WB, передаются сразу).
                -- При переходе группа сбрасывается.
                ---------------------------------------------------------------
                for s in 0 to NPIPE-1 loop
                    ex_n(s) := EX_BUBBLE;
                    if if_of(s).valid = '1' then
                        if redirect or stop then
                            if redirect then
                                n_sq := n_sq + 1;
                            end if;
                        else
                            op := opcode_of(if_of(s).instr);
                            r1 := unsigned(if_of(s).instr(11 downto 8));
                            r2 := unsigned(if_of(s).instr(7 downto 4));
                            ex_n(s).valid  := '1';
                            ex_n(s).pc     := if_of(s).pc;
                            ex_n(s).op     := op;
                            ex_n(s).r1     := r1;
                            ex_n(s).r2     := r2;
                            ex_n(s).a      := rf(to_integer(r1));
                            ex_n(s).b      := rf(to_integer(r2));
                            ex_n(s).target := unsigned(if_of(s).instr(IAW-1 downto 0));
                            ex_n(s).tf     := if_of(s).tf;

                            -- pragma translate_off
                            -- монитор: конфликт по данным через регистры
                            -- (источник ещё не записан: производитель на EX или
                            -- в более раннем слоте той же группы на OF)
                            for j in 0 to NPIPE-1 loop
                                if (wb_n(j).valid = '1' and writes_reg(wb_n(j).op) and
                                    ((reads_r1(op) and wb_n(j).rd = r1) or
                                     (reads_r2(op) and wb_n(j).rd = r2))) or
                                   (j < s and ex_n(j).valid = '1' and writes_reg(ex_n(j).op) and
                                    ((reads_r1(op) and ex_n(j).r1 = r1) or
                                     (reads_r2(op) and ex_n(j).r1 = r2))) then
                                    hz := true;
                                    report "DATA HAZARD (registers): instruction at pc=" &
                                           integer'image(to_integer(if_of(s).pc)) &
                                           " reads a register that is not yet written"
                                           severity error;
                                end if;
                            end loop;
                            -- pragma translate_on
                        end if;
                    end if;
                end loop;
                of_ex <= ex_n;

                ---------------------------------------------------------------
                -- IF: выборка группы команд
                ---------------------------------------------------------------
                if_n := (others => IF_BUBBLE);
                if stop or fetch_stop = '1' then
                    fetch_stop <= '1';
                elsif redirect then
                    -- выбранная в этом такте группа относится к неверному пути
                    if PREDICT_NOT_TAKEN then
                        n_sq := n_sq + NPIPE;
                    else
                        c_stall <= c_stall + 1;  -- выборки нет: PC загружается адресом перехода
                    end if;
                    pc <= new_pc;
                else
                    blocked := false;
                    if not PREDICT_NOT_TAKEN then
                        -- переход на OF или EX: ждём вычисления условия
                        for s in 0 to NPIPE-1 loop
                            if (if_of(s).valid = '1' and is_ctrl(opcode_of(if_of(s).instr))) or
                               (of_ex(s).valid = '1' and is_ctrl(of_ex(s).op)) then
                                blocked := true;
                            end if;
                        end loop;
                    end if;
                    if blocked then
                        c_stall <= c_stall + 1;
                    else
                        cut := NPIPE;
                        for s in 0 to NPIPE-1 loop
                            if s < cut then
                                if_n(s) := ('1', pc + s, imem_data(s), c_cycles);
                                if not PREDICT_NOT_TAKEN and is_ctrl(opcode_of(imem_data(s))) then
                                    cut := s + 1;   -- группа обрывается после перехода
                                end if;
                            end if;
                        end loop;
                        pc <= pc + cut;
                    end if;
                end if;
                if_of <= if_n;

                -- pragma translate_off
                -- трасса: состояние ступеней в этом такте
                if TRACE_FILE /= "" then
                    if not topen then
                        file_open(trace_f, TRACE_FILE, write_mode);
                        write(tl, string'("cycle |       IF        |       OF        |       EX        |       WB        | event"));
                        writeline(trace_f, tl);
                        topen := true;
                    end if;
                    write(tl, integer'image(to_integer(c_cycles)), right, 5);
                    write(tl, string'(" |"));
                    for s in 0 to NPIPE-1 loop
                        if PREDICT_NOT_TAKEN and (redirect or stop) and fetch_stop = '0' then
                            slot(tl, '1', pc + s, "x");    -- выбрана и отброшена
                        else
                            slot(tl, if_n(s).valid, if_n(s).pc, "");
                        end if;
                    end loop;
                    write(tl, string'("  |"));
                    for s in 0 to NPIPE-1 loop
                        if redirect or stop then slot(tl, if_of(s).valid, if_of(s).pc, "x");
                        else slot(tl, if_of(s).valid, if_of(s).pc, ""); end if;
                    end loop;
                    write(tl, string'("  |"));
                    for s in 0 to NPIPE-1 loop
                        if of_ex(s).valid = '1' and wb_n(s).valid = '0' then
                            slot(tl, '1', of_ex(s).pc, "x");
                        else
                            slot(tl, of_ex(s).valid, of_ex(s).pc, "");
                        end if;
                    end loop;
                    write(tl, string'("  |"));
                    for s in 0 to NPIPE-1 loop slot(tl, ex_wb(s).valid, ex_wb(s).pc, ""); end loop;
                    write(tl, string'("  | "));
                    if redirect then
                        write(tl, "JL taken -> " & integer'image(to_integer(new_pc)));
                    elsif stop then
                        write(tl, string'("HALT in EX: fetch stopped"));
                    elsif not PREDICT_NOT_TAKEN and fetch_stop = '0' and if_n(0).valid = '0' then
                        write(tl, string'("fetch stalled (branch in OF/EX)"));
                    end if;
                    if halt_wb then
                        write(tl, string'("HALT in WB: done"));
                    end if;
                    writeline(trace_f, tl);
                end if;
                -- pragma translate_on

                ---------------------------------------------------------------
                if halt_wb then
                    halted_r <= '1';
                end if;
                if hz then
                    hazard_r <= '1';
                end if;
                c_cycles   <= c_cycles + 1;
                c_retired  <= c_retired + n_ret;
                c_squashed <= c_squashed + n_sq;
                c_taken    <= c_taken + n_tk;
            end if;
        end if;
    end process;

    halted       <= halted_r;
    dbg_pc       <= pc;
    dbg_regs     <= regs;
    dbg_flags    <= flags;
    dbg_hazard   <= hazard_r;
    cnt_cycles   <= c_cycles;
    cnt_retired  <= c_retired;
    cnt_squashed <= c_squashed;
    cnt_taken    <= c_taken;
    cnt_stall    <= c_stall;
    dbg_retire   <= ex_wb;

end architecture;

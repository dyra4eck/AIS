-------------------------------------------------------------------------------
-- Лабораторная работа 2, вариант 7
-- Общие типы, константы и функции процессорного ядра.
--
--   3 конвейера, 16 регистров общего назначения (16 бит),
--   команды Load, Store, +, -, условный переход по "<" (JL), NOP, HALT.
--   Разрешаемый конфликт: конфликт по управлению.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpu_pkg is

    constant NPIPE : positive := 3;   -- количество конвейеров
    constant NREG  : positive := 16;  -- количество регистров общего назначения
    constant DW    : positive := 16;  -- разрядность данных
    constant IW    : positive := 16;  -- разрядность команды
    constant IAW   : positive := 8;   -- разрядность адреса памяти команд
    constant TW    : positive := 32;  -- разрядность метки времени (для измерений)
    constant DAW   : positive := 8;   -- разрядность адреса памяти данных

    subtype word_t    is std_logic_vector(DW-1 downto 0);
    subtype instr_t   is std_logic_vector(IW-1 downto 0);
    subtype iaddr_t   is unsigned(IAW-1 downto 0);
    subtype daddr_t   is unsigned(DAW-1 downto 0);
    subtype reg_idx_t is unsigned(3 downto 0);
    subtype opcode_t  is std_logic_vector(3 downto 0);
    subtype tstamp_t  is unsigned(TW-1 downto 0);  -- номер такта (отладка, измерения)

    -- Коды операций (биты 15..12 команды)
    constant OP_NOP   : opcode_t := "0000";  -- NOP
    constant OP_LOAD  : opcode_t := "0001";  -- LOAD  Rd, (Ra) : Rd := DM[Ra]
    constant OP_STORE : opcode_t := "0010";  -- STORE Rs, (Ra) : DM[Ra] := Rs
    constant OP_ADD   : opcode_t := "0011";  -- ADD   Rd, Rs   : Rd := Rd + Rs, флаги
    constant OP_SUB   : opcode_t := "0100";  -- SUB   Rd, Rs   : Rd := Rd - Rs, флаги
    constant OP_JL    : opcode_t := "0101";  -- JL    addr     : if (N xor V) then PC := addr
    constant OP_HALT  : opcode_t := "1111";  -- HALT           : останов (служебная команда)

    type word_arr_t  is array (natural range <>) of word_t;
    type instr_arr_t is array (0 to NPIPE-1) of instr_t;
    type daddr_arr_t is array (0 to NPIPE-1) of daddr_t;

    -- Регистр флагов
    type flags_t is record
        z : std_logic;  -- результат равен нулю
        n : std_logic;  -- результат отрицательный
        v : std_logic;  -- переполнение (знаковое)
        c : std_logic;  -- перенос (ADD) / заём (SUB)
    end record;
    constant FLAGS_RESET : flags_t := (others => '0');

    -- Регистр между ступенями "выборка команды" и "выборка операнда"
    type if_slot_t is record
        valid : std_logic;
        pc    : iaddr_t;
        instr : instr_t;
        tf    : tstamp_t;   -- такт выборки команды (только для измерений)
    end record;
    constant IF_BUBBLE : if_slot_t := ('0', (others => '0'), (others => '0'), (others => '0'));

    -- Регистр между ступенями "выборка операнда" и "вычисление результата"
    type ex_slot_t is record
        valid  : std_logic;
        pc     : iaddr_t;
        op     : opcode_t;
        r1     : reg_idx_t;  -- операнд1: номер регистра
        r2     : reg_idx_t;  -- операнд2: номер регистра
        a      : word_t;     -- значение регистра операнда1
        b      : word_t;     -- значение регистра операнда2
        target : iaddr_t;    -- адрес перехода (JL)
        tf     : tstamp_t;   -- такт выборки команды
    end record;
    constant EX_BUBBLE : ex_slot_t := ('0', (others => '0'), OP_NOP, (others => '0'),
                                       (others => '0'), (others => '0'), (others => '0'),
                                       (others => '0'), (others => '0'));

    -- Регистр между ступенями "вычисление результата" и "запись результата"
    type wb_slot_t is record
        valid  : std_logic;
        pc     : iaddr_t;
        op     : opcode_t;
        rd     : reg_idx_t;  -- регистр результата (ADD/SUB/LOAD)
        result : word_t;     -- результат (ADD/SUB/LOAD) или записываемые данные (STORE)
        addr   : daddr_t;    -- адрес в памяти данных (STORE)
        tf     : tstamp_t;   -- такт выборки команды
    end record;
    constant WB_BUBBLE : wb_slot_t := ('0', (others => '0'), OP_NOP, (others => '0'),
                                       (others => '0'), (others => '0'), (others => '0'));

    type if_bundle_t is array (0 to NPIPE-1) of if_slot_t;
    type ex_bundle_t is array (0 to NPIPE-1) of ex_slot_t;
    type wb_bundle_t is array (0 to NPIPE-1) of wb_slot_t;

    function opcode_of(i : instr_t) return opcode_t;
    function is_ctrl(op : opcode_t) return boolean;      -- JL, HALT
    function writes_reg(op : opcode_t) return boolean;   -- LOAD, ADD, SUB
    function reads_r1(op : opcode_t) return boolean;     -- ADD, SUB, STORE
    function reads_r2(op : opcode_t) return boolean;     -- ADD, SUB, LOAD, STORE
    function is_less(f : flags_t) return boolean;        -- условие перехода "<"

    -- АЛУ: ADD/SUB с формированием флагов
    procedure alu(op : in opcode_t; a, b : in word_t;
                  res : out word_t; f : out flags_t);

end package;

package body cpu_pkg is

    function opcode_of(i : instr_t) return opcode_t is
    begin
        return i(15 downto 12);
    end function;

    function is_ctrl(op : opcode_t) return boolean is
    begin
        return op = OP_JL or op = OP_HALT;
    end function;

    function writes_reg(op : opcode_t) return boolean is
    begin
        return op = OP_LOAD or op = OP_ADD or op = OP_SUB;
    end function;

    function reads_r1(op : opcode_t) return boolean is
    begin
        return op = OP_ADD or op = OP_SUB or op = OP_STORE;
    end function;

    function reads_r2(op : opcode_t) return boolean is
    begin
        return op = OP_ADD or op = OP_SUB or op = OP_LOAD or op = OP_STORE;
    end function;

    function is_less(f : flags_t) return boolean is
    begin
        return (f.n xor f.v) = '1';
    end function;

    procedure alu(op : in opcode_t; a, b : in word_t;
                  res : out word_t; f : out flags_t) is
        variable ua, ub, ur : unsigned(DW downto 0);
        variable r          : word_t;
    begin
        ua := unsigned('0' & a);
        ub := unsigned('0' & b);
        if op = OP_SUB then
            ur := ua - ub;
            r  := std_logic_vector(ur(DW-1 downto 0));
            f.v := (a(DW-1) xor b(DW-1)) and (r(DW-1) xor a(DW-1));
        else
            ur := ua + ub;
            r  := std_logic_vector(ur(DW-1 downto 0));
            f.v := not (a(DW-1) xor b(DW-1)) and (r(DW-1) xor a(DW-1));
        end if;
        f.c := ur(DW);
        f.n := r(DW-1);
        if unsigned(r) = 0 then f.z := '1'; else f.z := '0'; end if;
        res := r;
    end procedure;

end package body;

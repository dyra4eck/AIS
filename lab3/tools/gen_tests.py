#!/usr/bin/env python3
"""
Генератор тестов ЛР3 (tests/*.asm).

Тесты минимального времени (без конфликтов):
  min_all   - потоки по 30 команд ADD, SUB, LOAD, STORE, NOP (без переходов)
  min_jl    - поток из 30 невыполняемых переходов JL
Тесты максимального времени (с конфликтами по управлению):
  max_taken - каждая команда (всех типов) стоит по адресу выполняемого перехода
  max_seq   - каждая команда следует за невыполняемым JL в той же группе
              (худший случай для режима приостановки выборки)
Синтетические программы для оценки производительности:
  bench_k{K}_p{P} - блоки по K команд, каждый заканчивается переходом JL,
              доля выполняемых переходов P% (0, 50, 100)

Конфликты по данным исключены: регистр, записанный в группе g, читается
не раньше группы g+2 (регистры чередуются по группам).
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "tests")
N_STREAM = 30


def write(name, title, text):
    with open(os.path.join(OUT, name + ".asm"), "w", encoding="utf-8") as f:
        f.write(f"; {title}\n; (сгенерировано tools/gen_tests.py)\n\n{text}")


def setup(extra=""):
    """Общая часть: DM[0] = 1, DM[1] = -1; R1 = 1."""
    return (".data\n.org 0\n        .word 1          ; 0: константа 1\n"
            "        .word -1         ; 1: константа -1\n\n.text\n"
            "; G0\n        LOAD  R1, (R0)   ; R1 = 1\n        NOP 2\n"
            "; G1\n        NOP 3\n" + extra)


def stream(op_fmt, n, first_group):
    """n команд одного типа по 3 в группе; наборы регистров чередуются по группам."""
    sets = [(2, 3, 4), (5, 6, 7)]
    lines = []
    for i in range(n):
        g, s = divmod(i, 3)
        r = sets[(first_group + g) % 2][s]
        if s == 0:
            lines.append(f"; G{first_group + g}")
        lines.append("        " + op_fmt.format(r=r))
    return "\n".join(lines) + "\n"


def gen_min_all():
    text = setup()
    g = 2
    for name, fmt in (("add", "ADD   R{r}, R1"), ("sub", "SUB   R{r}, R1"),
                      ("load", "LOAD  R{r}, (R0)"), ("store", "STORE R1, (R0)"),
                      ("nop", "NOP")):
        text += f".region {name}{N_STREAM}\n" + stream(fmt, N_STREAM, g) + ".endregion\n"
        g += N_STREAM // 3
    text += f"; G{g}\n        HALT\n        NOP 2\n"
    write("min_all", "Минимальное время: потоки однотипных команд без конфликтов", text)


def gen_min_jl():
    text = setup("; G2\n        ADD   R15, R1    ; R15 = 1, флаги: не \"<\"\n        NOP 2\n")
    text += f".region jl{N_STREAM}\n"
    for i in range(N_STREAM):
        if i % 3 == 0:
            text += f"; G{3 + i // 3}\n"
        text += "        JL    fail       ; не выполняется\n"
    text += ".endregion\n        HALT\n        NOP 2\n"
    text += "fail:\n        STORE R1, (R1)   ; признак ошибки: DM[1] := 1\n        HALT\n"
    write("min_jl", "Минимальное время: поток невыполняемых переходов", text)


# команды X для тестов максимального времени; флаги не должны меняться
# (max_taken: всегда "<", max_seq: всегда не "<")
X_TAKEN = ["ADD   R5, R14    ; -k + (-1): остаётся < 0",
           "SUB   R6, R1     ; -k - 1: остаётся < 0",
           "LOAD  R7, (R0)",
           "STORE R1, (R0)",
           "NOP",
           None]  # None - JL
X_SEQ = ["ADD   R5, R0     ; 1 + 0: не \"<\"",
         "SUB   R6, R0     ; 1 - 0: не \"<\"",
         "LOAD  R7, (R0)",
         "STORE R1, (R0)",
         "NOP",
         "JL    fail       ; не выполняется"]
REPS = 4


def gen_max_taken():
    text = setup("; G2\n        SUB   R14, R1    ; R14 = -1\n        SUB   R5, R1     ; R5 = -1\n"
                 "        SUB   R6, R1     ; R6 = -1, флаги: \"<\"\n; G3\n        NOP 3\n")
    text += ".region chain\n"
    n = len(X_TAKEN) * REPS
    for b in range(n):
        x = X_TAKEN[b % len(X_TAKEN)]
        nxt = f"b{b + 1}" if b + 1 < n else "done"
        text += f"b{b}:                    ; G{4 + b}\n"
        if x is None:
            text += f"        JL    {nxt}{' ' * (11 - len(nxt))}; JL по адресу перехода, в конвейере 0\n"
            if b == n - 1:
                text += ".endregion            ; последняя завершаемая команда участка - JL\n"
            text += "        NOP              ; аннулируется\n        NOP              ; аннулируется\n"
        else:
            text += f"        {x}\n        NOP\n        JL    {nxt}\n"
    if X_TAKEN[(n - 1) % len(X_TAKEN)] is not None:
        text += ".endregion\n"
    text += "done:\n        HALT\n        NOP 2\n"
    write("max_taken", "Максимальное время: каждая команда по адресу выполняемого перехода", text)


def gen_max_seq():
    text = setup("; G2\n        ADD   R5, R1     ; R5 = 1\n        ADD   R6, R1     ; R6 = 1\n"
                 "        ADD   R15, R1    ; флаги: не \"<\"\n; G3\n        NOP 3\n")
    text += ".region pairs\n"
    for i in range(len(X_SEQ) * REPS):
        text += "        JL    fail       ; не выполняется\n"
        text += "        " + X_SEQ[i % len(X_SEQ)] + "\n"
    text += ".endregion\n        HALT\n        NOP 2\n"
    text += "fail:\n        STORE R1, (R1)   ; признак ошибки\n        HALT\n"
    write("max_seq", "Максимальное время: каждая команда следует за невыполняемым JL", text)


def gen_bench(k, p, total=72):
    """Блоки по k команд (k кратно 3): k-2 команды ADD, установка флагов, JL.
    Переход всегда на следующий блок, поэтому путь выполнения одинаков при
    любом исходе перехода, а выполняется ли он - задаётся флагами."""
    blocks = total // k
    text = (".data\n.org 0\n        .word 1\n        .word -1\n\n.text\n"
            "; G0\n        LOAD  R1, (R0)   ; R1 = 1\n        NOP 2\n; G1\n        NOP 3\n"
            "; G2\n        LOAD  R12, (R1)  ; -1\n        LOAD  R14, (R1)  ; -1\n"
            "        ADD   R13, R1    ; 1\n"
            "; G3\n        ADD   R15, R1    ; 1\n        NOP 2\n; G4\n        NOP 3\n; G5\n        NOP 3\n")
    text += ".region blocks\n"
    sets = [(2, 3, 4), (5, 6, 7)]
    addr = 18
    for b in range(blocks):
        taken = (p == 100) or (p == 50 and b % 2 == 0)
        text += f"blk{b}:\n"
        for i in range(k - 2):
            g, s = divmod(addr, 3)
            text += f"        ADD   R{sets[g % 2][s]}, R1\n"
            addr += 1
        reg = (12 if b % 2 == 0 else 14) if taken else (13 if b % 2 == 0 else 15)
        note = '"<" - переход выполняется' if taken else 'не "<"'
        text += f"        ADD   R{reg}, R0    ; флаги: {note}\n"
        text += f"        JL    {'blk' + str(b + 1) if b + 1 < blocks else 'done'}\n"
        addr += 2
    text += ".endregion\ndone:\n        HALT\n        NOP 2\n"
    write(f"bench_k{k}_p{p}",
          f"Синтетическая программа: блоки по {k} команд, переход в конце блока, "
          f"выполняется {p}% переходов", text)


def main():
    os.makedirs(OUT, exist_ok=True)
    gen_min_all()
    gen_min_jl()
    gen_max_taken()
    gen_max_seq()
    for k in (3, 6, 12):
        for p in (0, 50, 100):
            gen_bench(k, p)
    print("tests generated")


if __name__ == "__main__":
    main()

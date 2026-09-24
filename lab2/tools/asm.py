#!/usr/bin/env python3
"""
Ассемблер и эталонная (последовательная) модель процессора, вариант 7.

    python3 tools/asm.py tests/t1_arith.asm [-o tests/build]

Создаёт в каталоге build:
    NAME.imem.hex    - образ памяти команд
    NAME.dmem.hex    - образ памяти данных на момент начала теста
    NAME.expect.hex  - образ памяти данных на момент завершения теста,
                       вычисленный эталонной моделью (команды выполняются строго
                       по одной, без конвейера - т.е. так, как задумано программистом)
    NAME.regs.hex    - ожидаемые значения регистров R0..R15 после завершения
    NAME.timing.hex  - ожидаемые значения счётчиков (такты, аннулированные
                       команды, переходы, простои) для режимов predict и stall
    NAME.regions     - измеряемые участки программы (адрес начала, конца, имя)
    NAME.lst         - листинг: адрес, группа выборки, код, мнемоника;
                       итоговые регистры и число выполненных команд

Синтаксис:
    ; комментарий
    .text                     - секция команд (по умолчанию)
    .data                     - секция данных
    .org N                    - текущий адрес секции
    метка:
    LOAD  Rd, (Ra)            Rd := DM[Ra]
    STORE Rs, (Ra)            DM[Ra] := Rs
    ADD   Rd, Rs              Rd := Rd + Rs      (флаги Z N V C)
    SUB   Rd, Rs              Rd := Rd - Rs      (флаги Z N V C)
    JL    метка|адрес         if N xor V: PC := адрес
    NOP [n]                   n команд NOP (по умолчанию 1)
    HALT
    .word v1, v2, ...         слова данных (числа или метки)
    .fill n, v                n слов со значением v
    .region имя / .endregion  участок программы, время выполнения которого
                              измеряет тестовое окружение (ЛР3)
"""
import argparse
import os
import re
import sys

OPS = {"NOP": 0x0, "LOAD": 0x1, "STORE": 0x2, "ADD": 0x3, "SUB": 0x4, "JL": 0x5, "HALT": 0xF}
MNEM = {v: k for k, v in OPS.items()}
NPIPE = 3
MEM = 256
MASK = 0xFFFF
TEXT_LABELS = set()   # метки секции .text (для листинга)
REGIONS = []          # измеряемые участки: [имя, первый адрес, последний адрес]


def err(ln, msg):
    sys.exit(f"line {ln}: {msg}")


def reg(tok, ln):
    m = re.fullmatch(r"[Rr](\d+)", tok.strip())
    if not m or int(m.group(1)) > 15:
        err(ln, f"bad register '{tok}'")
    return int(m.group(1))


def mreg(tok, ln):
    m = re.fullmatch(r"\(\s*([Rr]\d+)\s*\)", tok.strip())
    if not m:
        err(ln, f"expected (Rn), got '{tok}'")
    return reg(m.group(1), ln)


def value(tok, labels, ln):
    tok = tok.strip()
    if tok in labels:
        return labels[tok]
    try:
        return int(tok, 0)
    except ValueError:
        err(ln, f"bad value '{tok}'")


def parse(path):
    """Два прохода: сбор меток, затем кодирование."""
    lines = []
    with open(path, encoding="utf-8") as f:
        for ln, raw in enumerate(f, 1):
            text = raw.split(";")[0].strip()
            lines.append((ln, text, raw.rstrip("\n")))

    def walk(labels, emit):
        sect, pc = "text", {"text": 0, "data": 0}
        for ln, text, raw in lines:
            while True:
                m = re.match(r"([A-Za-z_]\w*):\s*(.*)", text)
                if not m:
                    break
                if emit is None:
                    labels.setdefault(m.group(1), pc[sect])
                    TEXT_LABELS.add(m.group(1)) if sect == "text" else None
                text = m.group(2)
            if not text:
                continue
            parts = text.split(None, 1)
            op, args = parts[0].upper(), (parts[1] if len(parts) > 1 else "")
            argv = [a.strip() for a in args.split(",")] if args else []
            if op == ".REGION":
                if emit:
                    REGIONS.append([argv[0] if argv else f"r{len(REGIONS)}", pc["text"], None])
            elif op == ".ENDREGION":
                if emit:
                    if not REGIONS or REGIONS[-1][2] is not None:
                        err(ln, ".endregion without .region")
                    REGIONS[-1][2] = pc["text"] - 1
            elif op in (".TEXT", ".DATA"):
                sect = op[1:].lower()
            elif op == ".ORG":
                pc[sect] = value(argv[0], labels, ln)
            elif op == ".WORD":
                for a in argv:
                    if emit:
                        emit("data", pc["data"], value(a, labels, ln) & MASK, ln, raw)
                    pc["data"] += 1
            elif op == ".FILL":
                n = value(argv[0], labels, ln)
                v = value(argv[1], labels, ln) if len(argv) > 1 else 0
                for _ in range(n):
                    if emit:
                        emit("data", pc["data"], v & MASK, ln, raw)
                    pc["data"] += 1
            elif op in OPS:
                if sect != "text":
                    err(ln, "instruction outside .text")
                count = 1
                if op == "NOP" and argv:
                    count = value(argv[0], labels, ln)
                for _ in range(count):
                    if emit:
                        emit("text", pc["text"], encode(op, argv, labels, ln), ln, raw)
                    pc["text"] += 1
            else:
                err(ln, f"unknown mnemonic '{op}'")

    labels = {}
    walk(labels, None)
    imem, dmem = [0] * MEM, [0] * MEM
    src = {}

    def emit(sect, addr, word, ln, raw):
        if addr >= MEM:
            err(ln, "address out of range")
        (imem if sect == "text" else dmem)[addr] = word
        if sect == "text":
            src[addr] = raw.split(";")[0].strip()

    walk(labels, emit)
    return imem, dmem, src, labels


def encode(op, argv, labels, ln):
    code = OPS[op] << 12
    if op in ("ADD", "SUB"):
        if len(argv) != 2:
            err(ln, f"{op} needs 2 operands")
        return code | reg(argv[0], ln) << 8 | reg(argv[1], ln) << 4
    if op in ("LOAD", "STORE"):
        if len(argv) != 2:
            err(ln, f"{op} needs 2 operands")
        return code | reg(argv[0], ln) << 8 | mreg(argv[1], ln) << 4
    if op == "JL":
        if len(argv) != 1:
            err(ln, "JL needs an address")
        return code | (value(argv[0], labels, ln) & 0xFF)
    return code


def disasm(w):
    op = MNEM.get(w >> 12, "???")
    r1, r2 = (w >> 8) & 15, (w >> 4) & 15
    if op in ("ADD", "SUB"):
        return f"{op:5} R{r1}, R{r2}"
    if op in ("LOAD", "STORE"):
        return f"{op:5} R{r1}, (R{r2})"
    if op == "JL":
        return f"JL    {w & 0xFF}"
    return op


def s16(x):
    return x - 0x10000 if x & 0x8000 else x


def run(imem, dmem, max_steps=100000):
    """Эталонная модель: последовательное выполнение команд."""
    regs, mem = [0] * 16, list(dmem)
    n = v = 0
    pc, steps, taken = 0, 0, 0
    while True:
        if steps >= max_steps:
            sys.exit("reference model: HALT not reached")
        w = imem[pc]
        op, r1, r2 = w >> 12, (w >> 8) & 15, (w >> 4) & 15
        steps += 1
        npc = (pc + 1) & 0xFF
        if op == OPS["LOAD"]:
            regs[r1] = mem[regs[r2] & 0xFF]
        elif op == OPS["STORE"]:
            mem[regs[r2] & 0xFF] = regs[r1]
        elif op in (OPS["ADD"], OPS["SUB"]):
            a, b = regs[r1], regs[r2]
            full = a + b if op == OPS["ADD"] else a - b
            res = full & MASK
            sa, sb, sr = s16(a), s16(b), s16(res)
            exact = sa + sb if op == OPS["ADD"] else sa - sb
            v = int(exact != sr)
            n = int(sr < 0)
            regs[r1] = res
        elif op == OPS["JL"]:
            if n ^ v:
                npc = w & 0xFF
                taken += 1
        elif op == OPS["HALT"]:
            return mem, regs, steps, taken
        pc = npc


def timing(imem, dmem, predict):
    """Модель времени на уровне групп выборки (для проверки счётчиков RTL).

    Каждый такт выбирается одна группа (до NPIPE команд) либо выборка простаивает.
    predict: группа - всегда 3 команды; выполненный переход аннулирует более
             поздние команды своей группы и две уже выбранные группы (2 такта потерь).
    stall:   группа обрывается после JL/HALT; пока JL на ступенях OF и EX,
             выборка простаивает 2 такта (после HALT - 1 такт, затем выборка
             прекращается).
    HALT, выбранный в такте k, проходит WB в такте k+3: всего k+4 тактов.
    Возвращает: (такты, аннулированные команды, выполненные переходы, такты простоя).
    """
    st = {"regs": [0] * 16, "dmem": list(dmem), "n": 0, "v": 0}
    pc = cycle = squashed = taken = stall = 0
    while cycle < 100000:
        group = []
        for s in range(NPIPE):
            w = imem[(pc + s) & 0xFF]
            group.append(w)
            if not predict and (w >> 12) in (OPS["JL"], OPS["HALT"]):
                break
        next_pc, lost = (pc + len(group)) & 0xFF, 0
        for s, w in enumerate(group):
            op = w >> 12
            if op == OPS["HALT"]:
                return cycle + 4, squashed, taken, stall + (0 if predict else 1)
            if op == OPS["JL"]:
                if not predict:
                    stall, lost = stall + 2, 2
                if st["n"] ^ st["v"]:
                    taken += 1
                    next_pc = w & 0xFF
                    if predict:
                        squashed += (len(group) - s - 1) + 2 * NPIPE
                        lost = 2
                    break
            else:
                execute(st, w)
        pc = next_pc
        cycle += 1 + lost
    sys.exit("timing model: HALT not reached")


def execute(st, w):
    """Выполнение одной команды LOAD/STORE/ADD/SUB/NOP над состоянием st."""
    regs = st["regs"]
    op, r1, r2 = w >> 12, (w >> 8) & 15, (w >> 4) & 15
    if op == OPS["LOAD"]:
        regs[r1] = st["dmem"][regs[r2] & 0xFF]
    elif op == OPS["STORE"]:
        st["dmem"][regs[r2] & 0xFF] = regs[r1]
    elif op in (OPS["ADD"], OPS["SUB"]):
        a, b = regs[r1], regs[r2]
        res = (a + b if op == OPS["ADD"] else a - b) & MASK
        exact = s16(a) + s16(b) if op == OPS["ADD"] else s16(a) - s16(b)
        st["v"] = int(exact != s16(res))
        st["n"] = int(s16(res) < 0)
        regs[r1] = res


def write_hex(path, words, comments=None, upto=None):
    last = upto if upto is not None else max([i for i, w in enumerate(words) if w] + [0]) + 1
    with open(path, "w") as f:
        for a in range(last):
            c = f"   # {a:3d}" + (f": {comments[a]}" if comments and a in comments else "")
            f.write(f"{words[a]:04X}{c}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("-o", "--out", default=os.path.join(os.path.dirname(__file__), "..", "tests", "build"))
    args = ap.parse_args()
    name = os.path.splitext(os.path.basename(args.src))[0]
    os.makedirs(args.out, exist_ok=True)
    base = os.path.join(args.out, name)

    imem, dmem, src, labels = parse(args.src)
    mem, regs, steps, taken = run(imem, dmem)

    prog_len = max(src) + 1 if src else 0
    write_hex(base + ".imem.hex", imem, {a: disasm(imem[a]) for a in src}, prog_len)
    dlen = max([i for i, w in enumerate(dmem) if w] + [i for i, w in enumerate(mem) if w] + [0]) + 1
    write_hex(base + ".dmem.hex", dmem, upto=dlen)
    write_hex(base + ".expect.hex", mem, upto=dlen)
    write_hex(base + ".regs.hex", regs, {i: f"R{i}" for i in range(16)}, 16)
    with open(base + ".regions", "w") as f:
        f.write("# start end name - участки программы для измерения времени (.region)\n")
        for name_r, a, b in REGIONS:
            if b is None:
                sys.exit(f"region {name_r}: missing .endregion")
            f.write(f"{a:04X} {b:04X} {name_r}\n")
    tp, ts = timing(imem, dmem, True), timing(imem, dmem, False)
    names = ["cycles", "squashed", "taken", "stall"]
    write_hex(base + ".timing.hex", list(tp) + list(ts),
              {i: ("predict " if i < 4 else "stall ") + names[i % 4] for i in range(8)}, 8)

    addr_label = {a: l for l, a in labels.items() if l in TEXT_LABELS}
    with open(base + ".lst", "w") as f:
        f.write(f"; {name}: program {prog_len} words\n")
        f.write("; addr  grp  code  instruction\n")
        for a in range(prog_len):
            lab = addr_label.get(a, "")
            f.write(f"  {a:3d}   {a // NPIPE:3d}  {imem[a]:04X}  {(lab + ':') if lab else '':10} {disasm(imem[a])}\n")
        f.write(f"; reference model: {steps} instructions executed, {taken} branches taken\n")
        for mode, t in (("predict", tp), ("stall", ts)):
            f.write(f"; timing [{mode:7}]: cycles={t[0]} squashed={t[1]} taken={t[2]} stall={t[3]}\n")
        f.write("; registers: " + " ".join(f"R{i}={r:04X}" for i, r in enumerate(regs)) + "\n")
        f.write("; data memory (addr: before -> after):\n")
        for a in range(dlen):
            mark = "   *" if dmem[a] != mem[a] else ""
            f.write(f";   {a:3d}: {dmem[a]:04X} -> {mem[a]:04X}  ({s16(mem[a])}){mark}\n")
    print(f"{name}: {prog_len} words, reference: {steps} instr, {taken} taken, "
          f"R=" + ",".join(f"{s16(r)}" for r in regs))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Аналитическая модель процессорного ядра ЛР2 (вариант 7) и сравнение её оценок
с результатами моделирования RTL.

    ./run_perf.sh && python3 tools/model.py      ->  docs/comparison.md

Параметры модели: P = 3 конвейера, S = 4 ступени, r = 3 - номер ступени,
на которой вычисляется условие перехода (EX), штраф D = r - 1 = 2 такта.

Модель 1 (рекуррентная). Для команд k = 1, 2, ... в порядке выполнения программы:
    g_k - команда k попадает в ту же группу выборки, что и k-1:
          predict: pc_k = pc_{k-1} + 1, slot_{k-1} < P-1, k-1 - не выполненный JL;
          stall:   pc_k = pc_{k-1} + 1, slot_{k-1} < P-1, k-1 - не JL;
    F_k = F_{k-1}                          если g_k,
          F_{k-1} + 1 + D * b_{k-1}         иначе,
          где b_{k-1} = 1, если k-1 - выполненный JL (predict) или любой JL (stall);
    slot_k = slot_{k-1} + 1 если g_k, иначе 0;
    C_k = F_k + S - 1,  L_k = S,
    S_k = F_{k-1} если pc_k = pc_{k-1} + 1 и slot_{k-1} < P-1, иначе F_{k-1} + 1,
    W_k = F_k - S_k,  T_k = L_k + W_k.
    Время участка: T = C_end - F_start + 1; время программы: C_HALT + 1.

Модель 2 (формулы в замкнутом виде) - см. README, раздел 2; здесь вычисляется
для каждого измеряемого участка тестов.
"""
import math
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "..", "lab2", "tools"))
import asm  # noqa: E402  (ассемблер и эталонная модель ЛР2)

P, S, R_STAGE = 3, 4, 3
D = R_STAGE - 1
OPN = {0: "NOP", 1: "LOAD", 2: "STORE", 3: "ADD", 4: "SUB", 5: "JL", 15: "HALT"}
TYPES = ["LOAD", "STORE", "ADD", "SUB", "JL", "NOP"]
B = os.path.join(ROOT, "tests", "build")
RES = os.path.join(ROOT, "results")


def words(path):
    out = []
    for line in open(path):
        line = line.strip()
        if line and line[0] not in "#-":
            out.append(int(line.split()[0], 16))
    return out + [0] * (256 - len(out))


def trace(name):
    """Динамическая трасса: (pc, op, taken) - последовательное выполнение."""
    imem, dmem = words(f"{B}/{name}.imem.hex"), words(f"{B}/{name}.dmem.hex")
    st = {"regs": [0] * 16, "dmem": dmem, "n": 0, "v": 0}
    pc, tr = 0, []
    while len(tr) < 100000:
        w = imem[pc]
        op = w >> 12
        taken = False
        if op == 5:
            taken = bool(st["n"] ^ st["v"])
        elif op != 15:
            asm.execute(st, w)
        tr.append((pc, op, taken))
        if op == 15:
            return tr
        pc = (w & 0xFF) if taken else (pc + 1) & 0xFF
    sys.exit("no HALT")


def recurrence(tr, predict):
    """Модель 1: такты выборки/завершения и время каждой команды."""
    out = []
    for k, (pc, op, taken) in enumerate(tr):
        if k == 0:
            f, slot, s = 0, 0, 0
        else:
            ppc, pop, ptaken, pf, pslot = out[-1][:5]
            seq = pc == ppc + 1 and pslot < P - 1
            if predict:
                same = seq and not (pop == 5 and ptaken)
                pen = D if (pop == 5 and ptaken) else 0
            else:
                same = seq and pop != 5
                pen = D if pop == 5 else 0
            f = pf if same else pf + 1 + pen
            slot = pslot + 1 if same else 0
            s = pf if seq else pf + 1
        c = f + S - 1
        w = f - s
        out.append((pc, op, taken, f, slot, c, S, w, S + w))
    return out


def regions(name):
    res = []
    for line in open(f"{B}/{name}.regions"):
        if line.startswith("#") or not line.strip():
            continue
        a, b, nm = line.split(None, 2)
        res.append((int(a, 16), int(b, 16), nm.strip()))
    return res


def region_time(rec, a, b):
    """T = C_end - F_start + 1, N команд между ними (по первому входу и последнему выходу)."""
    ks = [k for k, r in enumerate(rec) if r[0] == a]
    ke = [k for k, r in enumerate(rec) if r[0] == b]
    if not ks or not ke:
        return None
    k0, k1 = ks[0], ke[-1]
    return rec[k1][5] - rec[k0][3] + 1, k1 - k0 + 1


def closed_form(name, region, predict, tr, a, b):
    """Модель 2: формулы в замкнутом виде для участков тестов."""
    body = [t for t in tr if a <= t[0] <= b]
    n = len(body)
    n_jl = sum(1 for t in body if t[1] == 5)
    n_tk = sum(1 for t in body if t[1] == 5 and t[2])
    if name == "min_all":
        return math.ceil(n / P) + S - 1, f"⌈N/P⌉+S−1 = ⌈{n}/3⌉+3"
    if name == "min_jl":
        if predict:
            return math.ceil(n / P) + S - 1, f"⌈N/P⌉+S−1 = ⌈{n}/3⌉+3"
        return (D + 1) * (n - 1) + S, f"(D+1)(N−1)+S = 3·{n - 1}+4"
    if name == "max_taken":
        # каждый блок - группа + D тактов; последний блок - JL в слоте 0
        blocks = n_tk
        return (D + 1) * (blocks - 1) + 1 + S - 1, f"(D+1)(B−1)+S = 3·{blocks - 1}+4"
    if name == "max_seq":
        if predict:
            return math.ceil(n / P) + S - 1, f"⌈N/P⌉+S−1 = ⌈{n}/3⌉+3"
        return (D + 1) * (n_jl - 1) + S, f"(D+1)(N_JL−1)+S = 3·{n_jl - 1}+4"
    m = re.match(r"bench_k(\d+)_p(\d+)", name)
    if m:
        k = int(m.group(1))
        blocks = n // k
        last_taken = body[-1][2]
        if predict:
            nt = n_tk - (1 if last_taken else 0)
            return (blocks * k // P + D * nt + S - 1,
                    f"B·k/P+D·n_t+S−1 = {blocks}·{k}/3+2·{nt}+3")
        return (blocks * k // P + D * (blocks - 1) + S - 1,
                f"B·k/P+D(B−1)+S−1 = {blocks}·{k}/3+2·{blocks - 1}+3")
    return None, "-"


def measured(name, mode):
    p = f"{RES}/{name}.{mode}.instr.csv"
    rows = []
    for line in open(p).read().splitlines()[1:]:
        f = line.split(";")
        rows.append((int(f[3]), f[4].strip(), int(f[5]), int(f[6]), int(f[7]), int(f[8])))
    perf = open(f"{RES}/{name}.{mode}.perf.txt").read()
    cyc = int(re.search(r"cycles=(\d+)", perf).group(1))
    regs = {m.group(1): (int(m.group(2)), int(m.group(3)))
            for m in re.finditer(r"region (\S+)\s+T=(\d+) N=(\d+)", perf)}
    return rows, cyc, regs


def main():
    tests = sorted(f[:-4] for f in os.listdir(os.path.join(ROOT, "tests")) if f.endswith(".asm"))
    order = [t for t in ("min_all", "min_jl", "max_taken", "max_seq") if t in tests] + \
            [t for t in tests if t.startswith("bench")]
    md = ["# Сравнение оценок аналитической модели и моделирования", "",
          "Сформировано `tools/model.py`. Модель 1 — рекуррентная модель выборки "
          "(для каждой команды), модель 2 — формулы в замкнутом виде (для участков).", ""]

    region_rows, type_rows, instr_rows, total_rows = [], [], [], []
    agg = {m: {t: [math.inf, 0, math.inf, 0] for t in TYPES} for m in ("predict", "stall")}
    for name in order:
        tr = trace(name)
        for mode in ("predict", "stall"):
            pr = mode == "predict"
            rec = recurrence(tr, pr)
            rows, cyc, mregs = measured(name, mode)
            # все команды, кроме HALT
            mod = [(r[0], OPN[r[1]], r[3], r[6], r[7], r[8]) for r in rec if r[1] != 15]
            meas = [(r[0], r[1], r[2], r[3], r[4], r[5]) for r in rows if r[1] != "HALT"]
            same = sum(1 for x, y in zip(mod, meas) if x == y)
            instr_rows.append(f"| {name} | {mode} | {len(mod)} | {len(meas)} | {same} | "
                              f"{'да' if same == len(mod) == len(meas) else '**нет**'} |")
            total_rows.append(f"| {name} | {mode} | {rec[-1][5] + 1} | {cyc} | "
                              f"{'да' if rec[-1][5] + 1 == cyc else '**нет**'} |")
            for a, b, rn in regions(name):
                t1, n1 = region_time(rec, a, b)
                t2, formula = closed_form(name, rn, pr, tr, a, b)
                tm, nm = mregs.get(rn, (None, None))
                ok = t1 == tm and (t2 is None or t2 == tm)
                region_rows.append(
                    f"| {name} | {rn} | {mode} | {n1} | {formula} | {t2} | {t1} | {tm} | "
                    f"{n1 / tm:.2f} | {'да' if ok else '**нет**'} |")
            # min/max по типам: модель и измерение
            for tname in TYPES:
                tm_ = [r[8] for r in rec if OPN[r[1]] == tname]
                tms = [r[5] for r in meas if r[1] == tname]
                if tm_:
                    a_ = agg[mode][tname]
                    a_[0] = min(a_[0], min(tm_)); a_[1] = max(a_[1], max(tm_))
                    a_[2] = min(a_[2], min(tms)); a_[3] = max(a_[3], max(tms))

    md += ["## 1. Время выполнения команд по типам (все тесты)", "",
           "T — время выполнения команды с учётом задержки из-за конфликта (T = L + W, "
           "L — латентность, W — задержка выборки).", "",
           "| Тип | Режим | T min (модель) | T min (RTL) | T max (модель) | T max (RTL) |",
           "|---|---|---:|---:|---:|---:|"]
    for mode in ("predict", "stall"):
        for tname in TYPES:
            a_ = agg[mode][tname]
            md.append(f"| {tname} | {mode} | {a_[0]} | {a_[2]} | {a_[1]} | {a_[3]} |")
    md += ["", "## 2. Время выполнения участков программ", "",
           "| Тест | Участок | Режим | N | Формула (модель 2) | T модель 2 | T модель 1 | T RTL | IPC | Совпадает |",
           "|---|---|---|---:|---|---:|---:|---:|---:|---|"] + region_rows
    md += ["", "## 3. Время выполнения тестов целиком (тактов до останова)", "",
           "| Тест | Режим | Модель 1 | RTL | Совпадает |", "|---|---|---:|---:|---|"] + total_rows
    md += ["", "## 4. Покомандное сравнение", "",
           "Для каждой выполненной команды сравниваются адрес, тип, такт выборки F, "
           "латентность L, задержка W и время T.", "",
           "| Тест | Режим | Команд (модель) | Команд (RTL) | Совпало | Все совпали |",
           "|---|---|---:|---:|---:|---|"] + instr_rows
    open(os.path.join(ROOT, "docs", "comparison.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
    bad = sum(1 for r in region_rows + total_rows + instr_rows if "**нет**" in r)
    print(f"docs/comparison.md written, mismatches: {bad}")


if __name__ == "__main__":
    main()

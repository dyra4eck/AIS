#!/usr/bin/env python3
"""
Формирует docs/tests.md - описание тестов для отчёта: последовательность команд
(мнемоника), образ памяти команд, образы памяти данных до и после выполнения
(ожидаемый и полученный при моделировании) и результаты моделирования.

    ./run_tests.sh && python3 tools/report_tests.py
"""
import glob
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
B = os.path.join(ROOT, "tests", "build")
R = os.path.join(ROOT, "results")


def words(path):
    out = []
    for line in open(path):
        line = line.strip()
        if line and line[0] not in "#-":
            out.append(int(line.split()[0], 16))
    return out


def s16(x):
    return x - 0x10000 if x & 0x8000 else x


def header(asm):
    lines = []
    for line in open(asm, encoding="utf-8"):
        if not line.startswith(";"):
            break
        lines.append(line[1:].strip())
    return lines


def main():
    out = ["# Приложение. Тесты: программы и образы памяти", "",
           "Файл сформирован скриптом `tools/report_tests.py` из результатов "
           "ассемблирования (`tests/build/`) и моделирования (`results/`).", ""]
    for asm in sorted(glob.glob(os.path.join(ROOT, "tests", "*.asm"))):
        name = os.path.basename(asm)[:-4]
        hdr = header(asm)
        out += [f"## {hdr[0]}", "", f"Файл: [`tests/{name}.asm`](../tests/{name}.asm)", ""]
        out += [" ".join(hdr[1:]), ""] if len(hdr) > 1 else []

        # листинг
        out += ["### Последовательность команд и образ памяти команд", "",
                "Группа — номер тройки команд, выбираемой за один такт (при выборке "
                "подряд с адреса 0).", "", "```"]
        lst = open(os.path.join(B, name + ".lst"), encoding="utf-8").read().splitlines()
        out += [l for l in lst if not l.startswith(";") or l.startswith("; addr")]
        out += ["```", ""]

        # память данных
        d0 = words(os.path.join(B, name + ".dmem.hex"))
        de = words(os.path.join(B, name + ".expect.hex"))
        outs = {}
        for mode in ("predict", "stall"):
            p = os.path.join(R, f"{name}.{mode}.dmem.out.hex")
            if os.path.exists(p):
                outs[mode] = words(p)
        n = max(len(d0), len(de))
        d0 += [0] * (n - len(d0))
        de += [0] * (n - len(de))
        out += ["### Образ памяти данных", "",
                "Показаны ненулевые ячейки. «Ожидаемый» образ вычислен эталонной "
                "моделью (последовательное выполнение), «predict»/«stall» — "
                "получены при моделировании RTL в двух режимах.", "",
                "| Адрес | До теста | Ожидаемый после | predict | stall | |",
                "|---:|---:|---:|---:|---:|---|"]
        for a in range(n):
            vals = [d0[a], de[a]] + [outs[m][a] for m in outs]
            if not any(vals):
                continue
            mark = "изменена" if d0[a] != de[a] else ""
            got = " | ".join(f"{outs[m][a]:04X}" for m in ("predict", "stall") if m in outs)
            ok = all(outs[m][a] == de[a] for m in outs)
            out.append(f"| {a} | {d0[a]:04X} ({s16(d0[a])}) | {de[a]:04X} ({s16(de[a])}) | "
                       f"{got} | {mark}{'' if ok else ' **НЕ СОВПАДАЕТ**'} |")
        out.append("")

        # результаты
        out += ["### Результаты моделирования", "", "```"]
        for mode in ("predict", "stall"):
            p = os.path.join(R, f"{name}.{mode}.log")
            if os.path.exists(p):
                for l in open(p):
                    if re.search(r"registers:|flags:|mode=|TEST ", l):
                        out.append(l.rstrip())
        out += ["```", ""]

    open(os.path.join(ROOT, "docs", "tests.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("docs/tests.md written")


if __name__ == "__main__":
    main()

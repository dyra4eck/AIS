#!/usr/bin/env python3
"""
Оценка полноты тестирования мутационным анализом.

В копию модели ядра поочерёдно вносятся типичные ошибки (мутации), прежде всего
в механизм разрешения конфликта по управлению, и прогоняется весь набор тестов
в обоих режимах. Мутация "убита", если хотя бы один тест завершился с ошибкой.

    python3 tools/mutation_test.py
"""
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CORE = os.path.join(ROOT, "rtl", "cpu_core.vhd")

# (название, исходный фрагмент, заменяющий фрагмент)
MUTATIONS = [
    ("не аннулируются более поздние команды группы с переходом",
     "                        if kill then\n",
     "                        if false then\n"),
    ("не сбрасывается группа на ступени OF при переходе",
     "                        if redirect or stop then\n",
     "                        if stop then\n"),
    ("не отбрасывается группа, выбираемая (IF) в такте перехода",
     "                elsif redirect then\n",
     "                elsif redirect and false then\n"),
    ("PC не загружается адресом перехода",
     "                    pc <= new_pc;\n",
     "                    pc <= pc + NPIPE;\n"),
    ("нет передачи флагов внутри группы (JL видит только регистр флагов)",
     "                                    if is_less(f) then\n",
     "                                    if is_less(flags) then\n"),
    ("условие перехода без учёта переполнения (только N)",
     "                                    if is_less(f) then\n",
     "                                    if f.n = '1' then\n"),
    ("флаги не сохраняются в регистр флагов",
     "                flags <= f;\n",
     "                flags <= flags;\n"),
    ("инверсное условие перехода (>=)",
     "                                    if is_less(f) then\n",
     "                                    if not is_less(f) then\n"),
    ("режим stall: группа не обрывается после перехода",
     "                                    cut := s + 1;   -- группа обрывается после перехода\n",
     "                                    null;\n"),
    ("режим stall: выборка не приостанавливается",
     "                    if blocked then\n",
     "                    if false then\n"),
    ("режим stall: приостановка только пока переход на OF",
     "                               (of_ex(s).valid = '1' and is_ctrl(of_ex(s).op)) then\n",
     "                               false then\n"),
    ("SUB выполняется как ADD",
     "            ur := ua - ub;\n",
     "            ur := ua + ub;\n"),
    ("неверный флаг переполнения при вычитании",
     "            f.v := (a(DW-1) xor b(DW-1)) and (r(DW-1) xor a(DW-1));\n",
     "            f.v := '0';\n"),
    ("нет передачи результата WB -> OF в том же такте",
     "                            ex_n(s).a      := rf(to_integer(r1));\n",
     "                            ex_n(s).a      := regs(to_integer(r1));\n"),
    ("при записи в один адрес побеждает более ранний конвейер",
     "            for i in 0 to NPIPE-1 loop\n                if we(i) = '1' then",
     "            for i in NPIPE-1 downto 0 loop\n                if we(i) = '1' then"),
]


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True)


def main():
    tests = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "tests", "*.asm")))
    for t in tests:
        run(f"python3 tools/asm.py tests/{t}.asm -o tests/build", ROOT)
    tmp = os.path.join(ROOT, "work_mut")
    killed = 0
    for name, old, new in MUTATIONS:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.copytree(os.path.join(ROOT, "rtl"), os.path.join(tmp, "rtl"))
        shutil.copytree(os.path.join(ROOT, "tb"), os.path.join(tmp, "tb"))
        os.makedirs(os.path.join(tmp, "work"))
        os.makedirs(os.path.join(tmp, "results"))
        os.symlink(os.path.join(ROOT, "tests"), os.path.join(tmp, "tests"))
        target = "dmem.vhd" if "we(i)" in old else ("cpu_pkg.vhd" if "ur :=" in old or "f.v" in old else "cpu_core.vhd")
        path = os.path.join(tmp, "rtl", target)
        src = open(path, encoding="utf-8").read()
        if old not in src:
            sys.exit(f"mutation not applicable: {name}")
        open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
        std = "--std=08 --workdir=work"
        r = run(f"ghdl -a {std} rtl/cpu_pkg.vhd rtl/mem_init_pkg.vhd rtl/imem.vhd rtl/dmem.vhd "
                f"rtl/cpu_core.vhd rtl/cpu_system.vhd tb/tb_cpu.vhd && ghdl -e {std} tb_cpu", tmp)
        if r.returncode:
            sys.exit(f"compile failed for mutation '{name}':\n{r.stderr}")
        failed = []
        for t in tests:
            for mode, m in (("true", "predict"), ("false", "stall")):
                r = run(f"ghdl -r {std} tb_cpu -gTEST_NAME={t} -gPREDICT_NOT_TAKEN={mode} "
                        f"-gMAX_CYCLES=1000 --ieee-asserts=disable", tmp)
                if "PASSED" not in r.stdout:
                    failed.append(f"{t}[{m}]")
        status = "УБИТА " if failed else "ВЫЖИЛА"
        killed += bool(failed)
        print(f"{status} | {name}\n       | не прошли: {', '.join(failed) if failed else '-'}")
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"\nубито мутаций: {killed} из {len(MUTATIONS)}")


if __name__ == "__main__":
    main()

#!/bin/bash
# ЛР3: оценка характеристик ядра из ЛР2.
#   ./run_perf.sh           - все тесты в двух режимах
#   ./run_perf.sh min_all   - один тест
# Результаты: results/ИМЯ.РЕЖИМ.perf.txt (сводка), .instr.csv (по командам),
#             .trace.txt (потактовая трасса конвейера)
cd "$(dirname "$0")"
set -e
RTL=../lab2/rtl
mkdir -p work results tests/build
STD="--std=08 --workdir=work"

for f in tests/*.asm; do
    python3 ../lab2/tools/asm.py "$f" -o tests/build > /dev/null
done

ghdl -a $STD $RTL/cpu_pkg.vhd $RTL/mem_init_pkg.vhd $RTL/imem.vhd $RTL/dmem.vhd \
             $RTL/cpu_core.vhd $RTL/cpu_system.vhd tb/tb_perf.vhd
ghdl -e $STD tb_perf

if [ $# -gt 0 ]; then TESTS="$*"; else TESTS=$(ls tests/*.asm | xargs -n1 basename | sed 's/\.asm$//'); fi
pass=0; fail=0
set +e
for t in $TESTS; do
    for mode in true false; do
        out=$(ghdl -r $STD tb_perf -gTEST_NAME=$t -gPREDICT_NOT_TAKEN=$mode --ieee-asserts=disable 2>&1)
        echo "$out"
        echo
        if echo "$out" | grep -q "PASSED"; then pass=$((pass+1)); else fail=$((fail+1)); fi
    done
done
echo "passed: $pass, failed: $fail"
[ $fail -eq 0 ]

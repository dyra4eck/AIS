#!/bin/bash
# Сборка модели, ассемблирование тестов и прогон каждого теста в двух режимах
# разрешения конфликта по управлению (predict - предсказание "не выполняется"
# со сбросом конвейера, stall - приостановка выборки).
#   ./run_tests.sh              - все тесты
#   ./run_tests.sh t3_jl_taken  - один тест (+ временная диаграмма results/*.vcd)
cd "$(dirname "$0")"
set -e
mkdir -p work results tests/build
GHDL="ghdl"
STD="--std=08 --workdir=work"

# ассемблирование всех тестов (образы памяти нужны уже при элаборации)
for f in tests/*.asm; do
    python3 tools/asm.py "$f" -o tests/build > /dev/null
done

$GHDL -a $STD rtl/cpu_pkg.vhd rtl/mem_init_pkg.vhd rtl/imem.vhd rtl/dmem.vhd \
              rtl/cpu_core.vhd rtl/cpu_system.vhd tb/tb_cpu.vhd
$GHDL -e $STD tb_cpu

if [ $# -gt 0 ]; then TESTS="$*"; else TESTS=$(ls tests/*.asm | xargs -n1 basename | sed 's/\.asm$//'); fi

pass=0; fail=0
set +e
for t in $TESTS; do
    for mode in true false; do
        [ "$mode" = true ] && m=predict || m=stall
        extra=""
        [ $# -gt 0 ] && extra="--vcd=results/$t.$m.vcd"
        out=$($GHDL -r $STD tb_cpu -gTEST_NAME=$t -gPREDICT_NOT_TAKEN=$mode \
                  --ieee-asserts=disable $extra 2>&1)
        echo "$out" > results/$t.$m.log
        echo "$out" | grep -E "mode=|TEST " | sed 's/^/  /'
        if echo "$out" | grep -q "PASSED"; then pass=$((pass+1)); else fail=$((fail+1)); echo "$out" | grep -i error | head; fi
    done
done
echo
echo "passed: $pass, failed: $fail"
[ $fail -eq 0 ]

#!/bin/bash
# Сборка для лабораторной работы 1, вариант 7: -fbranch-probabilities
#
#   main_O2   / main_O2.s  - базовый вариант: -O2 (вероятности ветвлений угадываются эвристиками)
#   main_bp   / main_bp.s  - -O2 -fbranch-probabilities (вероятности берутся из профиля)
set -e
cd "$(dirname "$0")"
CFLAGS="-O2"

rm -f *.o *.gcda *.gcno *.gcov main_O2 main_bp main_prof

# 1. Инструментированная сборка (-fprofile-arcs; -ftest-coverage нужен только для gcov)
gcc $CFLAGS -fprofile-arcs -ftest-coverage -c main.c -o main_prof.o
gcc -fprofile-arcs main_prof.o -o main_prof

# 2. Тренировочный запуск: создаётся main_prof.gcda со счётчиками дуг графа потока управления
./main_prof > /dev/null
gcov -b -c -o . main_prof.o > /dev/null      # main.c.gcov - наглядный отчёт по ветвлениям
find . -maxdepth 1 -name "*.gcov" ! -name main.c.gcov -delete

# GCC ищет файл профиля по имени выходного файла: main_bp.o / main_bp.s -> main_bp.gcda
cp main_prof.gcda main_bp.gcda

# 3. Ассемблерный код для сравнения
gcc $CFLAGS                        -masm=intel -S main.c -o main_O2.s
gcc $CFLAGS -fbranch-probabilities -masm=intel -S main.c -o main_bp.s

# 4. Исполняемые файлы для замера времени.
# Ассемблеру передаётся -mbranches-within-32B-boundaries: на процессорах Intel Skylake и
# новее (JCC erratum) переход, пересекающий 32-байтную границу, не попадает в кэш микроопераций,
# и случайное расположение кода могло бы исказить сравнение. Ключ одинаково применяется к обеим
# версиям и не меняет файлы .s, полученные выше. Отключить: JCC_FIX= ./build.sh
JCC_FIX=${JCC_FIX--Wa,-mbranches-within-32B-boundaries}
gcc $CFLAGS $JCC_FIX main.c -o main_O2
gcc $CFLAGS $JCC_FIX -fbranch-probabilities -c main.c -o main_bp.o
gcc main_bp.o -o main_bp

echo "Готово: main_O2, main_bp, main_O2.s, main_bp.s, main.c.gcov"
echo "Сравнение ассемблера: meld main_O2.s main_bp.s  (или diff -u main_O2.s main_bp.s)"

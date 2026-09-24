#!/bin/bash
# Многократный запуск обеих версий и автоматический анализ результатов
cd "$(dirname "$0")"
RUNS=${1:-20}

# Запуски чередуются (O2, bp, O2, bp, ...), чтобы всплески фоновой нагрузки
# одинаково влияли на обе версии.
a=""; b=""
for (( i=1; i <= RUNS; i++ )); do
    la=$(./main_O2); lb=$(./main_bp)
    printf '%2d  -O2: %-40s  -O2 -fbranch-probabilities: %s\n' "$i" "$la" "$lb" >&2
    a+="${la##*cycles = }"$'\n'
    b+="${lb##*cycles = }"$'\n'
done
a=${a%$'\n'}; b=${b%$'\n'}

stats() { sort -n | awk '{v[NR]=$1; s+=$1}
    END {m = (NR % 2) ? v[(NR+1)/2] : int((v[NR/2] + v[NR/2+1]) / 2);
         printf "%d %d %d %d", v[1], m, s/NR, v[NR]}'; }
read amin amed aavg amax <<< "$(echo "$a" | stats)"
read bmin bmed bavg bmax <<< "$(echo "$b" | stats)"

printf '\n%-28s %12s %12s %12s %12s\n' "" "min" "median" "avg" "max"
printf '%-28s %12d %12d %12d %12d\n' "-O2"                        "$amin" "$amed" "$aavg" "$amax"
printf '%-28s %12d %12d %12d %12d\n' "-O2 -fbranch-probabilities" "$bmin" "$bmed" "$bavg" "$bmax"
awk -v a="$amin" -v b="$bmin" -v c="$amed" -v d="$bmed" -v e="$aavg" -v f="$bavg" \
    'BEGIN {printf "\nУскорение: по минимуму %.2fx, по медиане %.2fx, по среднему %.2fx\n", a/b, c/d, e/f}'

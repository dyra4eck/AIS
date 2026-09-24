# Сравнение оценок аналитической модели и моделирования

Сформировано `tools/model.py`. Модель 1 — рекуррентная модель выборки (для каждой команды), модель 2 — формулы в замкнутом виде (для участков).

## 1. Время выполнения команд по типам (все тесты)

T — время выполнения команды с учётом задержки из-за конфликта (T = L + W, L — латентность, W — задержка выборки).

| Тип | Режим | T min (модель) | T min (RTL) | T max (модель) | T max (RTL) |
|---|---|---:|---:|---:|---:|
| LOAD | predict | 4 | 4 | 6 | 6 |
| STORE | predict | 4 | 4 | 6 | 6 |
| ADD | predict | 4 | 4 | 6 | 6 |
| SUB | predict | 4 | 4 | 6 | 6 |
| JL | predict | 4 | 4 | 6 | 6 |
| NOP | predict | 4 | 4 | 6 | 6 |
| LOAD | stall | 4 | 4 | 7 | 7 |
| STORE | stall | 4 | 4 | 7 | 7 |
| ADD | stall | 4 | 4 | 7 | 7 |
| SUB | stall | 4 | 4 | 7 | 7 |
| JL | stall | 4 | 4 | 7 | 7 |
| NOP | stall | 4 | 4 | 7 | 7 |

## 2. Время выполнения участков программ

| Тест | Участок | Режим | N | Формула (модель 2) | T модель 2 | T модель 1 | T RTL | IPC | Совпадает |
|---|---|---|---:|---|---:|---:|---:|---:|---|
| min_all | add30 | predict | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | sub30 | predict | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | load30 | predict | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | store30 | predict | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | nop30 | predict | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | add30 | stall | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | sub30 | stall | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | load30 | stall | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | store30 | stall | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_all | nop30 | stall | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_jl | jl30 | predict | 30 | ⌈N/P⌉+S−1 = ⌈30/3⌉+3 | 13 | 13 | 13 | 2.31 | да |
| min_jl | jl30 | stall | 30 | (D+1)(N−1)+S = 3·29+4 | 91 | 91 | 91 | 0.33 | да |
| max_taken | chain | predict | 64 | (D+1)(B−1)+S = 3·23+4 | 73 | 73 | 73 | 0.88 | да |
| max_taken | chain | stall | 64 | (D+1)(B−1)+S = 3·23+4 | 73 | 73 | 73 | 0.88 | да |
| max_seq | pairs | predict | 48 | ⌈N/P⌉+S−1 = ⌈48/3⌉+3 | 19 | 19 | 19 | 2.53 | да |
| max_seq | pairs | stall | 48 | (D+1)(N_JL−1)+S = 3·27+4 | 85 | 85 | 85 | 0.56 | да |
| bench_k12_p0 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 6·12/3+2·0+3 | 27 | 27 | 27 | 2.67 | да |
| bench_k12_p0 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 6·12/3+2·5+3 | 37 | 37 | 37 | 1.95 | да |
| bench_k12_p100 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 6·12/3+2·5+3 | 37 | 37 | 37 | 1.95 | да |
| bench_k12_p100 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 6·12/3+2·5+3 | 37 | 37 | 37 | 1.95 | да |
| bench_k12_p50 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 6·12/3+2·3+3 | 33 | 33 | 33 | 2.18 | да |
| bench_k12_p50 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 6·12/3+2·5+3 | 37 | 37 | 37 | 1.95 | да |
| bench_k3_p0 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 24·3/3+2·0+3 | 27 | 27 | 27 | 2.67 | да |
| bench_k3_p0 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 24·3/3+2·23+3 | 73 | 73 | 73 | 0.99 | да |
| bench_k3_p100 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 24·3/3+2·23+3 | 73 | 73 | 73 | 0.99 | да |
| bench_k3_p100 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 24·3/3+2·23+3 | 73 | 73 | 73 | 0.99 | да |
| bench_k3_p50 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 24·3/3+2·12+3 | 51 | 51 | 51 | 1.41 | да |
| bench_k3_p50 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 24·3/3+2·23+3 | 73 | 73 | 73 | 0.99 | да |
| bench_k6_p0 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 12·6/3+2·0+3 | 27 | 27 | 27 | 2.67 | да |
| bench_k6_p0 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 12·6/3+2·11+3 | 49 | 49 | 49 | 1.47 | да |
| bench_k6_p100 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 12·6/3+2·11+3 | 49 | 49 | 49 | 1.47 | да |
| bench_k6_p100 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 12·6/3+2·11+3 | 49 | 49 | 49 | 1.47 | да |
| bench_k6_p50 | blocks | predict | 72 | B·k/P+D·n_t+S−1 = 12·6/3+2·6+3 | 39 | 39 | 39 | 1.85 | да |
| bench_k6_p50 | blocks | stall | 72 | B·k/P+D(B−1)+S−1 = 12·6/3+2·11+3 | 49 | 49 | 49 | 1.47 | да |

## 3. Время выполнения тестов целиком (тактов до останова)

| Тест | Режим | Модель 1 | RTL | Совпадает |
|---|---|---:|---:|---|
| min_all | predict | 56 | 56 | да |
| min_all | stall | 56 | 56 | да |
| min_jl | predict | 17 | 17 | да |
| min_jl | stall | 97 | 97 | да |
| max_taken | predict | 80 | 80 | да |
| max_taken | stall | 80 | 80 | да |
| max_seq | predict | 24 | 24 | да |
| max_seq | stall | 92 | 92 | да |
| bench_k12_p0 | predict | 34 | 34 | да |
| bench_k12_p0 | stall | 46 | 46 | да |
| bench_k12_p100 | predict | 46 | 46 | да |
| bench_k12_p100 | stall | 46 | 46 | да |
| bench_k12_p50 | predict | 40 | 40 | да |
| bench_k12_p50 | stall | 46 | 46 | да |
| bench_k3_p0 | predict | 34 | 34 | да |
| bench_k3_p0 | stall | 82 | 82 | да |
| bench_k3_p100 | predict | 82 | 82 | да |
| bench_k3_p100 | stall | 82 | 82 | да |
| bench_k3_p50 | predict | 58 | 58 | да |
| bench_k3_p50 | stall | 82 | 82 | да |
| bench_k6_p0 | predict | 34 | 34 | да |
| bench_k6_p0 | stall | 58 | 58 | да |
| bench_k6_p100 | predict | 58 | 58 | да |
| bench_k6_p100 | stall | 58 | 58 | да |
| bench_k6_p50 | predict | 46 | 46 | да |
| bench_k6_p50 | stall | 58 | 58 | да |

## 4. Покомандное сравнение

Для каждой выполненной команды сравниваются адрес, тип, такт выборки F, латентность L, задержка W и время T.

| Тест | Режим | Команд (модель) | Команд (RTL) | Совпало | Все совпали |
|---|---|---:|---:|---:|---|
| min_all | predict | 156 | 156 | 156 | да |
| min_all | stall | 156 | 156 | 156 | да |
| min_jl | predict | 39 | 39 | 39 | да |
| min_jl | stall | 39 | 39 | 39 | да |
| max_taken | predict | 76 | 76 | 76 | да |
| max_taken | stall | 76 | 76 | 76 | да |
| max_seq | predict | 60 | 60 | 60 | да |
| max_seq | stall | 60 | 60 | 60 | да |
| bench_k12_p0 | predict | 90 | 90 | 90 | да |
| bench_k12_p0 | stall | 90 | 90 | 90 | да |
| bench_k12_p100 | predict | 90 | 90 | 90 | да |
| bench_k12_p100 | stall | 90 | 90 | 90 | да |
| bench_k12_p50 | predict | 90 | 90 | 90 | да |
| bench_k12_p50 | stall | 90 | 90 | 90 | да |
| bench_k3_p0 | predict | 90 | 90 | 90 | да |
| bench_k3_p0 | stall | 90 | 90 | 90 | да |
| bench_k3_p100 | predict | 90 | 90 | 90 | да |
| bench_k3_p100 | stall | 90 | 90 | 90 | да |
| bench_k3_p50 | predict | 90 | 90 | 90 | да |
| bench_k3_p50 | stall | 90 | 90 | 90 | да |
| bench_k6_p0 | predict | 90 | 90 | 90 | да |
| bench_k6_p0 | stall | 90 | 90 | 90 | да |
| bench_k6_p100 | predict | 90 | 90 | 90 | да |
| bench_k6_p100 | stall | 90 | 90 | 90 | да |
| bench_k6_p50 | predict | 90 | 90 | 90 | да |
| bench_k6_p50 | stall | 90 | 90 | 90 | да |

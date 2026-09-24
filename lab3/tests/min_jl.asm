; Минимальное время: поток невыполняемых переходов
; (сгенерировано tools/gen_tests.py)

.data
.org 0
        .word 1          ; 0: константа 1
        .word -1         ; 1: константа -1

.text
; G0
        LOAD  R1, (R0)   ; R1 = 1
        NOP 2
; G1
        NOP 3
; G2
        ADD   R15, R1    ; R15 = 1, флаги: не "<"
        NOP 2
.region jl30
; G3
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G4
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G5
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G6
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G7
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G8
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G9
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G10
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G11
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
; G12
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
.endregion
        HALT
        NOP 2
fail:
        STORE R1, (R1)   ; признак ошибки: DM[1] := 1
        HALT

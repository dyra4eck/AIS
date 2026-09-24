; Максимальное время: каждая команда следует за невыполняемым JL
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
        ADD   R5, R1     ; R5 = 1
        ADD   R6, R1     ; R6 = 1
        ADD   R15, R1    ; флаги: не "<"
; G3
        NOP 3
.region pairs
        JL    fail       ; не выполняется
        ADD   R5, R0     ; 1 + 0: не "<"
        JL    fail       ; не выполняется
        SUB   R6, R0     ; 1 - 0: не "<"
        JL    fail       ; не выполняется
        LOAD  R7, (R0)
        JL    fail       ; не выполняется
        STORE R1, (R0)
        JL    fail       ; не выполняется
        NOP
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        ADD   R5, R0     ; 1 + 0: не "<"
        JL    fail       ; не выполняется
        SUB   R6, R0     ; 1 - 0: не "<"
        JL    fail       ; не выполняется
        LOAD  R7, (R0)
        JL    fail       ; не выполняется
        STORE R1, (R0)
        JL    fail       ; не выполняется
        NOP
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        ADD   R5, R0     ; 1 + 0: не "<"
        JL    fail       ; не выполняется
        SUB   R6, R0     ; 1 - 0: не "<"
        JL    fail       ; не выполняется
        LOAD  R7, (R0)
        JL    fail       ; не выполняется
        STORE R1, (R0)
        JL    fail       ; не выполняется
        NOP
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
        ADD   R5, R0     ; 1 + 0: не "<"
        JL    fail       ; не выполняется
        SUB   R6, R0     ; 1 - 0: не "<"
        JL    fail       ; не выполняется
        LOAD  R7, (R0)
        JL    fail       ; не выполняется
        STORE R1, (R0)
        JL    fail       ; не выполняется
        NOP
        JL    fail       ; не выполняется
        JL    fail       ; не выполняется
.endregion
        HALT
        NOP 2
fail:
        STORE R1, (R1)   ; признак ошибки
        HALT

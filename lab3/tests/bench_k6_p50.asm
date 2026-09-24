; Синтетическая программа: блоки по 6 команд, переход в конце блока, выполняется 50% переходов
; (сгенерировано tools/gen_tests.py)

.data
.org 0
        .word 1
        .word -1

.text
; G0
        LOAD  R1, (R0)   ; R1 = 1
        NOP 2
; G1
        NOP 3
; G2
        LOAD  R12, (R1)  ; -1
        LOAD  R14, (R1)  ; -1
        ADD   R13, R1    ; 1
; G3
        ADD   R15, R1    ; 1
        NOP 2
; G4
        NOP 3
; G5
        NOP 3
.region blocks
blk0:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk1
blk1:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R15, R0    ; флаги: не "<"
        JL    blk2
blk2:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk3
blk3:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R15, R0    ; флаги: не "<"
        JL    blk4
blk4:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk5
blk5:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R15, R0    ; флаги: не "<"
        JL    blk6
blk6:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk7
blk7:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R15, R0    ; флаги: не "<"
        JL    blk8
blk8:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk9
blk9:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R15, R0    ; флаги: не "<"
        JL    blk10
blk10:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk11
blk11:
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
        ADD   R5, R1
        ADD   R15, R0    ; флаги: не "<"
        JL    done
.endregion
done:
        HALT
        NOP 2

; Синтетическая программа: блоки по 3 команд, переход в конце блока, выполняется 100% переходов
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
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk1
blk1:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk2
blk2:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk3
blk3:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk4
blk4:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk5
blk5:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk6
blk6:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk7
blk7:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk8
blk8:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk9
blk9:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk10
blk10:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk11
blk11:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk12
blk12:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk13
blk13:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk14
blk14:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk15
blk15:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk16
blk16:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk17
blk17:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk18
blk18:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk19
blk19:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk20
blk20:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk21
blk21:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    blk22
blk22:
        ADD   R2, R1
        ADD   R12, R0    ; флаги: "<" - переход выполняется
        JL    blk23
blk23:
        ADD   R5, R1
        ADD   R14, R0    ; флаги: "<" - переход выполняется
        JL    done
.endregion
done:
        HALT
        NOP 2

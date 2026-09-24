; Минимальное время: потоки однотипных команд без конфликтов
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
.region add30
; G2
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
; G3
        ADD   R5, R1
        ADD   R6, R1
        ADD   R7, R1
; G4
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
; G5
        ADD   R5, R1
        ADD   R6, R1
        ADD   R7, R1
; G6
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
; G7
        ADD   R5, R1
        ADD   R6, R1
        ADD   R7, R1
; G8
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
; G9
        ADD   R5, R1
        ADD   R6, R1
        ADD   R7, R1
; G10
        ADD   R2, R1
        ADD   R3, R1
        ADD   R4, R1
; G11
        ADD   R5, R1
        ADD   R6, R1
        ADD   R7, R1
.endregion
.region sub30
; G12
        SUB   R2, R1
        SUB   R3, R1
        SUB   R4, R1
; G13
        SUB   R5, R1
        SUB   R6, R1
        SUB   R7, R1
; G14
        SUB   R2, R1
        SUB   R3, R1
        SUB   R4, R1
; G15
        SUB   R5, R1
        SUB   R6, R1
        SUB   R7, R1
; G16
        SUB   R2, R1
        SUB   R3, R1
        SUB   R4, R1
; G17
        SUB   R5, R1
        SUB   R6, R1
        SUB   R7, R1
; G18
        SUB   R2, R1
        SUB   R3, R1
        SUB   R4, R1
; G19
        SUB   R5, R1
        SUB   R6, R1
        SUB   R7, R1
; G20
        SUB   R2, R1
        SUB   R3, R1
        SUB   R4, R1
; G21
        SUB   R5, R1
        SUB   R6, R1
        SUB   R7, R1
.endregion
.region load30
; G22
        LOAD  R2, (R0)
        LOAD  R3, (R0)
        LOAD  R4, (R0)
; G23
        LOAD  R5, (R0)
        LOAD  R6, (R0)
        LOAD  R7, (R0)
; G24
        LOAD  R2, (R0)
        LOAD  R3, (R0)
        LOAD  R4, (R0)
; G25
        LOAD  R5, (R0)
        LOAD  R6, (R0)
        LOAD  R7, (R0)
; G26
        LOAD  R2, (R0)
        LOAD  R3, (R0)
        LOAD  R4, (R0)
; G27
        LOAD  R5, (R0)
        LOAD  R6, (R0)
        LOAD  R7, (R0)
; G28
        LOAD  R2, (R0)
        LOAD  R3, (R0)
        LOAD  R4, (R0)
; G29
        LOAD  R5, (R0)
        LOAD  R6, (R0)
        LOAD  R7, (R0)
; G30
        LOAD  R2, (R0)
        LOAD  R3, (R0)
        LOAD  R4, (R0)
; G31
        LOAD  R5, (R0)
        LOAD  R6, (R0)
        LOAD  R7, (R0)
.endregion
.region store30
; G32
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G33
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G34
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G35
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G36
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G37
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G38
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G39
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G40
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
; G41
        STORE R1, (R0)
        STORE R1, (R0)
        STORE R1, (R0)
.endregion
.region nop30
; G42
        NOP
        NOP
        NOP
; G43
        NOP
        NOP
        NOP
; G44
        NOP
        NOP
        NOP
; G45
        NOP
        NOP
        NOP
; G46
        NOP
        NOP
        NOP
; G47
        NOP
        NOP
        NOP
; G48
        NOP
        NOP
        NOP
; G49
        NOP
        NOP
        NOP
; G50
        NOP
        NOP
        NOP
; G51
        NOP
        NOP
        NOP
.endregion
; G52
        HALT
        NOP 2

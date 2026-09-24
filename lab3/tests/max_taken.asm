; Максимальное время: каждая команда по адресу выполняемого перехода
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
        SUB   R14, R1    ; R14 = -1
        SUB   R5, R1     ; R5 = -1
        SUB   R6, R1     ; R6 = -1, флаги: "<"
; G3
        NOP 3
.region chain
b0:                    ; G4
        ADD   R5, R14    ; -k + (-1): остаётся < 0
        NOP
        JL    b1
b1:                    ; G5
        SUB   R6, R1     ; -k - 1: остаётся < 0
        NOP
        JL    b2
b2:                    ; G6
        LOAD  R7, (R0)
        NOP
        JL    b3
b3:                    ; G7
        STORE R1, (R0)
        NOP
        JL    b4
b4:                    ; G8
        NOP
        NOP
        JL    b5
b5:                    ; G9
        JL    b6         ; JL по адресу перехода, в конвейере 0
        NOP              ; аннулируется
        NOP              ; аннулируется
b6:                    ; G10
        ADD   R5, R14    ; -k + (-1): остаётся < 0
        NOP
        JL    b7
b7:                    ; G11
        SUB   R6, R1     ; -k - 1: остаётся < 0
        NOP
        JL    b8
b8:                    ; G12
        LOAD  R7, (R0)
        NOP
        JL    b9
b9:                    ; G13
        STORE R1, (R0)
        NOP
        JL    b10
b10:                    ; G14
        NOP
        NOP
        JL    b11
b11:                    ; G15
        JL    b12        ; JL по адресу перехода, в конвейере 0
        NOP              ; аннулируется
        NOP              ; аннулируется
b12:                    ; G16
        ADD   R5, R14    ; -k + (-1): остаётся < 0
        NOP
        JL    b13
b13:                    ; G17
        SUB   R6, R1     ; -k - 1: остаётся < 0
        NOP
        JL    b14
b14:                    ; G18
        LOAD  R7, (R0)
        NOP
        JL    b15
b15:                    ; G19
        STORE R1, (R0)
        NOP
        JL    b16
b16:                    ; G20
        NOP
        NOP
        JL    b17
b17:                    ; G21
        JL    b18        ; JL по адресу перехода, в конвейере 0
        NOP              ; аннулируется
        NOP              ; аннулируется
b18:                    ; G22
        ADD   R5, R14    ; -k + (-1): остаётся < 0
        NOP
        JL    b19
b19:                    ; G23
        SUB   R6, R1     ; -k - 1: остаётся < 0
        NOP
        JL    b20
b20:                    ; G24
        LOAD  R7, (R0)
        NOP
        JL    b21
b21:                    ; G25
        STORE R1, (R0)
        NOP
        JL    b22
b22:                    ; G26
        NOP
        NOP
        JL    b23
b23:                    ; G27
        JL    done       ; JL по адресу перехода, в конвейере 0
.endregion            ; последняя завершаемая команда участка - JL
        NOP              ; аннулируется
        NOP              ; аннулируется
done:
        HALT
        NOP 2

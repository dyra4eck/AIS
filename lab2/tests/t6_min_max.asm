; Тест 6. Поиск минимума и максимума в массиве из 7 чисел.
; Переходы зависят от данных: в каждой итерации два условных перехода,
; выполняющихся или нет в зависимости от элемента. Безусловный переход
; реализуется парой "ADD R14, R0 ; JL" (R14 = -1, флаги всегда дают "<").
; Текущие max и min хранятся в памяти (DM[32], DM[33]).
; Первый элемент сравнивается с max = -32768: max - x даёт переполнение
; (V=1, N=0), но условие "<" вычисляется верно (N xor V).

.data
.org 0
        .word 1          ; 0: константа 1
        .word array      ; 1: адрес массива
        .word -7         ; 2: -N
        .word vmax       ; 3: адрес max
        .word vmin       ; 4: адрес min
.org 16
array:  .word 12, -5, 300, 7, -300, 299, 0
.org 32
vmax:   .word -32768
vmin:   .word 32767

.text
; G0
        LOAD  R1, (R0)   ; R1 = 1
        NOP 2
; G1
        NOP 3
; G2
        LOAD  R2, (R1)   ; R2 = адрес массива
        ADD   R10, R1    ; R10 = 1
        SUB   R14, R1    ; R14 = -1
; G3
        NOP 3
; G4
        ADD   R10, R1    ; R10 = 2
        NOP 2
; G5
        NOP 3
; G6
        LOAD  R8, (R10)  ; R8 = -7 (счётчик)
        ADD   R10, R1    ; R10 = 3
        NOP
; G7
        NOP 3
; G8
        LOAD  R11, (R10) ; R11 = адрес max
        ADD   R10, R1    ; R10 = 4
        NOP
; G9
        NOP 3
; G10
        LOAD  R12, (R10) ; R12 = адрес min
        NOP 2
; G11
        NOP 3
loop:                   ; G12
        LOAD  R5, (R2)   ; x
        LOAD  R6, (R2)   ; x (копия для сравнения с min)
        LOAD  R7, (R11)  ; max
; G13
        LOAD  R9, (R12)  ; min
        ADD   R2, R1     ; указатель++
        NOP
; G14
        SUB   R7, R5     ; max - x
        NOP
        JL    newmax     ; max < x
chkmin:                 ; G15
        SUB   R6, R9     ; x - min
        NOP
        JL    newmin     ; x < min
next:                   ; G16
        ADD   R13, R1    ; число итераций++
        ADD   R8, R1     ; счётчик++ (флаги для JL - последняя команда перед ним)
        JL    loop
; G17
        HALT
        NOP 2

newmax:                 ; max := x
        STORE R5, (R11)
        ADD   R14, R0    ; флаги: "<"
        JL    chkmin
newmin:                 ; min := x
        STORE R5, (R12)
        ADD   R14, R0    ; флаги: "<"
        JL    next

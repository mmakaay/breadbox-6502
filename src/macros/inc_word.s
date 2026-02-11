.ifndef INC16_S
INC16_S = 1

.macro inc_word target
    ; Increment a 16 bit (word) value with 1.
    ;
    ; In:
    ;   target = address of the word to increment
    ; Out:
    ;   target = value incremented by 1 + carry
    ;   Carry = set when high byte overflows
    ;   A = clobbered
    clc
    lda     target
    adc     #1
    sta     target
    lda     target+1
    adc     #0
    sta     target+1
.endmacro

.endif
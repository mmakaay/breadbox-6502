.ifndef INC16_S
INC16_S = 1

.macro INC_WORD target
    ; Increment a 16 bit (word) value with 1.
    ;
    ; In:
    ;   target = address of the word to increment
    ; Out:
    ;   target = value incremented by 1
    ;   Carry = set when word wraps ($FFFF -> $0000)
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
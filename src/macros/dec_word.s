.ifndef DEC16_S
DEC16_S = 1

.macro DEC_WORD target
    ; Decrement a 16 bit (word) value by 1.
    ;
    ; In:
    ;   target = address of the word to decrement
    ; Out:
    ;   target = value decremented by 1
    ;   Carry = clear when word wraps ($0000 -> $FFFF)
    ;   A = clobbered
    
    sec
    lda     target
    sbc     #1
    sta     target
    lda     target+1
    sbc     #0
    sta     target+1
.endmacro

.endif

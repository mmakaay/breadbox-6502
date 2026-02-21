.ifndef STORE16_S
STORE16_S = 1

.include "set_byte.s"

.macro SET_WORD target, lo, hi
    ; Store a 16 bit value (word) in two consecutive memory positions.
    ;
    ; In:
    ;   target = address of the low byte target address
    ;   lo = the low byte to sture
    ;   hi = the high byte to store
    ; Out:
    ;   target = value of low byte
    ;   target + 1 = value of high byte
    ;   A = clobbered
    
    SET_BYTE target, lo
    SET_BYTE target + 1, hi
.endmacro

.endif
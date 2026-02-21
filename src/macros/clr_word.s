.ifndef CLEAR16_S
CLEAR16_S = 1

.include "set_word.s"

.macro CLR_WORD target
    ; Store #0000 in a word.
    ;
    ; In:
    ;   target = address of the target address
    ; Out:
    ;   target = #0000
    ;   A = clobbered
    
    SET_WORD target, #00, #00
.endmacro

.endif
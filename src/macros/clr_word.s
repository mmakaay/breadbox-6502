.ifndef CLEAR16_S
CLEAR16_S = 1

.include "set_word.s"

.macro clr_word target
    ; Store #0000 in a word.
    ;
    ; In:
    ;   target = address of the target address
    ; Out:
    ;   target = #0000
    ;   A = clobbered
    set_word target, #00, #00
.endmacro

.endif
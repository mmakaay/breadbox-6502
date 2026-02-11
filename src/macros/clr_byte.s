.ifndef CLEAR8_S
CLEAR8_S = 1

.include "set_byte.s"

.macro clr_byte target
    ; Store #00 in a byte.
    ;
    ; In:
    ;   target = address of the target address
    ; Out:
    ;   target = #0
    ;   A = clobbered
    set_byte target, #00
.endmacro

.endif
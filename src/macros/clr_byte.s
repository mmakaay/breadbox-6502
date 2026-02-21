.ifndef CLEAR8_S
CLEAR8_S = 1

.include "set_byte.s"

.macro CLR_BYTE target
    ; Store #00 in a byte.
    ;
    ; In:
    ;   target = address of the target address
    ; Out:
    ;   target = #0
    ;   A = clobbered
    
    SET_BYTE target, #00
.endmacro

.endif
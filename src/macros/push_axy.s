.ifndef PUSH_AXY_S
PUSH_AXY_S = 1

.macro push_axy
    ; Push A, X and Y onto the stack.
    pha
    txa
    pha
    tya
    pha
.endmacro

.endif

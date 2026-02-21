.ifndef PUSH_AXY_S
PUSH_AXY_S = 1

.macro PUSH_AXY
    ; Push A, X and Y onto the stack.
    
    pha
    txa
    pha
    tya
    pha
.endmacro

.endif

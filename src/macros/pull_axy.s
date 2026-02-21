.ifndef PULL_AXY_S
PULL_AXY_S = 1

.macro PULL_AXY
    ; Pull A, X and Y from the stack (reverse order of PUSH_AXY).
    
    pla
    tay
    pla
    tax
    pla
.endmacro

.endif

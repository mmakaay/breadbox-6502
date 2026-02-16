.ifndef PULL_AXY_S
PULL_AXY_S = 1

.macro pull_axy
    ; Pull A, X and Y from the stack (reverse order of push_axy).
    pla
    tay
    pla
    tax
    pla
.endmacro

.endif

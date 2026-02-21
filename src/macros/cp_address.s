.ifndef CP_ADDRESS_S
CP_ADDRESS_S = 1

.include "set_word.s"

.macro CP_ADDRESS target, source
    ; Store a 16 bit address in two consecutive memory positions.
    ;
    ; This stores the address of the source label (not the
    ; contents) at that address. Useful for example for setting
    ; up indirect jump vectors and pointers.
    ;
    ; In:
    ;   target = address to store into
    ;   source = address to take the address from
    ; Out:
    ;   target = low byte of source address
    ;   target + 1 = high byte of source address
    ;   A = clobbered
    
    SET_WORD target, #<source, #>source
.endmacro

.endif

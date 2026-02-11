.ifndef COPY16_S
COPY16_S = 1

.include "set_word.s"

.macro cp_word target, source
    ; Copy 16 bits (word) from the source address to the target address.
    ;
    ; In:
    ;   target = address to copy value to
    ;   source = address to copy value from
    ; Out:
    ;   source = preserved
    ;   target = copied value from source
    ;   A = clobbered
    set_word target, #<source, #>source
.endmacro

.endif
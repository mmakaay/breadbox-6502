.ifndef CP_WORD_S
CP_WORD_S = 1

.macro CP_WORD target, source
    ; Copy a 16 bit value (word) from one memory location to another.
    ;
    ; In:
    ;   target = address to copy to
    ;   source = address to copy from
    ; Out:
    ;   target = value copied from source
    ;   source = preserved
    ;   A = clobbered
    
    lda     source
    sta     target
    lda     source + 1
    sta     target + 1
.endmacro

.endif
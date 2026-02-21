.ifndef STORE8_S
STORE8_S = 1

.macro SET_BYTE target, value
    ; Store an 8 bit value (byte) in a memory position.
    ;
    ; In:
    ;   target = address of the target address
    ;   value = the ow byte to sture
    ; Out:
    ;   target = value
    ;   A = clobbered
    
    lda     value
    sta     target
.endmacro

.endif
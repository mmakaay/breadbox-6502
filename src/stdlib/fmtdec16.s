.ifndef FMTDEC16_S
FMTDEC16_S = 1

.include "str.s"
.include "stdlib/divmod16.s"

.segment "CODE"

.proc fmtdec16
    ; Format 16 bit value (word) into decimal representation string.
    ;
    ; In:
    ;   ZP::word_a = the 16 bit value to convert.
    ; Out:
    ;   ZP::str = reversed (!), null-terminated string (max 5 digits)
    ;   ZP::word_a = clobbered
    ;   A = clobbered
    ;   X/Y = preserved

    txa
    pha
    tya
    pha

    jsr str_clr  ; Clear string buffer

    ; Set the divider for divmod to 10, so we can use it to strip off the "ones".
    SET_WORD ZP::word_b, #10, #00

@next_digit:
    jsr divmod16

    lda ZP::word_c      ; Get computed remainder
    clc                 ; Clear carry for clean addition
    adc #'0'            ; Add remainder to ASCII value of "0"
    jsr str_add         ; Add the ASCII digit to the string buffer

    ; Repeat until all base 10 digits have been extracted.
    lda ZP::word_a
    ora ZP::word_a + 1
    bne @next_digit     ; Branch if the quotient is not yet at zero

    pla
    tay
    pla
    tax
    rts

.endproc

.endif

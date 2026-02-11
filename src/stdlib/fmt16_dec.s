.ifndef FMT16_DEC_S
FMT16_DEC_S = 1

.include "str.s"
.include "../macros/set_word.s"

.segment "CODE"

.proc fmt16_dec
    ; Format 16 bit value into decimal representation string.
    ;
    ; In:
    ;   Regs::word_a = the 16 bit value to convert.
    ; Out:
    ;   Regs::str = null-terminated string (max 5 digits)
    ;   Regs::word_a = clobbered
    ;   A = clobbered
    ;   X/Y = preserved

    phx
    phy

    jsr str_clr  ; Clear string buffer

    ; Set the divider for divmod to 10, so we can use it to strip off the "ones".
    set_word Regs::word_b, #10, #00

    @next_digit:
        jsr divmod16

        clc               ; Clear carry for clean addition
        lda Regs::word_c  ; Get computed remainder
        adc #'0'          ; Add remainder to ASCII value of "0"
        jsr str_add       ; Add the ASCII digit to the string buffer

        ; Repeat until all base 10 digits have been extracted.
        lda Regs::word_a
        ora Regs::word_a + 1
        bne @next_digit  ; Branch if the quotient is not yet at zero

    ply
    plx
    rts

.endproc

.endif
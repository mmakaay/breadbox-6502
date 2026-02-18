; From: Binary to decimal can’t be that hard, right?
; --------------------------------------------------
;
; Tutorial : https://www.youtube.com/watch?v=v3-a-zqKfgA&t=2497
; Result   : https://www.youtube.com/watch?v=v3-a-zqKfgA&t=2497
;
; This implementation does not contain the full conversion code from
; the tutorial video. The stdlib (standaard subroutines that can be
; included in projects) provides the subroutine `fmtdec16` for this
; purpose. Below, you can find how it is used.

.include "breadbox/kernal.s"
.include "stdlib/fmtdec16.s"

binary_value:  .word 1729
decimal_value: .asciiz "65535"

main:
    ; Convert the binary value to a decimal string value.
    lda binary_value      ; Load low byte of binary value.
    sta ZP::word_a        ; Store in call argument low byte
    lda binary_value + 1  ; Load high byte of binary value.
    sta ZP::word_a + 1    ; Store in call argument high byte
    jsr fmtdec16          ; Call stdlib subroute to convert to decimal

    ; Print the resulting decimal string value.
    ldy ZP::strlen        ; Get string length result from fmtdec16.
@loop:
    cpy #0                ; String index reached the start of the string?
    beq @halt             ; Then stop printing.
    dey                   ; Move to the next byte.
    lda ZP::str,y         ; Load the byte from the decimal representation.
    sta LCD::byte         ; Store the byte as the LCD write call argument.
    jsr LCD::write        ; Write the byte (a digit) to the LCD display.
    jmp @loop             ; Process next character.

@halt:
    jmp KERNAL::halt

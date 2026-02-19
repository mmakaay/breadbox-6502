.setcpu "65C02"

PORTB = $6000
PORTA = $6001
PORTB_DIR = $6002
PORTA_DIR = $6003


; Suppress warnings about segments that are in the breadbox.cfg memory
; layout, but that are not used in this minimal application.
.segment "ZEROPAGE"
.segment "KERNAL"
.segment "VARIABLES"

.segment "CODE"

    RESET:
        lda #$FF         ; Set all pins on port B to output 
        sta PORTB_DIR

    LOOP:
        lda #%10000000   ; Do the Knight Rider!
        sta PORTB
        lda #%11000000
        sta PORTB
        lda #%01100000
        sta PORTB
        lda #%00110000
        sta PORTB
        lda #%00011000
        sta PORTB
        lda #%00001100
        sta PORTB
        lda #%00000110
        sta PORTB
        lda #%00000011
        sta PORTB
        lda #%00000001
        sta PORTB

        nop
        nop

        lda #%00000011
        sta PORTB
        lda #%00000110
        sta PORTB
        lda #%00001100
        sta PORTB
        lda #%00011000
        sta PORTB
        lda #%00110000
        sta PORTB
        lda #%01100000
        sta PORTB
        lda #%11000000
        sta PORTB
        lda #%10000000
        sta PORTB

        jmp LOOP         ; And repeat ad infinitum

.segment "VECTORS"

    .word RESET          ; NMI vector
    .word RESET          ; RESET vector
    .word RESET          ; IRQ vector


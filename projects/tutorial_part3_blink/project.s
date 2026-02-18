; From: Assembly language vs. machine code
; ----------------------------------------
;
; Tutorial : https://youtu.be/oO8_2JJV0B4
; Result   : https://youtu.be/oO8_2JJV0B4&t=840
; Code     : https://eater.net/downloads/blink.s
;
; Note that a very low clockspeed is required to be able to see the
; LEDs blink. At high speeds, the output will just look a bunch
; of active LEDs.

.include "breadbox/kernal.s"

main:
    set_byte GPIO::port, GPIO::PORTB  ; Select VIA port B
    set_byte GPIO::mask, #$ff         ; Select all pins
    jsr GPIO::set_outputs             ; And make them outputs

    set_byte GPIO::value, #$50        ; Use $50 (%01010000)
    jsr GPIO::set_pins                ; to set the pin output values

@loop:
    ror GPIO::value                   ; Shift bits in value to the right
    jsr GPIO::set_pins                ; Set the pin output values

    jmp @loop                         ; And repeat


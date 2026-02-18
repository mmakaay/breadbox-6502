; From: How do CPUs read machine code?
; ------------------------------------
;
; Tutorial : https://youtu.be/yl8vPW5hydQ
; Result   : https://youtu.be/yl8vPW5hydQ?t=2678
; Code     : https://eater.net/downloads/makerom.py
;
; Note that a very low clockspeed is required to be able to see the
; LEDs blink. At high speeds, the output will just look a bunch
; of active LEDs.

.include "breadbox/kernal.s"

main:
    set_byte GPIO::port, GPIO::PORTB  ; Select VIA port B
    set_byte GPIO::mask, #$ff         ; Select all pins
    jsr GPIO::set_outputs             ; And make them outputs

@loop:
    set_byte GPIO::value, #$55        ; Use $55 (%01010101)
    jsr GPIO::set_pins                ; to set the pin output values

    set_byte GPIO::value, #$aa        ; Use $aa (%10101010)
    jsr GPIO::set_pins                ; to set the pin output values

    jmp @loop                         ; And repeat


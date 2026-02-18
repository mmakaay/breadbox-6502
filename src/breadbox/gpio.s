; -----------------------------------------------------------------
; GPIO (General Purpose I/O) abstraction
;
; This provides a standard API for accessing device pins for
; input/output purposes, abstracting the underlying hardware.
; This can for example be used to control the port A and port B
; pins on a 65C22 VIA IC. You can control either all pins on a
; single port at once, or only a subset of pins. Even controlling
; a single pin (without touching the other pins on the same port)
; is made easy by this abstraction, e.g.:
;
;   lda GPIO::PORTA     ; Select VIA port A
;   sta GPIO::port      ;
;   lda GPIO::P4        ; Select pin 4 (i.e. PA4 in context of port A)
;   sta GPIO::mask      ;
;   jsr GPIO::turn_on   ; Turn on PA4 (set to output + write value)
;
; Parameters are passed via zero page variables:
;
;   GPIO::port  = port selector (GPIO::PORTA or GPIO::PORTB)
;   GPIO::mask  = pin mask (meaning depends on procedure)
;   GPIO::value = pin values / data byte
;
; All procedures preserve A, X, Y.
; -----------------------------------------------------------------

.ifndef BIOS_GPIO_S
BIOS_GPIO_S = 1

.include "breadbox/kernal.s"

.scope GPIO

.segment "ZEROPAGE"

    port:  .res 1              ; Port selector (GPIO::PORTA or GPIO::PORTB)
    mask:  .res 1              ; Pin mask (meaning depends on procedure)
    value: .res 1              ; Pin values / data byte
    temp:  .res 1              ; In-subroutine temporary storage

.segment "KERNAL"

    ; Import the hardware driver.
    ; Currently, there is only one.
    .include "breadbox/gpio/w65c22_via.s"

    ; Port selection constants.
    PORTA = 1
    PORTB = 0

    ; Pin bit masks.
    P0 = %00000001
    P1 = %00000010
    P2 = %00000100
    P3 = %00001000
    P4 = %00010000
    P5 = %00100000
    P6 = %01000000
    P7 = %10000000

    ; -------------------------------------------------------------
    ; Access to the low level driver API
    ; -------------------------------------------------------------

    set_inputs = DRIVER::set_inputs
        ; Set data direction to input for the requested pins.
        ;
        ; In (zero page):
        ;   GPIO::mask = pin mask (1 = set to input)
        ;   GPIO::port = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   A, X, Y preserved

    set_outputs = DRIVER::set_outputs
        ; Set data direction to output for the requested pins.
        ;
        ; In (zero page):
        ;   GPIO::mask = pin mask (1 = set to output)
        ;   GPIO::port = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   A, X, Y preserved

    set_pins = DRIVER::set_pins
        ; Set pin values for a selected group of pins.
        ; Pins not selected by the mask are preserved.
        ;
        ; The pins must have be configured for output, before calling this subroutine.
        ;
        ; In (zero page):
        ;   GPIO::mask  = pin mask (1 = update this pin, 0 = preserve)
        ;   GPIO::value = pin values (desired state for masked pins)
        ;   GPIO::port  = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   A, X, Y preserved

    turn_on = DRIVER::turn_on
        ; Turn on (set HIGH) selected pins.
        ; Other pins are preserved.
        ;
        ; The pins must have be configured for output, before calling this subroutine.
        ;
        ; In (zero page):
        ;   GPIO::mask = pin mask (1 = turn on this pin)
        ;   GPIO::port = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   A, X, Y preserved

    turn_off = DRIVER::turn_off
        ; Turn off (set LOW) selected pins.
        ; Other pins are preserved.
        ;
        ; The pins must have be configured for output, before calling this subroutine.
        ;
        ; In (zero page):
        ;   GPIO::mask = pin mask (1 = turn off this pin)
        ;   GPIO::port = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   A, X, Y preserved

    write_port = DRIVER::write_port
        ; Write a full byte to the port register.
        ;
        ; The pins must have be configured for output, before calling this subroutine.
        ;
        ; In (zero page):
        ;   GPIO::value = byte to write
        ;   GPIO::port  = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   A, X, Y preserved

    read_port = DRIVER::read_port
        ; Read a full byte from the port register.
        ;
        ; The pins must have be configured for input, before calling this subroutine.
        ;
        ; In (zero page):
        ;   GPIO::port = port (GPIO::PORTA or GPIO::PORTB)
        ; Out:
        ;   GPIO::value = byte read
        ;   A, X, Y preserved

.endscope

.endif

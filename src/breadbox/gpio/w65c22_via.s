; -----------------------------------------------------------------
; GPIO driver for W65C22 VIA (Versatile Interface Adapter)
;
; Implements GPIO operations using absolute,Y addressing on the
; VIA port registers. Since PORTA = PORTB + 1 and DDRA = DDRB + 1,
; an internal Y register value selects the port:
;
;   Y = 0 -> port B
;   Y = 1 -> port A
;
; Parameters are passed via zero page variables (GPIO::port,
; GPIO::mask, GPIO::value). All procedures preserve A, X, Y.
;
; -----------------------------------------------------------------

.ifndef BIOS_GPIO_VIA_W65C22_S
BIOS_GPIO_VIA_W65C22_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "KERNAL"

    .proc set_inputs
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda mask                   ; A = pin mask (bit 1 = make related pin an input)
        eor #$ff                   ; A = inverted mask (bit 1 = keep pin direction as-is)
        and IO::DDRB_REGISTER,Y    ; A = AND active data direction config, pins from mask to 0 (input)
        sta IO::DDRB_REGISTER,Y    ; Write combined data direction config

        pla
        tay
        pla
        rts
    .endproc

    .proc set_outputs
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda mask                   ; A = pin mask (bit 1 = make related pin an output)
        ora IO::DDRB_REGISTER,Y    ; A = OR active data direction config, pins from mask to 1 (output)
        sta IO::DDRB_REGISTER,Y    ; Write combined data direction config

        pla
        tay
        pla
        rts
    .endproc

    .proc set_pins
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda mask                   ; A = pin mask (bit 1 = update pin, bit 0 = keep as-is)
        eor #$ff                   ; A = inverted mask (bit 1 = keep as-is, bit 0 = update pin)
        and IO::PORTB_REGISTER,Y   ; A = AND active pin states, to make pins to update 0
        sta temp                   ; Store intermediate pin states

        lda value                  ; A = value (with bit 1 = turn on pin, bit 0 = turn off pin)
        and mask                   ; A = AND mask, to make the bits outside the mask 0
        ora temp                   ; A = OR intermediate pin states, to merge with pins to set

        sta IO::PORTB_REGISTER,Y   ; Write combined pin states

        pla
        tay
        pla
        rts
    .endproc

    .proc turn_on
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda mask                   ; A = pin mask (bit 1 = turn on pin, 0 = keep as-is)
        ora IO::PORTB_REGISTER,Y   ; A = OR active pin states, to make pins to turn on 1
        sta IO::PORTB_REGISTER,Y   ; Write combined pin states

        pla
        tay
        pla
        rts
    .endproc

    .proc turn_off
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda mask                   ; A = pin mask (bit 1 = turn off pin, bit 0 = keep as-is)
        eor #$ff                   ; A = inverted mask (bit 1 = keep as-is, bit 0 = turn off pin)
        and IO::PORTB_REGISTER,Y   ; A = AND active pin states (making pins to turn off 0)
        sta IO::PORTB_REGISTER,Y   ; Write combined pin states

        pla
        tay
        pla
        rts
    .endproc

    .proc write_port
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda value                  ; A = value (bit 1 = turn on pin, 0 = turn off pin)
        sta IO::PORTB_REGISTER,Y   ; Write pin states

        pla
        tay
        pla
        rts
    .endproc

    .proc read_port
        pha
        tya
        pha

        ldy port                   ; Y = 0 (port B) or 1 (port A)
        lda IO::PORTB_REGISTER,Y   ; A = active pin states for selected port
        sta value                  ; Write to output value

        pla
        tay
        pla
        rts
    .endproc

.endscope

.endif

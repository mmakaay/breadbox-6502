; -----------------------------------------------------------------
; W65C22 VIA (Versatile Interface Adapter)
;
; This is an adapter device that is currently not implemented as
; a HAL layer. I don't think this is required, since projects
; that I haver seen so far, all use W65C22 ICs.
; -----------------------------------------------------------------

.ifndef BIOS_VIA_W65C22_S
BIOS_VIA_W65C22_S = 1

.include "bios/bios.s"

; The start of the VIA register space is configured in the
; linker configuration. The linker provides the starting
; address that is imported here.
.import __VIA_START__

.scope VIA

.segment "ZEROPAGE"

    tmp_byte: .res 1

.segment "BIOS"

    ; Registers
    PORTB_REGISTER = __VIA_START__ + $0 ; I/O register for port B
    PORTA_REGISTER = __VIA_START__ + $1 ; I/O register for port A
    DDRB_REGISTER  = __VIA_START__ + $2 ; Data direction for pins B0 - B7 (bit per pin, 0 = in, 1 = out)
    DDRA_REGISTER  = __VIA_START__ + $3 ; Data direction for pins A0 - A7 (bit per pin, 0 = in, 1 = out)
    PCR_REGISTER   = __VIA_START__ + $c ; Peripheral Control Register (configure CA1/2, CB1/2)
    IFR_REGISTER   = __VIA_START__ + $d ; Interrupt Flag Register (read triggered interrupt)
    IER_REGISTER   = __VIA_START__ + $e ; Interrupt Enable Register (configure interrupts)

    ; IER register bits
    IER_SET   = %10000000   
    IER_CLR   = %00000000  
    IER_T1    = %01000000   ; Timer 1
    IER_T2    = %00100000   ; Timer 2
    IER_CB1   = %00010000  
    IER_CB2   = %00001000  
    IER_SHR   = %00000100   ; Shift register
    IER_CA1   = %00000010   ; Shift register
    IER_CA2   = %00000001   ; Shift register

    ; Port pins (can be used for both port A and B)
    P0        = %00000001
    P1        = %00000010
    P2        = %00000100
    P3        = %00001000
    P4        = %00010000
    P5        = %00100000
    P6        = %01000000
    P7        = %10000000

    .proc porta_set_inputs
        ; Set data direction to input for the requested pins on port A. 
        ;
        ; Usage:
        ;   lda #%10000110 ; to enable input on PA1, PA2 and PA7
        ;   lda #(VIA::BIT::P1 | VIA::BIT::P2 | VIA::BIT::P7)  ; equivalent
        ;   jsr porta_set_inputs
        ;
        ; In:
        ;   A = with bits for ports to update set to 1
        ; Output:
        ;   A = clobbered
        ;   Port A = requested pins set to input mode, other ports preserved

        eor #$ff
        and DDRA_REGISTER
        sta DDRA_REGISTER
        rts
    .endproc

    .proc porta_set_outputs
        ; Set data direction to output for the requested pins on port A. 
        ;
        ; Usage:
        ;   lda #%00110000 ; to enable output on PA4 and PA5
        ;   lda #(VIA::BIT::P4 | VIA::BIT::P5)  ; equivalent
        ;   jsr porta_set_outputs
        ;
        ; In:
        ;   A = with bits for ports to update set to 1
        ; Output:
        ;   A = clobbered
        ;   Port A = requested pins set to output mode, other ports preserved

        ora DDRA_REGISTER
        sta DDRA_REGISTER
        rts
    .endproc

    .proc porta_set_pins
        ; Set pin values on port A for a selected group of pins.
        ; Pins not selected by the mask are preserved.
        ;
        ; Usage:
        ;   lda #(VIA::BIT::P7 | VIA::BIT::P6 | VIA::BIT::P5)  ; mask: pins to update
        ;   ldx #(VIA::BIT::P7 | VIA::BIT::P5)                 ; values: P7=1, P6=0, P5=1
        ;   jsr VIA::porta_set_pins
        ;
        ; In:
        ;   A = pin mask (1 = update this pin, 0 = preserve)
        ;   X = pin values (desired state for pins to update)
        ; Out:
        ;   A = clobbered
        ;   X = preserved

        eor #$ff           ; Invert mask to get preserve-mask
        and PORTA_REGISTER ; A = preserved pin values
        stx tmp_byte       ; Save X temporarily
        ora tmp_byte       ; Merge preserved values with desired pin values
        sta PORTA_REGISTER ; Write final result (single write)
        rts
    .endproc

    .proc porta_turn_on
        ; Turn on (set HIGH) selected pins on port A.
        ; Other pins are preserved.
        ;
        ; Usage:
        ;   lda #VIA::BIT::P7             ; pin(s) to turn on
        ;   jsr VIA::porta_turn_on
        ;
        ; In:
        ;   A = pin mask (1 = turn on this pin)
        ; Out:
        ;   A = clobbered

        ora PORTA_REGISTER
        sta PORTA_REGISTER
        rts
    .endproc

    .proc porta_turn_off
        ; Turn off (set LOW) selected pins on port A.
        ; Other pins are preserved.
        ;
        ; Usage:
        ;   lda #VIA::BIT::P7             ; pin(s) to turn off
        ;   jsr VIA::porta_turn_off
        ;
        ; In:
        ;   A = pin mask (1 = turn off this pin)
        ; Out:
        ;   A = clobbered

        eor #$ff
        and PORTA_REGISTER
        sta PORTA_REGISTER
        rts
    .endproc

    .proc portb_turn_on
        ; Turn on (set HIGH) selected pins on port B.
        ; Other pins are preserved.
        ;
        ; Usage:
        ;   lda #VIA::BIT::P7             ; pin(s) to turn on
        ;   jsr VIA::portb_turn_on
        ;
        ; In:
        ;   A = pin mask (1 = turn on this pin)
        ; Out:
        ;   A = clobbered

        ora PORTB_REGISTER
        sta PORTB_REGISTER
        rts
    .endproc

    .proc portb_turn_off
        ; Turn off (set LOW) selected pins on port B.
        ; Other pins are preserved.
        ;
        ; Usage:
        ;   lda #VIA::BIT::P7             ; pin(s) to turn off
        ;   jsr VIA::portb_turn_off
        ;
        ; In:
        ;   A = pin mask (1 = turn off this pin)
        ; Out:
        ;   A = clobbered

        eor #$ff
        and PORTB_REGISTER
        sta PORTB_REGISTER
        rts
    .endproc

    .proc portb_set_pins
        ; Set pin values on port B for a selected group of pins.
        ; Pins not selected by the mask are preserved.
        ;
        ; Usage:
        ;   lda #(VIA::BIT::P7 | VIA::BIT::P6 | VIA::BIT::P5)  ; mask: pins to update
        ;   ldx #(VIA::BIT::P7 | VIA::BIT::P5)                 ; values: P7=1, P6=0, P5=1
        ;   jsr VIA::portb_set_pins
        ;
        ; In:
        ;   A = pin mask (1 = update this pin, 0 = preserve)
        ;   X = pin values (desired state for pins to update)
        ; Out:
        ;   A = clobbered
        ;   X = preserved

        eor #$ff           ; Invert mask to get preserve-mask
        and PORTB_REGISTER ; A = preserved pin values
        stx tmp_byte       ; Save X temporarily
        ora tmp_byte       ; Merge preserved values with desired pin values
        sta PORTB_REGISTER ; Write final result
        rts
    .endproc

    .proc portb_set_inputs
        ; Set data direction to input for the requested pins on port B. 
        ;
        ; Usage:
        ;   lda #%10000110 ; to enable input on PA1, PA2 and PA7
        ;   lda #(VIA::BIT::P1 | VIA::BIT::P2 | VIA::BIT::P7)  ; equivalent
        ;   jsr portb_set_inputs
        ;
        ; In:
        ;   A = with bits for ports to update set to 1
        ; Output:
        ;   A = clobbered
        ;   Port B = requested pins set to input mode, other ports preserved

        eor #$ff
        and DDRB_REGISTER
        sta DDRB_REGISTER
        rts
    .endproc

    .proc portb_set_outputs
        ; Set data direction to output for the requested pins on port B. 
        ;
        ; Usage:
        ;   lda #%00110000 ; to enable output on PA4 and PA5
        ;   lda #(VIA::BIT::P4 | VIA::BIT::P5)  ; equivalent
        ;   jsr portb_set_outputs
        ;
        ; In:
        ;   A = with bits for ports to update set to 1
        ; Output:
        ;   A = clobbered
        ;   Port B = requested pins set to output mode, other ports preserved

        ora DDRB_REGISTER
        sta DDRB_REGISTER
        rts
    .endproc

.endscope

.endif

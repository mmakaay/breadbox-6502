; -----------------------------------------------------------------
; HD44780 LCD (8 bit data bus, 2 line display, 5x8 font)
;
; Drives the LCD using an 8 bit data bus connection, with all
; data bus pins connected to VIA port B, and the control pins
; connected to 3 pins of VIA port A.
;
;    HD44780 LCD                           65C22 VIA
;    ┌─────────┐                          ┌─────────┐
;    │         │                          │         │
;    │         │                     n/c──┤ PA*     │
;    │  RS     │◄─────────────────────────┤ PA5     │ (PIN_RS)
;    │  RWB    │◄─────────────────────────┤ PA6     │ (PIN_RWB)
;    │  E      │◄─────────────────────────┤ PA7     │ (PIN_EN)
;    │         │                          │         │
;    │  D0     │◄────────────────────────►│ PB0     │
;    │  D1     │◄────────────────────────►│ PB1     │
;    │  D2     │◄────────────────────────►│ PB2     │
;    │  D3     │◄────────────────────────►│ PB3     │
;    │  D4     │◄────────────────────────►│ PB4     │
;    │  D5     │◄────────────────────────►│ PB5     │
;    │  D6     │◄────────────────────────►│ PB6     │
;    │  D7     │◄────────────────────────►│ PB7     │
;    │         │                          │         │
;    └─────────┘                          └─────────┘
;
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_S
BIOS_LCD_HD44780_S = 1

.include "bios/bios.s"

.scope DRIVER

.segment "BIOS"

    ; Pin mapping LCD control pins -> VIA port A.
    PIN_EN  = VIA::P7
    PIN_RWB = VIA::P6
    PIN_RS  = VIA::P5
    VIA_PORTA_PINS = (PIN_EN | PIN_RWB | PIN_RS)

    ; Pin mapping LCD data pins -> VIA port B.
    VIA_PORTB_PINS = %11111111

    .include "bios/lcd/hd44780_common.s"

    .proc init
        ; Initialize all pins connected to the LCD in output mode.
        ; Port A (CMND register) will always be in output mode from here on. 
        ; Port B (DATA register) will toggle input/output mode, depending on use.
        lda #VIA_PORTA_PINS
        jsr VIA::porta_set_outputs
        lda #VIA_PORTB_PINS
        jsr VIA::portb_set_outputs

        ; Clear LCD control bits (EN, RW, RS), preserving non-LCD pins.
        lda #VIA_PORTA_PINS
        ldx #0
        jsr VIA::porta_set_pins

        ; Configure an initial display mode.
        jsr wait_till_ready
        lda #%00111000   ; Set 8-bit mode, 2 line display, 5x8 font
        jsr write_instruction
        jsr wait_till_ready
        lda #%00001110   ; Turn display on, cursor on, blink off
        jsr write_instruction
        jsr wait_till_ready
        lda #%00000110   ; Shift cursor on data, no display shift
        jsr write_instruction

        ; Clear the screen.
        jsr clr

        rts
    .endproc

    .proc write_instruction
        ; Write instruction to CMND register.
        ;
        ; In:
        ;   A = instruction byte to write
        ; Out:
        ;   A = clobbered

        ; Put the byte on the LCD data bus.
        sta VIA::PORTB_REGISTER

        ; Set control pins: RWB=0 (write), RS=0 (CMND), EN=0.
        lda #VIA_PORTA_PINS
        ldx #0
        jsr VIA::porta_set_pins

        ; Pulse EN high then low to trigger data transfer.
        lda #PIN_EN
        jsr VIA::porta_turn_on
        lda #PIN_EN
        jsr VIA::porta_turn_off
        
        rts
    .endproc

    .proc write
        ; Write byte to DATA register.
        ;
        ; In:
        ;   A = byte to write
        ; Out:
        ;   A = preserved

        sta VIA::PORTB_REGISTER
        pha
        
        ; Set control pins: RWB=0 (write), RS=1 (DATA), EN=0.
        lda #VIA_PORTA_PINS
        ldx #PIN_RS
        jsr VIA::porta_set_pins

        ; Pulse EN high then low to trigger data transfer.
        lda #PIN_EN
        jsr VIA::porta_turn_on
        lda #PIN_EN
        jsr VIA::porta_turn_off
        pla

        rts
    .endproc

    .proc check_ready
        ; Poll the LCD to see if it is ready for input.
        ;
        ; Out:
        ;   A = 0 if the LCD is ready for input
        ;   A != 0 if the LCD is busy

        ; Configure VIA port B for input, so we can read the status.
        lda #VIA_PORTB_PINS
        jsr VIA::portb_set_inputs

        ; Set control pins: RWB=1 (read), RS=0 (CMND), EN=0.
        lda #VIA_PORTA_PINS
        ldx #PIN_RWB
        jsr VIA::porta_set_pins

        ; Pulse EN high, read PORTB, then EN low.
        lda #PIN_EN
        jsr VIA::porta_turn_on
        lda VIA::PORTB_REGISTER        ; Read status byte from the LCD
        pha
        lda #PIN_EN
        jsr VIA::porta_turn_off
        
        ; Restore VIA port B for output.
        lda #VIA_PORTB_PINS
        jsr VIA::portb_set_outputs

        pla                            ; Fetch the status byte that we read
        and #BUSY_FLAG                 ; Strip all bits, except the busy bit

        rts
    .endproc

    .proc wait_till_ready
        ; Wait for the LCD screen to be ready for the next input.

        pha
    @loop:
        jsr check_ready
        bne @loop
        pla
        rts
    .endproc

.endif

.endscope


; -----------------------------------------------------------------
; HD44780 LCD (8 bit data bus, 2 line display, 5x8 font)
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_COMMON_S
BIOS_LCD_HD44780_COMMON_S = 1

.include "bios/bios.s"

.segment "BIOS"

    .scope BIT
    ; These are bit values for the LCD pins that are connected to port A of the VIA.
    ; The bit values can be OR-ed to get the value to write to port A.
    ; Some zero values are provided for code readability, e.g. to be able to
    ; write #(BIT::WRITE | BIT::DATA), instead of less explicit BIT::DATA.

    ; EN pin (connected to PA7)
    EN         = VIA::BIT::P7    ; Enable bit, toggle on -> off to transfer data

    ; RWB pin (connected to PA6)
    WRITE      = 0               ; Write bit (LCD RW pin = 0)
    READ       = VIA::BIT::P6    ; Read bit (LCD RW pin = 1)

    ; RS pin (connected to PA5)
    CMND       = 0               ; Select instruction register (LCD RS pin = 0)
    DATA       = VIA::BIT::P5    ; Select data register (LCD RS pin = 1)

    ; Port B is fully used for reading or writing bytes of data from or to the LCD.
    ; LCD pins DB0 - DB7 are connected PBB - PB7 on the VIA.
    ; DB7 can be used to check if the LCD is busy when reading from CMND register.
    BUSY       = VIA::BIT::P7

    ; High level definition of the pins that we use on VIA port A and B.
    PORTA_PINS = %11100000  ; Pins on port A, controlled by the LCD code
    PORTB_PINS = %11111111  ; All pins on port B are controlled by the LCD code
    .endscope

    .proc init
        ; Initialize the LCD hardware.
        ;
        ; Out:
        ;   A = clobbered 

        ; Initialize all pins connected to the LCD for output.
        ; Port A (CMND register) will always be in output mode from there. 
        ; Port B (DATA register) will toggle input/output depending on use.
        lda #BIT::PORTA_PINS
        jsr VIA::porta_set_outputs
        lda #BIT::PORTB_PINS
        jsr VIA::portb_set_outputs

        ; Clear LCD control bits (EN, RW, RS), preserving non-LCD pins.
        lda VIA::REG::PORTA
        and #(BIT::PORTA_PINS ^ $ff)
        sta VIA::REG::PORTA

        ; Configure an initial display mode.
        lda #%00111000   ; Set 8-bit mode, 2 line display, 5x8 font
        jsr write_instruction
        lda #%00001110   ; Turn display on, cursor on, blink off
        jsr write_instruction
        lda #%00000110   ; Shift cursor on data, no display shift
        jsr write_instruction

        ; Clear the screen.
        jsr clr

        rts
    .endproc

    .proc clr
        ; Clear the LCD screen.
        ;
        ; Out:
        ;   A = clobbered

        lda #%00000001   ; Clear screen, set address to 0
        jsr write_instruction
        rts
    .endproc

    .proc home
        ; Move LCD output position to home.
        ;
        ; Out:
        ;   A = clobbered

        lda #%00000010   ; Move cursor to home position
        jsr write_instruction
        rts
    .endproc

    .proc write_instruction
        ; Wait for LCD to become ready, and write instruction to CMND register.
        ;
        ; In:
        ;   A = instruction byte to write
        ; Out:
        ;   A = clobbered

        jsr wait_till_ready

        ; No rts, fall through to no wait implementation.
    .endproc

    .proc write_instruction_nowait
        ; Write instruction to CMND register.
        ;
        ; In:
        ;   A = instruction byte to write
        ; Out:
        ;   A = clobbered

        ; Put the byte on the LCD data bus.
        sta VIA::REG::PORTB

        ; Trigger transfer of the byte to the instruction register.
        lda VIA::REG::PORTA            ; Enable "write command" bits
        and #(BIT::PORTA_PINS ^ $ff)
        ora #(BIT::WRITE | BIT::CMND)
        sta VIA::REG::PORTA
        ora #BIT::EN                   ; Turn on enable bit to trigger data transfer
        sta VIA::REG::PORTA
        and #(BIT::EN ^ $ff)           ; Turn off enable bit to stop data transfer
        sta VIA::REG::PORTA
        
        rts
    .endproc

    .proc write
        ; Wait for LCD to become ready, and write byte to DATA register.
        ;
        ; In:
        ;   A = byte to write

        jsr wait_till_ready

        ; No rts, fall through to no wait implementation.
    .endproc

    .proc write_no_wait
        ; Write byte to DATA register.
        ;
        ; Out:
        ;   A = clobbered
        sta VIA::REG::PORTB
        
        ; Transfer byte to the data register.
        pha
        lda VIA::REG::PORTA            ; Enable writing to DATA register
        and #(BIT::PORTA_PINS ^ $ff)
        ora #(BIT::WRITE | BIT::DATA) 
        sta VIA::REG::PORTA
        ora #BIT::EN                   ; Turn on enable bit to trigger data transfer
        sta VIA::REG::PORTA
        and #(BIT::EN ^ $ff)           ; Turn off enable bit to stop data transfer
        sta VIA::REG::PORTA
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
        lda #BIT::PORTB_PINS
        jsr VIA::portb_set_inputs

        ; Read the status from the LCD.
        lda VIA::REG::PORTA            ; Enable reading from CMND register
        and #(BIT::PORTA_PINS ^ $ff)
        ora #(BIT::READ | BIT::CMND) 
        sta VIA::REG::PORTA
        ora #BIT::EN                   ; Enable LCD data transfer
        sta VIA::REG::PORTA
        lda VIA::REG::PORTB            ; Read status byte from the LCD
        pha
        lda VIA::REG::PORTA            ; Disable LCD data transfer
        and #(BIT::EN ^ $ff)
        sta VIA::REG::PORTA
        
        ; Restore VIA port B for output.
        lda #BIT::PORTB_PINS
        jsr VIA::portb_set_outputs

        pla                            ; Get the status byte that we read
        and #BIT::BUSY                 ; Strip all bits, except the busy bit

        rts
    .endproc

    ; Wait for the LCD screen to be ready for the next input.
    .proc wait_till_ready
        pha
    @loop:
        jsr check_ready
        bne @loop
        pla
        rts
    .endproc

.endif

.endscope



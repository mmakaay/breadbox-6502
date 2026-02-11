; -----------------------------------------------------------------
; HD44780 LCD (2 line display, 5x8 font)
; -----------------------------------------------------------------

.ifndef BIOS_LCD_S
BIOS_LCD_S = 1

.include "macros/macros.s"

.scope LCD

.segment "BIOS"

    ; Constants for the LCD display
    ; PORTA
    LCD_EN    = %10000000  ; Enable bit, toggle to transfer (LCD E pin = 1)
    LCD_READ  = %01000000  ; Read bit (LCD RW pin = 1)
    LCD_WRITE = %00000000  ; Write bit (LCD RW pin = 0)
    LCD_CMND  = %00000000  ; Select instruction register (LCD RS pin = 0)
    LCD_DATA  = %00100000  ; Select data register (LCD RS pin = 1)
    ; PORTB
    LCD_BUSY  = %10000000  ; Busy bit

    ; Subroutine: initialize the LCD hardware.
    ; Out:
    ;   A = clobbered 
    init:
        clr_byte VIA::PORTA   ; Clear control bits (EN, RW, RS)

        set_byte VIA::DDRB, #%11111111
        set_byte VIA::DDRA, #%11100000

        lda #%00111000   ; Set 8-bit mode, 2 line display, 5x8 font
        jsr send_instruction
        lda #%00001110   ; Turn display on, cursor on, blink off
        jsr send_instruction
        lda #%00000110   ; Shift cursor on data, no display shift
        jsr send_instruction
        rts

    ; Subroutine: clear the LCD screen.
    ; Out:
    ;   A = clobbered
    clr:
        lda #%00000001   ; Clear screen, set address to 0
        jsr send_instruction
        rts

    ; Subroutine: move LCD output position to home
    ; Out:
    ;   A = clobbered
    home:
        lda #%00000010   ; Move cursor to home position
        jsr send_instruction
        rts

    ; Subroutine: send an instruction to the LCD display.
    ; In:
    ;   A = instruction
    ; Out:
    ;   A = clobbered
    send_instruction:
        jsr wait_till_idle

        ; Put the instruction on the LCD inputs.
        sta VIA::PORTB

        ; Write to instruction register.
        set_byte VIA::PORTA, #(LCD_WRITE | LCD_CMND | LCD_EN)
        set_byte VIA::PORTA, #(LCD_WRITE | LCD_CMND)
        set_byte VIA::PORTA, #(LCD_WRITE | LCD_CMND)
        
        rts


    ; Subroutine: send data to the LCD display.
    ; In:
    ;   A = data
    ; Out:
    ;   A = clobbered
    send_data:
        jsr wait_till_idle

        ; Put the provided data on the LCD inputs.
        sta VIA::PORTB

        ; Write to data register.
        set_byte VIA::PORTA, #(LCD_WRITE | LCD_DATA)
        set_byte VIA::PORTA, #(LCD_WRITE | LCD_DATA | LCD_EN)
        set_byte VIA::PORTA, #(LCD_WRITE | LCD_DATA)

        rts


    ; Subroutine: wait for the LCD screen to not be busy.
    wait_till_idle:
        pha
        set_byte VIA::DDRB, #%00000000   ; Configure port B for input

        @loop:
            set_byte VIA::PORTA, #(LCD_READ | LCD_CMND)
            set_byte VIA::PORTA, #(LCD_READ | LCD_CMND | LCD_EN)
            lda  VIA::PORTB  ; Load status information from port B
            and #LCD_BUSY    ; Look only at the LCD busy bit
            bne @loop        ; Wait until busy bit = 0

        set_byte VIA::PORTA, #(LCD_READ | LCD_CMND) 
        set_byte VIA::DDRB, #%11111111   ; Configure port B for output
        pla
        rts

.endif

.endscope
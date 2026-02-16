; -----------------------------------------------------------------
; LCD display HAL
;
; Parameters are passed via zero page: LCD::byte.
; All procedures preserve A, X, Y.
;
; Configuration
; -------------
; Define these constants in `config.s` to override defaults.
;
;   LCD_DRIVER    = HD44780_8BIT or HD44780_4BIT (default: HD44780_8BIT)
;   LCD_CMND_PORT = GPIO port for CMND pins (PORTA or PORTB)
;   LCD_DATA_PORT = GPIO port for DATA pins (PORTA or PORTB)
;   LCD_PIN_RS    = pin bitmask for Register Select
;   LCD_PIN_RWB   = pin bitmask for Read/Write
;   LCD_PIN_EN    = pin bitmask for Enable
;
; Each driver provides its own defaults. See hd44780_4bit.s and
; hd44780_8bit.s for the default pin layouts.
;
; -----------------------------------------------------------------

.ifndef BIOS_LCD_S
BIOS_LCD_S = 1

.include "bios/bios.s"

.scope LCD
    .if ::LCD_DRIVER = ::HD44780_8BIT
        .include "bios/lcd/hd44780_8bit.s"
    .elseif ::LCD_DRIVER = ::HD44780_4BIT
        .include "bios/lcd/hd44780_4bit.s"
    .else
        .error "LCD_DRIVER invalid (see bios/constants.s for options)"
    .endif

    .segment "ZEROPAGE"

    byte: .res 1 ; Input byte for write / write_instruction

    .segment "BIOS"

    ; -------------------------------------------------------------
    ; Access to the low level driver API
    ; -------------------------------------------------------------

    init = DRIVER::init
        ; Initialize the LCD hardware.
        ;
        ; Out:
        ;   A, X, Y preserved

    check_ready = DRIVER::check_ready
        ; Poll the LCD to see if it is ready for input.
        ;
        ; Out:
        ;   LCD::byte = 0 if the LCD is ready for input
        ;   LCD::byte != 0 if the LCD is busy
        ;   A, X, Y preserved

    write_instruction = DRIVER::write_instruction
        ; Write instruction to CMND register.
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

    write = DRIVER::write
        ; Write byte to DATA register.
        ;
        ; In (zero page):
        ;   LCD::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

    clr = DRIVER::clr
        ; Clear the LCD screen (waits for ready).
        ;
        ; Out:
        ;   A, X, Y preserved

    home = DRIVER::home
        ; Move LCD output position to home (waits for ready).
        ;
        ; Out:
        ;   A, X, Y preserved

    ; -------------------------------------------------------------
    ; High level convenience wrappers.
    ; -------------------------------------------------------------

    .proc write_instruction_when_ready
        ; Wait for LCD to become ready, then write instruction to
        ; CMND register.
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

        pha
        lda byte                   ; Save the instruction byte
        pha
    @wait:
        jsr check_ready
        lda byte
        bne @wait
        pla                        ; Restore the instruction byte
        sta byte
        jsr write_instruction
        pla
        rts
    .endproc

    .proc write_when_ready
        ; Wait for LCD to become ready, then write byte to DATA register.
        ;
        ; In (zero page):
        ;   LCD::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

        pha
        lda byte                   ; Save the data byte
        pha
    @wait:
        jsr check_ready
        lda byte
        bne @wait
        pla                        ; Restore the data byte
        sta byte
        jsr write
        pla
        rts
    .endproc

.endscope

.endif

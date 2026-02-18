; -----------------------------------------------------------------
; LCD display HAL
;
; Parameters are passed via zero page: LCD::byte.
; All procedures preserve A, X, Y.
;
; Configuration
; -------------
; Define these constants in `config.inc` to configure the driver:
;
;   LCD_DRIVER         = HD44780_8BIT or HD44780_4BIT
;   LCD_CMND_PORT      = GPIO port for CMND pins (PORTA or PORTB)
;   LCD_CMND_PIN_RS    = pin bitmask for Register Select
;   LCD_CMND_PIN_RWB   = pin bitmask for Read/Write
;   LCD_CMND_PIN_EN    = pin bitmask for Enable
;   LCD_DATA_PORT      = GPIO port for DATA pins (PORTA or PORTB)
;
; See `config-example.inc` for more information.
; -----------------------------------------------------------------

.ifndef BIOS_LCD_S
BIOS_LCD_S = 1

.include "breadbox/kernal.s"

.scope LCD
    .if ::LCD_DRIVER = ::HD44780_8BIT
        .include "breadbox/lcd/hd44780_8bit.s"
    .elseif ::LCD_DRIVER = ::HD44780_4BIT
        .include "breadbox/lcd/hd44780_4bit.s"
    .else
        .error "LCD_DRIVER invalid (see config-example.s for options)"
    .endif

.segment "ZEROPAGE"

    byte: .res 1 ; Zero page byte, used as argument or return value

.segment "KERNAL"

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

    _write_cmnd = DRIVER::write_cmnd
        ; Write instruction to CMND register (no wait).
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

    _write = DRIVER::write
        ; Write byte to DATA register (no wait).
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

    .proc write_cmnd
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
        jsr _write_cmnd
        pla
        rts
    .endproc

    .proc write
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
        jsr _write
        pla
        rts
    .endproc

.endscope

.endif

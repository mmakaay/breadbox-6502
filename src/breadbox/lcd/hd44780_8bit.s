; -----------------------------------------------------------------
; HD44780 LCD driver (8-bit data bus, 2 line display, 5x8 font)
;
; Drives the LCD using an 8-bit data bus connection, with all
; 8 data bus pins on one GPIO port and 3 control pins on another.
;
; Parameters and responses are passed via zero page: LCD::byte.
; All procedures preserve A, X, Y.
; -----------------------------------------------------------------

.ifndef KERNAL_LCD_HD44780_8BIT_S
KERNAL_LCD_HD44780_8BIT_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "KERNAL"

    ; -----------------------------------------------------------------
    ; Configuration (for example configuration, see config-example.inc)
    ; -----------------------------------------------------------------

    CMND_PORT    = ::LCD_CMND_PORT
    CMND_PIN_EN  = ::LCD_CMND_PIN_EN
    CMND_PIN_RWB = ::LCD_CMND_PIN_RWB
    CMND_PIN_RS  = ::LCD_CMND_PIN_RS

    DATA_PORT    = ::LCD_DATA_PORT
    DATA_PINS    = %11111111
    FUNCTION_SET = %00111000  ; 8-bit mode, 2 line display, 5x8 font

    ; -----------------------------------------------------------------
    ; Implementation
    ; -----------------------------------------------------------------

    .include "breadbox/lcd/hd44780_common.s"

    .proc init
        ; Initialize all pins connected to the LCD in output mode.
        ;
        ; Port A control pins will always be in output mode from here on.
        ; Port B data pins will toggle input/output mode, depending on use.
        ;
        ; Out:
        ;   A, X, Y preserved

        pha
        jsr _configure_gpio_pins
        jsr _power_up_in_8bit_mode
        jsr _configure_display
        jsr clr
        pla
        rts
    .endproc

    .proc write_cmnd
        ; Write instruction to CMND register.
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Put the full byte on the LCD data bus.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::value, byte
        jsr GPIO::write_port

        ; Set control pins: RWB=0 (write), RS=0 (CMND), EN=0.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        SET_BYTE GPIO::value, #0
        jsr GPIO::set_pins

        ; Pulse EN high then low to trigger data transfer.
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        pla
        rts
    .endproc

    .proc write
        ; Write byte to DATA register.
        ;
        ; In (zero page):
        ;   LCD::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Put the full byte on the LCD data bus.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::value, byte
        jsr GPIO::write_port

        ; Set control pins: RWB=0 (write), RS=1 (DATA), EN=0.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        SET_BYTE GPIO::value, #CMND_PIN_RS
        jsr GPIO::set_pins

        ; Pulse EN high then low to trigger data transfer.
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        pla
        rts
    .endproc

    .proc check_ready
        ; Poll the LCD to see if it is ready for input.
        ;
        ; Out:
        ;   LCD::byte = 0 if the LCD is ready for input
        ;   LCD::byte != 0 if the LCD is busy
        ;   A, X, Y preserved

        pha

        ; Configure data port for input, so we can read the status.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        jsr GPIO::set_inputs

        ; Set control pins: RWB=1 (read), RS=0 (CMND), EN=0.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        SET_BYTE GPIO::value, #CMND_PIN_RWB
        jsr GPIO::set_pins

        ; EN to high, to make status available on DATA port.
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_on

        ; Select and read the DATA port.
        SET_BYTE GPIO::port, #DATA_PORT
        jsr GPIO::read_port

        ; Extract and store the busy flag.
        lda GPIO::value              
        and #BUSY_FLAG
        sta byte

        ; EN to low, to stop the read operation on the DATA port.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_off

        ; Restore data port for output.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        pla
        rts
    .endproc

.endscope

.endif


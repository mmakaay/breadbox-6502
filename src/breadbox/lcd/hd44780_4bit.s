; -----------------------------------------------------------------
; HD44780 LCD driver (4-bit data bus, 2 line display, 5x8 font)
;
; Drives the LCD using a 4-bit data bus connection, with possibly
; all pins connected to a single GPIO port.
;
; Parameters and responses are passed via zero page: LCD::byte.
; All procedures preserve A, X, Y.
; -----------------------------------------------------------------

.ifndef KERNAL_LCD_HD44780_4BIT_S
KERNAL_LCD_HD44780_4BIT_S = 1

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
    DATA_PINS    = %11110000
    FUNCTION_SET = %00101000  ; 4-bit mode, 2 line display, 5x8 font

    ; -----------------------------------------------------------------
    ; Implementation
    ; -----------------------------------------------------------------

    .include "breadbox/lcd/hd44780_common.s"

    .proc init
        ; Initialize the LCD in 4-bit mode.
        ;
        ; The LCD powers up in 8-bit mode. A specific nibble sequence
        ; is required to reliably switch to 4-bit mode, regardless of
        ; the LCD's current state.
        ;
        ; Out:
        ;   A, X, Y preserved

        PUSH_AXY
        jsr _configure_gpio_pins
        jsr _power_up_in_8bit_mode
        jsr _enable_4bit_mode
        jsr _configure_display
        jsr clr
        PULL_AXY
        rts
    .endproc

    .proc write_cmnd
        ; Write instruction to CMND register (as two nibbles).
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Select CMND register in write mode: RWB=0 (write), RS=0 (CMND), EN=0.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        SET_BYTE GPIO::value, #0
        jsr GPIO::set_pins

        ; Send byte as two nibbles.
        jsr _write_byte_as_two_nibbles

        pla
        rts
    .endproc

    .proc write
        ; Write byte to DATA register (as two nibbles).
        ;
        ; In (zero page):
        ;   LCD::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Select DATA register in write mode: RWB=0 (write), RS=1 (DATA), EN=0.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        SET_BYTE GPIO::value, #CMND_PIN_RS
        jsr GPIO::set_pins

        ; Send byte as two nibbles.
        jsr _write_byte_as_two_nibbles

        pla
        rts
    .endproc

    .proc check_ready
        ; Poll the LCD to see if it is ready for input.
        ; Reads the busy flag from the high nibble (D7 = PB7).
        ; The low nibble is clocked out but ignored.
        ;
        ; Out:
        ;   LCD::byte = 0 if the LCD is ready for input
        ;   LCD::byte != 0 if the LCD is busy
        ;   A, X, Y preserved

        pha

        ; Configure data pins for input.
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

        ; Low nibble: clock it out (data ignored).
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        ; Restore data pins for output.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        pla
        rts
    .endproc

    ; -----------------------------------------------------------------
    ; Private code
    ; -----------------------------------------------------------------

    .proc _write_byte_as_two_nibbles
        ; Write LCD::byte as two nibbles to the 4-bit data bus.
        ;
        ; Control pins to select the register to use (RS = DATA/CMND) and
        ; to put it in write mode (RWB = 0) must already be set by the caller.
        ;
        ; In (zero page):
        ;   LCD::byte = byte to send

        ; High nibble: upper 4 bits of byte, already in position.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        lda byte
        and #$f0 ; Not strictly required, because of pin masking.
        sta GPIO::value
        jsr GPIO::set_pins

        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        ; Low nibble: lower 4 bits of byte, shifted to upper position.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        lda byte
        asl
        asl
        asl
        asl
        sta GPIO::value
        jsr GPIO::set_pins

        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        rts
    .endproc

.endscope

.endif

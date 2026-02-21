; -----------------------------------------------------------------
; HD44780 LCD common definitions
;
; Shared between 8-bit and 4-bit HD44780 drivers.
; -----------------------------------------------------------------

.ifndef KERNAL_LCD_HD44780_COMMON_S
KERNAL_LCD_HD44780_COMMON_S = 1

.include "breadbox/kernal.s"

.segment "KERNAL"

    ; Build pin mask that can be used for GPIO calls, based on the
    ; pin configuration as provided by the main driver code.
    CMND_PINS = (CMND_PIN_EN | CMND_PIN_RWB | CMND_PIN_RS)

    ; From the datasheet:
    ; When the busy flag is 1, the device is in the internal operation
    ; mode, and the next instruction will not be accepted. When reading
    ; from the DATA register, the busy flag is output to DB7. The next
    ; instruction must be written after ensuring that the busy flag is 0.
    BUSY_FLAG = %10000000

    .proc clr
        ; Clear the LCD screen (waits for ready).
        ;
        ; Out:
        ;   A, X, Y preserved

        pha
        SET_BYTE byte, #%00000001   ; Clear screen, set address to 0
        jsr write_cmnd
        pla
        rts
    .endproc

    .proc home
        ; Move LCD output position to home (waits for ready).
        ;
        ; Out:
        ;   A, X, Y preserved

        pha
        SET_BYTE byte, #%00000010   ; Move cursor to home position
        jsr write_cmnd
        pla
        rts
    .endproc

    ; -----------------------------------------------------------------
    ; Private code
    ; -----------------------------------------------------------------

    .proc _configure_gpio_pins
        ; Configure and initialize GPIO pins.

        ; Set data pins to output.
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        ; Set command pins to output.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        jsr GPIO::set_outputs

        ; Clear LCD control bits (EN, RW, RS), preserving non-LCD pins.
        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PINS
        SET_BYTE GPIO::value, #0
        jsr GPIO::set_pins
        
        rts
    .endproc

    .proc _power_up_in_8bit_mode
        ; Execute the power up procedure as described in the data sheet.

        ; Wait >15ms after Vcc rises.
        DELAY_MS 20

        ; The LCD might be in an unknown state. Sending the "Function set"
        ; command for 8-bit operation three times guarantees a known state,
        ; after which we can reliably switch to 4-bit mode.
        SET_BYTE byte, #%00110000 ; Set 8-bit operation
        jsr _write_init_byte      ; 1st attempt
        DELAY_MS 5                ; Wait >4.1ms
        jsr _write_init_byte      ; 2nd attempt
        DELAY_US 150              ; Wait >100us
        jsr _write_init_byte      ; 3rd attempt
        DELAY_US 150              ; Not in datasheet, but let's delay here too
        
        rts
    .endproc

    .proc _enable_4bit_mode
        ; Enable 4-bit mode, to be used after powering up in 8-bit mode.

        SET_BYTE byte, #%00100000
        jsr _write_init_byte
        rts
    .endproc

    .proc _configure_display
        SET_BYTE byte, #FUNCTION_SET
        jsr write_cmnd
        SET_BYTE byte, #%00001110 ; Turn display on, cursor on, blink off
        jsr write_cmnd
        SET_BYTE byte, #%00000110 ; Shift cursor on data, no display shift
        jsr write_cmnd

        rts
    .endproc    

    .proc _write_init_byte
        SET_BYTE GPIO::port, #DATA_PORT
        SET_BYTE GPIO::mask, #DATA_PINS
        SET_BYTE GPIO::value, byte
        jsr GPIO::set_pins

        SET_BYTE GPIO::port, #CMND_PORT
        SET_BYTE GPIO::mask, #CMND_PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        rts
    .endproc

.endif

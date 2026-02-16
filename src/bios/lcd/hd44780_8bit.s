; -----------------------------------------------------------------
; HD44780 LCD driver (8-bit data bus, 2 line display, 5x8 font)
;
; Drives the LCD using an 8-bit data bus connection, with all
; 8 data bus pins on one port and 3 control pins on another.
;
; Pin configuration
; -----------------
; All pins are configurable via LCD_* constants defined before
; including bios.s. The default layout matches Ben Eater's
; breadboard tutorial:
;
;    HD44780 LCD                           GPIO
;    ┌─────────┐                          ┌─────────┐
;    │         │                          │         │
;    │         │                     n/c──┤ PA0-4   │
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
; Parameters are passed via zero page: LCD::byte.
; All procedures preserve A, X, Y.
;
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_8BIT_S
BIOS_LCD_HD44780_8BIT_S = 1

.include "bios/bios.s"

.scope DRIVER

.segment "BIOS"

    ; -----------------------------------------------------------------
    ; Pin configuration
    ;
    ; The default configuration matches the configuration as used by
    ; Ben Eater in his LCD display tutorial, making sure that no
    ; specific configuration is required to make things work.
    ; -----------------------------------------------------------------

    .ifndef LCD_CMND_PORT
        LCD_CMND_PORT = ::PORTA
    .endif
    .ifndef LCD_DATA_PORT
        LCD_DATA_PORT = ::PORTB
    .endif
    .ifndef LCD_PIN_RS
        LCD_PIN_RS = ::P5
    .endif
    .ifndef LCD_PIN_RWB
        LCD_PIN_RWB = ::P6
    .endif
    .ifndef LCD_PIN_EN
        LCD_PIN_EN = ::P7
    .endif

    CMND_PORT = LCD_CMND_PORT
    DATA_PORT = LCD_DATA_PORT
    DATA_PINS = %11111111

    .include "bios/lcd/hd44780_common.s"

    .proc init
        ; Initialize all pins connected to the LCD in output mode.
        ;
        ; Port A control pins will always be in output mode from here on.
        ; Port B data pins will toggle input/output mode, depending on use.
        ;
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Set data pins to output.
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        ; Set command pins to output.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        jsr GPIO::set_outputs
        
        ; Clear LCD control bits (EN, RW, RS), preserving non-LCD pins.
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #0
        jsr GPIO::set_pins

        ; Configure an initial display mode.
        set_byte byte, #%00111000         ; Set 8-bit mode, 2 line display, 5x8 font
        jsr write_instruction_when_ready
        set_byte byte, #%00001110         ; Turn display on, cursor on, blink off
        jsr write_instruction_when_ready
        set_byte byte, #%00000110         ; Shift cursor on data, no display shift
        jsr write_instruction_when_ready

        ; Clear the screen.
        jsr clr

        pla
        rts
    .endproc

    .proc write_instruction
        ; Write instruction to CMND register.
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Put the full byte on the LCD data bus.
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::value, byte
        jsr GPIO::write_port

        ; Set control pins: RWB=0 (write), RS=0 (CMND), EN=0.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #0
        jsr GPIO::set_pins

        ; Pulse EN high then low to trigger data transfer.
        set_byte GPIO::mask, #PIN_EN
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
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::value, byte
        jsr GPIO::write_port

        ; Set control pins: RWB=0 (write), RS=1 (DATA), EN=0.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #PIN_RS
        jsr GPIO::set_pins

        ; Pulse EN high then low to trigger data transfer.
        set_byte GPIO::mask, #PIN_EN
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
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        jsr GPIO::set_inputs

        ; Set control pins: RWB=1 (read), RS=0 (CMND), EN=0.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #PIN_RWB
        jsr GPIO::set_pins

        ; Pulse EN high, read data port, then EN low.
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_on

        set_byte GPIO::port, #DATA_PORT
        jsr GPIO::read_port        ; GPIO::value = status byte from the LCD

        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_off

        ; Restore data port for output.
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        ; Strip all bits except the busy bit and store in LCD::byte.
        lda GPIO::value
        and #BUSY_FLAG
        sta byte

        pla
        rts
    .endproc

.endscope

.endif


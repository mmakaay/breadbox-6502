; -----------------------------------------------------------------
; HD44780 LCD driver (4-bit data bus, 2 line display, 5x8 font)
;
; Drives the LCD using a 4-bit data bus connection. Each byte is
; transferred as two nibbles (high nibble first). Data writes use
; pin masking to preserve non-LCD pins on shared ports.
;
; Pin configuration
; -----------------
; All pins are configurable via LCD_* constants defined before
; including bios.s. Command and data pins can be on the same or
; different ports. The default layout uses a single port (port B),
; leaving PB3 free for other hardware:
;
;    HD44780 LCD                           GPIO
;    ┌─────────┐                          ┌─────────┐
;    │         │                          │         │
;    │  RS     │◄─────────────────────────┤ PB0     │ (PIN_RS)
;    │  RWB    │◄─────────────────────────┤ PB1     │ (PIN_RWB)
;    │  E      │◄─────────────────────────┤ PB2     │ (PIN_EN)
;    │         │                     free─┤ PB3     │
;    │  D4     │◄────────────────────────►│ PB4     │
;    │  D5     │◄────────────────────────►│ PB5     │
;    │  D6     │◄────────────────────────►│ PB6     │
;    │  D7     │◄────────────────────────►│ PB7     │
;    │         │                          │         │
;    │  D0-D3  │         n/c              │  PA*    │ (free)
;    │         │                          │         │
;    └─────────┘                          └─────────┘
;
; Parameters are passed via zero page: LCD::byte.
; All procedures preserve A, X, Y.
;
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_4BIT_S
BIOS_LCD_HD44780_4BIT_S = 1

.include "bios/bios.s"

.scope DRIVER

.segment "BIOS"

    ; -----------------------------------------------------------------
    ; Configuration
    ;
    ; The default configuration when using the 4 bit driver, matches
    ; the configuration as used by Ben Eater in his LCD display
    ; tutorial, making sure that no specific configuration is required
    ; to make things work.
    ;
    ; The pin configuration can be overridden from `config.s`, for
    ; example to only use pins on VIA port B, and keeping port A
    ; completely free for other uses. See the `config.s.example` for
    ; more information on this.
    ; -----------------------------------------------------------------

    .ifndef LCD_CMND_PORT
        LCD_CMND_PORT = ::PORTB
    .endif
    .ifndef LCD_DATA_PORT
        LCD_DATA_PORT = ::PORTB
    .endif
    .ifndef LCD_PIN_RS
        LCD_PIN_RS = ::P0
    .endif
    .ifndef LCD_PIN_RWB
        LCD_PIN_RWB = ::P1
    .endif
    .ifndef LCD_PIN_EN
        LCD_PIN_EN = ::P2
    .endif

    CMND_PORT = LCD_CMND_PORT
    DATA_PORT = LCD_DATA_PORT
    DATA_PINS = %11110000

    ; -----------------------------------------------------------------
    ; Implementation
    ; -----------------------------------------------------------------

    .include "bios/lcd/hd44780_common.s"

    .proc init
        ; Initialize the LCD in 4-bit mode.
        ;
        ; The LCD powers up in 8-bit mode. A specific nibble sequence
        ; is required to reliably switch to 4-bit mode, regardless of
        ; the LCD's current state.
        ;
        ; Out:
        ;   A, X, Y preserved

        pha
        txa
        pha
        tya
        pha

        ; Set command pins to output.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        jsr GPIO::set_outputs

        ; Set data pins (upper nibble) to output.
        ; Non-data pins on this port are not touched.
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        ; Clear LCD control bits (EN, RW, RS), preserving non-LCD pins.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #0
        jsr GPIO::set_pins

        ; --- Special 4-bit initialization sequence ---
        ;
        ; The LCD might be in an unknown state (8-bit mode, or halfway
        ; through a 4-bit transfer). Sending the 8-bit function set
        ; command ($30) three times guarantees a known state, after
        ; which we can reliably switch to 4-bit mode.

        ; Wait >15ms after power on.
        jsr _delay
        jsr _delay
        jsr _delay

        ; Function set (8-bit): high nibble 0011 = $30.
        set_byte byte, #$30
        jsr _send_init_nibble         ; 1st attempt
        jsr _delay                   ; Wait >4.1ms
        jsr _send_init_nibble         ; 2nd attempt
        jsr _delay                   ; Wait >100us (delay is generous)
        jsr _send_init_nibble         ; 3rd attempt
        jsr _delay

        ; Switch to 4-bit mode: high nibble 0010 = $20.
        set_byte byte, #$20
        jsr _send_init_nibble

        ; --- Now in 4-bit mode. Commands sent as two nibbles. ---

        set_byte byte, #%00101000   ; 4-bit mode, 2 line display, 5x8 font
        jsr write_cmnd_when_ready
        set_byte byte, #%00001110   ; Turn display on, cursor on, blink off
        jsr write_cmnd_when_ready
        set_byte byte, #%00000110   ; Shift cursor on data, no display shift
        jsr write_cmnd_when_ready

        ; Clear the screen.
        jsr clr

        pla
        tay
        pla
        tax
        pla
        rts
    .endproc

    .proc write_cmnd
        ; Write instruction to CMND register (two nibbles).
        ;
        ; In (zero page):
        ;   LCD::byte = instruction byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Set control pins: RWB=0 (write), RS=0 (CMND), EN=0.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #0
        jsr GPIO::set_pins

        ; Send byte as two nibbles.
        jsr _send_byte

        pla
        rts
    .endproc

    .proc write
        ; Write byte to DATA register (two nibbles).
        ;
        ; In (zero page):
        ;   LCD::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

        pha

        ; Set control pins: RWB=0 (write), RS=1 (DATA), EN=0.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #PIN_RS
        jsr GPIO::set_pins

        ; Send byte as two nibbles.
        jsr _send_byte

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

        ; Configure data pins for input (preserves non-data pins).
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        jsr GPIO::set_inputs

        ; Set control pins: RWB=1 (read), RS=0 (CMND), EN=0.
        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #CMND_PINS
        set_byte GPIO::value, #PIN_RWB
        jsr GPIO::set_pins

        ; High nibble: pulse EN high, read data port (D7=busy flag), EN low.
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_on

        set_byte GPIO::port, #DATA_PORT
        jsr GPIO::read_port          ; GPIO::value = data port byte
        lda GPIO::value              ; Save high nibble (has busy flag)
        pha

        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_off

        ; Low nibble: clock it out (data ignored).
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        ; Restore data pins for output (preserves non-data pins).
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        jsr GPIO::set_outputs

        ; Extract busy flag from the saved high nibble.
        pla
        and #BUSY_FLAG
        sta byte

        pla
        rts
    .endproc

    ; -----------------------------------------------------------------
    ; Internal helpers (not part of the driver API)
    ; -----------------------------------------------------------------

    .proc _send_byte
        ; Send LCD::byte as two nibbles over the 4-bit data bus.
        ; Control pins (RS, RWB) must already be set by the caller.
        ;
        ; In (zero page):
        ;   LCD::byte = byte to send

        ; High nibble: upper 4 bits of byte, already in position.
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        lda byte
        and #$f0
        sta GPIO::value
        jsr GPIO::set_pins

        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        ; Low nibble: lower 4 bits of byte, shifted to upper position.
        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        lda byte
        asl
        asl
        asl
        asl
        sta GPIO::value
        jsr GPIO::set_pins

        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        rts
    .endproc

    .proc _send_init_nibble
        ; Send a single nibble during the initialization sequence
        ; (before 4-bit mode is active). The nibble value is read from
        ; LCD::byte, already positioned for PB4-PB7.
        ; RS and RWB must already be set by the caller.

        set_byte GPIO::port, #DATA_PORT
        set_byte GPIO::mask, #DATA_PINS
        set_byte GPIO::value, byte
        jsr GPIO::set_pins

        set_byte GPIO::port, #CMND_PORT
        set_byte GPIO::mask, #PIN_EN
        jsr GPIO::turn_on
        jsr GPIO::turn_off

        rts
    .endproc

    .proc _delay
        ; Delay approximately 5ms at 1MHz.
        ; Used during the initialization sequence where busy flag
        ; polling is not yet available.
        ;
        ; Out:
        ;   A preserved
        ;   X, Y clobbered (caller must save if needed)

        ldx #5
    @outer:
        ldy #250
    @inner:
        dey                          ; 2 cycles
        bne @inner                   ; 3 cycles (taken)
        dex                          ; 2 cycles
        bne @outer                   ; 3 cycles (taken)
        rts
    .endproc

.endscope

.endif

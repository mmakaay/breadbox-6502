; ----------------------------------------------------------------------------
; UART test 
;
; This will:
; - show UART status information bits on line 2 of the LCD
; - print characters that are received over the serial connection to
;   line 1 of the LCD, and echo then back over the serial connection
;
; This can be used to check if the serial communication is working correctly.
; ----------------------------------------------------------------------------

.include "bios/bios.s"

.segment "DATA"

    hello: .asciiz "Serial test"

.segment "ZEROPAGE"

    cursor: .res 1  ; Current position on LCD line 1 (0-15)

.segment "CODE"

    .proc main
        jsr display_welcome_message
        lda #16  ; Cursor to end of line, so first byte read clears LCD line 1
        sta cursor

    @loop:
        ; Show UART status register.
        jsr show_status

        ; Loop, until we see a byte in the receive buffer.
        jsr UART::check_rx
        beq @loop

        ; Wrap if cursor is at end of LCD line 1.
        lda cursor
        cmp #16
        bne @read
        jsr clear_line1

    @read:
        ; Read the incoming byte.
        jsr UART::read

        ; Display received byte on LCD line 1.
        jsr set_cursor_line1
        jsr LCD::write_when_ready
        inc cursor

        ; Echo byte back via UART transmitter.
        jsr UART::write_when_ready

        jmp @loop
    .endproc

    ; Show the UART status register bits on LCD line 2.
    .proc show_status
        ; Position cursor at start of LCD line 2.
        lda #$c0 ; Set DDRAM address = $40 (line 2)
        jsr LCD::write_instruction_when_ready

        ; Display "S:" prefix.
        lda #'S'
        jsr LCD::write_when_ready
        lda #':'
        jsr LCD::write_when_ready

        ; Display 8 status bits, MSB first.
        ; Bit meaning: IRQ DSR DCD TXE RXF OVR FRM PAR
        jsr UART::load_status
        ldx #8
    @loop:
        ; Rotate MSB into carry, keeping all bits for next iteration.
        rol
        pha
        lda #'0'
        adc #0              ; '0' + carry = '0' or '1'
        jsr LCD::write_when_ready
        pla
        dex
        bne @loop

        rts
    .endproc

    ; Move LCD cursor to current position on line 1.
    .proc set_cursor_line1
        pha
        lda cursor          ; DDRAM address = $00 + cursor position
        ora #%10000000      ; Set DDRAM address command (bit 7)
        jsr LCD::write_instruction_when_ready
        pla
        rts
    .endproc

    ; Clear LCD line: write spaces and set cursor to start of line.
    .proc clear_line1
        pha
        jsr LCD::home
        ldx #16
    @loop:
        lda #' '
        jsr LCD::write_when_ready
        dex
        bne @loop
        clr_byte cursor
        pla
        rts
    .endproc

    ; Print the welcome message on the LCD.
    .proc display_welcome_message
        ldx #0
    @loop:
        lda hello,x
        beq @done
        jsr LCD::write_when_ready
        inx
        jmp @loop
    @done:
        rts
    .endproc


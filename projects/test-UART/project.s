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

; Uncomment to disable LCD debug output support.
;ENABLE_LCD = 1

.include "breadbox/kernal.s"

.ifdef ENABLE_LCD
.segment "ZEROPAGE"

    cursor: .res 1
.endif

.segment "CODE"

.ifdef ENABLE_LCD
    hello: .asciiz "Serial test"
.endif

    .proc main
.ifdef ENABLE_LCD
        jsr display_welcome_message
        lda #16  ; Cursor to end of line, so first byte read clears LCD line 1
        sta cursor
.endif

    @loop:
.ifdef ENABLE_LCD
        ; Show UART status register.
        jsr show_status
.endif

        ; Loop, until we read a byte from the receive buffer.
        jsr UART::read
        bcc @loop

.ifdef ENABLE_LCD
        ; Wrap if cursor is at end of LCD line 1.
        lda cursor
        cmp #16
        bne @read
        jsr clear_line1
.endif

    @read:
.ifdef ENABLE_LCD
        ; Position cursor, then display received byte on LCD line 1.
        jsr set_cursor_line1
.endif
        lda UART::byte

.ifdef ENABLE_LCD
        sta LCD::byte
        jsr LCD::write
        inc cursor
.endif

        ; Echo byte back via UART transmitter.
        jsr UART::write_terminal

        jmp @loop
    .endproc

.ifdef ENABLE_LCD

    ; Show the UART status register bits on LCD line 2.
    .proc show_status
        ; Position cursor at start of LCD line 2.
        lda #$c0             ; Set DDRAM address = $40 (line 2)
        sta LCD::byte
        jsr LCD::write_cmnd

        ; Display "S:" prefix.
        lda #'S'
        sta LCD::byte
        jsr LCD::write
        lda #':'
        sta LCD::byte
        jsr LCD::write

        ; Display 8 status bits, MSB first.
        ; Bit meaning: IRQ DSR DCD TXE RXF OVR FRM PAR
        jsr UART::load_status
        lda UART::byte
        ldx #8
    @loop:
        ; Rotate MSB into carry, keeping all bits for next iteration.
        rol
        pha
        lda #'0'
        adc #0              ; '0' + carry = '0' or '1'
        sta LCD::byte
        jsr LCD::write
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
        sta LCD::byte
        jsr LCD::write_cmnd
        pla
        rts
    .endproc

    ; Clear LCD line: write spaces and set cursor to start of line.
    .proc clear_line1
        pha
        jsr LCD::home
        lda #' '
        sta LCD::byte
        ldx #16
    @loop:
        jsr LCD::write
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
        sta LCD::byte
        jsr LCD::write
        inx
        jmp @loop
    @done:
        rts
    .endproc

.endif




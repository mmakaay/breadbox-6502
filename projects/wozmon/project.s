INCLUDE_WOZMON = YES

.include "breadbox/kernal.s"

.import __WOZMON_START__

lcd_text:     .asciiz "Running WozMon"
console_text: .byte   $0d, $0d, "Welcome to WozMon", $0d, $00

main:

; This code will also work, when LCD support is excluded.
.ifdef HAS_LCD
    ldx #0
@send_lcd_text:
    lda lcd_text,x
    beq @done
    sta LCD::byte
    jsr LCD::write
    inx
    jmp @send_lcd_text
@done:
.endif

    ldx #0
@send_console_text:
    lda console_text,x
    beq @start
    sta UART::byte
    jsr UART::write_text
    inx
    jmp @send_console_text

@start:
    jmp __WOZMON_START__


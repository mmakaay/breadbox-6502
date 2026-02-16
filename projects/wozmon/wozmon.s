; This can also go in config.s, to let the BIOS always include wozmon.
INCLUDE_WOZMON = 1

.include "bios/bios.s"

.import __WOZMON_START__

lcd_text:     .asciiz "Running WozMon"
console_text: .asciiz "Welcome to WozMon"

main:
    ldx #0
@send_lcd_text:
    lda lcd_text,x
    beq @done
    sta LCD::byte
    jsr LCD::write_when_ready
    inx
    jmp @send_lcd_text
@done:

    ldx #0
@send_console_text:
    lda console_text,x
    beq @done2
    sta UART::byte
    jsr UART::write_when_ready
    inx
    jmp @send_console_text
@done2:
    jsr UART::write_crnl_when_ready

    jmp __WOZMON_START__


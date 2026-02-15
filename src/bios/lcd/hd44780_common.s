; -----------------------------------------------------------------
; HD44780 LCD (8 bit data bus, 2 line display, 5x8 font)
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_COMMON_S
BIOS_LCD_HD44780_COMMON_S = 1

.include "bios/bios.s"

.segment "BIOS"

; From the datasheet:
; When the busy flag is 1, the device is in the internal operation
; mode, and the next instruction will not be accepted. When reading
; from the DATA register, the busy flag is output to DB7. The next
; instruction must be written after ensuring that the busy flag is 0.
BUSY_FLAG = %10000000

.proc clr
    lda #%00000001   ; Clear screen, set address to 0
    jsr write_instruction_when_ready
    rts
.endproc

.proc home
    lda #%00000010   ; Move cursor to home position
    jsr write_instruction_when_ready
    rts
.endproc

.endif

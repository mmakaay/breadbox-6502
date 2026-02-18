; -----------------------------------------------------------------
; HD44780 LCD common definitions
;
; Shared between 8-bit and 4-bit HD44780 drivers.
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_COMMON_S
BIOS_LCD_HD44780_COMMON_S = 1

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

    .proc wait_till_ready
        ; Wait for the LCD screen to be ready for the next input.
        ;
        ; Out:
        ;   A, X, Y preserved

        pha
    @loop:
        jsr check_ready
        lda byte
        bne @loop
        pla
        rts
    .endproc

    .proc clr
        ; Clear the LCD screen (waits for ready).
        ;
        ; Out:
        ;   A, X, Y preserved

        pha
        set_byte byte, #%00000001   ; Clear screen, set address to 0
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
        set_byte byte, #%00000010   ; Move cursor to home position
        jsr write_cmnd
        pla
        rts
    .endproc

.endif

; -----------------------------------------------------------------
; HD44780 LCD common definitions
;
; Shared between 8-bit and 4-bit HD44780 drivers.
; Provides the zero page parameter, control pin constants,
; the busy flag constant, and common procedures.
;
; The including driver must define LCD_PIN_EN, LCD_PIN_RWB,
; LCD_PIN_RS (with .ifndef-guarded defaults) before including
; this file.
;
; -----------------------------------------------------------------

.ifndef BIOS_LCD_HD44780_COMMON_S
BIOS_LCD_HD44780_COMMON_S = 1

.include "bios/bios.s"

.segment "BIOS"

    ; LCD control pin mapping (derived from LCD_* configuration).
    PIN_EN  = LCD_PIN_EN
    PIN_RWB = LCD_PIN_RWB
    PIN_RS  = LCD_PIN_RS
    CMND_PINS = (PIN_EN | PIN_RWB | PIN_RS)

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
        jsr write_instruction_when_ready
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
        jsr write_instruction_when_ready
        pla
        rts
    .endproc

.endif

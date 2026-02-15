; -----------------------------------------------------------------
; LCD display HAL
; -----------------------------------------------------------------

.ifndef BIOS_LCD_S
BIOS_LCD_S = 1

.include "bios/bios.s"

.scope LCD

.segment "BIOS"

    ; Import the hardware driver.
    .include "bios/lcd/hd44780_8bit.s"

    ; -------------------------------------------------------------
    ; Access to the low level driver API
    ; -------------------------------------------------------------

    init = DRIVER::init
        ; Initialize the LCD hardware.
        ;
        ; Out:
        ;   A = clobbered 

    check_ready = DRIVER::check_ready
        ; Poll the LCD to see if it is ready for input.
        ;
        ; Out:
        ;   A = 0 if the LCD is ready for input (Z = 1)
        ;   A != 0 if the LCD is busy (Z = 0)

    write_instruction = DRIVER::write_instruction
        ; Write instruction to CMND register.
        ;
        ; In:
        ;   A = instruction byte to write
        ; Out:
        ;   A = clobbered

    write = DRIVER::write
        ; Write byte to DATA register.
        ;
        ; In:
        ;   A = byte to write
        ; Out:
        ;   A = preserved

    clr = DRIVER::clr
        ; Clear the LCD screen (waits for ready).
        ;
        ; Out:
        ;   A = clobbered

    home = DRIVER::home
        ; Move LCD output position to home (waits for ready).
        ;
        ; Out:
        ;   A = clobbered

    ; -------------------------------------------------------------
    ; High level convenience wrappers.
    ; -------------------------------------------------------------

    .proc write_instruction_when_ready
        ; Wait for LCD to become ready, then write instruction to CMND register.
        ;
        ; In:
        ;   A = instruction byte to write
        ; Out:
        ;   A = clobbered

        pha
    @wait:
        jsr check_ready
        bne @wait
        pla
        jsr write_instruction
        rts
    .endproc

    .proc write_when_ready
        ; Wait for LCD to become ready, then write byte to DATA register.
        ;
        ; In:
        ;   A = byte to write
        ; Out:
        ;   A = preserved

        pha
    @wait:
        jsr check_ready
        bne @wait
        pla
        jsr write
        rts
    .endproc

.endif

.endscope

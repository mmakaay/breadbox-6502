; -----------------------------------------------------------------
; LCD display support
; -----------------------------------------------------------------

.ifndef BIOS_LCD_S
BIOS_LCD_S = 1

.include "bios/bios.s"

.scope LCD

.segment "BIOS"

    ; Import the hardware driver.
    .include "bios/lcd/hd44700_8bit.s"

    ; Initialize the LCD hardware.
    ;
    ; Out:
    ;   A = clobbered 
    ;
    ; Initialize all pins connected to the LCD for output.
    ; Port A (CMND register) will always be in output mode from there. 
    ; Port B (DATA register) will toggle input/output depending on use.
    ;
    init = DRIVER::init

    ; Clear the LCD screen.
    ;
    ; Out:
    ;   A = clobbered
    ;
    clr = DRIVER::clr

    ; Move LCD output position to home.
    ;
    ; Out:
    ;   A = clobbered
    ;
    home = DRIVER::home

    ; Wait for LCD to become ready, and write instruction to CMND register.
    ;
    ; In:
    ;   A = instruction byte to write
    ; Out:
    ;   A = clobbered
    ;
    write_instruction = DRIVER::write_instruction

    ; Write instruction to CMND register.
    ;
    ; In:
    ;   A = instruction byte to write
    ; Out:
    ;   A = clobbered
    ;
    write_instruction_nowait = DRIVER::write_instruction_nowait

    ; Wait for LCD to become ready, and write byte to DATA register.
    ;
    ; In:
    ;   A = byte to write
    ;
    write = DRIVER::write

    ; Write byte to DATA register.
    ;
    ; Out:
    ;   A = clobbered
    ;
    write_no_wait = DRIVER::write_no_wait

    ; Poll the LCD to see if it is ready for input.
    ;
    ; Out:
    ;   A = 0 if the LCD is ready for input
    ;   A != 0 if the LCD is busy
    ;
    check_ready = DRIVER::check_ready

    ; Wait for the LCD screen to be ready for the next input.
    ;
    wait_till_ready = DRIVER::wait_till_ready

.endif

.endscope

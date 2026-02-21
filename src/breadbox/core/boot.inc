; -----------------------------------------------------------------
; Boot sequence and KERNAL entry points
;
; Provides the boot subroutine (jumped to by reset vector) and the
; halt loop. The boot sequence initializes hardware in order and
; then jumps to `main`, which must be implemented by the
; application.
; -----------------------------------------------------------------

.ifndef KERNAL_BOOT_INC
KERNAL_BOOT_INC = 1

.include "breadbox/kernal.inc"

.scope KERNAL

.segment "KERNAL"

    boot:
        ldx #$ff  ; Initialize stack pointer
        txs

        jsr VECTORS::init
        .ifdef HAS_LCD
            jsr LCD::init
        .endif
        .ifdef HAS_UART
            jsr UART::init
        .endif

        jmp main  ; Note: `main` must be implemented by application

    ; Can be jumped to (jmp KERNAL::halt), to halt the computer.
    halt:
        jmp halt

.endscope

.macro HALT
    ; Halt program execution.

    jmp KERNAL::halt
.endmacro

.endif

; -----------------------------------------------------------------
; KERNAL for my Ben Eater-style breadboard computer
; -----------------------------------------------------------------

.ifndef KERNAL_S
KERNAL_S = 1

; I use a W65C02, but let's keep the code compatible for 6502. This
; is good for compatibility, but also for forced-upon compatibility
; in cases where a vendor ship an NMOS 6502 CPU, stamped as a W65C02.
; (debugging BRA being skipped instead of actually branching on an
; NMOS 6502 was not that much fun).
.setcpu "6502"

; Include general purpose macros, that make it easier to write some
; often used code fragments.
.include "macros/macros.s"

; Include global constants and the configuration file.
.include "breadbox/constants.s"
.include "config.inc"

; Include boot and interrupt vectors.
.include "breadbox/vectors.s"

; Utility APIs.
.include "breadbox/print.s"
.include "breadbox/delay.s"

; Hardware Abstraction Layer (HAL) and hardware drivers.
.include "breadbox/io/w65c22.s"
.include "breadbox/gpio.s"
.ifdef INCLUDE_LCD
    .if INCLUDE_LCD
        HAS_LCD = YES
        .include "breadbox/lcd.s"
    .endif
.endif
.ifdef INCLUDE_UART
    .if INCLUDE_UART
        .include "breadbox/uart.s"
        HAS_UART = YES
    .endif
.endif

; WozMon.
.ifdef INCLUDE_WOZMON
    .if INCLUDE_WOZMON
        .ifndef HAS_UART
            .error "WoZMon cannot be enabled without UART support"
        .endif
        .include "breadbox/wozmon.s"
    .endif
.endif

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

; Prevent build warnings when a segment is not used in a project.
.segment "STACK"
.segment "RAM"
.segment "WOZMON"

; Make sure that code without segment after including this uses CODE.
.segment "CODE"

.macro HALT
    ; Halt program execution.

    jmp KERNAL::halt
.endmacro

.endif
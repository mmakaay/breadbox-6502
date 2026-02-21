; -----------------------------------------------------------------
; KERNAL for my Ben Eater-style breadboard computer
;
; This is the main include file. It pulls in all KERNAL components
; in the correct order. Projects include this single file to get
; the full KERNAL.
; -----------------------------------------------------------------

.ifndef KERNAL_INC
KERNAL_INC = 1

; I use a W65C02, but let's keep the code compatible for 6502. This
; is good for compatibility, but also for forced-upon compatibility
; in cases where a vendor ship an NMOS 6502 CPU, stamped as a W65C02.
; (debugging BRA being skipped instead of actually branching on an
; NMOS 6502 was not that much fun).
.setcpu "6502"

; Include general purpose macros, that make it easier to write some
; often used code fragments.
.include "breadbox/macros/clr_byte.inc"
.include "breadbox/macros/clr_word.inc"
.include "breadbox/macros/dec_word.inc"
.include "breadbox/macros/cp_address.inc"
.include "breadbox/macros/cp_word.inc"
.include "breadbox/macros/inc_word.inc"
.include "breadbox/macros/pull_axy.inc"
.include "breadbox/macros/push_axy.inc"
.include "breadbox/macros/set_byte.inc"
.include "breadbox/macros/set_word.inc"

; Include global constants and the configuration file.
.include "breadbox/core/constants.inc"
.include "config.inc"

; Core: interrupt vectors.
.include "breadbox/core/vectors.inc"

; Utilities.
.include "breadbox/util/print.inc"
.include "breadbox/util/delay.inc"

; Hardware Abstraction Layer (HAL) and hardware drivers.
.include "breadbox/io/w65c22.inc"
.include "breadbox/gpio.inc"
.ifdef INCLUDE_LCD
    .if INCLUDE_LCD
        HAS_LCD = YES
        .include "breadbox/lcd.inc"
    .endif
.endif
.ifdef INCLUDE_UART
    .if INCLUDE_UART
        .include "breadbox/uart.inc"
        HAS_UART = YES
    .endif
.endif

; WozMon.
.ifdef INCLUDE_WOZMON
    .if INCLUDE_WOZMON
        .ifndef HAS_UART
            .error "WoZMon cannot be enabled without UART support"
        .endif
        .include "breadbox/wozmon.inc"
    .endif
.endif

; Boot sequence (must come after HAL includes, so HAS_LCD / HAS_UART
; are defined when the boot code's .ifdef guards are evaluated).
.include "breadbox/core/boot.inc"

; Prevent build warnings when a segment is not used in a project.
.segment "STACK"
.segment "RAM"
.segment "WOZMON"

; Make sure that code without segment after including this uses CODE.
.segment "CODE"

.endif
; -----------------------------------------------------------------
; Delay API
;
; Provides timed delays based on the configured CPU clock speed.
;
; High-level macros (compile-time):
;   DELAY_US <microseconds>   - delay for a known number of us
;   DELAY_MS <milliseconds>   - delay for a known number of ms
;
; Low-level subroutine (runtime):
;   DELAY::wait               - delay for DELAY::iterations * 5 cycles
;
; The implementation uses a nested X/Y register loop. Each iteration
; of the inner loop takes 5 CPU cycles (dey:2 + bne:3), giving a
; total delay of approximately iterations * 5 cycles.
;
; All procedures preserve A, X, Y. The DELAY macros clobber A.
; -----------------------------------------------------------------

.ifndef KERNAL_DELAY_INC
KERNAL_DELAY_INC = 1

.include "breadbox/kernal.inc"

.scope DELAY

.segment "ZEROPAGE"

    iterations: .res 2             ; 16-bit iteration count (lo/hi)

.segment "KERNAL"

    .proc wait
        ; Delay for approximately iterations * 5 CPU cycles.
        ;
        ; In (zero page):
        ;   DELAY::iterations = 16-bit iteration count (lo/hi)
        ; Out:
        ;   A, X, Y preserved

        PUSH_AXY

        ldy iterations             ; Low byte: partial first pass
        ldx iterations+1           ; High byte: number of full 256 passes
        inx                        ; Always run at least the low-byte pass
    @loop:
        dey
        bne @loop
        dex
        bne @loop

        PULL_AXY
        rts
    .endproc

.endscope

.macro DELAY_US us
    ; Compile-time microsecond delay.
    ;
    ; Converts a compile-time constant (microseconds) into the matching
    ; iteration count for the current CPU_CLOCK, then calls DELAY::wait.
    ;
    ; In:
    ;   us = delay duration in microseconds (compile-time constant)
    ; Out:
    ;   A = clobbered (by SET_WORD)
    ;   X, Y preserved

    .local ITERATIONS
    ITERATIONS = (us * (::CPU_CLOCK / 1000000)) / 5
    SET_WORD DELAY::iterations, #<ITERATIONS, #>ITERATIONS
    jsr DELAY::wait
.endmacro

.macro DELAY_MS ms
    ; Compile-time millisecond delay.
    ;
    ; Converts a compile-time constant (milliseconds) into the matching
    ; iteration count for the current CPU_CLOCK, then calls DELAY::wait.
    ;
    ; In:
    ;   ms = delay duration in milliseconds (compile-time constant)
    ; Out:
    ;   A = clobbered (by SET_WORD)
    ;   X, Y preserved

    DELAY_US ms * 1000
.endmacro

.endif

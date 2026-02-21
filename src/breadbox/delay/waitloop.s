; -------------------------------------------------------------------------
; CPU wait loop delay
;
; Software delay using a nested X/Y register loop. Each iteration of
; the inner loop takes 5 CPU cycles (dey:2 + bne:3), giving a total
; delay of approximately iterations * 5 cycles.
;
; The 16-bit iteration count is split across X (high byte) and Y (low
; byte). The low byte runs first, then each outer pass runs a full
; 256-iteration inner loop. This gives a linear relationship between
; the iteration count and the delay duration.
; -------------------------------------------------------------------------

.ifndef KERNAL_DELAY_WAITLOOP_S
KERNAL_DELAY_WAITLOOP_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "KERNAL"

    iterations = DELAY::iterations

    .proc wait
        PUSH_AXY

        ldy iterations         ; Low byte: partial first pass
        ldx iterations+1       ; High byte: number of full 256 passes
        inx                    ; Always run at least the low-byte pass
    @loop:
        dey
        bne @loop
        dex
        bne @loop

        PULL_AXY
        rts
    .endproc

.endscope

.endif

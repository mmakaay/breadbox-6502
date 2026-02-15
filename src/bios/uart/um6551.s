; -----------------------------------------------------------------
; UM6551 ACIA (Asynchronous Communications Interface Adapter)
; -----------------------------------------------------------------

.ifndef BIOS_UART_UM6551_S
BIOS_UART_UM6551_S = 1

.include "bios/bios.s"

.segment "BIOS"

.scope DRIVER

    .include "bios/uart/6551_common.s"

    .proc init
        jsr soft_reset

        ; Configure:
        ; - data = 8 bits, 1 stopbit
        ; - transmitter baud rate = 19200
        ; - receiver baud rate = using transmitter baud rate generator
        set_byte CTRL_REGISTER, #(LEN8 | STOP1 | B19200 | RCSGEN)

        ; Configure:
        ; - parity = none
        ; - echo = off
        ; - transmitter = on
        ; - receiver = on
        ; - interrupts = none
        set_byte CMD_REGISTER, #(PAROFF | ECHOOFF | TIC2 | DTRON | IRQOFF)

        rts
    .endproc

    .proc soft_reset
        ; Soft reset by writing to the status register.
        clr_byte STATUS_REGISTER

        ; Wait for soft reset to complete. The UART needs time to finish its
        ; internal reset before CTRL and CMD writes will take effect.
        ; This is a crude delay loop, but it works. Before using this, an
        ; attempt was done to base readiness on the TXEMPTY status bit, but
        ; that did not work.
        ldx #$ff
        ldy #$ff
    @wait:
        dey
        bne @wait
        dex
        bne @wait

        rts
    .endproc

    .proc load_status
        lda STATUS_REGISTER
        rts
    .endproc

    .proc check_rx
        lda STATUS_REGISTER
        and #RXFULL
        rts
    .endproc

    .proc check_tx
        lda STATUS_REGISTER
        and #TXEMPTY
        rts
    .endproc

    .proc read
        lda DATA_REGISTER
        rts
    .endproc

    .proc write
        sta DATA_REGISTER
        rts
    .endproc

.endscope

.endif


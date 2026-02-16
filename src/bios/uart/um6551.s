; -----------------------------------------------------------------
; UM6551 ACIA (Asynchronous Communications Interface Adapter)
; -----------------------------------------------------------------

.ifndef BIOS_UART_UM6551_S
BIOS_UART_UM6551_S = 1

.include "bios/bios.s"

.segment "BIOS"

.scope DRIVER

    .include "bios/uart/6551_common.s"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    .proc init
        pha
        txa
        pha
        tya
        pha

        jsr soft_reset

        ; Configure:
        ; - data = 8 bits, 1 stopbit
        ; - transmitter baud rate = according to configuration
        ; - receiver baud rate = using transmitter baud rate generator
        set_byte CTRL_REGISTER, #(LEN8 | STOP1 | USE_BAUD_RATE | RCSGEN)

        ; Configure:
        ; - parity = none
        ; - echo = off
        ; - transmitter = on
        ; - receiver = on
        ; - interrupts = none
        set_byte CMD_REGISTER, #(PAROFF | ECHOOFF | TIC2 | DTRON | IRQOFF)

        pla
        tay
        pla
        tax
        pla
        rts
    .endproc

    .proc soft_reset
        pha
        txa
        pha
        tya
        pha

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

        pla
        tay
        pla
        tax
        pla
        rts
    .endproc

    .proc load_status
        pha
        lda STATUS_REGISTER
        sta byte
        pla
        rts
    .endproc

    .proc check_rx
        pha
        lda STATUS_REGISTER
        and #RXFULL
        sta byte
        pla
        rts
    .endproc

    .proc check_tx
        pha
        lda STATUS_REGISTER
        and #TXEMPTY
        sta byte
        pla
        rts
    .endproc

    .proc read
        pha
        lda DATA_REGISTER
        sta byte
        pla
        rts
    .endproc

    .proc write
        pha
        lda byte
        sta DATA_REGISTER
        pla
        rts
    .endproc

.endscope

.endif


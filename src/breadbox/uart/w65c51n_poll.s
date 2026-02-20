; -------------------------------------------------------------------------
; W65C51N ACIA polling driver
;
; Simple polling driver for the WDC W65C51N ACIA. No interrupts, no
; buffers. Suitable for basic serial I/O (e.g. Ben Eater tutorial style).
;
; The W65C51N TXEMPTY status bit is permanently stuck high due to a
; hardware bug, so this driver uses a software delay after each
; transmitted byte to ensure the transmitter has finished.
;
; Wiring diagram
; --------------
;
;     W65C02 CPU                            W65C51N ACIA
;    ┌──────────┐                          ┌──────────┐
;    │          │                          │ GND      │──── GND
;    │  A12     │──── address decoding ───►│ CS0      │
;    │  A14-A15 │──── for chip select ────►│ CS1B     │
;    │          │                          │ RESB     │◄─── RESET
;    │          │                          │ RxC      │──── n/c
;    │          │                          │ XTAL1/2  │◄─── 1.8432 MHz
;    │          │                          │ RTSB     │──── n/c
;    │          │                          │ CTSB     │──── GND
;    │          │                          │ TxD      │◄─── RS232 TxD
;    │          │                          │ DTRB     │──── n/c
;    │          │                          │ RxD      │───► RS232 TxD
;    │  A0      │──── register select ────►│ RS0      │
;    │  A1      │──── register select ────►│ RS1      │
;    │          │                          │          │
;    │          │                          │ Vcc      │──── +5V
;    │          │                          │ DCDB     │──── GND
;    │          │                          │ DSRB     │──── GND
;    │  D0-D7   │◄────── data bus ─────────│ D0-D7    │
;    │  IRQB    │──── n/c          n/c ────│ IRQB     │
;    │  PHI2    │────── system clock ─────►│ PHI2     │
;    │  R/WB    │─────── read/write ──────►│ R/WB     │
;    └──────────┘                          └──────────┘
;
; Important points:
;  - DCDB (Data Carrier Detect) *must* be tied to ground to make RxD work.
;  - CTS (Clear To Send) *must* be tied to ground to make TxD work.
;  - DSRB (Data Set Ready) is unused, but should not be left floating.
;  - XTAL: passive 1.8432 MHz crystal on XTAL1/XTAL2, or active crystal
;    module on XTAL1 with XTAL2 floating.
; -------------------------------------------------------------------------

.ifndef KERNAL_UART_W65C51N_POLL_S
KERNAL_UART_W65C51N_POLL_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "KERNAL"

    .include "breadbox/uart/w65c51n_common.s"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    .proc init
        push_axy

        jsr _soft_reset

        ; Configure:
        ; - data = 8 bits, 1 stopbit
        ; - transmitter baud rate = according to configuration
        ; - receiver baud rate = using transmitter baud rate generator
        set_byte CTRL_REGISTER, #(LEN8 | STOP1 | USE_BAUD_RATE | RCSGEN)

        ; Configure:
        ; - parity = none
        ; - echo = off
        ; - transmitter = on (TIC2, no TX IRQs — they don't work anyway)
        ; - receiver = on
        ; - interrupts = none
        set_byte CMD_REGISTER, #(PAROFF | ECHOOFF | TIC2 | DTRON | IRQOFF)

        pull_axy
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
        ; Always report ready. TXEMPTY is stuck high on the W65C51N,
        ; and the actual TX timing is handled by the delay in write.
        pha
        lda #1
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
        push_axy
        lda byte
        sta DATA_REGISTER
        jsr _tx_delay
        pull_axy
        rts
    .endproc

.endscope

.endif

; -------------------------------------------------------------------------
; UM6551 ACIA (Asynchronous Communications Interface Adapter)
;
; Drives the ACIA for RS232 serial communication. The ACIA is memory-mapped
; directly on the CPU bus (active-low chip select address decoded from the
; address lines).
;
; This version of the driver 
;
; Wiring diagram
; --------------
;
;     W65C02 CPU                            UM6551 ACIA
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
; Important points from the datasheet:
;  - DCDB (Data Carrier Detect) *must* be tied to ground to make RxD work.
;  - CTS (Clear To Send) *must* be tied to ground to make TxD work.
;  - DSRB (Data Set Ready) is unused, but should not be left floating.
;
; Address decoding is following Ben Eater's setup. This can be
; different in your own device layout of course.
;
; XTAL can be:
; - passive 1.8432 Mhz crystal, series resonance, on XTAL1/XTAl2,
;   without any other components (like the resistor and capacitor
;   as used with a W65C51 IC).
; - active 1.8432 Mhz crystal module, with its output connected to
;   XTAL1, leaving XTAL2 fully floating.
; -------------------------------------------------------------------------

.ifndef KERNAL_UART_UM6551_POLL_S
KERNAL_UART_UM6551_POLL_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "KERNAL"

    .include "breadbox/uart/um6551_common.s"

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
        ; - transmitter = on
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


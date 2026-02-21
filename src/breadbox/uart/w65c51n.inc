; -------------------------------------------------------------------------
; W65C51N ACIA (Asynchronous Communications Interface Adapter)
;
; Drives the WDC W65C51N ACIA for RS232 serial communication.
;
; This implementation uses IRQ-driven RX with a circular buffer and
; RTS flow control, identical to the UM6551 driver. The TX side is
; different: the W65C51N has a hardware bug that makes TXEMPTY and
; TX interrupts non-functional, so transmission uses a software
; delay after each byte.
;
; - IRQ-driven RX: incoming bytes are buffered by the IRQ handler, so
;   data is not lost when bytes arrive faster than the application
;   processes them.
; - Read buffer: circular 256-byte buffer for incoming bytes.
; - Timed TX: outgoing bytes are written directly to the DATA register,
;   followed by a calibrated delay for one character time. The write
;   subroutine blocks during this delay, but RX interrupts continue
;   to be serviced (the delay does not disable interrupts).
; - Flow control: RTS signalling via a VIA GPIO pin, to tell the remote
;   side to stop sending when the read buffer is filling up.
;
; About the flow control approach:
;
; The W65C51N has built-in RTS and DTR pins, but neither is usable for
; clean flow control (same limitations as the UM6551). Using a plain
; VIA GPIO pin avoids all problems.
;
; Note:
; Only inbound flow control is implemented (we tell the remote to stop).
; Outbound flow control (remote tells us to stop) is not needed: the
; connecting systems are normally many magnitudes faster than our trusty
; 6502, so they will not choke on our data output rate.
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
;    │  IRQB    │◄─────── interrupts ──────│ IRQB *)  │
;    │  PHI2    │────── system clock ─────►│ PHI2     │
;    │  R/WB    │─────── read/write ──────►│ R/WB     │
;    └──────────┘                          └──────────┘
;
;     I/O *)
;    ┌──────────┐
;    │ GPIO PIN │───► RS232 RTS (directly drives remote CTS, active low, 1 = stop)
;    └──────────┘
;
; *) Differences in wiring, compared to the `w65c51n_poll.s` implementation:
; - IRQB is connected to the IRQB pin on the CPU.
; - A VIA GPIO pin drives the RS232 RTS line for flow control.
;   Configurable via UART_RTS_PORT/UART_RTS_PIN in config.inc.
;
; About the IRQB connection:
; - Be sure to add a pull-up resistor to IRQB on the CPU. The IRQB pin on
;   the ACIA is "open drain", which means it is not driving the IRQB pin
;   high when there is no IRQ to communicate. The pull up handles this.
; - For good isolation (when multiple devices are connected to IRQB), add
;   a diode (anode pointing to the CPU, kathode - striped side - to the
;   ACIA) between ACIA and CPU.
; -------------------------------------------------------------------------

.ifndef KERNAL_UART_W65C51N_S
KERNAL_UART_W65C51N_S = 1

.include "breadbox/kernal.inc"

.scope DRIVER

.segment "RAM"

    rx_buffer: .res $100       ; Circular buffer for incoming bytes

.segment "ZEROPAGE"

    rx_w_ptr:     .res 1       ; Write position in the rx_buffer
    rx_r_ptr:     .res 1       ; Read position in the rx_buffer
    rx_pending:   .res 1       ; Number of bytes pending in the input buffer
    rx_off:       .res 1       ; Whether flow control halted rx

    status:       .res 1       ; Shadow of the STATUS register

.segment "KERNAL"

    .include "breadbox/uart/w65c51n_common.inc"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    .include "breadbox/uart/6551_irq.inc"

    ; CMD register value: TIC2 (transmitter on, no TX IRQs).
    ; TX interrupts are broken on the W65C51N, so TIC2 is the only
    ; mode used. RX interrupts are enabled via IRQON.
    CMD_VALUE    = PAROFF | ECHOOFF | TIC2 | DTRON | IRQON

    .proc init
        PUSH_AXY

        jsr _soft_reset

        ; Initialize variables.
        lda #0
        sta rx_r_ptr
        sta rx_w_ptr
        sta rx_pending
        sta rx_off
        lda STATUS_REGISTER
        sta status

        ; Configure the RTS GPIO pin as output, active LOW (= send).
        SET_BYTE GPIO::port, #RTS_PORT
        SET_BYTE GPIO::mask, #RTS_PIN
        jsr GPIO::set_outputs
        jsr GPIO::turn_off

        ; Configure the ACIA before enabling IRQs, to avoid spurious
        ; interrupts from bytes that arrived during/before reset.
        SET_BYTE CTRL_REGISTER, #(LEN8 | STOP1 | USE_BAUD_RATE | RCSGEN)
        SET_BYTE CMD_REGISTER, #CMD_VALUE

        ; Now install the IRQ handler and enable interrupts.
        SET_IRQ _irq_handler
        cli

        PULL_AXY
        rts
    .endproc

    .proc check_tx
        ; Always report ready. There is no TX buffer; the write
        ; subroutine handles timing via a software delay.
        pha
        lda #1
        sta byte
        pla
        rts
    .endproc

    .proc write
        PUSH_AXY
        lda byte
        sta DATA_REGISTER
        jsr _tx_delay
        PULL_AXY
        rts
    .endproc

    ; -----------------------------------------------------------------
    ; Private code
    ; -----------------------------------------------------------------

    .proc _irq_handler
        pha
        txa
        pha

        lda STATUS_REGISTER  ; Acknowledge the IRQ by reading STATUS.
        sta status           ; Update shadow for public API.
        jsr _irq_handler_rx  ; RX: read incoming byte if available

        pla
        tax
        pla
        rti
    .endproc

.endscope

.endif

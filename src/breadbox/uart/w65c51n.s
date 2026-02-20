; -------------------------------------------------------------------------
; W65C51N ACIA (Asynchronous Communications Interface Adapter)
;
; Drives the WDC W65C51N ACIA for RS232 serial communication.
;
; This implementation uses IRQ-driven RX with a circular buffer and
; CTS flow control, identical to the UM6551 driver. The TX side is
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
;   procedure blocks during this delay, but RX interrupts continue
;   to be serviced (the delay does not disable interrupts).
; - Flow control: CTS signalling via a VIA GPIO pin, to tell the remote
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
;    │ GPIO PIN │───► RS232 CTS (pin acts as RTS pin, active low, 1 = stop flow)
;    └──────────┘
;
; *) Differences in wiring, compared to the `w65c51n_poll.s` implementation:
; - IRQB is connected to the IRQB pin on the CPU.
; - A VIA GPIO pin drives the RS232 CTS line for flow control.
;   Configurable via UART_CTS_PORT/UART_CTS_PIN in config.inc.
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

.include "breadbox/kernal.s"

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

    .include "breadbox/uart/w65c51n_common.s"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    ; -----------------------------------------------------------------
    ; Hardware flow control CTS pin.
    ;
    ; Flow control is driven via a VIA GPIO pin (instead of the ACIA's
    ; DTR or RTS pins, which have side effects that make them unusable
    ; for clean flow control). The pin directly drives the RS232 CTS
    ; line: HIGH = stop sending, LOW = send.
    ;
    ; The GPIO HAL is used for init and _turn_rx_on (main thread).
    ; The IRQ handler (_turn_rx_off) uses direct register access to
    ; avoid corrupting GPIO zero-page variables that LCD code may be
    ; using when the IRQ fires.
    ;
    ; The VIA port and pin are configurable via config.inc
    ; (UART_CTS_PORT, UART_CTS_PIN).
    ; Avoid sharing a port with a busy driver (e.g. LCD data bus).
    ; -----------------------------------------------------------------

    CTS_PORT     = ::UART_CTS_PORT
    CTS_PIN      = ::UART_CTS_PIN
    CTS_PORT_REG = IO::PORTB_REGISTER + ::UART_CTS_PORT

    ; CMD register value: TIC2 (transmitter on, no TX IRQs).
    ; TX interrupts are broken on the W65C51N, so TIC2 is the only
    ; mode used. RX interrupts are enabled via IRQON.
    CMD_VALUE    = PAROFF | ECHOOFF | TIC2 | DTRON | IRQON

    .proc init
        push_axy

        jsr _soft_reset

        ; Initialize variables.
        lda #0
        sta rx_r_ptr
        sta rx_w_ptr
        sta rx_pending
        sta rx_off
        lda STATUS_REGISTER
        sta status

        ; Configure the CTS GPIO pin as output, active LOW (= send).
        set_byte GPIO::port, #CTS_PORT
        set_byte GPIO::mask, #CTS_PIN
        jsr GPIO::set_outputs
        jsr GPIO::turn_off

        ; Configure the ACIA before enabling IRQs, to avoid spurious
        ; interrupts from bytes that arrived during/before reset.
        set_byte CTRL_REGISTER, #(LEN8 | STOP1 | USE_BAUD_RATE | RCSGEN)
        set_byte CMD_REGISTER, #CMD_VALUE

        ; Now install the IRQ handler and enable interrupts.
        cp_address ::VECTORS::irq_vector, _irq_handler
        cli

        pull_axy
        rts
    .endproc

    .proc load_status
        pha
        lda status
        sta byte
        pla
        rts
    .endproc

    .proc check_rx
        pha
        lda rx_pending
        sta byte
        pla
        rts
    .endproc

    .proc read
        pha
        txa
        pha

        ; Check if we can read a byte from the input buffer.
        ; The carry flag is used for communicating if a byte could be read.
        clc            ; carry 0 = flag "no byte was read"
        lda rx_pending ; Check if there are any pending bytes.
        beq @done      ; No, we're done, leaving carry = 0.

        ; Read the next character from the input buffer.
        ldx rx_r_ptr
        lda rx_buffer,X
        sta byte

        ; Update counters.
        inc rx_r_ptr
        dec rx_pending

        jsr _turn_rx_on_if_buffer_emptying
        sec            ; carry 1 = flag "byte was read"

    @done:
        pla
        tax
        pla
        rts
    .endproc

    .proc check_tx
        ; Always report ready. There is no TX buffer; the write
        ; procedure handles timing via a software delay.
        pha
        lda #1
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

    ; -----------------------------------------------------------------
    ; Internal helpers (not part of the driver API)
    ; -----------------------------------------------------------------

    .proc _irq_handler
        pha
        txa
        pha

        lda STATUS_REGISTER  ; Acknowledge the IRQ by reading STATUS.
        sta status           ; Update shadow for public API.

        ; --- RX: read incoming byte if available ---

        and #RXFULL          ; Does the status indicate we can read a byte?
        beq @done            ; No, nothing to do.

        lda DATA_REGISTER    ; Load the byte from the UART DATA register.
        ldx rx_w_ptr         ; Store the byte in the input buffer.
        sta rx_buffer,X
        inc rx_w_ptr         ; Update counters.
        inc rx_pending

        jsr _turn_rx_off_if_buffer_almost_full

    @done:
        pla
        tax
        pla
        rti
    .endproc

    .proc _turn_rx_off_if_buffer_almost_full
        lda rx_off           ; RX turned off already? (0 = no, 1 = yes).
        bne @done            ; Yes, no need to check pending buffer size.

        lda rx_pending       ; Buffer almost full?
        cmp #$d0
        bcc @done            ; No, no need to change rx_off state.

        ; The buffer is almost full. Assert CTS HIGH to tell remote to stop.
        lda #1
        sta rx_off
        lda CTS_PORT_REG
        ora #CTS_PIN
        sta CTS_PORT_REG

    @done:
        rts
    .endproc

    .proc _turn_rx_on_if_buffer_emptying
        lda rx_off           ; RX turned off? (0 = no, 1 = yes).
        beq @done            ; No, no need to check pending buffer size.

        lda rx_pending       ; Buffer empty enough again?
        cmp #$50
        bcs @done            ; No, no need to change rx_off state.

        ; The buffer is emptying. Assert CTS LOW to tell remote to send.
        ; SEI protects the full rx_off + CTS update, so the IRQ handler
        ; cannot re-assert CTS HIGH between clearing rx_off and the
        ; port register write.
        sei
        lda #0
        sta rx_off
        lda CTS_PORT_REG
        and #($FF ^ CTS_PIN)
        sta CTS_PORT_REG
        cli

    @done:
        rts
    .endproc

.endscope

.endif

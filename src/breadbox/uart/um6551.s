; -------------------------------------------------------------------------
; UM6551 ACIA (Asynchronous Communications Interface Adapter)
;
; Drives the ACIA for RS232 serial communication. The ACIA is memory-mapped
; directly on the CPU bus (active-low chip select address decoded from the
; address lines).
;
; This implementation uses various techniques to make the serial connection
; rock solid:
;
; - IRQ-driven RX and TX: incoming bytes are buffered by the IRQ handler,
;   and outgoing bytes are drained from the write buffer by the IRQ
;   handler when the transmitter is ready. No polling required.
; - Read buffer: circular 256-byte buffer for incoming bytes, so data is
;   not lost when bytes arrive faster than the application processes them.
; - Write buffer: circular 256-byte buffer for outgoing bytes. The
;   application queues bytes without waiting; the IRQ handler transmits
;   them one by one as the ACIA becomes ready (TXEMPTY).
; - Flow control: RTS signalling via a VIA GPIO pin, to tell the remote
;   side to stop sending when the read buffer is filling up.
;
; TX buffer and TIC mode switching:
;
; The transmitter interrupt control (TIC) mode is switched between TIC2
; (TX IRQs off, idle) and TIC1 (TX IRQs on, transmitting). When the
; write buffer is empty, TIC2 prevents spurious TXEMPTY interrupts. When
; the application queues the first byte, the driver switches to TIC1,
; which immediately fires a TXEMPTY IRQ to start draining. The handler
; switches back to TIC2 when the buffer is empty.
;
; About the flow control approach:
;
; The UM6551 has built-in RTS and DTR pins, but neither is usable for clean
; flow control. TIC0 (the only way to raise RTSB) also disables the
; transmitter, deadlocking any write. DTROFF disables the receiver and
; IRQs, which can cause lost bytes. Using a plain VIA GPIO pin avoids
; both problems: the 6551 receiver stays always on, and we have direct,
; side-effect-free control over the RTS line.
;
; Note:
; Only inbound flow control is implemented (we tell the remote to stop).
; Outbound flow control (remote tells us to stop) is not yet implemented,
; but the write buffer makes it possible: the remote could signal us to
; pause, and we would simply stop draining the TX buffer until cleared.
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
; See the notes from `um6551_poll.s` for some important pointers about the
; wiring diagram.
;
; *) Differences in wiring, compared to the `um6551_poll.s` implementation:
; - IRQB is connected to the IRQB pin on the CPU.
; - A VIA GPIO pin (default: PA7) drives the RS232 RTS line for flow
;   control. Configurable via UART_RTS_PORT/UART_RTS_PIN in config.inc.
;
; About the IRQB connection:
; - Be sure to add a pull-up resistor to IRQB on the CPU. The IRQB pin on
;   the ACIA is "open drain", which means it is not driving the IRQB pin
;   high when there is no IRQ to communicate. The pull up handles this.
; - For good isolation (when multiple devices are connected to IRQB), add
;   a diode (anode pointing to the CPU, kathode - striped side - to the
;   ACIA) between ACIA and CPU. Ben uses SB140 diodes for this. I didn't
;   have those on stock myself, and went for a 1N5819 instead.
; -------------------------------------------------------------------------

.ifndef KERNAL_UART_UM6551_S
KERNAL_UART_UM6551_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "RAM"

    rx_buffer: .res $100       ; Circular buffer for incoming bytes
    tx_buffer: .res $100       ; Circular buffer for outgoing bytes

.segment "ZEROPAGE"

    rx_w_ptr:     .res 1       ; Write position in the rx_buffer
    rx_r_ptr:     .res 1       ; Read position in the rx_buffer
    rx_pending:   .res 1       ; Number of bytes pending in the input buffer
    rx_off:       .res 1       ; Wether flow control halted rx

    tx_w_ptr:     .res 1       ; Write position in the tx_buffer
    tx_r_ptr:     .res 1       ; Read position in the tx_buffer
    tx_pending:   .res 1       ; Number of bytes pending in the output buffer
    tx_off:       .res 1       ; Wether flow control halted tx
    
    status:       .res 1       ; Shadow of the STATUS register

.segment "KERNAL"

    .include "breadbox/uart/um6551_common.s"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    ; -----------------------------------------------------------------
    ; Hardware flow control RTS pin.
    ;
    ; Flow control is driven via a VIA GPIO pin (instead of the ACIA's
    ; DTR or RTS pins, which have side effects that make them unusable
    ; for clean flow control). The pin directly drives the RS232 RTS
    ; line: HIGH = stop sending, LOW = send.
    ;
    ; The GPIO HAL is used for init and _turn_rx_on (main thread).
    ; The IRQ handler (_turn_rx_off) uses direct register access to
    ; avoid corrupting GPIO zero-page variables that LCD code may be
    ; using when the IRQ fires.
    ;
    ; The VIA port and pin are configurable via config.inc
    ; (UART_RTS_PORT, UART_RTS_PIN).
    ; Avoid sharing a port with a busy driver (e.g. LCD data bus).
    ; -----------------------------------------------------------------

    RTS_PORT     = ::UART_RTS_PORT
    RTS_PIN      = ::UART_RTS_PIN
    RTS_PORT_REG = IO::PORTB_REGISTER + ::UART_RTS_PORT

    ; Combined CMD register values for TIC mode switching.
    ; All base flags (parity, echo, DTR, IRQ) are baked in, so
    ; switching modes is a single register write.
    CMD_TX_ACTIVE = PAROFF | ECHOOFF | TIC1 | DTRON | IRQON
    CMD_TX_IDLE   = PAROFF | ECHOOFF | TIC2 | DTRON | IRQON

    .proc init
        push_axy

        jsr _soft_reset

        ; Initialize variables.
        lda #0
        sta rx_r_ptr
        sta rx_w_ptr
        sta rx_pending
        sta rx_off
        sta tx_r_ptr
        sta tx_w_ptr
        sta tx_pending
        sta tx_off
        lda STATUS_REGISTER
        sta status

        ; Configure the RTS GPIO pin as output, active LOW (= send).
        set_byte GPIO::port, #RTS_PORT
        set_byte GPIO::mask, #RTS_PIN
        jsr GPIO::set_outputs
        jsr GPIO::turn_off

        ; Configure the ACIA before enabling IRQs, to avoid spurious
        ; interrupts from bytes that arrived during/before reset.
        ; The receiver is always on (DTRON). Flow control is handled
        ; externally via the RTS GPIO pin.
        set_byte CTRL_REGISTER, #(LEN8 | STOP1 | USE_BAUD_RATE | RCSGEN)
        set_byte CMD_REGISTER, #CMD_TX_IDLE

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
        clc                  ; carry 0 = flag "no byte was read"
        lda rx_pending       ; Check if there are any pending bytes.
        beq @done            ; No, we're done, leaving carry = 0.

        ; Read the next character from the input buffer.
        ldx rx_r_ptr
        lda rx_buffer,X
        sta byte
        
        ; Update counters.
        inc rx_r_ptr
        dec rx_pending

        jsr _turn_rx_on_if_buffer_emptying
        sec                  ; carry 1 = flag "byte was read"
    
    @done:
        pla
        tax
        pla
        rts    
    .endproc

    .proc check_tx
        pha
        lda tx_pending
        eor #$FF             ; 255 (full) → 0, anything else → non-zero
        sta byte
        pla
        rts
    .endproc

    .proc write
        pha
        txa
        pha

        ; Disable interrupts for the critical section: checking
        ; the buffer, writing to it, and deciding on kickstart
        ; must be atomic with respect to the IRQ handler draining
        ; the buffer.
        sei

        ; Check if the buffer is full.
        lda tx_pending
        cmp #$FF
        beq @full

        ; Queue the byte into the transmit buffer.
        lda byte
        ldx tx_w_ptr
        sta tx_buffer,X
        inc tx_w_ptr
        inc tx_pending

        ; If this is the first byte in the buffer, enable TX
        ; interrupts to kickstart the transmit chain. The ACIA
        ; will fire an IRQ immediately after CLI (TXEMPTY is
        ; already set), and the handler will drain the byte.
        lda tx_pending
        cmp #1
        bne @done
        set_byte CMD_REGISTER, #CMD_TX_ACTIVE

    @done:
        cli
        pla
        tax
        pla
        clc                   ; Success: byte queued
        rts

    @full:
        cli
        pla
        tax
        pla
        sec                   ; Error: buffer full
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
        beq @check_tx        ; No, skip to TX handling.

        lda DATA_REGISTER    ; Load the byte from the UART DATA register.
        ldx rx_w_ptr         ; Store the byte in the input buffer.
        sta rx_buffer,X
        inc rx_w_ptr         ; Update counters.
        inc rx_pending

        jsr _turn_rx_off_if_buffer_almost_full

        ; --- TX: send next byte from buffer if transmitter ready ---

    @check_tx:
        lda status           ; Reload (A was clobbered by RX path).
        and #TXEMPTY         ; Is the transmitter ready?
        beq @done            ; No, nothing to do.

        lda tx_pending       ; Any bytes waiting to be sent?
        beq @tx_stop         ; No, disable TX IRQs.

        ; Send the next byte from the transmit buffer.
        ldx tx_r_ptr
        lda tx_buffer,X
        sta DATA_REGISTER
        inc tx_r_ptr
        dec tx_pending

        lda tx_pending       ; Buffer now empty?
        bne @done            ; No, keep TIC1 for the next TXEMPTY.

    @tx_stop:
        ; Buffer empty (or was already empty). Switch to TIC2
        ; to stop TXEMPTY from triggering further IRQs.
        set_byte CMD_REGISTER, #CMD_TX_IDLE

    @done:
        pla
        tax
        pla
        rti
    .endproc

    .proc _turn_rx_off_if_buffer_almost_full
        ; Check if the buffer is almost full. If it is, signal the remote side
        ; (via RS232 RTS) to stop sending data.

        lda rx_off           ; RX turned off already? (0 = no, 1 = yes).
        bne @done            ; Yes, no need to check pending buffer size.
        
        lda rx_pending        ; Buffer almost full?
        cmp #$d0
        bcc @done            ; No, no need to change rx_off state.

        ; The buffer is almost full. Assert RTS HIGH to tell remote to stop.
        lda #1
        sta rx_off
        lda RTS_PORT_REG
        ora #RTS_PIN
        sta RTS_PORT_REG

    @done:
        rts  
    .endproc

    .proc _turn_rx_on_if_buffer_emptying
        ; Check if the buffer is emptying. If it is, signal the remote side
        ; (via RS232 RTS) to start sending data.

        lda rx_off           ; RX turned off? (0 = no, 1 = yes).
        beq @done            ; No, no need to check pending buffer size.
        
        lda rx_pending        ; Buffer empty enough again?
        cmp #$50
        bcs @done            ; No, no need to change rx_off state.

        ; The buffer is emptying. Assert RTS LOW to tell remote to send.
        ; SEI protects the full rx_off + RTS update, so the IRQ handler
        ; cannot re-assert RTS HIGH between clearing rx_off and the
        ; port register write.
        sei
        lda #0
        sta rx_off
        lda RTS_PORT_REG
        and #($FF ^ RTS_PIN)
        sta RTS_PORT_REG
        cli
    
    @done:
        rts
    .endproc

.endscope

.endif

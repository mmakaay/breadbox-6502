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
; - IRQ triggering: to not requiring polling for checking when bytes can
;   be read from the RX buffer, and to make the TX polling possible without
;   having to actively read the STATUS register.
; - Read buffer: to temporarily store incoming bytes when they arrive
;   faster than the computer can process them.
; - Flow control: CTS signalling via a VIA GPIO pin, to tell the remote
;   side to stop sending when the read buffer is filling up.
;
; About the flow control approach:
;
; The UM6551 has built-in RTS and DTR pins, but neither is usable for clean
; flow control. TIC0 (the only way to raise RTSB) also disables the
; transmitter, deadlocking any write. DTROFF disables the receiver and
; IRQs, which can cause lost bytes. Using a plain VIA GPIO pin avoids
; both problems: the 6551 receiver stays always on, and we have direct,
; side-effect-free control over the CTS line.
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
;    │ GPIO PIN │───► RS232 CTS (pin acts as RTS pin, active low, 1 = stop flow)
;    └──────────┘
;
; See the notes from `um6551_poll.s` for some important pointers about the
; wiring diagram.
;
; *) Differences in wiring, compared to the `um6551_poll.s` implementation:
; - IRQB is connected to the IRQB pin on the CPU.
; - A VIA GPIO pin (default: PA7) drives the RS232 CTS line for flow
;   control. Configurable via UART_CTS_PORT/UART_CTS_PIN in config.inc.
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

    input_buffer: .res $100    ; Circular buffer for incoming bytes

.segment "ZEROPAGE"

    write_ptr:    .res 1       ; Write position in the input_buffer
    read_ptr:     .res 1       ; Read position in the input_buffer
    pending:      .res 1       ; Number of bytes pending in the input buffer
    rx_off:       .res 1       ; Wether the remote is signalled to stop sending
    status:       .res 1       ; Shadow of the STATUS register

.segment "KERNAL"

    .include "breadbox/uart/um6551_common.s"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    ; -----------------------------------------------------------------
    ; Hardware flow control CTS pin.
    ;
    ; Flow control is driven via a VIA GPIO pin (instead of the 6551's
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
    ; (UART_CTS_PORT, UART_CTS_PIN). Defaults: port A, pin 7.
    ; Avoid sharing a port with a busy driver (e.g. LCD data bus).
    ; -----------------------------------------------------------------

    CTS_PORT     = ::UART_CTS_PORT
    CTS_PIN      = ::UART_CTS_PIN
    CTS_PORT_REG = IO::PORTB_REGISTER + ::UART_CTS_PORT

    .proc init
        push_axy

        jsr _soft_reset

        ; Initialize variables.
        lda #0
        sta read_ptr
        sta write_ptr
        sta pending
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
        ; The receiver is always on (DTRON). Flow control is handled
        ; externally via the CTS GPIO pin.
        set_byte CTRL_REGISTER, #(LEN8 | STOP1 | USE_BAUD_RATE | RCSGEN)
        set_byte CMD_REGISTER, #(PAROFF | ECHOOFF | TIC1 | DTRON | IRQON)

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
        lda pending
        sta byte
        pla
        rts
    .endproc

    .proc read
        pha
        txa
        pha

        ; Make sure a byte is available. The caller should have checked using
        ; the check_rx routine, but if that was not done, then we don't actually
        ; read from the buffer, and use the carry bit to indicate that no byte
        ; was read (carry = 0). This can also be used by callers to know if an
        ; actual read was done.
        clc            ; carry 0 = flag "no byte was read"
        lda pending    ; Check if there are any pending bytes.
        beq @done      ; No, we're done, leaving carry = 0.
        sec            ; carry 1 = flat "byte was read"

        ; Read the next character from the input buffer.
        ldx read_ptr
        lda input_buffer,X
        sta byte
        
        ; Update counters.
        inc read_ptr
        dec pending

        jsr _turn_rx_on_if_buffer_emptying
    
    @done:
        pla
        tax
        pla
        rts    
    .endproc

    .proc check_tx
        pha
        lda status
        and #TXEMPTY
        sta byte
        pla
        rts
    .endproc

    .proc write
        pha
        lda byte              ; Load byte from `byte` argument.
        sta DATA_REGISTER     ; Write it to the transmitter.
        pla
        rts
    .endproc

    ; -----------------------------------------------------------------
    ; Internal helpers (not part of the driver API)
    ; -----------------------------------------------------------------

    .proc _irq_handler
        pha
        txa
        pha

        lda STATUS_REGISTER  ; Acknowledge the IRQ by reading from STATUS.
        sta status

        and #RXFULL          ; Does the status indicate we can read a byte?
        beq @done            ; No, we're done here.

        lda DATA_REGISTER    ; Load the byte from the UART DATA register.
        ldx write_ptr        ; Store the byte in the input buffer.
        sta input_buffer,X
        inc write_ptr        ; Update counters.
        inc pending

        jsr _turn_rx_off_if_buffer_almost_full

    @done:
        pla
        tax
        pla
        rti
    .endproc

    .proc _turn_rx_off_if_buffer_almost_full
        ; Check if the buffer is almost full. If it is, signal the remote side
        ; (via RS232 CTS) to stop sending data.

        lda rx_off           ; RX turned off already? (0 = no, 1 = yes).
        bne @done            ; Yes, no need to check pending buffer size.
        
        lda pending          ; Buffer almost full?
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
        ; Check if the buffer is emptying. If it is, signal the remote side
        ; (via RS232 CTS) to start sending data.

        lda rx_off           ; RX turned off? (0 = no, 1 = yes).
        beq @done            ; No, no need to check pending buffer size.
        
        lda pending          ; Buffer empty enough again?
        cmp #$50
        bcs @done            ; No, no need to change rx_off state.

        ; The buffer is emptying. Assert CTS LOW to tell remote to send.
        lda #0
        sta rx_off
        set_byte GPIO::port, #CTS_PORT
        set_byte GPIO::mask, #CTS_PIN
        jsr GPIO::turn_off
    
    @done:
        rts
    .endproc

.endscope

.endif


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
; - IRQ triggering: so the CPU sees bytes as soon they are in the RX buffer.
; - Read buffer: to temporarily store incoming bytes when they arrive
;   faster than the computer can process them.
; - Flow control: RTS support, to signal the other side that it must
;   temporarily stop sending data, when the read buffer is filling up.
;
; Note:
; At this point, only RTS is implemented. CTS support (to not send data
; when the other side requests this) is not implemented. The simple reason
; being that connecting systems normally are many magnitutes faster than
; our trusty 6502, which makes it very unlikely that they will choke on our
; data output rate.
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
;    │          │                          │ RTSB     │───► RS232 CTS
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
;    │  IRQB    │◄─────── interrupts ──────│ IRQB     │
;    │  PHI2    │────── system clock ─────►│ PHI2     │
;    │  R/WB    │─────── read/write ──────►│ R/WB     │
;    └──────────┘                          └──────────┘
;
; See the notes from `um6551.s` for some important pointers about the
; wiring diagram.
;
; Differences in wiring, compared to the `um6551.s` implementation:
; - RTSB is connected to the CTS pin of the RS232 interface.
; - IRQB is connected to the IRQB pin on the CPU.
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

.ifndef BIOS_UART_UM6551_IRQ_S
BIOS_UART_UM6551_IRQ_S = 1

.include "breadbox/kernal.s"

.scope DRIVER

.segment "ZEROPAGE"

    write_ptr: .res 1
    read_ptr:  .res 1

.segment "RAM"

    input_buffer: .res $100

.segment "KERNAL"

    .include "breadbox/uart/6551_common.s"

    ; The ZP byte is declared in the HAL (uart.s).
    byte = UART::byte

    .proc init
        push_axy

        jsr _soft_reset

        ; Initialize the input buffer, by syncing up the read and write pointers.
        ; This makes the circular buffer effectively empty.
        lda read_ptr
        sta write_ptr

        ; Setup and enable IRQ handler (for now, directly connected to the CPU).
        cp_address ::VECTORS::irq_vector, _irq_handler
        cli

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
        ; - interrupts = enabled
        set_byte CMD_REGISTER, #(PAROFF | ECHOOFF | TIC2 | DTRON | IRQON)

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

    check_rx = _get_buffer_size

    .proc read
        pha
        txa
        pha

        ; Read the next character from the input buffer.
        ldx read_ptr
        lda input_buffer,X
        sta byte
        inc read_ptr

        pla
        tax
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

    .proc write
        pha
        lda byte
        sta DATA_REGISTER
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

        lda DATA_REGISTER   ; Load the byte from the UART DATA register

        ldx write_ptr       ; Store the byte in the input buffer
        sta input_buffer,X
        inc write_ptr

        lda STATUS_REGISTER ; Acknowledge the IRQ by reading from STATUS
        
        pla
        tax
        pla
        rti
    .endproc

    .proc _get_buffer_size
        ; Return the number of bytes that are stored in the buffer.
        ;
        ; byte = number of bytes in the buffer
        ; A, X, Y = preserved

        pha
        lda write_ptr  ; Get the current write pointer
        sec            ; Set carry, as required for clean subtract operation
        sbc read_ptr   ; Subtract the read pointer to get the buffer size
        sta byte

        pla
        rts
    .endproc

.endscope

.endif


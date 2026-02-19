; -----------------------------------------------------------------
; UART HAL for RS232 serial communication
;
; Parameters are passed via zero page: UART::byte.
; All procedures preserve A, X, Y.
;
; Configuration
; -------------
; No configuration required. The UART base address is provided
; by the linker via __UART_START__.
;
; -----------------------------------------------------------------

.ifndef KERNAL_UART_S
KERNAL_UART_S = 1

.include "breadbox/kernal.s"

.scope UART

    ; The start of the UART register space is configured in the
    ; linker configuration. The linker provides the starting
    ; address that is imported here.
    .import __UART_START__

    ; Import the hardware driver.
    .if ::UART_DRIVER = ::UM6551
        .include "breadbox/uart/um6551.s"
    .elseif ::UART_DRIVER = ::UM6551_POLL
        .include "breadbox/uart/um6551_poll.s"
    .endif

.segment "ZEROPAGE"

    byte: .res 1               ; Input/output byte for read/write

.segment "KERNAL"

    ; -------------------------------------------------------------
    ; Low level driver API (no waiting)
    ; -------------------------------------------------------------

    init = DRIVER::init
        ; Initialize the serial interface: N-8-1, 19200 baud.
        ;
        ; Out:
        ;   A, X, Y preserved

    check_rx = DRIVER::check_rx
        ; Check if there is a byte in the receiver buffer.
        ;
        ; Out:
        ;   UART::byte = non-zero if data available, zero if not
        ;   A, X, Y preserved

    _read = DRIVER::read
        ; Read a byte from the receiver (no wait).
        ;
        ; Out:
        ;   UART::byte = received byte
        ;   A, X, Y preserved

    check_tx = DRIVER::check_tx
        ; Check if a byte can be sent to the transmitter.
        ;
        ; Out:
        ;   UART::byte = non-zero if ready, zero if busy
        ;   A, X, Y preserved

    _write = DRIVER::write
        ; Write a byte to the transmitter (no wait).
        ;
        ; In (zero page):
        ;   UART::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

    load_status = DRIVER::load_status
        ; Load the status register.
        ;
        ; Out:
        ;   UART::byte = status bits (IRQ DSR DCD TXE RXF OVR FRM PAR)
        ;   A, X, Y preserved

    ; -------------------------------------------------------------
    ; High level API (waits for hardware to be ready)
    ; -------------------------------------------------------------

    .proc read
        ; Wait for a byte in the receiver buffer, then read it.
        ;
        ; Out:
        ;   UART::byte = received byte
        ;   A, X, Y preserved

        pha
    @wait_for_rx:
        jsr check_rx
        lda byte
        beq @wait_for_rx
        jsr _read
        pla
        rts
    .endproc

    .proc write
        ; Wait for transmitter to be ready, then write a byte.
        ;
        ; In (zero page):
        ;   UART::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

        pha
        lda byte               ; Save the data byte
        pha
    @wait_for_tx:
        jsr check_tx
        lda byte
        beq @wait_for_tx
        pla                    ; Restore the data byte
        sta byte
        jsr _write
        pla
        rts
    .endproc

    .proc write_text
        ; Text-mode write: if the byte is CR ($0D), send CR+LF.
        ; For raw/binary output, use write instead.
        ;
        ; In (zero page):
        ;   UART::byte = byte to write
        ; Out:
        ;   A, X, Y preserved

        pha
        lda byte
        cmp #$0d              ; Is it CR?
        bne @raw
        jsr write             ; Yes, send CR first
        lda #$0a              ; Then queue LF
        sta byte
    @raw:
        pla
        jmp write             ; Send byte (LF after CR, or original char)
    .endproc

.endscope

.endif

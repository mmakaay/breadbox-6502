; -----------------------------------------------------------------
; UART HAL for RS232 serial communication
; -----------------------------------------------------------------

.ifndef BIOS_UART_S
BIOS_UART_S = 1

.include "bios/bios.s"

.scope UART

    ; The start of the UART register space is configured in the
    ; linker configuration. The linker provides the starting
    ; address that is imported here.
    .import __UART_START__
    
    ; Import the hardware driver.
    .include "bios/uart/um6551.s"
    
    ; -------------------------------------------------------------
    ; Access to the low level driver API
    ; -------------------------------------------------------------

    init = DRIVER::init
        ; Initialize the serial interface: N-8-1, 19200 baud.
        ;
        ; Out:
        ;   A, X, Y = clobbered

    soft_reset = DRIVER::soft_reset
        ; Write to status register for soft reset
        ;
        ; Out:
        ;   A, X, Y = clobbered

    check_rx = DRIVER::check_rx
        ; Check if there is a byte in the receiver buffer.
        ;
        ; Out:
        ;   A = clobbered
        ;   Z = 0: data available in the receiver (A != 0)
        ;   Z = 1: no data available (A = 0)

    read = DRIVER::read
        ; Read a byte from the receiver.
        ;
        ; Out:
        ;   A = read byte

    check_tx = DRIVER::check_tx
        ; Check if a byte can be sent to the transmitter.
        ;
        ; Out:
        ;   A = clobbered
        ;   Z = 0: transmitter ready for sending data (A != 0)
        ;   Z = 1: send not possible (A = 0)

    write = DRIVER::write
        ; Write a byte to the transmitter.
        ;
        ; Out:
        ;   A = preserved

    load_status = DRIVER::load_status
        ; Load the status bits into register A.
        ;
        ; Out:
        ;   A = status bits (IRQ DSR DCD TXE RXF OVR FRM PAR)

    ; -------------------------------------------------------------
    ; High level convenience wrappers.
    ; -------------------------------------------------------------

    .proc read_when_ready
        ; Wait for a byte in the receiver buffer and then read it.
        ;
        ; Out:
        ;   A = read byte

        pha
    @wait_for_rx:
        jsr check_rx
        beq @wait_for_rx
        pla
        jsr read
        rts
    .endproc

    .proc write_when_ready
        ; Wait for the transmitter buffer to be empty and then write a byte to it.
        ;
        ; In:
        ;   A = the byte to write
        ; Out:
        ;   A = clobbered

        pha
    @wait_for_tx:
        jsr check_tx
        beq @wait_for_tx
        pla
        jsr write
        rts
    .endproc
    
.endscope

.endif

; -----------------------------------------------------------------
; W65C51 ACIA (Asynchronous Communications Interface Adapter)
; -----------------------------------------------------------------

.ifndef SERIAL_S
SERIAL_S = 1

.include "macros/macros.s"

.scope SERIAL

; The start of the ACIA register space is configured in the
; linker configuration. The linker provides the starting
; address that is imported here.
.import __ACIA_START__

.segment "BIOS"

    .scope REG
    ; Registers
    DATA   = __ACIA_START__ + $0  ; I/O register for bus communication
    STATUS = __ACIA_START__ + $1  ; Status register
    CMD    = __ACIA_START__ + $2  ; Command register
    CTRL   = __ACIA_START__ + $3  ; Control register
    .endscope

    .scope BIT
    ; STATUS register
    IRQ        = %10000000       ; Bit is 1 when interrupt has occurred
    DSR        = %01000000       ; Bit is 0 when Data Set is Ready
    DCD        = %00100000       ; Bit is 0 when Data Carrier is Detected
    TXEMPTY    = %00010000       ; Bit is 1 when Transmitter Data Register is Empty
    RXFULL     = %00001000       ; Bit is 1 when Receiver Data Register is Full
    OVERRUN    = %00000100       ; Bit is 1 when Overrun has occurred
    FRAMINGERR = %00000010       ; Bit is 1 when Framing Error was detected
    PARITYERR  = %00000001       ; Bit is 1 when Parity Error was detected

    ; CMD register
    PAROFF     = %00000000       ; Parity disabled
    PARODD     = %00100000       ; Odd parity receiver and transmitter
    PAREVEN    = %01000000       ; Even parity receiver and transmitter
    PARPTCD    = %10100000       ; Mark parity bit transmitted, parity check disabled
    PARSTCD    = %11100000       ; Space parity bit transmitted, parity check disabled
    REM        = %00010000       ; Receiver Echo Mode enable (use with TIC0)
    TIC0       = %00000000       ; Transmit interrupt = off, RTS level high, transmitter off
    TIC1       = %00000100       ; Transmit interrupt = on,  RTS level Low,  transmitter = on
    TIC2       = %00001000       ; Transmit interrupt = off, RTS level Low,  transmitter = on
    TIC3       = %00001100       ; Transmit interrupt = off, RTS level Low,  transmitter = transmit BRK
    RIRD       = %00000010       ; IRQB receiver interrupt disabled
    DTR        = %00000001       ; Enable receiver and all interrupts (DTRB to low)

    ; CTRL register
    ; Stop Bit Number (SBN)
    STOPBIT1   = %00000000       ; 1 stop bit
    STOPBIT2   = %10000000       ; 2 stop bits, 1.5 for WL5 - parity, 1 for WL8 + parity
    ; Word Length (WL)
    WORDLEN8   = %00000000       ; 8 bits per word
    WORDLEN7   = %00100000       ; 7 bits per word
    WORDLEN6   = %01000000       ; 6 bits per word
    WORDLEN5   = %01100000       ; 5 bits per word
    ; Receiver Clock Source (RCS)
    CLKEXT     = %00000000       ; External
    CLKBAUD    = %00010000       ; Baud rate generator
    ; Selected Baud Rate (SBR)
    BAUD2400   = %00001010       ; Baud rate 2400
    BAUD7200   = %00001101       ; Baud rate 7200
    BAUD9600   = %00001110       ; Baud rate 9600
    BAUD19200  = %00001111       ; Baud rate 19200
    .endscope

    .proc init
        ; Initialize the serial interface: N-8-1, 19200 baud.
        ;
        ; Out:
        ;   A = clobbered

        ; Write to status register for soft reset
        clr_byte REG::STATUS

        ; Configure: 8 bits, 1 stopbit, 19200 baud
        set_byte REG::CTRL, #(BIT::STOPBIT1 | BIT::WORDLEN8 | BIT::BAUD19200)

        ; Configure: no parity, no echo, no transmitter/receiver interrupts 
        set_byte REG::CMD, #(BIT::PAROFF | BIT::TIC2 | BIT::RIRD | BIT::DTR)

        rts
    .endproc

    .proc check_rx
        ; Check if data can be retrieved from the receiver.
        ;
        ; Usage:
        ;   jsr check_rx
        ;   beq no_data  ; branch if no data available
        ;   ; ... retrieve data from the receiver
        ;
        ; Out:
        ;   Z = 0: data available in the receiver (A != 0)
        ;   Z = 1: no data available (A = 0)
        lda REG::STATUS
        and #BIT::RXFULL
        rts
    .endproc

    .proc check_tx
        ; Check if data can be sent to the transmitter.
        ;
        ; Usage:
        ;   jsr check_tx
        ;   beq tx_not_ready  ; branch if transmitter not ready
        ;   ; ... send data to the transmitter
        ;
        ; Out:
        ;   Z = 0: transmitter ready for sending data (A != 0)
        ;   Z = 1: send not possible (A = 0)
        lda REG::STATUS
        and #BIT::TXEMPTY
        rts
    .endproc

    .proc read
        ; Read a byte from the receiver.
        ;
        ; Out:
        ;   A = read byte
        lda REG::DATA
        rts
    .endproc

.endscope

.endif

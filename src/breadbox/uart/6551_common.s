; -----------------------------------------------------------------
; Common code for 6551 ACIA devices
; -----------------------------------------------------------------

.ifndef BIOS_UART_6551_COMMON_S
BIOS_UART_6551_COMMON_S = 1

.include "breadbox/kernal.s"

.segment "KERNAL"

; Registers
DATA_REGISTER   = __UART_START__ + $0
STATUS_REGISTER = __UART_START__ + $1
CMD_REGISTER    = __UART_START__ + $2
CTRL_REGISTER   = __UART_START__ + $3

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

; Parity check controls
PAROFF     = %00000000       ; Parity disabled
PARODD     = %00100000       ; Odd parity receiver and transmitter
PAREVEN    = %01000000       ; Even parity receiver and transmitter
PARMARK    = %10100000       ; Mark parity bit transmitted, parity check disabled
PARSPACE   = %11100000       ; Space parity bit transmitted, parity check disabled

; Receiver echo
ECHOOFF    = %00000000       ; Echo disabled
ECHOON     = %00010000       ; Echo enabled (use with TIC0)

; Transmitter controls
TIC0       = %00000000       ; Transmit interrupt = off, RTS = high, transmitter = off
TIC1       = %00000100       ; Transmit interrupt = on,  RTS = low,  transmitter = on
TIC2       = %00001000       ; Transmit interrupt = off, RTS = low,  transmitter = on
TIC3       = %00001100       ; Transmit interrupt = off, RTS = Low,  transmitter = transmit BRK

; Receiver interrupt control
IRQON      = %00000000       ; IRQB enabled (from bit 3 of status register) TODO read what that means
IRQOFF     = %00000010       ; IRQB disabled

; Data terminal ready control
DTROFF     = %00000000       ; Receiver = off, interrupts = off, DTRB = high
DTRON      = %00000001       ; Receiver = on, interrupts = on, DTRB = low

; CTRL register

; Stop Bit Number (SBN)
STOP1      = %00000000       ; 1 stop bit
STOP2      = %10000000       ; 2 stop bits, 1.5 for WL5 - parity, 1 for WL8 + parity

; Word Length (WL)
LEN8       = %00000000       ; 8 bits per word
LEN7       = %00100000       ; 7 bits per word
LEN6       = %01000000       ; 6 bits per word
LEN5       = %01100000       ; 5 bits per word

; Receiver Clock Source (RCS)
RCSEXT     = %00000000       ; Use external clock (on RxC, providing a 16x clock input) 
RCSGEN     = %00010000       ; Use baud rate generator (using 1.8432 MHz crystal on XTAL1/XTAL2)

; Selected Baud Rate (SBR)
BNONE      = %00000000       ; 16x external clock
B50        = %00000001       ; Baud rate 50
B75        = %00000010       ; Baud rate 75
B109       = %00000011       ; Baud rate 109.92
B134       = %00000100       ; Baud rate 134.58
B150       = %00000101       ; Baud rate 150
B300       = %00000110       ; Baud rate 300
B600       = %00000111       ; Baud rate 600
B1200      = %00001000       ; Baud rate 1200
B2400      = %00001010       ; Baud rate 2400
B3600      = %00001011       ; Baud rate 3600
B4800      = %00001100       ; Baud rate 4800
B7200      = %00001101       ; Baud rate 7200
B9600      = %00001110       ; Baud rate 9600
B19200     = %00001111       ; Baud rate 19200

; -----------------------------------------------------------------
; Configuration
;
; The default configuration uses a baud rate of 19200. This matches
; the configuration as used by Ben Eater in his LCD display
; tutorial, making sure that no specific configuration is required
; to make things work.
; -----------------------------------------------------------------

.ifndef ::UART_BAUD_RATE
    ::UART_BAUD_RATE = ::BAUD19200
.endif

.if ::UART_BAUD_RATE = ::BAUD1200
    USE_BAUD_RATE = B1200
.elseif ::UART_BAUD_RATE = ::BAUD2400
    ::USE_BAUD_RATE = B2400
.elseif ::UART_BAUD_RATE = ::BAUD4800
    ::USE_BAUD_RATE = B4800
.elseif ::UART_BAUD_RATE = ::BAUD7200
    ::USE_BAUD_RATE = B7200
.elseif ::UART_BAUD_RATE = ::BAUD9600
    ::USE_BAUD_RATE = B9600
.elseif ::UART_BAUD_RATE = ::BAUD19200
    ::USE_BAUD_RATE = B19200
.else
    .error "UART_BAUD_RATE invalid for UM6551 ACIA"
.endif

.endif

; -----------------------------------------------------------------
; Implementation
; -----------------------------------------------------------------

; ... none yet

; -----------------------------------------------------------------
; Internal helpers (not part of the driver API)
; -----------------------------------------------------------------

.proc _soft_reset
    ; Perform a soft reset of the UART.
    ;
    ; Out:
    ;   A, X, Y preserved

    push_axy

    ; Soft reset by writing to the status register.
    clr_byte STATUS_REGISTER

    ; Wait for soft reset to complete. The UART needs time to finish its
    ; internal reset before CTRL and CMD writes will take effect.
    ; This is a crude delay loop, but it works. Before using this, an
    ; attempt was done to base readiness on the TXEMPTY status bit, but
    ; that did not work.
    ldx #$ff
    ldy #$ff
@wait:
    dey
    bne @wait
    dex
    bne @wait

    pull_axy
    rts
.endproc


; -----------------------------------------------------------------
; Common code for W65C51N ACIA devices
;
; The W65C51N is register-compatible with the original 6551, but has
; a hardware bug: the TXEMPTY status bit (bit 4) is permanently
; stuck high and never reflects the actual transmitter state. The
; TIC1 transmit interrupt relies on the same flag, so it never fires
; either.
;
; The _tx_delay procedure provides a software workaround: a timed
; delay calibrated to one character time at the configured baud
; rate and CPU clock. Drivers call it after every DATA_REGISTER
; write to ensure the transmitter has finished before the next byte.
; -----------------------------------------------------------------

.ifndef KERNAL_UART_W65C51N_COMMON_S
KERNAL_UART_W65C51N_COMMON_S = 1

.include "breadbox/kernal.s"

.segment "KERNAL"

; Registers
DATA_REGISTER   = UART_ADDRESS + $0
STATUS_REGISTER = UART_ADDRESS + $1
CMD_REGISTER    = UART_ADDRESS + $2
CTRL_REGISTER   = UART_ADDRESS + $3

; STATUS register
IRQ        = %10000000       ; Bit is 1 when interrupt has occurred
DSR        = %01000000       ; Bit is 0 when Data Set is Ready
DCD        = %00100000       ; Bit is 0 when Data Carrier is Detected
TXEMPTY    = %00010000       ; ** BROKEN on W65C51N: always reads 1 **
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

; Transmitter interrupt control
TIC0       = %00000000       ; RTSB = high, IRQ = off, transmitter = off
TIC1       = %00000100       ; RTSB = low,  IRQ = on,  transmitter = on (** IRQ broken **)
TIC2       = %00001000       ; RTSB = low,  IRQ = off, transmitter = on
TIC3       = %00001100       ; RTSB = Low,  IRQ = off, transmitter = transmit BRK

; Receiver interrupt control
IRQON      = %00000000       ; IRQB enabled (from bit 3 of status register)
IRQOFF     = %00000010       ; IRQB disabled

; Data terminal ready control
DTROFF     = %00000000       ; DTRB = high, IRQ = off, receiver = off
DTRON      = %00000001       ; DTRB = low,  IRQ = on,  receiver = on

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
; -----------------------------------------------------------------

.if ::UART_BAUD_RATE = 1200
    USE_BAUD_RATE = B1200
.elseif ::UART_BAUD_RATE = 2400
    ::USE_BAUD_RATE = B2400
.elseif ::UART_BAUD_RATE = 4800
    ::USE_BAUD_RATE = B4800
.elseif ::UART_BAUD_RATE = 7200
    ::USE_BAUD_RATE = B7200
.elseif ::UART_BAUD_RATE = 9600
    ::USE_BAUD_RATE = B9600
.elseif ::UART_BAUD_RATE = 19200
    ::USE_BAUD_RATE = B19200
.else
    .error "UART_BAUD_RATE invalid for W65C51N ACIA"
.endif

; -----------------------------------------------------------------
; TX delay calculation
;
; Character time in CPU cycles (10 bits: 1 start + 8 data + 1 stop).
; The delay loop body is 5 cycles per iteration (dey:2 + bne:3).
;
; For baud rates where the iteration count fits in a single byte
; (≤ 255), a simple Y-register loop is used. For larger counts
; (low baud rates or fast clocks), a nested X/Y loop is used.
; -----------------------------------------------------------------

CHAR_CYCLES = (10 * ::CPU_CLOCK) / ::UART_BAUD_RATE
TX_DELAY_ITERATIONS = CHAR_CYCLES / 5

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

.if TX_DELAY_ITERATIONS <= 255

    .proc _tx_delay
        ; Delay for approximately one character time.
        ; Used after writing to DATA_REGISTER to work around the
        ; W65C51N TXEMPTY bug.
        ;
        ; Clobbers: Y

        ldy #TX_DELAY_ITERATIONS
    @wait:
        dey
        bne @wait
        rts
    .endproc

.else

    ; Nested loop for lower baud rates or faster clocks.
    ; Inner loop: 200 iterations × 5 cycles = 1000 cycles per outer pass.
    ; Outer count is rounded up to ensure we meet the minimum delay.
    TX_DELAY_OUTER = (TX_DELAY_ITERATIONS / 200) + 1
    TX_DELAY_INNER = 200

    .proc _tx_delay
        ; Delay for approximately one character time.
        ; Used after writing to DATA_REGISTER to work around the
        ; W65C51N TXEMPTY bug.
        ;
        ; Clobbers: X, Y

        ldx #TX_DELAY_OUTER
    @outer:
        ldy #TX_DELAY_INNER
    @inner:
        dey
        bne @inner
        dex
        bne @outer
        rts
    .endproc

.endif

.endif

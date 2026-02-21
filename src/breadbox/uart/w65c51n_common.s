; -----------------------------------------------------------------
; Common code for W65C51N ACIA devices
;
; The W65C51N is register-compatible with the original 6551, but has
; a hardware bug: the TXEMPTY status bit (bit 4) is permanently
; stuck high and never reflects the actual transmitter state. The
; TIC1 transmit interrupt relies on the same flag, so it never fires
; either.
;
; The _tx_delay procedure provides a software workaround: it uses
; the DELAY module to wait one character time after every
; DATA_REGISTER write, ensuring the transmitter has finished
; before the next byte.
; -----------------------------------------------------------------

.ifndef KERNAL_UART_W65C51N_COMMON_S
KERNAL_UART_W65C51N_COMMON_S = 1

.include "breadbox/kernal.s"

; -----------------------------------------------------------------
; Shared 6551 register definitions, constants, baud rate mapping,
; and _soft_reset procedure.
; -----------------------------------------------------------------

.segment "KERNAL"

    .include "breadbox/uart/6551_common.s"

; -----------------------------------------------------------------
; Private code
; -----------------------------------------------------------------

; The time that sending a seingle character takes in microseconds
; (10 bits: start + 8 data + stop). Used by _tx_delay to wait for
; the transmitter to finish.
CHAR_TIME_US = 10000000 / ::UART_BAUD_RATE

.proc _tx_delay
    ; Delay for approximately one character transmission time.
    ;
    ; Used after writing to DATA_REGISTER to work around the
    ; W65C51N TXEMPTY bug.
    ;
    ; Out:
    ;   A, X, Y preserved

    DELAY_US CHAR_TIME_US
    rts
.endproc

.endif

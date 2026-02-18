; --------------------------------------------------------------------
; Global constants for use in config.inc
;
; These are loaded before config.inc and before any HAL or driver
; module, so scoped symbols like GPIO::PORTA are not available
; yet at configuration time.
;
; This file bridges that gap by providing unscoped, human-readable
; names for ports, pins and driver identifiers. The HAL and driver
; modules reference the same constants internally, so the values
; used here translate directly into hardware behaviour.
;
; Adding a new driver or peripheral? Register its selectable
; options here so they can be referenced from config.inc.
; --------------------------------------------------------------------

.ifndef CONSTANTS_S
CONSTANTS_S = 1

; --- Driver selection -----------------------------------------------

; LCD
HD44780_8BIT = 1      ; HD44780, 8-bit data bus
HD44780_4BIT = 2      ; HD44780, 4-bit data bus

; UART
UM6551       = 3      ; UM6551, only with RXFULL/TXEMPTY polling
UM6551_IRQ   = 4      ; UM6551, using IRQ, buffering and flow control

; --- Booleans ------------------------------------------------------

NO  = 0
YES = 1

; --- I/O port selection ---------------------------------------------

PORTA = 1
PORTB = 0

; --- Pin bitmasks ---------------------------------------------------

P0 = %00000001
P1 = %00000010
P2 = %00000100
P3 = %00001000
P4 = %00010000
P5 = %00100000
P6 = %01000000
P7 = %10000000

; --- Baud rates -----------------------------------------------------

BAUD1200   = 1200
BAUD2400   = 2400
BAUD4800   = 4800
BAUD7200   = 7200
BAUD9600   = 9600
BAUD19200  = 19200
BAUD115200 = 115200

.endif
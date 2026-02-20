; ------------------------------------------------------------------------
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
; -------------------------------------------------------------------------

.ifndef CONSTANTS_S
CONSTANTS_S = 1

; --- CPU clock -----------------------------------------------------------

MHZ = 1000000  ; Can be used to specify CPU speed, for example "4 * MHZ"

; --- Driver selection ----------------------------------------------------

; IO
W65C22       = 1      ; W65C22 VIA

; LCD
HD44780_8BIT = 2      ; HD44780 LCD, 8-bit data bus
HD44780_4BIT = 3      ; HD44780 LCD, 4-bit data bus

; UART
UM6551_POLL  = 4      ; UM6551 ACIA, simple polling
UM6551       = 5      ; UM6551 ACIA, IRQ-driven, buffering, flow control
W65C51N_POLL = 6      ; W65C51N ACIA, simple polling
W65C51N      = 7      ; W65C51N ACIA, IRQ-driven, buffering, flow control

; --- Booleans ------------------------------------------------------------

NO  = 0
YES = 1

; --- I/O port selection --------------------------------------------------

PORTA = 1
PORTB = 0

; --- Pin bitmasks --------------------------------------------------------

P0 = %00000001
P1 = %00000010
P2 = %00000100
P3 = %00001000
P4 = %00010000
P5 = %00100000
P6 = %01000000
P7 = %10000000

.endif
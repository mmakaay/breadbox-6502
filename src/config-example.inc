; KERNAL configuration
;
; All named constants used below (HD44780_8BIT, PORTA, P5, etc.)
; are defined in breadbox/constants.s, which is loaded before this
; file. See that file for the full list of available names.

; --------------------------------------------------------------------
; CPU clock speed
;
; Used by drivers that need cycle-accurate timing (e.g. the W65C51N
; transmit delay). The MHZ constant (10^6) can be used to specify
; other clock speeds, for example by using "4 * MHZ".
; --------------------------------------------------------------------

CPU_CLOCK = 1 * MHZ

; --------------------------------------------------------------------
; WozMon
;
; An adapted version of WozMon, including some bugfixes, and fitting
; in the original Apple II WozMon address space $FF00 - $FFF9.
; --------------------------------------------------------------------

INCLUDE_WOZMON = YES

; --------------------------------------------------------------------
; IO bus device
; --------------------------------------------------------------------

INCLUDE_IO = YES

IO_DRIVER  = W65C22
IO_ADDRESS = $6000

; --------------------------------------------------------------------
; UART for serial communication
;
; Since nobody ever seems to be using anything else than the typical
; N-8-1 configuration (no parity, word length 8, 1 stop bit), only
; the baud rate is configurable here.
; --------------------------------------------------------------------

INCLUDE_UART = YES

; Available drivers:
;   W65C51N      - WDC W65C51N ACIA, IRQ-driven RX buffer, timed TX
;   W65C51N_POLL - WDC W65C51N, simple polling, timed TX
;   UM6551       - UM6551/R6551/SY6551 ACIA, IRQ-driven RX/TX buffers
;   UM6551_POLL  - UM6551, simple polling (no IRQ, no buffers)
;
UART_DRIVER    = W65C51N
UART_ADDRESS   = $5000
UART_BAUD_RATE = 19200

; Hardware flow control CTS pin (UM6551 and W65C51N drivers only).
;
; The CTS signal is directly driven via a GPIO pin, rather than
; through the 6551's own DTR or RTS pins (both have side effects that
; make them unusable for clean flow control).
;
; The pin can be on either VIA port. However, avoid placing it on a
; port that is heavily used by other drivers (e.g. LCD data bus),
; because read-modify-write contention on the shared port register
; can cause occasional missed flow control transitions.
;
; Default: PA7 (port A, pin 7).
UART_CTS_PORT  = PORTA
UART_CTS_PIN   = P7

; --------------------------------------------------------------------
; LCD display
;
; To use a different setup, uncomment one of the presets below
; or write your own.
;
; The CMND pins can be assigned to any pin on a single VIA port.
; The DATA pins can only be assigned to P0-7 (in 8 bit mode) or
; P4-7 (in 4 bit mode) of a single VIA port.
; --------------------------------------------------------------------

INCLUDE_LCD = YES

;--------
; Preset: Ben Eater tutorial wiring, 8-bit mode
;
; Same pin layout as used in the tutorial video, with the CMND pins
; connected to VIA port A, and the DATA pins connected to VIA port B.
;
;    HD44780 LCD                           GPIO
;    ┌─────────┐                          ┌─────────┐
;    │         │                     n/c──┤ PA0-4   │
;    │  RS     │◄─────────────────────────| PA5     │
;    │  RWB    │◄─────────────────────────| PA6     │
;    │  E      │◄─────────────────────────| PA7     │
;    │         │                          │         │
;    │  D0     │◄────────────────────────►│ PB0     │
;    │  D1     │◄────────────────────────►│ PB1     │
;    │  D2     │◄────────────────────────►│ PB2     │
;    │  D3     │◄────────────────────────►│ PB3     │
;    │  D4     │◄────────────────────────►│ PB4     │
;    │  D5     │◄────────────────────────►│ PB5     │
;    │  D6     │◄────────────────────────►│ PB6     │
;    │  D7     │◄────────────────────────►│ PB7     │
;    └─────────┘                          └─────────┘

LCD_DRIVER       = HD44780_8BIT
LCD_CMND_PORT    = PORTA         ; CMND pins connected to VIA port A
LCD_CMND_PIN_RS  = P5            ; Register Select
LCD_CMND_PIN_RWB = P6            ; Read/Write
LCD_CMND_PIN_EN  = P7            ; Enable
LCD_DATA_PORT    = PORTB         ; DATA pins connected to VIA port B

;--------
; Preset: Ben Eater tutorial wiring, but in 4-bit mode
;
; Same pin layout as the tutorial video, but only the upper four DATA
; lines (PB4-7) are used. Pins PB0-3 can be disconnected.
;
;    HD44780 LCD                           GPIO
;    ┌─────────┐                          ┌─────────┐
;    │         │                          │         │
;    │         │                     n/c──┤ PA0-4   │
;    │  RS     │◄─────────────────────────| PA5     │
;    │  RWB    │◄─────────────────────────| PA6     │
;    │  E      │◄─────────────────────────| PA7     │
;    │         │                          │         │
;    │  D0-3   │──n/c                n/c──| PB0-3   │
;    │  D4     │◄────────────────────────►│ PB4     │
;    │  D5     │◄────────────────────────►│ PB5     │
;    │  D6     │◄────────────────────────►│ PB6     │
;    │  D7     │◄────────────────────────►│ PB7     │
;    │         │                          │         │
;    └─────────┘                          └─────────┘

;LCD_DRIVER       = HD44780_4BIT
;LCD_CMND_PORT    = PORTA
;LCD_CMND_PIN_RS  = P5            ; Register Select
;LCD_CMND_PIN_RWB = P6            ; Read/Write
;LCD_CMND_PIN_EN  = P7            ; Enable
;LCD_DATA_PORT    = PORTB         ; DATA pins connected to PB4-7

;--------
; Preset: single-port 4-bit mode (all on port B)
;
; CMND and DATA share port B. PB0-PB2 for control, PB4-PB7
; for data, leaving PB3 free for other hardware. Port A is
; entirely available.
;
;    HD44780 LCD                           GPIO
;    ┌─────────┐                          ┌─────────┐
;    │         │                     n/c-─│ PA0-7   │
;    │         │                          │         │
;    │  RS     │◄─────────────────────────┤ PB0     │
;    │  RWB    │◄─────────────────────────┤ PB1     │
;    │  E      │◄─────────────────────────┤ PB2     │
;    │  D0-3   │──n/c                n/c-─| PB3     │
;    │  D4     │◄────────────────────────►│ PB4     │
;    │  D5     │◄────────────────────────►│ PB5     │
;    │  D6     │◄────────────────────────►│ PB6     │
;    │  D7     │◄────────────────────────►│ PB7     │
;    └─────────┘                          └─────────┘

;LCD_DRIVER       = HD44780_4BIT
;LCD_CMND_PORT    = PORTB
;LCD_CMND_PIN_RS  = P0            ; Register Select
;LCD_CMND_PIN_RWB = P1            ; Read/Write
;LCD_CMND_PIN_EN  = P2            ; Enable
;LCD_DATA_PORT    = PORTB         ; DATA pins connected to PB4-7
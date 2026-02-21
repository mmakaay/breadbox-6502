; KERNAL configuration, overriding src/config.inc
;
; This configuration matches the hardware setup as used in
; Ben Eater's tutorial video.

CPU_CLOCK        = 1 * MHZ

IO_ADDRESS       = $6000

INCLUDE_LCD      = YES
LCD_DRIVER       = HD44780_8BIT
LCD_CMND_PORT    = PORTA         ; CMND pins connected to VIA port A
LCD_CMND_PIN_RS  = P5            ; Register Select
LCD_CMND_PIN_RWB = P6            ; Read/Write
LCD_CMND_PIN_EN  = P7            ; Enable
LCD_DATA_PORT    = PORTB         ; DATA pins connected to VIA port B


INCLUDE_UART     = NO            ; No UART yet
INCLUDE_WOZMON   = NO            ; No WozMon yet


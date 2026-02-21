; KERNAL configuration, overriding src/config.inc
;
; This configuration matches the hardware setup as used in
; Ben Eater's tutorial video.

CPU_CLOCK        = 1 * MHZ

IO_ADDRESS       = $6000

INCLUDE_LCD      = NO
INCLUDE_UART     = NO            ; No UART yet
INCLUDE_WOZMON   = NO            ; No WozMon yet


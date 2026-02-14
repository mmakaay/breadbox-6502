; -----------------------------------------------------------------
; W65C22 VIA (Versatile Interface Adapter)
; -----------------------------------------------------------------

.ifndef BIOS_VIA_S
BIOS_VIA_S = 1

; The start of the VIA register space is configured in the
; linker configuration. The linker provides the starting
; address that is imported here.
.import __VIA_START__

.scope VIA

.segment "BIOS"

    ; Registers
    .scope REG
    PORTB     = __VIA_START__ + $0       ; I/O register for port B
    PORTA     = __VIA_START__ + $1       ; I/O register for port A
    DDRB      = __VIA_START__ + $2       ; Data direction for pins B0 - B7 (bit per pin, 0 = in, 1 = out)
    DDRA      = __VIA_START__ + $3       ; Data direction for pins A0 - A7 (bit per pin, 0 = in, 1 = out)
    PCR       = __VIA_START__ + $c       ; Peripheral Control Register (configure CA1/2, CB1/2)
    IFR       = __VIA_START__ + $d       ; Interrupt Flag Register (read triggered interrupt)
    IER       = __VIA_START__ + $e       ; Interrupt Enable Register (configure interrupts)
    .endscope

    .scope BIT
    ; IER register bits
    IER_SET   = %10000000   
    IER_CLR   = %00000000  
    IER_T1    = %01000000   ; Timer 1
    IER_T2    = %00100000   ; Timer 2
    IER_CB1   = %00010000  
    IER_CB2   = %00001000  
    IER_SHR   = %00000100   ; Shift register
    IER_CA1   = %00000010   ; Shift register
    IER_CA2   = %00000001   ; Shift register
    .endscope

.endscope

.endif

; -----------------------------------------------------------------
; BIOS for the Ben Eater breadboard computer
; -----------------------------------------------------------------

.ifndef BIOS_S
BIOS_S = 1

; I use a 65C02, but let's keep the code compatible for 6502.
; This is good for compatibility, but also for forced-upon
; compatibility in cases where Ali Express vendors ship a 6502
; CPU as a 65C02 :-/ (debugging BRA being skipped instead of
; actually branching on 6502 was not that much fun).
.setcpu "6502"

.include "macros/macros.s"
.include "via.s"
.include "lcd.s"
;.include "serial.s"

; Prevent build warnings when a segment is not used in an application.
.segment "DATA"
.segment "VARIABLES"

.scope BIOS

.segment "BIOS"

    boot:
        ldx #$ff               ; Initialize stack pointer
        txs

        jsr init_interrupts    ; Initialze interrupt handling
        jsr LCD::init          ; Initialize LCD display
        jsr LCD::clr           ; Clear LCD display
        ;jsr SERIAL::init       ; Initialize the ACIA serial connection

        jmp main               ; Note: `main` must be implemented by application

    ; Can be jumped to, to fully halt the computer.
    halt:
        jmp halt               ; Stop execution

.segment "ZEROPAGE"

    ; Address vectors, that can be modified in order to point
    ; to a custom interrupt handler.
    nmi_vector: .res 2
    irq_vector: .res 2

.segment "BIOS"

    .proc init_interrupts
        ; Setup the default interrupt handling:
        ; 
        ; - Interrupts disabled
        ; - A null NMI handler
        ; - A null IRQ handler
        ;
        ; Out:
        ;   A = clobbered
        sei                    ; Disable interrupts (must be enabled
                               ; using `cli` when code that uses this
                               ; bios requires interrupts)
        cp_address nmi_vector, default_nmi
        cp_address irq_vector, default_irq

        rts
    .endproc

    dispatch_nmi:
        jmp (nmi_vector)       ; Forward to configured NMI handler
    
    dispatch_irq:
        jmp (irq_vector)       ; Forward to configured IRQ handler

    default_nmi:
        rti
    
    default_irq:
        rti

.segment "VECTORS"

    .word dispatch_nmi         ; Non-Maskable Interrupt vector
    .word boot                 ; Reset vector
    .word dispatch_irq         ; IRQ vector

.endscope

.endif

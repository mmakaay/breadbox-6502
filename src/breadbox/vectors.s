.scope VECTORS

.segment "ZEROPAGE"

    ; Address vectors, that can be modified in order to point
    ; to a custom interrupt handler.
    nmi_vector: .res 2
    irq_vector: .res 2

.segment "KERNAL"

    .proc init
        ; Setup the default vectors and interrupt handling:
        ; 
        ; - Reset vector points to KERNAL::boot
        ; - Null NMI handler
        ; - Null IRQ handler
        ; - Interrupts disabled
        ;
        ; Out:
        ;   A = clobbered

        ; Disable interrupts. If code that uses this KERNAL requires
        ; interrupt handling, these must be enabled using `cli`.
        sei

        CP_ADDRESS nmi_vector, default_nmi
        CP_ADDRESS irq_vector, default_irq

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
    .word ::KERNAL::boot         ; Reset vector
    .word dispatch_irq         ; IRQ vector

.endscope

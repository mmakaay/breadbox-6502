.include "bios/bios.s"
.include "stdlib/divmod16.s"
.include "stdlib/fmtdec16.s"

.segment "DATA"

    hello: .asciiz "Press button!"

.segment "RAM"

    irq_counter:      .word 0
    last_irq_counter: .word 0

.segment "CODE"

    main:
        ; Initialize the IRQ counters
        clr_word irq_counter
        clr_word last_irq_counter

        ; Activate interrupts for VIA's CA1 port
        set_byte VIA::IER_REGISTER, #(VIA::IER_SET | VIA::IER_CA1)
        clr_byte VIA::PCR_REGISTER  ; Trigger interrupt on falling edge

        ; Configure IRQ handler
        cp_address BIOS::irq_vector, handle_irq
        cli

        jsr print_welcome

    @wait_for_button:
        lda irq_counter
        ora irq_counter + 1
        beq @wait_for_button

        jsr LCD::clr

    @loop_irq_counter:
        ; Convert the number to a decimal string.
        ; Disable interrupts, to prevent race conditions on irq_counter.
        sei
        cp_word Regs::word_a, irq_counter
        cli

        ; Did the irq_counter change? 
        lda Regs::word_a
        cmp last_irq_counter
        bne @update
        lda Regs::word_a + 1
        cmp last_irq_counter + 1
        bne @update

        ; No change, wait a bit longer.
        jmp @loop_irq_counter

    @update:
        ; Remember the current value for next comparison.
        cp_word last_irq_counter, Regs::word_a

        ; The IRQ counter has changed. Update LCD display.
        jsr fmtdec16
        jsr LCD::home
        jsr @print_str_reverse

        jmp @loop_irq_counter


    @print_str_reverse:
        ldy Regs::strlen
    @loop:
        cpy #0
        beq @done
        dey
        lda Regs::str,y
        jsr LCD::write_when_ready
        jmp @loop
    @done:
        rts


    print_welcome:
        pha
        txa
        pha
        ldx #0
    @loop:
        lda hello,x
        beq @done
        jsr LCD::write_when_ready
        inx
        jmp @loop
    @done:
        pla
        tax
        pla
        rts


    handle_irq:
        pha
        inc_word irq_counter  ; Increment the IRQ counter
        bit VIA::PORTA_REGISTER   ; Read PORTA to clear interrupt
        pla
        rti


.include "bios/bios.s"
.include "stdlib/divmod16.s"
.include "stdlib/fmtdec16.s"

.segment "DATA"

    hello: .asciiz "Press button!"

.segment "VARIABLES"

    irq_counter: .word   0

.segment "CODE"

    main:
        ; Reset the IRQ counter
        clr_word irq_counter

        ; Activate interrupts for VIA's CA1 port
        set_byte VIA::IER, #(VIA::IER_SET | VIA::IER_CA1)
        clr_byte VIA::PCR  ; Trigger interrupt on falling edge

        ; Configure IRQ handler
        cp_word BIOS::irq_vector, handle_irq
        cli

        jsr hello_world

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
        jsr fmtdec16

        jsr LCD::home
        jsr @print_str_reverse

        bra @loop_irq_counter


    ; Subroutine: print the decimal string.
    ; Out: Y clobbered
    @print_str_reverse:
        ldy Regs::strlen
        @loop:
            cpy #0
            beq @done
            dey
            lda Regs::str,y
            jsr LCD::send_data
            bra @loop
        @done:
            rts


    ; Subroutine: print hello message to the LCD.
    hello_world:
        pha
        phx
        ldx #0
        @loop:
            lda hello,x
            beq @done
            jsr LCD::send_data
            inx
            bra @loop
        @done:
        plx
        pla
        rts


    handle_irq:
        pha
        inc_word irq_counter  ; Increment the IRQ counter
        bit VIA::PORTA             ; Read PORTA to clear interrupt
        pla
        rti


.include "bios/bios.s"
.include "stdlib/common.s"
.include "stdlib/math.s"
.include "stdlib/string.s"
.include "macros/inc16.s"

.segment "DATA"

    hello: .asciiz "Press button!"

.segment "VARIABLES"

    irq_counter: .word   0

.segment "CODE"

    main:
        lda #0
        sta irq_counter           ; Reset the IRQ counter
        sta irq_counter + 1

        lda #(IER_SET | IER_CA1)  ; Activate interrupts for CA1
        sta IER
        lda #0
        sta PCR                   ; Trigger VIA CA1 interrupt on falling edge

        lda #<dispatch_irq        ; Configure IRQ handler to use.
        sta BIOS::irq_vector
        lda #>dispatch_irq
        sta BIOS::irq_vector + 1
        
        cli                       ; Enable interrupts

        jsr hello_world

    @wait_for_button:
        lda irq_counter
        ora irq_counter + 1
        beq @wait_for_button

        jsr lcd_clear

    @loop_irq_counter:
        ; Convert the number to a decimal string.
        sei                         ; Disable interrupts, to prevent race condition
        lda irq_counter             ; when the IRQ counter gets updated right between
        sta String::word2dec::value ; reading the two bytes here.
        lda irq_counter + 1
        sta String::word2dec::value + 1
        cli
        jsr String::word2dec

        jsr lcd_home
        jsr print_decimal

        jmp @loop_irq_counter


    ; Subroutine: print the decimal string.
    ; Out: Y clobbered
    print_decimal:
        pha
        ldy #0
    @loop:
        cpy #5
        beq @done
        lda String::word2dec::decimal,y
        beq @done
        jsr lcd_send_data
        iny
        bra @loop
    @done:
        pla
        rts


    ; Subroutine: print hello message to the LCD.
    hello_world:
        pha
        phx
        ldx #0
    @loop:
        lda hello,x
        beq @done
        jsr lcd_send_data
        inx
        bra @loop
    @done:
        plx
        pla
        rts


    dispatch_irq:
        pha
        inc16 irq_counter  ; Increment the IRQ counter
        bit PORTA          ; Read PORTA to clear interrupt
        pla
        rti


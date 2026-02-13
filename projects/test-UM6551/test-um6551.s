.include "bios/bios.s"

.segment "DATA"

    hello: .asciiz "Serial test"

.segment "CODE"

    main:
        jsr LCD::clr
        jsr @welcome

    @wait_for_rx:
        jsr SERIAL::check_rx
        beq @wait_for_rx

        jsr SERIAL::read
        jsr LCD::send_data
        jmp @wait_for_rx

    @welcome:
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


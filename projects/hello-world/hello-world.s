.include "bios/bios.s"

.segment "CODE"

    main:
        jsr hello_world
        jsr BIOS::halt

    .proc hello_world
        pha
        txa
        pha
        ldx #0
    @loop:
        lda hello,x
        beq @done
        jsr LCD::send_data
        inx
        jmp @loop
    @done:
        pla
        tax
        pla
        rts
    .endproc


.segment "DATA"

    hello:
        .asciiz "Hello, world!"


.include "bios/bios.s"

.segment "DATA"

    hello: .asciiz "Serial test"

.segment "ZEROPAGE"

    status_val: .res 1

.segment "CODE"

    main:
        jsr LCD::clr
        jsr welcome

    @poll:
        ; Read ACIA status register directly
        lda $5001
        sta status_val

        ; Show status bits on LCD line 2
        jsr show_status

        ; Check RXFULL (bit 3)
        lda status_val
        and #$08
        beq @poll

        ; Data received - read it and show on LCD line 1
        lda $5000           ; Read ACIA DATA register
        pha
        jsr LCD::home
        pla
        jsr LCD::write

        jmp @poll


    .proc show_status
        ; Position cursor at start of LCD line 2
        lda #$c0            ; Set DDRAM address = $40 (line 2)
        jsr LCD::write_instruction

        ; Display "S:" prefix
        lda #'S'
        jsr LCD::write
        lda #':'
        jsr LCD::write

        ; Display 8 status bits, MSB first
        ; Bit meaning: IRQ DSR DCD TXE RXF OVR FRM PAR
        ldx #8
    @loop:
        asl status_val      ; Shift MSB into carry
        lda #'0'
        adc #0              ; '0' + carry = '0' or '1'
        jsr LCD::write
        dex
        bne @loop

        rts
    .endproc


    .proc welcome
        ldx #0
    @loop:
        lda hello,x
        beq @done
        jsr LCD::write
        inx
        jmp @loop
    @done:
        rts
    .endproc


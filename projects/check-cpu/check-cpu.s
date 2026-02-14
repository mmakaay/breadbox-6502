; -----------------------------------------------------------------
; CPU check: detect NMOS 6502 vs CMOS 65C02.
;
; Uses the decimal mode ADC flag behavior difference:
;   SED / LDA #$99 / CLC / ADC #$01
;   Result: A = $00 on both CPUs.
;   65C02: Z=1 (Z flag reflects BCD result $00)
;   6502:  Z=0 (Z flag reflects binary intermediate $9A)
;
; The result is shown on the LCD display.
; -----------------------------------------------------------------

.include "bios/bios.s"

.segment "ZEROPAGE"

    ptr: .res 2

.segment "DATA"

    msg_6502:  .asciiz "CPU: NMOS 6502"
    msg_65c02: .asciiz "CPU: CMOS 65C02"

.segment "CODE"

    main:
        ; Detect CPU type using decimal mode Z flag behavior.
        sed
        lda #$99
        clc
        adc #$01        ; A=$00 on both; Z=1 on 65C02, Z=0 on 6502
        cld

        beq @is_65c02

    @is_6502:
        lda #<msg_6502
        sta ptr
        lda #>msg_6502
        sta ptr+1
        jmp @print

    @is_65c02:
        lda #<msg_65c02
        sta ptr
        lda #>msg_65c02
        sta ptr+1

    @print:
        ldy #0
    @loop:
        lda (ptr),y
        beq @done
        jsr LCD::send_data
        iny
        bne @loop       ; branch always (message < 256 bytes)

    @done:
        jmp BIOS::halt

; From: Interrupt handling
; ------------------------
;
; Tutorial : https://www.youtube.com/watch?v=oOYA-jsWTmc
; Result   : https://www.youtube.com/watch?v=oOYA-jsWTmc&t=1276
;
; I implemented the debounce countdown different from how Ben did it in
; the video. I moved the debounce countdown outside the interrupt routine,
; but have it set and checked from inside the interrupt routine. This has
; some advantages over handling the full countdown in the IRQ handler:
;
; - As was mentioned in the video, having the countdown in the handler
;   makes the button presses feel laggy, because the LCD display is only
;   updated after the debounce has completed. In my implementation, the
;   IRQ handler quickly returns after starting the debounce countdown,
;   allowing for immediate feedback to the user, while the deboucing is
;   running in the background.
;
; - Starting the debounce countdown can also be seen as a signal that
;   the interrupt counter value has changed. Only when a new countdown
;   is started, the LCD display is updated with the new value. This
;   saves a lot of resources, compared to continuously updating the LCD,
;   even when there is no new counter value to display.

.include "breadbox/kernal.s"
.include "stdlib/fmtdec16.s"

.segment "ZEROPAGE"

counter:      .word 0
debounce:     .word 0

.segment "CODE"

.proc main
    ; Initialize the variables to zero.
    clr_word counter
    clr_word debounce

    ; Activate interrupts for VIA's CA1 port.
    ; At the time of writing, there is no abstraction layer for this yet,
    ; so here wee only make use of constants as provided by the kernal code
    ; to setup the IRQ pin.
    set_byte IO::IER_REGISTER, #(IO::IER_SET | IO::IER_CA1)
    clr_byte IO::PCR_REGISTER    ; Makes CA1 trigger interrupt on falling edge

    ; Configure and enable the IRQ handler.
    cp_address VECTORS::irq_vector, handle_irq
    cli

@wait_for_change:
    ; Wait until the counter value has changed. We know the counter value
    ; has changed, when a debounce countdown has been activated.
    lda debounce                 ; Check if debounce counter is 0.
    ora debounce + 1
    beq @wait_for_change         ; It is, wait some more.

    ; We've got a new counter value. Update LCD display.
    cp_word ZP::word_a, counter  ; Store counter value in fmtdec16 argument
    jsr fmtdec16                 ; Call fmtdec16 to convert counter to decimal.
    jsr LCD::home                ; Move the LCD cursor to the home position.
    jsr print_str_reverse        ; Print the converted string to the LCD display.

    ; Run the debounce countdown.
@debounce_countdown:
    lda debounce                 ; Check if debounce counter is 0.
    ora debounce + 1
    beq @wait_for_change         ; Yes, go wait for the next change.
    dec_word debounce            ; No, decrement the debounce counter,
    jmp @debounce_countdown      ; and debounce a bit longer.
.endproc

.proc handle_irq
    push_axy                       ; Store the registers.

    lda debounce                   ; When debounce is active, ignore the IRQ.
    ora debounce + 1
    bne @done

    set_word debounce, #$00, #$20  ; Enable debounce countdown.
    inc_word counter               ; Increment the interrupt counter.
    
@done:
    bit IO::PORTA_REGISTER         ; Read PORTA to clear interrupt.
    pull_axy                       ; Restore the registers.
    rti
.endproc

.proc print_str_reverse
    ldy ZP::strlen
@loop:
    cpy #0
    beq @done
    dey
    lda ZP::str,y
    sta LCD::byte
    jsr LCD::write
    jmp @loop
@done:
    rts
.endproc
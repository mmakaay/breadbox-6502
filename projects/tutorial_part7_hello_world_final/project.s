; From: Subroutine calls, now with RAM
; ------------------------------------
;
; Tutorial : https://youtu.be/omI0MrTWiMU
; Result   : https://youtu.be/omI0MrTWiMU?t=927
; Code     : https://eater.net/downloads/hello-world-final.s
;
; When comparing this code to the raw-dogged code as used
; in the tutorial video, it might become clear what advantage
; the kernal project brings. The hardware initialization and
; interaction are encapsulated by the kernal, and in the code
; below, we can make use of the high level `LCD::write`
; subroutine.

.include "breadbox/kernal.s"

message: .asciiz "Hello, world!"

main:
    ldx #0             ; Byte position to read from
@loop:
    lda message,x      ; Read next byte from message
    beq @done          ; Stop at terminating null-byte
    sta LCD::byte      ; Line the byte up for the LCD display
    jsr LCD::write     ; Wait for LCD display ready, then send byte
    inx                ; Move to the next byte position
    jmp @loop          ; And repeat
@done:
    jmp KERNAL::halt   ; Halt the computer
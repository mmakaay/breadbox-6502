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

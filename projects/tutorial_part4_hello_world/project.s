; From: Connecting and LCD to our computer
; ----------------------------------------
;
; Tutorial : https://youtu.be/FY3zTUaykVo
; Result   : https://youtu.be/FY3zTUaykVo?t=1614
; Code     : https://eater.net/downloads/hello-world.s
;
.include "breadbox/kernal.s"

main:
    set_byte LCD::byte, #'H'
    jsr LCD::write

    set_byte LCD::byte, #'e'
    jsr LCD::write

    set_byte LCD::byte, #'l'
    jsr LCD::write

    set_byte LCD::byte, #'l'
    jsr LCD::write

    set_byte LCD::byte, #'o'
    jsr LCD::write

    set_byte LCD::byte, #','
    jsr LCD::write

    set_byte LCD::byte, #' '
    jsr LCD::write

    set_byte LCD::byte, #'w'
    jsr LCD::write

    set_byte LCD::byte, #'o'
    jsr LCD::write

    set_byte LCD::byte, #'r'
    jsr LCD::write

    set_byte LCD::byte, #'l'
    jsr LCD::write

    set_byte LCD::byte, #'d'
    jsr LCD::write

    set_byte LCD::byte, #'!'
    jsr LCD::write

    jmp KERNAL::halt

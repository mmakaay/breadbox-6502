; -----------------------------------------------------------------
; Print module
;
; Generic string printing with configurable output device.
;
; The print procedure walks a null-terminated string via a
; 16-bit pointer, calling an output function for each byte. The
; output function is specified as a function pointer, allowing the
; same print logic to target any output device (LCD, UART, etc.).
;
; HAL modules provide convenience wrappers (e.g. `UART::print`,
; `LCD::print`) that set the writer and call print.
;
; The `PRINT` macro provides a convencience wrapper over those.
;
; For direct use:
;
;   CP_ADDRESS PRINT::string, my_text
;   CP_ADDRESS PRINT::writer, LCD::print
;   jsr PRINT::print
;
; Macro:
;
;   PRINT LCD, my_text
;
; Writer function contract:
;   In:  A = byte to write
;   Out: A, X preserved, Y may be clobbered
; -----------------------------------------------------------------

.ifndef KERNAL_PRINT_S
KERNAL_PRINT_S = 1

.include "breadbox/kernal.s"

.scope PRINT

.segment "ZEROPAGE"

    string: .res 2               ; Pointer to null-terminated string
    writer: .res 2               ; Pointer to output function

.segment "KERNAL"

    .proc print
        ; Print a null-terminated string via the configured writer.
        ;
        ; In (zero page):
        ;   PRINT::string = pointer to null-terminated string
        ;   PRINT::writer = pointer to output function
        ; Out:
        ;   A, X, Y preserved

        PUSH_AXY

        ldy #0
    @loop:
        lda (string),y
        beq @done
        jsr _call_writer
        iny
        bne @loop
        inc string+1             ; Page crossing: bump high byte
        jmp @loop

    @done:
        PULL_AXY
        rts
    .endproc

    ; Trampoline for indirect JSR.
    ;
    ; The 6502 has no `jsr (indirect)` instruction. A `jsr _call_writer`
    ; pushes the return address, then `jmp (writer)` jumps to the target
    ; function, whose `rts` returns to the original caller.
    _call_writer:
        jmp (writer)

.endscope

.macro PRINT device, string_address
    ; PRINT - print a null-terminated string on a given device.
    ;
    ; The procedure `device::print` must exist, to handle the printing.
    ; For example with `print LCD, str`, the procedure `LCD::print`
    ; must exist.
    ;
    ; In:
    ;   device = the device name (e.g. LCD or UART)
    ;   string_address = the address of the string to print
    ; Out:
    ;   A, X, Y preserved

    CP_ADDRESS PRINT::string, string_address
    jsr device::print
.endmacro

.endif

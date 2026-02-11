; Shared, register-like memory definitions that can be used input and/or
; output for subroutines.

.ifndef COMMON_S
COMMON_S = 1

.include "macros/macros.s"

.scope Regs

STR_LEN = 6  ; Only use now is for decimal formatting, with max value "65535"

.segment "ZEROPAGE"
    word_a:   .res 2
    word_b:   .res 2
    word_c:   .res 2

    str:      .res STR_LEN +1  ; String buffer (used by str.s), + 1 for null byte
    strlen:   .res 1           ; Length of the string as stored in str
.endscope

.endif
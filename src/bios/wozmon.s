; -----------------------------------------------------------------
; WozMon, modified for the breadboard computer BIOS
;
; Differences with the original:
; - No hard-coded memory addresses, but using the linker for
;   assigning these automatically.
; - Serial console is used for output.
; - Output is written using `UART::write_text`, which expands
;   CR to CR+LF for correct terminal line endings. Otherwise, the
;   terminal client does not move to the next line on carriage
;   return, unless the client is especially configured to treat
;   "\r" as "\r\n".
; - The Apple II only supports upper case, resulting in the
;   the original code also only working with upper case input.
;   This modified code converts all input to upper case, so
;   the user can also input lower case characters.
; - Like Ben Eater, I made sure that the ECHO routine remained at
;   $FFEF, like described in the Apple II manual.
;
; Even with ECHO at the expected position in memory, the test
; program requires a small modification. The Apple II example
; writes the code directly into the zero page, but that is also in
; use by our BIOS code. Therefore, a different memory location
; must be used for this. For example:
;
;     2000: A9 00 AA 20 EF FF E8 8A 4C 02 20
;
; Just for fun: this disassembles into the following code:
;
;     2000: A9 00     LDA #$00         ; A = 0
;     2002: AA        TAX              ; X = A
;     2003: 20 EF FF  JSR $FFEF        ; Call ECHO routine at $FFEF
;     2006: E8        INX              ; X = X + 1
;     2007: 8A        TXA              ; A = X
;     2008: 4C 02 20  JMP $2002        ; Loop forever
;
; -----------------------------------------------------------------

.ifndef BIOS_WOZMON_S
BIOS_WOZMON_S = 1

.include "bios/bios.s"

.scope WOZMON

    .segment "ZEROPAGE"

    XAML: .res 1       ; Last "opened" location Low
    XAMH: .res 1       ; Last "opened" location High
    STL:  .res 1       ; Store address Low
    STH:  .res 1       ; Store address High
    L:    .res 1       ; Hex value parsing Low
    H:    .res 1       ; Hex value parsing High
    YSAV: .res 1       ; Used to see if hex value is given
    MODE: .res 1       ; $00=XAM, $7F=STOR, $AE=BLOCK XAM
    
    .segment "RAM"

    IN: .res $FF      ; Input buffer

    .segment "WOZMON"

    RESET:
                    ; No hardware initialization required like the original, since
                    ; the BIOS initialization already setup the hardware for us.

                    LDA     #$1B           ; Begin with escape.

    NOTCR:
                    CMP     #$08           ; Backspace key?
                    BEQ     BACKSPACE      ; Yes.
                    CMP     #$1B           ; ESC?
                    BEQ     ESCAPE         ; Yes.
                    INY                    ; Advance text index.
                    BPL     NEXTCHAR       ; Auto ESC if line longer than 127.

    ESCAPE:
                    LDA     #$5C           ; "\".
                    JSR     ECHO           ; Output it.

    GETLINE:
                    LDA     #$0D           ; CR triggers CR+LF via ECHO.
                    JSR     ECHO

                    LDY     #$01           ; Initialize text index.
    BACKSPACE:      DEY                    ; Back up text index.
                    BMI     GETLINE        ; Beyond start of line, reinitialize.

    NEXTCHAR:
                    JSR     UART::read     ; Load character. B7 will be '0'.
                    LDA     UART::byte     ; Get received byte.
                    CMP     #$61           ; Lowercase letter?
                    BCC     @upper
                    SBC     #$20           ; Yes, convert to uppercase (carry set from CMP).
    @upper:
                    STA     IN,Y           ; Add to text buffer.
                    JSR     ECHO           ; Display character.
                    CMP     #$0D           ; CR?
                    BNE     NOTCR          ; No.

                    LDY     #$FF           ; Reset text index.
                    LDA     #$00           ; For XAM mode.
                    TAX                    ; X=0.
    SETBLOCK:
                    ASL
    SETSTOR:
                    ASL                    ; Leaves $7B if setting STOR mode.
                    STA     MODE           ; $00 = XAM, $74 = STOR, $B8 = BLOK XAM.
    BLSKIP:
                    INY                    ; Advance text index.
    NEXTITEM:
                    LDA     IN,Y           ; Get character.
                    CMP     #$0D           ; CR?
                    BEQ     GETLINE        ; Yes, done this line.
                    CMP     #$2E           ; "."?
                    BCC     BLSKIP         ; Skip delimiter.
                    BEQ     SETBLOCK       ; Set BLOCK XAM mode.
                    CMP     #$3A           ; ":"?
                    BEQ     SETSTOR        ; Yes, set STOR mode.
                    CMP     #$52           ; "R"?
                    BEQ     RUN            ; Yes, run user program.
                    STX     L              ; $00 -> L.
                    STX     H              ;    and H.
                    STY     YSAV           ; Save Y for comparison

    NEXTHEX:
                    LDA     IN,Y           ; Get character for hex test.
                    EOR     #$30           ; Map digits to $0-9.
                    CMP     #$0A           ; Digit?
                    BCC     DIG            ; Yes.
                    ADC     #$88           ; Map letter "A"-"F" to $FA-FF.
                    CMP     #$FA           ; Hex letter?
                    BCC     NOTHEX         ; No, character not hex.
    DIG:
                    ASL
                    ASL                    ; Hex digit to MSD of A.
                    ASL
                    ASL

                    LDX     #$04           ; Shift count.
    HEXSHIFT:
                    ASL                    ; Hex digit left, MSB to carry.
                    ROL     L              ; Rotate into LSD.
                    ROL     H              ; Rotate into MSD's.
                    DEX                    ; Done 4 shifts?
                    BNE     HEXSHIFT       ; No, loop.
                    INY                    ; Advance text index.
                    BNE     NEXTHEX        ; Always taken. Check next character for hex.

    NOTHEX:
                    CPY     YSAV           ; Check if L, H empty (no hex digits).
                    BEQ     ESCAPE         ; Yes, generate ESC sequence.

                    BIT     MODE           ; Test MODE byte.
                    BVC     NOTSTOR        ; B6=0 is STOR, 1 is XAM and BLOCK XAM.

                    LDA     L              ; LSD's of hex data.
                    STA     (STL,X)        ; Store current 'store index'.
                    INC     STL            ; Increment store index.
                    BNE     NEXTITEM       ; Get next item (no carry).
                    INC     STH            ; Add carry to 'store index' high order.
    TONEXTITEM:     JMP     NEXTITEM       ; Get next command item.

    RUN:
                    JMP     (XAML)         ; Run at current XAM index.

    NOTSTOR:
                    BMI     XAMNEXT        ; B7 = 0 for XAM, 1 for BLOCK XAM.

                    LDX     #$02           ; Byte count.
    SETADR:         LDA     L-1,X          ; Copy hex data to
                    STA     STL-1,X        ;  'store index'.
                    STA     XAML-1,X       ; And to 'XAM index'.
                    DEX                    ; Next of 2 bytes.
                    BNE     SETADR         ; Loop unless X = 0.

    NXTPRNT:
                    BNE     PRDATA         ; NE means no address to print.
                    LDA     #$0D           ; CR triggers CR+LF via ECHO.
                    JSR     ECHO
                    LDA     XAMH           ; 'Examine index' high-order byte.
                    JSR     PRBYTE         ; Output it in hex format.
                    LDA     XAML           ; Low-order 'examine index' byte.
                    JSR     PRBYTE         ; Output it in hex format.
                    LDA     #$3A           ; ":".
                    JSR     ECHO           ; Output it.

    PRDATA:
                    LDA     #$20           ; Blank.
                    JSR     ECHO           ; Output it.
                    LDA     (XAML,X)       ; Get data byte at 'examine index'.
                    JSR     PRBYTE         ; Output it in hex format.
    XAMNEXT:        STX     MODE           ; 0 -> MODE (XAM mode).
                    LDA     XAML
                    CMP     L              ; Compare 'examine index' to hex data.
                    LDA     XAMH
                    SBC     H
                    BCS     TONEXTITEM     ; Not less, so no more data to output.

                    INC     XAML
                    BNE     MOD8CHK        ; Increment 'examine index'.
                    INC     XAMH

    MOD8CHK:
                    LDA     XAML           ; Check low-order 'examine index' byte
                    AND     #$07           ; For MOD 8 = 0
                    BPL     NXTPRNT        ; Always taken.

    PRBYTE:
                    PHA                    ; Save A for LSD.
                    LSR
                    LSR
                    LSR                    ; MSD to LSD position.
                    LSR
                    JSR     PRHEX          ; Output hex digit.
                    PLA                    ; Restore A.

    PRHEX:
                    AND     #$0F           ; Mask LSD for hex print.
                    ORA     #$30           ; Add "0".
                    CMP     #$3A           ; Digit?
                    BCC     ECHO           ; Yes, output it.
                    ADC     #$06           ; Add offset for letter.

                    NOP                    ; A bunch of NOP instructions, in order to move
                    NOP                    ; the ECHO routine to the same location as defined
                    NOP                    ; in the original Apple II manual ($FFCF).
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP
                    NOP

    ECHO:
                    STA     UART::byte
                    JSR     UART::write_text
                    RTS

.endscope

.endif

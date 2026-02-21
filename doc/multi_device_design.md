# Multi-Device Support — Design Notes

## The problem

The KERNAL currently assumes exactly one of each device: one VIA, one LCD, one
UART. Every hardware module is a singleton. This document explores how to support
multiple instances of the same device type — for example two VIAs, two LCD
displays, or a mix of different I/O controllers.

## Where the coupling lives today

Three layers are hardwired to "exactly one":

1. **IO base address** — The GPIO driver reads from a single `__IO_START__`
   linker symbol. A second VIA at a different address has no way in.

2. **GPIO to device binding** — LCD and UART call `GPIO::set_pins`,
   `GPIO::turn_on`, etc., which always operate on the single VIA. There is no
   way to say "the GPIO pins on *that other* VIA."

3. **HAL singletons** — `LCD::byte` is one zero-page variable, `LCD::write` is
   one procedure. There is no concept of "which LCD."

The port selection trick (`GPIO::port` selecting port A or B via the Y register)
is a good precedent — it already parameterizes *within* a single VIA. The goal
is to extend that pattern *across* multiple devices.

## Constraints on the 6502

Any solution must be cheap. The 6502 has hard resource limits:

| Resource   | Limit                                               |
|------------|-----------------------------------------------------|
| Zero page  | 256 bytes total, shared across all modules          |
| ROM        | 32K, shared between KERNAL and application          |
| CPU cycles | No caches, no pipeline; every indirection is felt   |
| Tooling    | No type system to catch wiring mistakes at compile  |

## Recommended approach

Use **compile-time macro instantiation** for the device HAL layer (LCD, UART),
built on top of a **parameterized GPIO layer** that accepts a base address.

### Step 1 — Make GPIO base-address-aware

This is the foundational change. The GPIO driver currently uses absolute
addressing against the fixed VIA registers:

```asm
; Current: hardcoded to a single VIA
lda IO::PORTB_REGISTER,Y       ; Address resolved at link time from __IO_START__
```

Instead, introduce a zero-page pointer that holds the base address of the
*current* I/O device:

```asm
; New: indirect through a selectable base address
.segment "ZEROPAGE"
    io_base: .res 2             ; Pointer to the active IO device base address

.segment "KERNAL"
    .proc read_port
        pha
        tya
        pha

        ldy port
        lda (io_base),y         ; Read from base + port offset
        sta value

        pla
        tay
        pla
        rts
    .endproc
```

The register offsets (port B = base+0, port A = base+1, DDRB = base+2, etc.)
remain the same — they are VIA-inherent. But the *base* is no longer a
link-time constant. It lives in zero page and can be set before each call.

A small macro makes device selection readable:

```asm
.macro select_io addr
    ; Point GPIO to a specific IO device.
    ;
    ; In:
    ;   addr = base address constant (e.g., VIA1_BASE)
    ; Out:
    ;   GPIO::io_base = addr
    ;   A = clobbered
    SET_WORD GPIO::io_base, #<addr, #>addr
.endmacro
```

### Step 2 — Move hardware addresses to config.inc

The VIA base address currently comes from the linker config (`breadbox.cfg`)
via an imported symbol. For multi-device support, it is simpler to define device
base addresses as assembly constants in `config.inc`, alongside the existing
driver and pin configuration:

```asm
; config.inc

VIA1_BASE = $6000               ; Primary VIA (accent on the accent)
VIA2_BASE = $7000               ; Secondary VIA (accent on the accent)

UART_BASE = $5000               ; UART base address
```

This replaces the linker `define = yes` / `.import __IO_START__` pattern for
these devices. The linker memory regions in `breadbox.cfg` still need entries
for the hardware address ranges (to prevent the linker from placing code there),
but the actual addresses used in driver code come from `config.inc`.

The UART driver would follow the same pattern — read from a configurable base
address constant rather than importing `__UART_START__`.

### Step 3 — Instantiate device HAL modules

This is where "compile-time instantiation" comes in. The idea is to use the
assembler's macro and scoping features to create multiple independent copies of
a module, each with its own configuration baked in.

#### What "compile-time instantiation" means

In languages with classes, you write one class and create multiple objects from
it at runtime. In 6502 assembly, there are no objects, but you can achieve
something similar at compile time: write the driver logic once as a macro, and
invoke that macro multiple times with different parameters. Each invocation
produces a separate, independent block of code and zero-page variables in the
assembled output.

Think of it as a template. You write the template once, and the assembler
"stamps out" a copy for each device — filling in the specific addresses, pins,
and driver choices. The word "stamp" is used because it is like a rubber stamp:
you have one stamp (the template), and you press it onto the page (the ROM)
multiple times, each time with different ink (the configuration).

Here is a concrete example for LCD. Today, there is one `LCD` scope:

```asm
; --- Current: single LCD instance ---

.scope LCD
    .segment "ZEROPAGE"
        byte: .res 1

    .segment "KERNAL"
        .proc write
            ; ... driver code that talks to the one VIA ...
        .endproc
.endscope
```

To support two LCDs, you would define the driver logic inside a macro:

```asm
; --- Template: defines one complete LCD instance ---

.macro define_lcd name, io_base, driver, cmnd_port, cmnd_rs, cmnd_rwb, cmnd_en, data_port

    .scope name

        .segment "ZEROPAGE"
            byte: .res 1       ; Each instance gets its own byte

        .segment "KERNAL"

            .proc write
                ; Select the right IO device for this LCD instance.
                select_io io_base

                ; From here, the code is the same as today, but it operates
                ; on whichever VIA was selected above.
                pha
                SET_BYTE GPIO::port, #data_port
                SET_BYTE GPIO::value, byte
                jsr GPIO::write_port
                ; ... pulse EN, etc. ...
                pla
                rts
            .endproc

            ; ... other procedures (init, check_ready, write_cmnd, etc.) ...

    .endscope

.endmacro
```

Then in the KERNAL (or a setup file), you invoke the macro once per LCD:

```asm
; --- Instantiation: stamp out two LCD instances ---

define_lcd LCD0, VIA1_BASE, HD44780_8BIT, PORTA, P5, P6, P7, PORTB
define_lcd LCD1, VIA2_BASE, HD44780_4BIT, PORTB, P0, P1, P2, PORTB
```

After assembly, the ROM contains two independent sets of LCD routines:

- `LCD0::byte`, `LCD0::write`, `LCD0::init`, etc. — talks to VIA at `$6000`
- `LCD1::byte`, `LCD1::write`, `LCD1::init`, etc. — talks to VIA at `$7000`

Application code uses them by name:

```asm
main:
    lda #'H'
    sta LCD0::byte
    jsr LCD0::write         ; Write 'H' to the first display

    lda #'i'
    sta LCD1::byte
    jsr LCD1::write         ; Write 'i' to the second display
```

Each instance is completely self-contained. There is no runtime dispatch, no
shared state between instances, and no indirect jumps. The assembler has done
all the work.

#### Configuration in config.inc

Rather than the current flat constants (`LCD_DRIVER`, `LCD_CMND_PORT`, ...),
the configuration would be grouped per instance. Since ca65 does not have
structs or arrays of constants, a practical approach is a naming convention
with a prefix per instance:

```asm
; config.inc

INCLUDE_LCD = YES
LCD_COUNT   = 2

; Instance 0: 8-bit LCD on VIA #1
LCD0_IO_BASE      = VIA1_BASE
LCD0_DRIVER       = HD44780_8BIT
LCD0_CMND_PORT    = PORTA
LCD0_CMND_PIN_RS  = P5
LCD0_CMND_PIN_RWB = P6
LCD0_CMND_PIN_EN  = P7
LCD0_DATA_PORT    = PORTB

; Instance 1: 4-bit LCD on VIA #2
LCD1_IO_BASE      = VIA2_BASE
LCD1_DRIVER       = HD44780_4BIT
LCD1_CMND_PORT    = PORTB
LCD1_CMND_PIN_RS  = P0
LCD1_CMND_PIN_RWB = P1
LCD1_CMND_PIN_EN  = P2
LCD1_DATA_PORT    = PORTB
```

The instantiation macros read these constants to generate the right code.

### Step 4 — Two LCDs on one VIA

A specific and interesting case: two 4-bit LCDs sharing a single VIA. Since
4-bit mode only uses pins P4-P7 for data, the control pins determine which LCD
is active. Both LCDs can share the same data port and even the same data pins,
as long as they have separate EN (enable) lines:

```asm
;   LCD #0 control: PA5 = RS, PA6 = RWB, PA7 = EN
;   LCD #1 control: PA2 = RS, PA3 = RWB, PA4 = EN
;   Shared data:    PB4-PB7

LCD0_IO_BASE      = VIA1_BASE
LCD0_DRIVER       = HD44780_4BIT
LCD0_CMND_PORT    = PORTA
LCD0_CMND_PIN_RS  = P5
LCD0_CMND_PIN_RWB = P6
LCD0_CMND_PIN_EN  = P7
LCD0_DATA_PORT    = PORTB

LCD1_IO_BASE      = VIA1_BASE       ; Same VIA
LCD1_DRIVER       = HD44780_4BIT
LCD1_CMND_PORT    = PORTA           ; Same port, different pins
LCD1_CMND_PIN_RS  = P2
LCD1_CMND_PIN_RWB = P3
LCD1_CMND_PIN_EN  = P4
LCD1_DATA_PORT    = PORTB           ; Same data port and pins
```

This works because each instance only touches its own EN/RS/RWB pins via masked
GPIO operations (`GPIO::set_pins` with a mask). The other LCD's control pins
are not disturbed. Data pins are shared but only active during an EN pulse, and
only one LCD is ever pulsed at a time.

No changes to the driver code are needed for this — the macro instantiation
handles it naturally, because each instance has its own pin mask constants.

## What this costs

| Resource  | Current (1 LCD) | Two LCDs (macro approach) |
|-----------|-----------------|---------------------------|
| Zero page | 1 byte          | 2 bytes (+1)              |
| ROM       | ~200 bytes      | ~400 bytes (+200)         |
| CPU       | No overhead     | No overhead               |

The ROM duplication is the main cost. For two or three devices, this is
acceptable within 32K. If device counts grow larger, the shared-code approach
(using `select_io` to switch between instances before calling shared driver
routines) can reduce duplication at the cost of slightly more complex code.

## Migration path

A practical order of changes, each self-contained and buildable:

1. **Move VIA/UART base addresses from linker config to `config.inc`.**
   Define `VIA1_BASE` and `UART_BASE` as constants. Update `io/w65c22.s` and
   `uart.s` to use these instead of importing linker symbols. Keep the linker
   memory regions for address range reservation.

2. **Add `GPIO::io_base` to zero page.** Refactor `gpio/w65c22.s` to use
   indirect addressing through `io_base` instead of the absolute
   `IO::PORTB_REGISTER` addresses. Initialize `io_base` to `VIA1_BASE` during
   boot so existing code keeps working without changes.

3. **Add `select_io` macro.** Existing LCD/UART code can insert a `select_io`
   call at the top of each public procedure to explicitly set the IO device.
   For a single-VIA setup this is redundant but harmless, and it establishes
   the pattern.

4. **Convert LCD to a macro template.** Extract the driver logic into a
   `define_lcd` macro. Replace the current `LCD` scope with a single
   invocation: `define_lcd LCD, VIA1_BASE, ...`. The API (`LCD::write`, etc.)
   remains identical — existing projects do not break.

5. **Enable multi-LCD.** Add a second invocation in a project that needs it.
   At this point the infrastructure is in place and adding instances is just
   configuration.

Each step can be built and tested independently on hardware before moving to
the next.

## Alternative considered: runtime device descriptors

Instead of compile-time instantiation, device configuration could live in a
struct (a few bytes in ROM or RAM), with a zero-page pointer selecting the
active device at runtime. Driver code would read pin assignments and base
addresses from the struct via indirect indexed addressing.

This saves ROM (driver code exists only once) but adds indirection to every
hardware access, makes the driver code harder to follow, and uses more CPU
cycles. For a breadboard computer where the device count is known at build
time, the compile-time approach is simpler and more in line with how 6502
software is traditionally structured.

The runtime approach would become worthwhile if the system needed to support
a truly variable number of devices, for example a bus with hot-pluggable
peripherals. That is unlikely for this project, but the GPIO base-address
refactor (step 2) keeps the door open for it.

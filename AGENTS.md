# AGENTS.md - Breadbox 6502 KERNAL

## Project Overview

A KERNAL (boot sequence, HAL, drivers, stdlib) for Ben Eater-style 6502 breadboard computers.
Written in 6502 assembly using the **cc65** toolchain (ca65 assembler, ld65 linker).
An external emulator binary (Clementina 6502, Go-based) is included but not part of this build.

## Build System

**Toolchain**: cc65 suite (ca65, ld65, da65). Install via `brew install cc65` or build from source.
**Task runner**: `just` (install: `brew install just`). See `Justfile` at repo root.

```bash
# All build commands run FROM a project directory (e.g., projects/hello-world/)
cd projects/some-project

just build    # Assemble all *.s files, link into rom.bin (cleans first)
just clean    # Remove *.bin, *.o, *.a in current directory
just dump     # hexdump -C rom.bin
just dis      # da65 disassembly of rom.bin
just write    # Flash rom.bin to AT28C256 EEPROM via minipro
just write-u  # Same as write, but disables write protection first
```

### Manual build (equivalent to `just build`)

```bash
cd projects/some-project
ca65 -I . -I ../../src/ *.s
ld65 --config ../../src/breadboard.cfg *.o -o rom.bin
```

### Include paths

ca65 searches two include roots: the project directory itself and `src/`.
All KERNAL includes use paths relative to `src/` (e.g., `"breadbox/kernal.s"`, `"macros/macros.s"`).

### There are no automated tests

Testing is done manually on hardware or with the Clementina emulator (`emulator/clementina -r rom.bin`).

## Repository Layout

```
src/
  breadboard.cfg          # ld65 linker config (memory map & segments)
  config.inc              # Active hardware config (gitignored; copy config-example.inc)
  config-example.inc      # Documented example configuration
  breadbox/
    kernal.s              # KERNAL entry point, boot sequence, top-level includes
    constants.s           # Global unscoped constants for use in config.inc
    vectors.s             # Reset/NMI/IRQ vectors (dispatched via zero-page pointers)
    gpio.s                # GPIO HAL (port/pin abstraction over VIA)
    gpio/w65c22.s         # GPIO driver for W65C22 VIA
    io/w65c22.s           # VIA register definitions (imported via linker symbol)
    lcd.s                 # LCD HAL (check_ready, write, write_cmnd, clr, home)
    lcd/hd44780_8bit.s    # HD44780 8-bit driver
    lcd/hd44780_4bit.s    # HD44780 4-bit driver
    lcd/hd44780_common.s  # Shared LCD constants (BUSY_FLAG, clr, home)
    uart.s                # UART HAL (read, write, write_text, check_rx/tx)
    uart/um6551.s         # UM6551 driver (IRQ, buffered, flow control)
    uart/um6551_poll.s    # UM6551 polling driver (simple, no IRQ)
    uart/um6551_common.s  # Shared UART register definitions
    wozmon.s              # WozMon (Apple I monitor, adapted for KERNAL)
  macros/                 # General-purpose macros (set_byte, set_word, cp_address, etc.)
  stdlib/                 # Optional reusable procedures (divmod16, str, fmtdec16)
projects/                 # Each subdirectory is a standalone project
  hello-world/            # Minimal example
  wozmon/                 # WozMon serial monitor
  test-UART/              # UART serial test
  test-CPU/               # CPU test
  tutorial_*/             # Ben Eater tutorial re-implementations
```

## Code Style & Conventions

### CPU target

All code targets NMOS 6502 (`.setcpu "6502"`), not 65C02. This is intentional for
compatibility, even though the hardware uses a W65C02.

### Assembly formatting

- **Indentation**: 4 spaces (no tabs). Applies to all files (`.editorconfig`).
- **Instructions**: Always indented (4 spaces from column 0).
- **Labels**: Global labels flush left, no indent. Local labels (`@label`) indented.
- **Comments**: Inline comments use `;` aligned to a consistent column (usually col ~32-40).
  Block/header comments use `;` at column 0 with dashed separator lines.
- **Blank lines**: Separate logical blocks. No excessive blank lines.

### Naming conventions

| Element | Style | Example |
|---------|-------|---------|
| Scopes | PascalCase | `KERNAL`, `LCD`, `GPIO`, `UART`, `WOZMON` |
| Scope constants | UPPER_SNAKE | `PORTB_REGISTER`, `CMND_PIN_EN` |
| Global constants | UPPER_SNAKE | `HD44780_8BIT`, `BAUD19200`, `YES`, `NO` |
| Procedures (.proc) | snake_case | `write_cmnd`, `check_ready`, `set_cursor_line1` |
| Labels (global) | snake_case | `boot`, `halt`, `dispatch_nmi` |
| Labels (local @) | snake_case | `@loop`, `@done`, `@wait`, `@overflow` |
| Macros | snake_case | `set_byte`, `cp_address`, `push_axy` |
| Zero-page vars | snake_case | `byte`, `port`, `mask`, `value`, `cursor` |

### Include guards

Every `.s` file uses a manual include guard pattern:

```asm
.ifndef FILENAME_S
FILENAME_S = 1
; ... file contents ...
.endif
```

### Scoping (`.scope` / `.endscope`)

Modules are wrapped in `.scope` blocks: `GPIO`, `LCD`, `UART`, `IO`, `KERNAL`, `VECTORS`, `WOZMON`.
Drivers within a module use `.scope DRIVER` (see `lcd/hd44780_8bit.s`, `gpio/w65c22.s`).
Public API symbols are aliased at the module level (e.g., `init = DRIVER::init`).

### Procedures (`.proc` / `.endproc`)

Used for all non-trivial subroutines. Each `.proc` has a header comment documenting:
- What it does (one line)
- `In:` parameters (zero-page variables or registers)
- `Out:` return values and which registers are preserved/clobbered

### Register preservation

**Convention**: All public API procedures preserve A, X, Y (push on entry, pop on exit).
Document deviations explicitly with `A = clobbered` in the `Out:` section.
Macros typically clobber A and document this.

### Parameter passing

Parameters are passed via **zero-page variables** scoped to each module:
- `LCD::byte` for LCD operations
- `UART::byte` for UART operations
- `GPIO::port`, `GPIO::mask`, `GPIO::value` for GPIO operations
- `ZP::word_a`, `ZP::word_b`, etc. for stdlib routines

### Segments

Defined in `breadboard.cfg`. Code must use the correct segment directives:

| Segment | Use |
|---------|-----|
| `ZEROPAGE` | Zero-page variables (`.res N`) |
| `RAM` | RAM buffers |
| `KERNAL` | KERNAL/driver code (ROM, loaded before application) |
| `CODE` | Application/project code (ROM) |
| `DATA` | Read-only data in ROM |
| `WOZMON` | WozMon code ($FF00-$FFF9) |
| `VECTORS` | CPU vectors ($FFFA-$FFFF) |

### Conditional compilation

Hardware features are toggled via `config.inc` constants (`INCLUDE_LCD`, `INCLUDE_UART`,
`INCLUDE_WOZMON`) using `.ifdef` / `.if` guards. After conditional includes, presence
flags like `HAS_LCD` and `HAS_UART` indicate what was included.

### Hardware addresses

Never hard-code hardware addresses. Use linker-exported symbols:
- `__IO_START__` for VIA registers (imported in `io/w65c22.s`)
- `__UART_START__` for UART registers (imported in `uart.s`)

### Project structure

Every project has a single `project.s` file that:
1. Includes `"breadbox/kernal.s"` as first line
2. Implements a `main:` label (jumped to after KERNAL boot)
3. Optionally places a `config.inc` in the project dir to override `src/config.inc`

### Error handling

Assembly-level: use carry flag for error signaling (SEC = error, CLC = success).
Build-time: use `.error "message"` for invalid configuration.

### Macros usage

Prefer macros from `src/macros/` for common operations:
- `set_byte target, value` - store byte (clobbers A)
- `set_word target, lo, hi` - store 16-bit word (clobbers A)
- `cp_address target, source` - copy address to pointer (clobbers A)
- `clr_byte target` / `clr_word target` - zero out memory
- `inc_word target` / `dec_word target` - 16-bit increment/decrement
- `push_axy` / `pull_axy` - save/restore all registers

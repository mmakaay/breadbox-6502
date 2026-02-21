# BREADBOX 6502

This repository provides a KERNAL for 6502 breadboard computers.
No, "KERNAL" is not a typo: [see Wikipedia](https://en.wikipedia.org/wiki/KERNAL)

It was inspired by Ben Eater's 6502 breadboard tutorial series, and my desire
to revive and brush up my 1982 assembly skills.

See Ben's website at [https://eater.net](https://eater.net) for many useful
resources and a very binge-worthy collection of tutorial videos
(only binge-worthy if you are into this kind of thing, of course).

Of course, this code will work equally well for breadboard computers that have
been materialized as a real PCB.

## Features

Projects are built on top of the KERNAL functionality. A project starts out by
including the KERNAL code, and implementing the subroutine `main` to tell the
computer what to do after the KERNAL has initialized.

KERNAL:

- Configurable hardware (at compile time)
- Various hardware drivers
- Hardware Abstraction Layer (HAL) - APIs to access hardware from your project
- Boot sequence that initializes the system and hardware
- Project-specific `main` routine, called by boot sequence after initialization
- IRQ jump vectors (for IRQ and NMI) can be changed dynamically
- Macros for commonly repeated bits of code
- A stdlib (standard library) with routines you can include in your project
- Written using the feature-rich `ca65` assembler from the `cc65` project

Extra components:

- An improved version of WozMon (Apple II monitor application)

Demo software:

- Example projects in `projects/`
- including re-implementations of Ben's tutorial code using BREADBOX

## Hello, world

The mandatory example for any project:

```asm
.include "breadbox/kernal.s"

message: .asciiz "Hello, world!"

main:
    PRINT LCD, message     ; Print the greeting on the LCD display
    HALT
```

What you can see here is that hardware is abstracted by the KERNAL's HAL
layers, and that the code only has to worry about providing the required bytes
to the LCD display. The `PRINT` and `HALT` macros take care of the low-level
code. Of course, it is still possible to roll your own assembly code for this.

See also `projects/hello-world`.

## Writing assembly code

`vasm` is what Ben starts out with in his videos, but later on he uses the `cc65` suite.
This suite provides *a lot* of useful features, and I have written all assembly code
for this repository based on this.

The suite can be built using:

```bash
git clone https://github.com/cc65/cc65
cd cc65
make
```

Documentation at: https://cc65.github.io/doc/

## Configure the build

To support different configurations (hardware and features), you have to
provide a configuration file `config.inc`. This configuration file can for
example be used to configure what VIA pins to use for the LCD display and
whether to enable the WozMon component. You can place this configuration
file in your project directory, or in `src/config.inc` to have a
configuration that is shared between multiple projects.

An example configuration with explanation about the configuration options
can be found in `src/config-example.inc`.

Sounds difficult? No worries... The projects (under `projects/*`) that
re-implement the code from Ben's tutorial videos, all have a configuration
that matches the hardware layout as used in the videos. So if you are
following along with the videos, the related tutorial projects should
work as-is.

For information on configuration options, see the `src/config-example.inc`
file. Copy this file to `src/config.inc` or your own project directory to
get started.

## Build a ROM

To build a ROM from assembly code, a `Justfile` is provided, that can
be used to build the ROM images from `projects/*`.

The `just` tool is a lot like `make`, only it is more about performing
tasks than about build structuring, and it allows for hierarchical
`Justfile`s in the directory structure. It can be installed using
`brew install just`.

Documentation at: https://just.systems/man/en/

Some commands that can be used:

```bash
cd projects/some-project
just build  # Compiles *.s files, and links them into a `rom.bin`.
just write  # Writes `rom.bin` to EEPROM (given you use AT28C256 like Ben).
just dis    # Shows a disassembly of the created `rom.bin`.
just dump   # Shows a hexdump of the created `rom.bin`.
```

It is not required to use `just` of course. You can also execute the
various commands by hand. You can take a look at the `Justfile` as a starting
point for this.

## T48 EEPROM writer

For writing the ROM, I use a T48 writer.

Lesson learned: connect the device *directly* to a USB-C port on the computer.
It won't work when connected to a HUB, recognizable by a blinking LED.

There is no vendor software for macOS, but the open source application
`minipro` can be used. This can be installed from homebrew with
`brew install minipro`.

## Write an EEPROM

To write a ROM image to an EEPROM:

```bash
minipro -p AT28C256 -w rom.bin

# or equivalent using the `Justfile` recipe

just write
```

The EEPROM might be write protected. In that case, the extra option `-u` can
be used. The `minipro` application will warn about write protected EEPROMs
and suggest this flag. I had to disable write protection when I wrote to the
EEPROM for the first time.

```bash
minipro -u -p AT28C256 -w rom_image.bin

# or equivalent using the `Justfile` recipe

just write-u
```

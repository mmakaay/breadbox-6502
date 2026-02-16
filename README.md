# 65C02 breadboard computer

This repository contains information and code for my version
of Ben Eater's breadboard computer. See Ben's website at
[https://eater.net](https://eater.net) for many useful resources
and a very binge-worthy collection of explanation videos (only
binge-worthy, if you are into this kind of thing, of course).

## Coding a ROM 

A shabby way of doing it, is directly writing the bytes out to a file:

```python
#!/usr/bin/env python3

# Fill the full rom with NOPs.
rom = bytearray([0xea] * 32768)

rom[0] = 0xa9  # LDA #$42
rom[1] = 0x42

rom[2] = 0x8d  # STA $6000
rom[3] = 0x00
rom[4] = 0x60

# Set the boot pointer to the start of the ROM.
rom[0x7ffc] = 0x00
rom[0x7ffd] = 0x80

with open("some.bin", "wb") as f:
    f.write(rom)
```

A better and eventually easier way is to use an assembler.
Wasm is what Ben starts out with in his videos, but later on he
uses the "cc65" suite. This suite provides *a lot* of useful
features, and I have written all assembly code from this
repository using this.

```bash
git clone https://github.com/cc65/cc65
cd cc65
make
```

Documentation at: https://cc65.github.io/doc/

I have based all my code on cc65
See `src/` and `projects/` for examples.

## T48 EEPROM writer

For writing the ROM, I use a T48 writer.

Do connect the device directly to a USB-C port on the MacBook.
It won't work when connected to a HUB (not enough power I
presume).

There is no vendor software for MacBook, but the open source
application `minipro` can be used. This can be installed from
homebrew with `brew install minipro`.

## Write an EEPROM

To write a ROM image to an EEPROM:

```bash
minipro -p AT28C256 -w rom_image.bin
```

The EEPROM might be write protected. In that case, the extra
option `-u` can be used. The `minipro` application will warn
about write protected EEPROMs and suggest this flag.

## Build

To build a ROM, a `Justfile` is provided, that can be used to build
the ROM images from `projects/*`.

The `just` tool is a lot like `make`, only it is more about
performing tasks than about build structuring, and it allows for
hierarchical `Justfile`s in the directory structure. It can be
installed using `brew install just`.

Some commands that can be used:

```bash
cd src/some_rom_code
just build  # Compiles *.asm files, and links them into a `rom.bin`.
just write  # Writes the `rom.bin` to the EEPROM.
```


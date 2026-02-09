# Using the T38 EEPROM writer

## Setup 

Do connect the device directly to a USB-C port on the MacBook.
It won't work when connected to a HUB (not enough power I
presume).

There is no vendor software for MacBook, but the open source
application `minipro` can be used. This can be installed from
homebrew with `brew install minipro`.

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
Wasm is an option for this, but it looks like the cc65 suite provides
more useful features for this: https://cc65.github.io/

```bash
git clone https://github.com/cc65/cc65
cd cc65
make
```

Documentation at: https://cc65.github.io/doc/

See src/ for examples.

## Write an EEPROM

To write an EEPROM image (usingn a T48 writer) to the EEPROM
that I bought for the breadboard 6205 project:

```bash
minipro -p AT28C256 -w rom_image.bin
```

The EEPROM might be write protected. In that case, the extra
option `-u` can be used. The `minipro` application will warn
about write protected EEPROMs and suggest this flag.

## Build tooling

To build a ROM, a `Justfile` is provided in `src/`, that can be
used to build the ROM images from `src/*`.

The `just` tool is a lot like `make`, only it is more about
performing tasks than about build structuring, and it allows for
hierarchical `Justfile`s in the directory structure. It can be
installed using `brew install just`.

Commands that can be used:

```bash
cd src/some_rom_code
just build  # Compiles *.asm files, and links them into a `rom.bin`.
just write  # Writes the `rom.bin` to the EEPROM.
```


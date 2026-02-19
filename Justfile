help:
    @just --list

# Build ROM from invocation directory
build: clean
    #!/bin/bash
    echo "Building rom.bin for project ..."
    cd "{{invocation_directory()}}"
    ca65 -I "{{invocation_directory()}}" -I "{{justfile_directory()}}/src/" *.s
    ld65 --config "{{justfile_directory()}}/src/breadbox.cfg" *.o -o rom.bin

dump:
    hexdump -C "{{invocation_directory()}}/rom.bin"

dis:
    da65 --cpu 6502 "{{invocation_directory()}}/rom.bin"

# Build and write ROM from invocation directory to EEPROM
write:
    #!/bin/bash
    cd "{{invocation_directory()}}"
    minipro -p AT28C256 -w rom.bin

write-u:
    #!/bin/bash
    cd "{{invocation_directory()}}"
    minipro -u -p AT28C256 -w rom.bin

# Clean up in invocation directory
clean:
    #!/bin/bash
    cd "{{invocation_directory()}}"
    rm -f *.bin *.o *.a



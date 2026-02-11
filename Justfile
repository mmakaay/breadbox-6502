help:
    @just --list

# Build ROM from invocation directory
build:
    #!/bin/bash
    cd "{{invocation_directory()}}"
    ca65 --include-dir "{{justfile_directory()}}/src/" *.s
    ld65 --config "{{justfile_directory()}}/src/breadboard.cfg" *.o -o rom.bin

# Write ROM from invocation directory to EEPROM
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



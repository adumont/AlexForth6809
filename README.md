# AlexForth for 6809

# Introduction

This is a port of my [AlexForth for 6502](https://github.com/adumont/hb6502/tree/main/forth#homebrew-6502-sbc---forth) to the 6809 processor.

# Status

This Forth is a work in progress.

# Building Journal

Follow me in this *journal* on how I implement AlexForth for 6809:

- [Day 1: Inner Interpreter and Manually Threaded code](docs/day01/README.md)
- [Day 2: Colon defined Words and Return Stack!](docs/day02/README.md)
- [Day 3: Automating words headers, embedding constants into words definitions and memory manipulation words](docs/day03/README.md)
- [Day 4: About handling user I/O...](docs/day04/README.md)

# Requirements

- 6809 Assembler [asm6809](https://www.6809.org.uk/asm6809/)
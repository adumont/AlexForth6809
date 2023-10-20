# AlexForth for 6809 - Journal

# Day 4

About I/O...

## Basic I/O routines

At the moment the target to develop and run AlexForth 6809 is my Emu6809 emulator. In this context, there are two special addresses:

```
; IO Addresses
IN_CHAR         EQU $F004
OU_CHAR         EQU $F001
```

Loading a byte from `IN_CHAR` will effectively read a byte (character) from the emulator input (console).

Likewise, writing a byte (char) to `OU_CHAR` will result in the emulator outputting the char on the console output.

In that context, the I/O routines for AlexForth are trivial:

```
; IO Routines

getc
    ; load a char from input into B
    LDB IN_CHAR
    BEQ getc
    RTS

putc
    ; send char in B to output
    STB OU_CHAR
    RTS
```

To port AlexForth 6809 to a physical we would just need to modify those routines according to the I/O component of the board (serial port for example).

## Basic I/O Forth Words

Now, we can write a couple of corresponding Forth words that will read or write from or to the console.

`EMIT` will pull a word from the stack and put it in the `D` register, the low byte will then be in `B` register, ready for us to then call `putc` to send it to the output:

```
defword "EMIT"
; EMIT emit a single char
    ; char is on stack
    PULU D
    JSR putc
    NEXT
```

Similarly, `GETC` is again self explanatory: we clear `A` (High byte of `D`), call `getc` to read a byte from input into `B` and push `D` to the data stack:

```
defword "GETC"
; get a single char from IO, leave on stack
    CLRA
    JSR getc ; leaves the char in B
    PSHU D
    NEXT
```


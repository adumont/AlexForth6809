# AlexForth for 6809 - Journal

# Day 3

In this exciting journey into building a FORTH language from scratch, today we'll say goodbye to the cumbersome manual process of writing headers in our assembly code. We'll create a way to embed values inside words' definitions and unlock the posibility to branch in our FORTH code. Finally we'll define some basic memory manipulation words.

## Automatic headers generation

So far, we've been writing *manually* the headers of each of our FORTH words, for example:

```
h_PLUS
	FDB h_PUSH1
	FCB 1, "+"
do_PLUS
    [...]

h_DUP
	FDB h_PLUS      ; link to the header of PLUS
	FCB 3, "DUP"
do_DUP
    [...]
```

But doing so is very impractical. First we need to take great care of correctly linking every header to the previous one: notice how the first field in the header of `DUP` is a link to the address of the header for PLUS. Similarly, `PLUS` starts with a link to the previous word, `PUSH1`. Remember the structure of the FORTH dictionary is a linked list of words.

Maintaining manually those links is very cumbersome and error prone. Same goes for the field containing the length of the name, or even the name of the labels. This calls for a better and automated solution!

When developping AlexForth for 6502, I used the CA65 macro capability to automatically write the code for the headers. Unfortunately, asm6809 doesn't seem to have such a powerful capability. That's not a blocking problem though: I simply wrote a simple python script to preprocess the `forth.s` source file, and convert my own defined macros to the header as I needed :)!

So the format is the following: I can start a header like that:

```
defword "COLON"
```

and the preprocessor `macros.py` script (called directly from the `Makefile`) will automatically expand it to:

```
; defword "COLON", "COLON", 0
h_COLON
    FDB 0 ; link
    FCB 5
    FCB $43, $4F, $4C, $4F, $4E ; "COLON"
do_COLON
```

For now, the scripts takes care of:
- linking every header to the previous one (`COLON` being the first word at the time of this writing, it links to `0`)
- write the length field according to the length of the name (`COLON` is of length 5), It also OR the length with flags (see in a minute)
- Write the name as bytes in hex values (so we don't have trouble when our names contain " or weird characters)...

Notice how the scripts expands `defword "COLON"` into `defword "COLON", "COLON", 0`. Basically it's because it can take up to 3 arguments. Only the first one is mandatory.

The first argument is the name to be used for the labels in the header. If there's no 2nd argument, it will also be used as the name of the word.

Sometimes though, we'll want to have FORTH words with names than cannot be asm6809 labels (think about `:`, `;`...). In that case we will define a label different than the FORTH name, and specify it like that:

```
defword "PUSH0", "0"
```

This will be expanded into

```
; defword "PUSH0", "0", 0
h_PUSH0
    FDB h_SEMI ; link
    FCB 1
    FCB $30 ; "0"
do_PUSH0
```

Notice how the labels show "PUSH0", while the name is 1 char long ("0").

Now, let's anticipate that there is a third optional argument, that will be a flag. We'll use it later for immediate words or hidden words. The flag will be OR'ed to the length of the word. To be able to do that, words names in AlexForth are limited to 31 characters at most. So the length will always be encoded into 5 bits (LSB) and this leaves us the 3 most significant bits (MSB) available to store up to 3 flags.

## Words with embedded arguments

Many FORTH words take their arguments from the stack. But that can't always be the case. Sometimes we will need to store values inside words definition, so we will need a way to read an argument (a number or an address) from somewhere *near them*: the parameter will be embedded in the definition, right after the CFA of the word.

For that we will define three *internal words*. They usually won't be used by the user directly, but they will be used by the FORTH compiler. Because we haven't built the compiler yet, for now we will need them ourselve to manually write more advanced FORTH definitions later.

### LIT: embed a constant into a definition

When we write a FORTH word like:

```
: ADD15 $0015 + ; \ ADD15 adds $15 to the number on the stack
```

the constant `$0015` have to be embedded into the definition of the `ADD15` word. To be able to do that, we will define a primitive word called `LIT`.

Let's first look at how the word's definition would be laid out in memory if we were to manually compile it in our `forth.s`:

```
defword "ADD15"          ;
	jmp do_COLON         ;    : ADD15
	FDB do_LIT, $0015    ;      $0015
	FDB do_PLUS          ;      +
    FDB do_SEMI          ;    ;
```

Notice how our `ADD15` is first calling the word `LIT`, and the argument (literal)`$0015` is placed right after the address (CFA) of `LIT`.

What is LIT supposed to do? Easy enough: it's supposed to read the literal right after its CFA and put it on the stack.

Now how do we implement `LIT`: we're in the code of `LIT` so the FORTH `IP` register (stored in register `Y`) now points to the next cell, and this is precisely where our literal constant is located! So we just have to read what is at `Y`, increment `Y` by two (so it then points to the next word's CFA, in our case it will point to the CFA of `PLUS`), and then leave the literal on the stack.

We can write that in 6809 assembly like that:

```
defword "LIT"
    ; Push a literal word (2 bytes)
    ; (IP) aka Y points to literal instead of next instruction
    LDD ,Y++
    PSHU D
    NEXT
```

So back to `ADD15`, `LIT` will read the literal `$0015` embedded into the word's definition, and leave it on the stack. `PLUS` will then add it to whatever was already on the stack. Done.

### JUMP: reroute the FORTH thread

Now let's have a look at another word with an embedded argument. Similarly at how we can change the flow of an assembly program using JMP, we will often need in our FORTH programs to be able to reroute the thread (*the execution flow*) to another thread or another part of a FORTH thread.

Let's imagine the following part of a FORTH definition:

```
    FDB do_PUSH1
    FDB do_DUP
    FDB do_JUMP, addr
```

and somewhere else, the `addr` label is where we ought to continue our thread execution:

```
addr
    FDB do_PLUS
```

Clearly, the program will push a 1 to the stack (`PUSH1`), dupplicate it (`DUP`), then our intention is to make the FORTH Inner Interpreter jump to somewhere else, and continue from there as if nothing happened. Here we continue with `PLUS` to add the two 1.

Similarly to `LIT` which takes a literal, `JUMP` expects an address embedded right after its CFA in the definition. It's located at `Y`, and to implement the expected behaviour, we just have to place the address into `Y`. In 6809 it's a single instruction: `LDY ,Y`.

```
defword "JUMP"
    ; (IP) points to literal address to jump to
    ; instead of next word
    LDY ,Y
    NEXT
```

### 0BR: conditional branching!

Finally, the last of our embedded argument word for today, `0BR`, will jump to the address specified after it if and only if the value on the stack is 0. This will allow us to conditionally go into a FORTH program branch or another depending on a value handled by our program, supplied by the user, or read from a device or memory.

We have already defined `JUMP`, so `0BR` is very similar, we pop the top of the data stack, if it's 0, we want to jump to the address embedded after our CFA, so we run the same code as JUMP (tecnically, we even jump into the code of JUMP). If it wasn't 0, we don't want to jump, so we have to skip the embedded address: we just increment Y by 2.

```
defword "0BR"
    ; (IP) points to literal address to jump to if ToS is 0
    ; instead of next word
    LDD ,U++    ; we don't use PULU D as it doesn't set flags
    ; if D=0 we call the code for JUMP
    BEQ do_JUMP
    ; else, D is not 0, leave (aka advance Y by 2 and leave (NEXT))
    LEAY 2,Y    ; Y+2 -> Y
    NEXT
```

## Basic memory manipulation words

In FORTH the two basic memory operations are:
- Storing a value to memory: It's done by the `!` word, called *store*.
- Fectching a value from memory: It's done by the `@` word, called *fetch*.

AlexForth is a 16bit FORTH, each stack cell is 16-bits wide (2 bytes). As such, `!` and `@` will store and fetch a 16 bits value to and from memory.

Sometimes we will also need to work with single byte values, so there are two equivalent commands, `C!` and `C@` to store and fetch a byte to/from memory.

### Store: ! and C!

```
! ( value ADDR -- )
```

`!` takes two arguments from the stack: A 16-bits value, and an address. It then stores the value at the specified address. In 6809 assembly it can be done like this:

```
defword "STORE","!",
; ! ( value ADDR -- )
; Stores value at ADDR
    PULU X
    PULU D
    STD ,X
    NEXT
```

The 1 byte equivalent, `C!` is as simple:

```
defword "CSTORE","C!",
; C! ( byte ADDR -- )
; Stores value at ADDR
    PULU X
    PULU D      ; we pull 2 bytes (1 cell)
    STB ,X      ; but only store B (1 byte)
    NEXT
```

### Fetch: @ and C@

```
@ ( ADDR -- value )
```

`@` takes only an address from the stack, and returns the 16-bit value at that address. It can be implemented like that:

```
defword "FETCH","@",
; @ ( ADDR -- value )
; We read the data at the address on the
; stack and put the value on the stack
    ; load addr on ToS into X
    PULU X
    ; Read data at ,X and save on ToS
    LDD ,X
    PSHU D
    NEXT
```

Similarly, `C@`:

```
defword "CFETCH","C@",
; C@ ( ADDR -- byte )
; We read 1 byte at the address on the
; stack and put the value on the stack
    ; load addr on ToS into X
    PULU X
    ; Read data at ,X and save on ToS
    LDA #0
    LDB ,X
    PSHU D
    NEXT
```

## Recap

In this entry, we focused on automating the generation of headers for our FORTH words using a Python script to preprocess the source file and convert macros into headers, which should saves us time and reduces the risk of mistakes.

Additionally, we explored the concept of embedding arguments in word definitions. This allows us to store values inside word definitions and access them during execution. We introduced three internal words: LIT, JUMP, and 0BR. These words enable us to embed constants, reroute the FORTH thread, and perform conditional branching, respectively.

Lastly, we discussed basic memory manipulation words: !, @, C!, and C@. These words facilitate storing and fetching values from memory, both for 16-bit and single-byte operations.
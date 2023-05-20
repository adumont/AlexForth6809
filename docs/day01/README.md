# AlexForth for 6809 - Journal

# Day 1: Inner Interpreter and Manually Threaded code

In this article we'll define the first pieces and assemble them together into a working 6809 assembly program that will form the seed a DTC Forth language. Here is what we need to start with:

- A data stack,
- A Forth program (or Thread), made with the 3 words we have defined.
- An Inner Interpreter, which will be responsible for moving along the thread and run each word in turn.
- A small dictionary of words: we will define 3 words,

Now let's comment each piece one by one. The full code listing is [here](forth.lst).

## Data stack

For the data stack, we'll use the 6809 user stack, which is based on the `U` register and operated with the `PSHU` and `PULU` instructions.

## Forth Thread (program)

This Forth will be a DTC Forth: Direct Threaded Forth. That means that, when laid out in memory, each cell (2 bytes as we're on a 16bit CPU) will represent the address of the code to be executed by the inner interpreter.

For example, let's suppose our Forth program starts a $8034 and reads like this:

```
                      ; Small Forth Thread (program)
8034                  FORTH_THREAD
8034  80148014801F8031
```

This above is the thread of our Forth program. At this time, because we have no compiling words, and no I/O and no way to interpret oit (the future outer interpreter), it has been compiled manually, by simply laying out the addresses of the code (CFA: Code Field Address) of each words.

## The Inner Interpreter

Our Inner Intrepreter will start at $8034, read the first address: $8014 (which happens to be the CFA of a Forth word) and simply jump to it.

The Forth program seem to call 4 words, with their code (CFA)at $8014, $8014 (again), $801F and finally $8031.

The Inner Interpreter needs to keep track of where it is in the thread. For that purpose it used a pointer called `IP` for Instruction Pointer (Forth) register. In our case, we will store it in the (6809) `Y`.

`NEXT`: The Inner Interpreter needs a way to move along the Forth thread. This is done by a routine called `NEXT`, which will jump to the address pointed to by `IP` (or `Y`) and advance `Y` by 2 so it points to the next word in the thread.

In our case, `NEXT` will simply be the following macro, made of the single instruction `JMP [,Y++]`:

```
NEXT macro
     JMP [,Y++]
     endm
```

`Y` and `NEXT` together form the Inner Interpreter.

To start the execution of our Forth program by the Inner Interpreter we simply initialize `Y` to the address of the thread ($8034) and call `NEXT`. This is done by these lines:

```
                      ; Enter the thread:
800A  108E8034            LDY #FORTH_THREAD
800E                      NEXT
800E  6EB1                JMP [,Y++]
```

## The Dictionary

Our Forth dictionary is a linked list of words. At this point, word is a data structure made of two parts:

- A header, with two fields:
    - A pointer to the previous word's header (the first word will point to $0000, which will be useful to know we are at the end of the list).
    - A counted string with the name of the word. (Although in this minimal example, the name isn't used and is not relevant). The counted string starts with the length of the string encoded in one byte, followed by character string.
- A definition: the code that will be executed when the Inner Interpreter runs this word.

At this early stage, all our words are primitive (that means they are written in 6809 assembly). And our initial dictionary will be made of 3 words.

Our first word `1` will simply push 1 to the stack:

This is `1`'s header:

```
8010                  h_PUSH1
8010  0000                FDB $0000
8012  0131                FCB 1, "1"
```

Because this is our first word, the link field points to the address $0000.

And this is `1`'s definition (in 6809 assembly code):

```
8014                  do_PUSH1
8014  CC0001              LDD #$01
8017  3606                PSHU D
8019                          NEXT
8019  6EB1                JMP [,Y++]
```

Several things are worth noticing here:

The code for `1` is pretty straighforward: it loads the value 1 into the register `D` and pushes it to the user stack

Notice however how the definition ends with the macro `NEXT`: this is how our Forth will *move on to the next word and execute it*.

Notice also that the code for `1` starts at $8014. If you look back at the code of our Forth thread, now you can our program starts with two calls to `1`.

Our second word will be `+`. This is the header and code of `+` in our dictionary:

```
801B                  h_PLUS
801B  8010                FDB h_PUSH1
801D  012B                FCB 1, "+"
801F                  do_PLUS
801F  3706                PULU  D
8021  E3C4                ADDD ,U
8023  EDC4                STD  ,U
8025                          NEXT
8025  6EB1                JMP [,Y++]
```

Notice how the link field in `+`'s header points to the previous word's header ($8010, the address of the header of `1`).

The third word in our Forth thread had its CFA at $801F, so we now know it's `+`. So far it will execute: `1 1 +`

Because we have no outer interpreter yet, I have implemented a new word called `ENDLESS` that will simply loop endlessly. That way our Inner Interpreter will not go wild into random addresses.

This is the third and last word we have defined:

```
8027                  h_ENDLESS
8027  801B                 FDB h_PLUS
8029  07454E444C455353     FCB 7, "ENDLESS"
8031                  do_ENDLESS
8031  7E8031              JMP *
```

Once reached, this word will never end, so we don't need to end it with `NEXT`.

## Recap

- The Inner Interpreter is made of:
    - the Forth register `IP` (implemented in the `Y` register) and
    - the routine (macro) `NEXT` which execute a word and advance `IP` to point to the next word in the thread.

- Our dictionary is made of 3 words:

| Word  | Header Address | CFA Label |  CFA |
| :---: | :---: | ---- | :---: |
| `1`  | $8010  | do_PUSH1 | $8014 |
| `+`  | $801B  | do_PLUS | $801F |
| `ENDLESS`  | $8027  | do_ENDLESS | $8031 |

- Our Forth Thread (program):

```
                      ; Small Forth Thread (program)
8034                  FORTH_THREAD
8034  80148014801F8031     FDB do_PUSH1, do_PUSH1, do_PLUS, do_ENDLESS
```

We clearly see now that the Forth program is: `1 1 + ENDLESS`. At the moment, we simply *compiled* it manually by using the labels of the corresponding words' CFAs in the assembly code.


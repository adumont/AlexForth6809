# AlexForth for 6809 - Journal

# Day 2: Colon defined Words and Return Stack!

Following with the fundamentals of Forth internals, we'll need the ability to extend the language. In FORTH, this is done using what we call colon defined words.

## Example of a colon defined word

A classic example of a colon defined word is:

` : DOUBLE DUP + ; `

Let's break this down:

`:` (Colon) instructs FORTH that we want to define a new colon word. The next token, `DOUBLE`, will be the name of the word.

Then comes the definition of the word, in this case ` DUP + `. Indeed, running ` DUP + ` will double the value on the top of the data stack.

Finally `;` instructs FORTH this is the end of the word's definition.

If we already had a complete FORTH with a working FORTH interpreter (the *outer interter*), we could simply type the definition and that would compile it into the dictionary. But we're not there yet.

That doesn't mean we can't define colon words though. It just means that for now we will need to compile them manually. But that's not hard!

## New elements!

We will now need new elements to enhance our FORTH:

- A new stack, called the Return Stack
- COLON (aka ENTER) and SEMI (aka EXIT)
- How to layout colon defined words like `DOUBLE`
- And a new program using this word

Let's look at those from the end. To understand each piece we might need to imagine the other missing pieces are there already. All the pieces will finally fit together like the gears in a clockwork, inbricated with each other and working smoothly and flawlessly.

## Our test program

```
                      ; Small Forth Thread (program)
806E                  FORTH_THREAD
806E  8030                FDB do_PUSH1
8070  8058                FDB do_DOUBLE
8072  806B                FDB do_ENDLESS
```

Our test program is very simple: `PUSH1` will push a `1` to the stack. `DOUBLE` will double it (by executing `DUP` and `+`). `ENDLESS` will loop forever (end of the program).

This time, I have formated it vertically instead of all the addresses on the same line (as we've seen in Day 1). In memory there will be no difference at all (it will be stored at `80308058806B`) but it may help for later.

## Layout of Colon Defined Words

Let's assume for a moment that we have already defined two primitives, called `COLON` and `SEMI`. We don't know yet what they will do. Only that they are placeholders for some 6809 code.

Remember the previous definition for `DOUBLE`:

` : DOUBLE DUP + ; `

This is what the word will look like in our dictionary (I have omited the header, which is not really relevant for now):

```
8058                  do_DOUBLE
8058  7E8018              JMP do_COLON
805B  8049                FDB do_DUP
805D  803B                FDB do_PLUS
805F  8028                FDB do_SEMI
```

We can see that like all the other words we had defined in Day 1, `DOUBLE` starts with a 6809 instruction: a `JMP` to `do_COLON`: so basically it will jump to run the code of `COLON`.

Unlike other words we've seen so far though, what follows the `JMP` to COLON aren't 6809 instructions! They are the addresses to `DUP`, `PLUS` and `SEMI`! The addresses are just inlined after the JMP do_COLON!

## Follow the threaad!

Look how similar the internal representation of `DOUBLE` is to the internal representation of our main FORTH program (see above):

- main FORTH program:
```
                      ; Small Forth Thread (program)
806E                  FORTH_THREAD
806E  8030                FDB do_PUSH1
8070  8058                FDB do_DOUBLE
8072  806B                FDB do_ENDLESS
```

- Code for DOUBLE (without COLON):

```
8058  7E8018              JMP do_COLON
805B  8049                FDB do_DUP
805D  803B                FDB do_PLUS
805F  8028                FDB do_SEMI
```

Indeed, both are just lists of addresses to the CFA (Code Field Address) of words (with the exception of JMP do_COLON).

Let's remember first our example from Day 1, especially how the `IP` FORTH register (in our `Y` CPU register) is a pointer to the address of the code to be run (the code of our primitive words). Remember how `NEXT` would jump to the code address pointed to by `IP` and advance it by 2 (to end up pointing to the next word's address).

In day 1 we also used the word *thread* for our program. `IP` is a pointer that helps the Inner Interpreter keep track of where we are in the thread.

In this case, we expect the inner interpreter to:

- Run `PUSH1`
- Execute `DOUBLE`, ie: follow the thread jumping to a different location in memory: 805B (That will be the job of `COLON`)
    - 805B: Run `DUP`
    - 805D: Run `PLUS`
    - Go back to the main thread, ie (that's where `SEMI` is involved)
- 8072: Run `ENDLESS`

## COLON

With this execution plan in mind, let see how `COLON` actually works. This is the most complex part, be sure to be awake ;).

During the execution of `PUSH1` (but right before running its `NEXT`) the `IP` register is already pointing to $8070 (CFA of `DOUBLE`). `NEXT` will jump to $8058 (address at $8070) and increment `IP` to $8072 (CFA of `ENDLESS`).

$8058 is another JMP to COLON:

The first thing `COLON` does is save `IP`, by pushing it onto the Return Stack. We'll need it later to be able to return to `ENDLESS` once we end the execution of `DOUBLE`.

Now, `COLON` will update `IP` to point to the first address of its definition, that is $805B (whose content is $8049, address of `DUP`)

```
    8058  7E8018              JMP do_COLON
->  805B  8049                FDB do_DUP
    805D  803B                FDB do_PLUS
    805F  8028                FDB do_SEMI
```

How to do that? (Now it will get a little bit involved...)

$805B is actually 3 bytes after $8058 (3 byte is the length of the JMP do_COLON instruction)

And $8058 was the content of the cell (2 bytes) at `IP` before we incremented it by 2 in `NEXT`.

So if we load what's at Y-2 into Y, and add 3 to Y, Y will now be $805B! And with that we've managed to reroute our thread into `DOUBLE`! We just need to run `NEXT`!

Here's the code for `COLON` that does exactly that:

```
8010                  h_COLON
8010  0000                    FDB $0000
8012  05444F434F4C            FCB 5, "DOCOL"
8018                  do_COLON            ; COLON aka ENTER
                          ; push IP to Return Stack
8018  3420                PSHS Y

801A  10AE3E              LDY -2,Y    ; we get W --> Y
801D  3123                LEAY 3,Y    ; Y+3 -> Y
801F                          NEXT
801F  6EB1                JMP [,Y++]
```

## SEMI

`SEMI` is the counterpart of `COLON` but it's much simpler:

It simply pulls `IP` from the return stack and runs `NEXT`.

```
8021                  h_SEMI
8021  8010                    FDB h_COLON
8023  0453454D49              FCB 4, "SEMI"
8028                  do_SEMI
                          ; pull IP from Return Stack
8028  3520                PULS Y
802A                          NEXT
802A  6EB1                JMP [,Y++]
```

In our simple example above, `IP` will be restored to $8072, and `NEXT` will jump into `ENDLESS` to end our program as expected.

## Return Stack

In our implementation, the Return Stack will simply be the hardware (processor) stack.

We've already seen how COLON will save `IP` to the return stack before rerouting the thread by updating `IP` to a new value right after the exact JMP that called COLON, in the definition of the *colon defined word*.

Once the *colon defined word* ends, it will run `SEMI` that will pull and restore `IP` from the return stack, and run `NEXT` putting up back on track in the original thread.

The magic of using the return stack is that we can stack the calls to COLON.

We can create new colon words, that will in turn have any number of colon words in their definition, to any level (as long as we don't overflow the return stack!)

For example we could define:

: QUADRUPLE DOUBLE DOUBLE ;

Of course for now we'd have to compile it manually, like that:

```
do_QUADRUPLE
    JMP do_COLON
    FDB do_DOUBLE
    FDB do_DOUBLE
    FDB do_SEMI
```

When running QUADRUPLE, COLON will stack IP, and modify it to point to the first DOUBLE. Then enter DOUBLE and run COLON again, that will stack IP (which at that time points to the second DOUBLE)...

Similarly SEMI will unstack every value saved on the return stack, and restore `IP` to the value needed to get back on track on the thread were we left off when the corresponding COLON was called.

## Now what?

Equiped with COLON and SEMI, we can now write more complex FORTH programs!

We can enhance our FORTH dictionary with Primitive words like this one:

- Primitive words, like `DUP`, in assembly code:

```
h_DUP
	FDB h_PLUS
	FCB 3, "DUP"
do_DUP
    LDD ,U
    PSHU D
	NEXT
```

Usually, primitive words will end with a call to `NEXT`.

And we can now also write high level FORTH words, aka colon defined words or secondaries, using any number or primitive or secondary words in their definition, like this:

```
h_ACOLONWORD
	FDB h_DUP
	FCB 10, "ACOLONWORD"
do_ACOLONWORD
    JMP do_COLON
    FDB do_AWORD
    FDB do_SWAP
    FDB do_ANOTHERWORD
    FDB do_DROP
    FDB do_DUP
    FDB do_SEMI
```

Secondary words words must start with `JMP do_COLON` and end with `do_SEMI`. They dont't have any inline 6809 assembly code (except for the initial JMP).

## Recap

We have added to our Forth the ability to define new high level word using other Forth words. For that we have needed:

- A new stack, called the Return Stack
- A couple of primitived, COLON (aka ENTER) and SEMI (aka EXIT), that take care of the `IP` register, so we can follow the Forth thread through the definition of the colon defined words.
- We've seen how we (manually) layout colon defined words in our dictionary.
; AlexForth for 6809
; Copyright (C) 2023 Alexandre Dumont <adumont@gmail.com>
; SPDX-License-Identifier: GPL-3.0-only
;
; Target CPU is Motorola 6809

TOP_HW_STACK    EQU $0300
TOP_US_STACK    EQU $0400
MAX_LEN         EQU $80     ; Input Buffer MAX length, $80= 128 bytes
BKSPACE         EQU $08     ; Backspace char

; IO Addresses - Configure for your target
IN_CHAR         EQU $F004
OU_CHAR         EQU $F001

;
; -----------------------------------------------------------
;
; RAM AREA - SYSTEM VARIABLES in Direct Page (fast access)

    BSS
    ORG $0000

LATEST  RMB     2   ; Store the latest ADDR of the Dictionary
DPR     RMB     2   ; Data/Dictionary Pointer: Store the latest ADDR of next free space in RAM (HERE)
SEPR    RMB     1   ; Separator for parsing input
G1      RMB     2   ; General Purpose Register 1
G2      RMB     2   ; General Purpose Register 2

;
; -----------------------------------------------------------
;
    CODE

    ORG $8000
    SETDP $00           ; instructs assembler that our Direct Page is $00xx

    CLRA
    TFR A, DP
    LDU #TOP_US_STACK   ; User stack will be at 03xx (0400 downwards)
    LDS #TOP_HW_STACK   ; Hardware/CPU stack is in 2 pages 01xx-02xx (0300 downwards)
    LDX #USER_BASE
    STX DPR             ; initialize Dictionary Pointer

    LDX #p_LATEST
    STX LATEST

    ; Initialize INPUT_BUFFER_END
    LDX #INPUT_BUFFER_END
    STX INPUT_BUFFER_END

    ; Input buffer starts empty
    LDX #INPUT
    STX INPUT_END

    ; Position into the INPUT buffer set to start of buffer for now
    LDX #INPUT
    STX INPUT_IDX

; Y is our IP register
; NEXT is simply JMP [,Y++]

NEXT MACRO
    JMP [,Y++]
    ENDM

; Enter the thread:
    LDY #FORTH_THREAD
    NEXT

; Dictionary
defword "COLON"
    ; COLON aka ENTER
    ; push IP to Return Stack
    PSHS Y

    LDY -2,Y    ; we get W --> Y
    LEAY 3,Y    ; Y+3 -> Y
    NEXT

defword "SEMI"
    ; pull IP from Return Stack
    PULS Y
    NEXT

defword "PUSH0", "0"
    LDD #$0
    PSHU D
    NEXT

defword "PUSH1", "1"
    LDD #$01
    PSHU D
    NEXT

defword "PLUS", "+"
    PULU  D
    ADDD ,U
    STD  ,U
    NEXT

defword "SWAP"
    LDX 2,U
    LDD  ,U
    STX  ,U
    STD 2,U
    NEXT

defword "ROT"
    LDX 4,U

    LDD 2,U
    STD 4,U

    LDD  ,U
    STD 2,U

    STX  ,U
    NEXT

defword "NROT","-ROT"
    LDX  ,U

    LDD 2,U
    STD  ,U

    LDD 4,U
    STD 2,U

    STX 4,U
    NEXT

defword "DROP"
    LEAU 2,U
    NEXT

defword "DUP"
    LDD ,U
    PSHU D
    NEXT

defword "OVER"
    LDD 2,U
    PSHU D
    NEXT

defword "HERE"
; : HERE	DP @ ;
; Primitive version
    LDD DPR
    PSHU D
    NEXT

defword "COMMA", ","
    LDX DPR
    PULU D
    STD ,X++
    STX DPR
    NEXT

defword "CCOMMA", "C,"
    LDX DPR
    PULU D
    STB ,X+
    STX DPR
    NEXT

defword "LATEST"
; Simply returns the address of the label LATEST
    LDD #LATEST
    PSHU D
    NEXT

defword "LAST"
; ( -- ADDR ) returns header addr of last word in dict
; equivalent to : LAST LATEST @ ;
    LDD LATEST
    PSHU D
    NEXT

defword "LIT"
    ; Push a literal word (2 bytes)
    ; (IP) aka Y points to literal instead of next instruction
    LDD ,Y++
    PSHU D
    NEXT

defword "0BR"
    ; (IP) points to literal address to jump to if ToS is 0
    ; instead of next word
    LDD ,U++    ; we don't use PULU D as it doesn't set flags
    ; if D=0 we call the code for JUMP
    BEQ do_JUMP
    ; else, D is not 0, leave (aka advance Y by 2 and leave (NEXT))
    LEAY 2,Y    ; Y+2 -> Y
    NEXT

defword "JUMP"
    ; (IP) points to literal address to jump to
    ; instead of next word
    LDY ,Y
    NEXT

defword "EXEC"
    ; ( ADDR -- )
    ; JMP to addr on the stack, single instr on the 6809
    PULU PC

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

defword "STORE","!",
; ! ( value ADDR -- )
; Stores value at ADDR
    PULU X
    PULU D
    STD ,X
    NEXT

defword "CSTORE","C!",
; C! ( byte ADDR -- )
; Stores value at ADDR
    PULU X
    PULU D      ; we pull 2 bytes (1 cell)
    STB ,X      ; but only store B (1 byte)
    NEXT

; A test "colon word"!
defword "DOUBLE"
    JMP do_COLON
    FDB do_DUP
    FDB do_PLUS
    FDB do_SEMI

defword "EMIT"
; EMIT emit a single char
    ; char is on stack
    PULU D
    JSR putc
    NEXT

defword "GETC"
; get a single char from IO, leave on stack
    LDA #0
    JSR getc ; leaves the char in B
    PSHU D
    NEXT

defword "PRINT", "."
; Print data on top of stack (in hex for now)
; ( cell -- )
    LDB  ,U
    JSR print_byte
    BRA do_CPRINT    ; jump over CPRINT's header and continue in CPRINT

defword "CPRINT", "C.",
; Print data on top of stack (in hex for now)
; ( byte -- )
    LDB 1,U
    JSR print_byte
    LDB #' '
    JSR putc
    LEAU 2,U       ; DROP
    NEXT

defword "KEY"
    JSR _KEY
    LDA #$0
    PSHU D
    NEXT

defword "ENDLESS"
    JMP *

defword "WORD"
    LDB #$20        ; space separator
    BRA _PARSE

defword "PARSE"
; parse input buffer with separator SEPR
; ( SEPR -- ADDR LEN )

    PULU D          ; separator char is in B
_PARSE
    STB SEPR        ; we store the separator in SEPR

1 ; @skip
    JSR _KEY

    CMPB SEPR
    BEQ 1b          ; @skip

    CMPB #$0A
    BEQ 3f ; @return0        ;--> we have to exit leaving two zeros ( 0 0 ) on the stack

    CMPB #$0D
    BNE 5f ; @startW
    ; fallthrough into @return0

3 ; @return0

;    lda BOOT
;    bne 4f        ; if boot<>0 (aka boot mode, we don't set the prompt to 1)
;    inc OK        ; we mark 1 the OK flag
; 4 ;

    LDD #0      ; we reset D to 0
    TFR D,X     ; we reset X to 0 too
    PSHU D,X    ; we push both zeros in one instruction
    NEXT        ; exit PARSE leaving 2 zeros on the stack

; start of word
5 ; @startW:
    ; First we store the ADDR on stack

    ; exiting _KEY X is the next char, so X-1 is the starting addr of our word
    LEAX -1,X
    PSHU X      ; We push the ADDR to ToS

    LDA #1      ; we initialize A to 1, to count chars in WORD

6 ; @next2:
    JSR _KEY

    CMPB SEPR
    BEQ 8f      ; @endW

    CMPB #$0A
    BEQ 7f      ; @return

    CMPB #$0D
    BEQ 7f      ; @return

    INCA
    BRA 6b      ; @next2

7 ; @return

;    lda BOOT
;    bne @endW    ; if boot<>0 (aka boot mode, we don't set the prompt to 1)
;    inc OK        ; we mark 1 the OK flag

8 ; @endW
    ; compute length

    TFR A,B     ; length is in A, we transfer it to B
    LDA #0      ; and reset A to 0
    PSHU D      ; finally we push the length to the stack
    NEXT

;-----------------------------------------------------------------
; Small Forth Thread (program)
FORTH_THREAD
    FDB do_LIT, $1234, do_COMMA
    FDB do_LIT, $56, do_CCOMMA
    FDB do_LIT, $78, do_CCOMMA
    FDB do_ENDLESS

;-----------------------------------------------------------------

_KEY
; Returns with the next char from input buffer in register B
    LDX INPUT_IDX

    CMPX INPUT_END  ; reached end of input string?
    BEQ 1f  ; @eos

    LDB ,X+
    STX INPUT_IDX
    RTS

1 ; @eos
    JSR getline
    BRA _KEY


STRCMP
; Clobbers: X, Y, A, B
; Housekeeping: Save Y (IP) before calling STRCMP and restore it after calling STRCMP
; Input: expects the addr of 2 counted STR in X and Y
; Output:
; - Z flag set if both str equals
; - Z flag cleared if not equals

    LDA  ,X+        ; Load length of X string in A
    CMPA ,Y+
    BNE 2f          ; @end

    ; here we know both strings are the same length

    TSTA            ; Are both strings empty?
    BEQ 2f          ; @end

1 ; @next
    LDB  ,X+
    CMPB ,Y+
    BNE 2f          ; @end
    DECA
    BNE 1b          ; @next

2 ; @end
    RTS


nibble_asc_to_value
; converts a char representing a hex-digit (nibble)
; into the corresponding hex value
; - Input : char asc is in B (ex. 34)
; - Output: number is in B  (ex. 04)

; boundary check is it a digit?
    CMPB #'0'
    BMI 1f      ; @err
    CMPB #'F'+1
    BPL 1f      ; @err
    CMPB #'9'+1
    BMI 2f      ; @conv
    CMPB #'A'
    BPL 2f      ; @conv
1 ; @err:
    ; nibble wasn't valid, error
    ORCC #1     ; set carry flag
    RTS
2 ; @conv:
    ; conversion happens here
    CMPB #$41
    BMI 3f      ; @less
    SBCB #$37
3 ; @less:
    ANDB #$0F
    ANDCC #$FE  ; clear carry flag
    RTS

print_byte
; Input: a byte to print is in B
; Clobbers A
    TFR  B,A    ; saves B to A
    LSRB        ; here we shift right
    LSRB        ; to get B's HI nibble
    LSRB
    LSRB
    JSR print_nibble

    TFR  A,B    ; restores B
    ANDB #$0F   ; keep LO nibble
    ; fallthrough to print_nibble

print_nibble
; Input: nibble to print is in B
    CMPB #$0A
    BCS  1f
    ADDB #$67
1
    EORB  #$30
    JMP  putc

;-----------------------------------------------------------------
; Input Buffer Routines

; Getline refills the INPUT buffer
getline
    LDX #INPUT      ; X is our index into the INPUT buffer
    STX INPUT_IDX   ; resets the INPUT index position to start of buffer

1 ; @next
    JSR getc    ; get new char into B register

    CMPB #BKSPACE ; Backspace, CTRL-H
    BEQ 3f      ; @bkspace

    CMPB #$7F   ; Backspace key on Linux?
    BEQ 3f      ; @bkspace

    CMPX #INPUT_BUFFER_END
    BEQ 4f      ; @buffer_end

    STB ,X+     ; save char to INPUT buffer

    CMPB #$0A   ; \n
    BEQ 2f      ; @finish

    CMPB #$0D   ; \n
    BEQ 2f      ; @finish

    JSR putc
    BRA 1b      ; @next

2 ; @finish
    STX INPUT_END
    JMP _crlf

3 ; @bkspace
    CMPX #INPUT     ; start of line?
    BEQ 1b          ; @next, ie do nothing
    LDB #BKSPACE
    JSR putc        ; echo char
    LEAX -1,X       ; else: decrease X by 1
    BRA 1b          ; @next

4 ; @buffer_end
    TFR B, A        ; save char (B) into register A
    LDB #BKSPACE    ; send bckspace to erase last char
    JSR putc
    TFR A, B        ; restore last char
    STB -1,X        ; save char to INPUT
    JSR putc
    BRA 1b          ; @next

_crlf
    LDB #$0a    ; CR
    JSR putc
    LDB #$0d    ; LF
    JMP putc    ; will also to RTS

;-----------------------------------------------------------------
; IO Routines

getc
    LDB IN_CHAR
    BEQ getc
    RTS

putc
    STB OU_CHAR
    RTS

;-----------------------------------------------------------------
; p_LATEST point to the latest defined word (using defword macro)
p_LATEST EQU <filled with macro>
;
; -----------------------------------------------------------
;
; RAM AREA - SYSTEM VARIABLES
    BSS
    ORG TOP_US_STACK
INPUT               RMB     MAX_LEN ; CMD string (extend as needed, up to 256!)
INPUT_BUFFER_END    RMB     2       ; Addr of the first byte after INPUT buffer
INPUT_END           RMB     2       ; End of the INPUT string
INPUT_IDX           RMB     2       ; Position into the input buffer

; Base of user memory area.
USER_BASE               ; Start of user area (Dictionary)

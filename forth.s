; AlexForth for 6809
; Copyright (C) 2023 Alexandre Dumont <adumont@gmail.com>
; SPDX-License-Identifier: GPL-3.0-only
;
; Target CPU is Motorola 6809

TOP_HW_STACK    EQU $0300
TOP_US_STACK    EQU $0400
MAX_LEN         EQU $80		; Input Buffer MAX length, $80= 128 bytes

;
; -----------------------------------------------------------
;
; RAM AREA - SYSTEM VARIABLES in Direct Page (fast access)

    BSS
    ORG $0000

INP_LEN RMB     1   ; Length of the text in the input buffer
INP_IDX RMB     1   ; Index into the INPUT Buffer (for reading it with KEY)
LATEST  RMB     2   ; Store the latest ADDR of the Dictionary
G1      RMB     2   ; General Purpose Register 1
G2      RMB     2   ; General Purpose Register 2
DPR	    RMB     2   ; Data/Dictionary Pointer: Store the latest ADDR of next free space in RAM (HERE)

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

; Y is our IP register
; NEXT is simply JMP [,Y++]

NEXT macro
    JMP [,Y++]
    endm

; Enter the thread:
    LDY #FORTH_THREAD
    NEXT

; Dictionary
h_COLON
	FDB $0000
	FCB 5, "COLON"
do_COLON            ; COLON aka ENTER
    ; push IP to Return Stack
    PSHS Y

    LDY -2,Y    ; we get W --> Y
    LEAY 3,Y    ; Y+3 -> Y
	NEXT

h_SEMI
	FDB h_COLON
	FCB 4, "SEMI"
do_SEMI
    ; pull IP from Return Stack
    PULS Y
	NEXT

h_PUSH0
	FDB h_SEMI
    FCB 1, "0"
do_PUSH0
    LDD #$0
    PSHU D
	NEXT

h_PUSH1
	FDB h_PUSH0
    FCB 1, "1"
do_PUSH1
    LDD #$01
    PSHU D
	NEXT

h_PLUS
	FDB h_PUSH1
	FCB 1, "+"
do_PLUS
    PULU  D
    ADDD ,U
    STD  ,U
	NEXT

h_SWAP
	FDB h_PLUS
	FCB 4, "SWAP"
do_SWAP
    LDX 2,U
    LDD  ,U
    STX  ,U
    STD 2,U
	NEXT

h_ROT
	FDB h_SWAP
	FCB 3, "ROT"
do_ROT
    LDX 4,U

    LDD 2,U
    STD 4,U

    LDD  ,U
    STD 2,U

    STX  ,U
	NEXT

h_NROT
	FDB h_ROT
	FCB 4, "-ROT"
do_NROT
    LDX  ,U

    LDD 2,U
    STD  ,U

    LDD 4,U
    STD 2,U

    STX 4,U
	NEXT

h_DROP
	FDB h_NROT
	FCB 4, "DROP"
do_DROP
    LEAU 2,U
	NEXT

h_DUP
	FDB h_DROP
	FCB 3, "DUP"
do_DUP
    LDD ,U
    PSHU D
	NEXT

h_OVER
	FDB h_DROP
	FCB 4, "OVER"
do_OVER
    LDD 2,U
    PSHU D
	NEXT

h_LIT
	FDB h_OVER
	FCB 3, "LIT"
do_LIT
    ; Push a literal word (2 bytes)
    ; (IP) aka Y points to literal instead of next instruction
    LDD ,Y++
    PSHU D
	NEXT

h_0BR
	FDB h_LIT
	FCB 3, "0BR"
do_0BR
    ; (IP) points to literal address to jump to if ToS is 0
    ; instead of next word
    LDD ,U++    ; we don't use PULU D as it doesn't set flags
    ; if D=0 we call the code for JUMP
    BEQ do_JUMP
    ; else, D is not 0, leave (aka advance Y by 2 and leave (NEXT))
    LEAY 2,Y    ; Y+2 -> Y
    NEXT

h_JUMP
	FDB h_0BR
	FCB 4, "JUMP"
do_JUMP
    ; (IP) points to literal address to jump to
    ; instead of next word
    LDY ,Y
	NEXT

; A test "colon word"!
h_DOUBLE
	FDB h_JUMP
	FCB 6, "DOUBLE"
do_DOUBLE
    JMP do_COLON
    FDB do_DUP
    FDB do_PLUS
    FDB do_SEMI

h_ENDLESS
	FDB h_DOUBLE
    FCB 7, "ENDLESS"
do_ENDLESS
    JMP *

; Small Forth Thread (program)
FORTH_THREAD
    FDB do_PUSH1
    FDB do_0BR
    FDB 1F

    FDB do_LIT
    FDB $AAAA
    FDB do_DROP

    FDB do_JUMP
    FDB FORTH_THREAD

1   FDB do_LIT
    FDB $BBBB
    FDB do_DROP

    FDB do_ENDLESS

;
; -----------------------------------------------------------
;
; RAM AREA - SYSTEM VARIABLES
    BSS
    ORG TOP_US_STACK
INPUT   RMB     MAX_LEN ; CMD string (extend as needed, up to 256!)

; Base of user memory area.
USER_BASE               ; Start of user area (Dictionary)
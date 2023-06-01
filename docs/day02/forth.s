; AlexForth for 6809
; Copyright (C) 2023 Alexandre Dumont <adumont@gmail.com>
; SPDX-License-Identifier: GPL-3.0-only
;
; Target CPU is Motorola 6809

TOP_HW_STACK    EQU $0300

;
; Code starts here
;
    CODE

    ORG $8000
    SETDP $00           ; instructs assembler that our Direct Page is $00xx

    CLRA
    TFR A, DP
    LDU #$0100          ; User stack will be in direct page? Good idea?
    LDS #TOP_HW_STACK   ; Hardware/CPU stack is in pages 0100-0200 (0300 downwards)

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
	FCB 5, "DOCOL"
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

h_PUSH1
	FDB h_SEMI
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

h_DUP
	FDB h_PLUS
	FCB 3, "DUP"
do_DUP
    LDD ,U
    PSHU D
	NEXT

; A test "colon word"!
h_DOUBLE
	FDB h_DUP
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
    FDB do_DOUBLE
    FDB do_ENDLESS
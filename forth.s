; AlexForth for 6809
; Copyright (C) 2023 Alexandre Dumont <adumont@gmail.com>
; SPDX-License-Identifier: GPL-3.0-only
;
; Target CPU is Motorola 6809

TOP_HW_STACK    EQU $0300
TOP_US_STACK    EQU $0400
MAX_LEN         EQU $80		; Input Buffer MAX length, $80= 128 bytes
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

; A test "colon word"!
defword "DOUBLE"
    JMP do_COLON
    FDB do_DUP
    FDB do_PLUS
    FDB do_SEMI

defword "KEY"
    JSR _KEY
    LDA #$0
    PSHU D
    NEXT

defword "ENDLESS"
    JMP *

;-----------------------------------------------------------------
; Small Forth Thread (program)
FORTH_THREAD
    FDB do_KEY
    FDB do_ENDLESS

;-----------------------------------------------------------------

_KEY
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
	CMPX #INPUT		; start of line?
	BEQ 1b          ; @next, ie do nothing
	LDB #BKSPACE
	JSR putc	    ; echo char
	LEAX -1,X	    ; else: decrease X by 1
	BRA 1b          ; @next

4 ; @buffer_end
	TFR B, A        ; save char (B) into register A
	LDB #BKSPACE	; send bckspace to erase last char
	JSR putc
	TFR A, B		; restore last char
	STB -1,X	    ; save char to INPUT
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

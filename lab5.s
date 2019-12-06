	.text
	.global UART0Handler
	.global PortAHandler
	.global lab5

prompt: .string "Enter an expression (no spaces) on the keypad or the keyboard, then press 'Enter': ",0
remainder: .string "Remainder: ",0
expression: .word 0x20000000
U0LSR: .equ 0x18 ; UART0 Line Status Register

lab5:
	STMFD sp!, {lr}

	BL uart_init

	MOV r2, #0xC038
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x10
	STRB r1, [r2]				; Enable UART Recieve in UART0 Interrupt Mask Register Interrupt Mask

	MOV r2, #0xE100
	MOVT r2, #0xE000
	LDRB r1, [r2]
	ORR r1, r1, #0x20
	STRB r1, [r2] 				; Set Bit 5 of EN0

delay:							; delay loop for display purposes
	MOV r10, #0xFFFF
	ADD r11, r11, #1
	CMP r10, r11
	BNE delay


	BL GPIO_init
	BL display_prompt

infinite:						; infinite loop that waits for an interrupt
	B infinite

	LDMFD sp!, {lr}
	mov pc, lr

;--------------------------- GPIO init ----------------------------------------------
GPIO_init:
	STMFD sp!, {lr}

	; Direction Register and Digital Enables
	MOV r2, #0x7400
    MOVT r2, #0x4000			; Accessing address 0x40007400 Direction Register (Port D)
 	LDR r1, [r2]				; Load in byte from address
 	MOV r1, #0xF				; Configuring Pin as Output
 	STR r1, [r2]

	MOV r2, #0x751C				; Accessing Digital Enable for PORT D;
	MOVT r2, #0x4000
	LDR r1, [r2]
	MOV r1, #0xF				; Setting PIN 0 - 3 to enable
	STR r1, [r2]

	MOV r2, #0x73FC				; Accessing Port D to check each row
	MOVT r2, #0x4000
	LDR r1, [r2]
	MOV r1, #0xF
	STRB r1, [r2]				; turn on all pins in portD

	MOV r2, #0x4400
    MOVT r2, #0x4000			; Accessing address 0x40004400 Direction Register (Port A)
 	LDRB r1, [r2]				; Load in byte from address
 	BIC r1, r1, #0x3C			; Configuring Pin as Input
 	STRB r1, [r2]

	MOV r2, #0x451C				; Accessing Digital Enable for PORT A
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x3C			; Setting PIN 2 - 5 to enable
	STRB r1, [r2]

	MOV r2, #0x4410
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x3C
	STRB r1, [r2]				; Enable (unmask) GPIO Interrupt Mask

	MOV r2, #0xE100
	MOVT r2, #0xE000
	LDRB r1, [r2]
	ORR r1, r1, #0x1
	STRB r1, [r2]				; Set bit 0 of EN0

	MOV r2, #0x4404
	MOVT r2, #0x4000
	LDRB r1, [r2]
	BIC r1, r1, #0x3C
	STRB r1, [r2]				; Set edge sensitive triggering

	MOV r2, #0x4408
	MOVT r2, #0x4000
	LDRB r1, [r2]
	BIC r1, r1, #0x3C
	STRB r1, [r2]				; Allow GPIO Interrupt Event Register to Control Pin

	MOV r2, #0x440C
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x3C
	STRB r1, [r2]				; Set High (Rising Edge) Triggering

	LDMFD sp!, {lr}
	mov pc, lr


hello:
	STMFD sp!, {lr}

	MOV r1, #0
	BL read_string
	ADD r6, r6, #1					; Increment r6 to point at next byte in memory to store a char
	BL output_character

	CMP r0, #0x0					; Did we reach end of user input?
	BNE enddd

	; For displaying the answer to the expression
	BL output_string				; Branch to output_string
	BL display_remainder			; Display Remainder for division


enddd:
	LDMFD sp!, {lr}
	mov pc, lr

;--------------------------- interrupts ----------------------------------------------
; Handles interrupt when user presses keys on keyboard
UART0Handler:
	STMFD sp!, {r0-r12, lr}

loop:
	BL read_character				; Branch & Link to read_character subroutine (reads user input)
	BL read_string					; Branch & Link to read_string subroutine (stores user input into memory)
	ADD r6, r6, #1					; Increment r6 to point at next byte in memory to store a char
	BL output_character				; Branch & Link to output_character subroutine (sends char to PuTTy)
	CMP r0, #0x0					; Did we reach end of user input?
	BNE loop						; No: loop until end of string

	; For displaying the answer to the expression
	BL output_string				; Branch to output_string
	BL display_remainder			; Display Remainder for division


	MOV r2, #0xC044
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x10				; Clears UART interrupt
	STRB r1, [r2]					; Write '1' to UARTIM RXIM Bit

nothing:
	LDMFD r13!, {r0-r12, lr}
	BX lr

	;LDMFD sp!, {lr}
	;mov pc, lr
;----------------------------------------------------------------------------
; Handles interrupt from keypad on the board
PortAHandler:
	STMFD sp!, {lr}

;	MOV r2, #0xE180					; Disable interrupt NVIC
;	MOVT r2, #0xE000
;	LDRB r1, [r2]
;	ORR r1, r1, #0x1
;	STRB r1, [r2]

	BL read_from_keypad

	BL hello

	MOV r2, #0xC044
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x10				; Clears UART interrupt
	STRB r1, [r2]					; Write '1' to UARTIM RXIM Bit

	MOV r2, #0x441C
	MOVT r2, #0x4000
	LDRB r1, [r2]
	ORR r1, r1, #0x3C				; Clears keypad interrupt (PortA pins 2-5)
	;ORR r1, r1, #0xFF
	STRB r1, [r2]					; Write '1' to pin on port A

;	MOV r2, #0xE100					; Enable interrupt NVIC
;	MOVT r2, #0xE000
;	LDRB r1, [r2]
;	ORR r1, r1, #0x1
;	STRB r1, [r2]

endd:
	LDMFD sp!, {lr}
	BX lr


;------------------------- uart init ---------------------------------------------------
; uart_init initializes the user UART for use. This is your version (in assembly language) of the C function serial_init.

uart_init:
	STMFD SP!,{lr} 				; Store register lr on stack

	MOV r2, #0xE608
	MOVT r2, #0x400F
	LDR r1, [r2]
	MOV r1, #0x2B				; Enable clock for GPIO PORT A, B, D, & F
	STR r1, [r2]

	MOV r2, #0xE618
    MOVT r2, #0x400F			; r2 = 0x400FE618
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    ORR r1, r1, #1					; Changes r1 to #1
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xE608
    MOVT r2, #0x400F			; r2 = 0x400FE608
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    ORR r1, r1, #1					; Changes r1 to #1
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xC030
    MOVT r2, #0x4000			; r2 = 0x4000C030
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    MOV r1, #0					; Changes r1 to #0
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xC024
    MOVT r2, #0x4000			; r2 = 0x4000C024
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    MOV r1, #17				; Changes r1 to #104
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xC028
    MOVT r2, #0x4000			; r2 = 0x4000C028
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    MOV r1, #23					; Changes r1 to #11
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xCFC8
    MOVT r2, #0x4000			; r2 = 0x4000CFC8
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    MOV r1, #0					; Changes r1 to #0
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xC02C
    MOVT r2, #0x4000			; r2 = 0x4000C02C
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    MOV r1, #0x60				; Changes r1 to #0x60
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0xC030
    MOVT r2, #0x4000			; r2 = 0x4000C030
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    MOV r1, #0x301				; Changes r1 to #0x301
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0x451C
    MOVT r2, #0x4000			; r2 = 0x4000451C
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    ORR r1, r1, #0x03			; Changes r1 to #0x03
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0x4420
    MOVT r2, #0x4000			; r2 = 0x40004420
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    ORR r1, r1, #0x03			; Changes r1 to #0x03
    STR r1, [r2]				; Stores back into the address

    MOV r2, #0x452C
    MOVT r2, #0x4000			; r2 = 0x4000452C
    LDR r1, [r2]				; Loads in the value in address r2 into r1
    ORR r1, r1, #0x11			; Changes r1 to #0x11
    STR r1, [r2]				; Stores back into the address


	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- display prompt ---------------------------------------------------
; Displays the prompt for the user to enter an expression on PuTTy
display_prompt:
	STMFD SP!,{lr} 				; Store register lr on stack

	MOV r3, #0xC000          	; r3 = 0xC000
   	MOVT r3, #0x4000         	; r3 = 0x4000C000 (Data Register address)

displayLoop:
	ADR r4, prompt				; r4 = address of prompt
	LDRB r0, [r4, r7]			; load first char of prompt into r0
	ADD r7, r7, #1				; Increment to next char
	BL output_character			; Output char onto PuTTy
	CMP r0, #0x0				; Did we reach end of string? (null)
	BNE displayLoop				; No: loop until null is reached

	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- display remainder ---------------------------------------------------
display_remainder:
	STMFD SP!,{lr} 				; Store register lr on stack

	MOV r3, #0xC000          	; r3 = 0xC000
   	MOVT r3, #0x4000         	; r3 = 0x4000C000 (Data Register address)
	MOV r8, #0					; counter for # of digits the answer contains
	MOV r0, #0xD				; enter ASCII
	BL output_character
	MOV r0, #0xA				; newline ASCII
	BL output_character

	MOV r7, r1					; move remainder into r7 for conversion
	MOV r11, #0					; counter for pointing at next char

; displays the string "Remainder: " onto PuTTy
displayRemainder:
	ADR r4, remainder			; r4 = address of remainder
	LDRB r0, [r4, r11]			; load first char of string into r0
	ADD r11, r11, #1			; Increment to next char
	BL output_character			; Output char onto PuTTy
	CMP r0, #0x0				; Did we reach end of string? (null)
	BNE displayRemainder		; No: loop until null is reached


; Converts the remainder to a string in order to output onto PuTTy
	MOV r3, #0					; clear r3
	MOV r4, #0x000D
	MOVT r4, #0x2000			; r4 = 0x2000000D (base address for remainder)

r2string:
	BL int_to_string			; Branch to int_to_string
	STRB r3, [r4], #-1			; Store num into memory backwards (b/c answer comes out backwards)
	ADD r8, r8, #1				; increment counter
	CMP r7, #0					; Is quotient = 0?
	BNE r2string				; No: branch back again
	MOV r5, r4					; copy base address to r5 b/c r4 will get overwritten

loop7:
	LDRB r0, [r5, #1]!			; load byte in forward order now
	BL output_character			; display it on PuTTy
	SUB r8, r8, #1				; decrement counter
	CMP r8, #0					; is counter = 0?
	BNE loop7					; no: loop till counter = 0 (answer has been fully outputted)

	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- output character --------------------------------------------
; output_character transmits a character from the UART to PuTTy. The character is passed in r0.
output_character:
	STMFD sp!,{r2-r4, lr}

	MOV r2, #0xC018					; r2 = 0xC018
    MOVT r2, #0x4000				; r2 = 0x4000C018 (Status Register address)
    MOV r3, #0xC000          		; r3 = 0xC000
    MOVT r3, #0x4000         		; r3 = 0x4000C000 (Data Register address)

oloop:
	LDR r4, [r2]					; Load contents of Status Register into r4
	AND r4, r4, #0x20				; Isolate bit TxFF for testing
	CMP r4, #0x20					; Is the TxFF bit = 1?
	BEQ oloop						; If yes, loop until TxFF = 0

	STRB r0, [r3]					; Store byte back into data register

	LDMFD sp!, {r2-r4, lr}
	mov pc, lr

;------------------------- read string -------------------------------------------------
read_string:
; read_string reads a string entered in PuTTy and stores it as a null-terminated string in memory.
; The user terminates the string by hitting Enter.
; The base address of the string should be passed into the routine in r4.

	STMFD SP!,{lr} 					; Store register lr on stack

	LDR r4, expression
	STRB r0, [r4, r6] 				; store byte at address in r4
	CMP r0, #0x0D					; Did user press enter?
	BEQ terminate					; yes: branch to terminate
	CMP r0, #0x2F					; then, did user enter operator?
	BGT count						; no: (user entered num) branch to count
	CMP r0, #0x20					; then, did user enter space?
	BEQ loop						; yes: branch & wait for valid input
	CMP r0, #0x2E					; did user enter period?
	BEQ loop
	CMP r0, #0x2C					; did user press , ?
	BEQ loop
	CMP r0, #0x27					; did user period ' ?
	BEQ loop
	CMP r0, #0x21					; did user press ! ?
	BEQ loop
	CMP r0, #0x22					; " ?
	BEQ loop
	CMP r0, #0x23					; # ?
	BEQ loop
	CMP r0, #0x24					; $ ?
	BEQ loop
	CMP r0, #0x25					; % ?
	BEQ loop
	CMP r0, #0x26					; & ?
	BEQ loop
	CMP r0, #0x28					; ( ?
	BEQ loop
	CMP r0, #0x29					; ) ?
	BEQ loop
	CMP r0, #0x9					; tab?
	BEQ loop

	MOV r5, r0						; no: move operator to r5 for safe keeping
	BL string_to_int				; branch to string_to_int
	B continue						; branch to continue

; user has pressed enter
terminate:
	MOV r0, #0x0					; move null into r0
	STRB r0, [r4, r6]				; store null in memory
	ADD r4, r4, r6					; ensure address in r4 points to where the 2nd operand will be stored
	SUB r4, r4, r8
	BL string_to_int2				; Branch to string_to_int2 to convert 2nd operand to an int
	B continue

count:
	CMP r0, #0x30					; Is input greater than or equal to 0?
	BGE check2						; Yes: check #2
	B loop							; No: go back & wait for valid input

check2:
	CMP r0, #0x39					; Is input less than or equal to 9?
	BLE increment					; Yes: valid input verified
	B loop							; No: go back & wait for valid input

increment:
	ADD r8, r8, #1					; increment r8

continue:
	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- output string -----------------------------------------------
; output_string transmits a null-terminated string for display in PuTTy.
; The base address of the string should be passed into the routine in r4.
output_string:
	STMFD SP!,{lr} 				; Store register lr on stack

	; For displaying answer practically on PuTTy
	MOV r0, #0x20				; SPACE ASCII
	BL output_character
	MOV r0, #0x3D				; EQUAL ASCII
	BL output_character
	MOV r0, #0x20				; SPACE ASCII
	BL output_character

	MOV r4, #0x000A
	MOVT r4, #0x2000			; r4 = 0x2000000A (base address)
	MOV r8, #0					; counter for # of digits the answer contains

div:
	BL int_to_string			; Branch to int_to_string
	STRB r3, [r4], #-1			; Store num into memory backwards (b/c answer comes out backwards)
	ADD r8, r8, #1				; increment counter
	CMP r7, #0					; Is quotient = 0?
	BNE div						; No: branch back to div again
	MOV r5, r4					; copy base address to r5 b/c r4 will get overwritten

loop6:
	LDRB r0, [r5, #1]!			; load byte in forward order now
	BL output_character			; display it on PuTTy
	SUB r8, r8, #1				; decrement counter
	CMP r8, #0					; is counter = 0?
	BNE loop6					; no: loop till counter = 0 (answer has been fully outputted)

	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- read character ----------------------------------------------
; read_character reads a character which is received by the UART from PuTTy, returning the character in r0.
read_character:
	STMFD SP!,{lr}					; Store register lr on stack
	MOV r2, #0xC018          		; Holds 0xC018 in r2
    MOVT r2, #0x4000         		; r2 = 0x4000C018 (Status Register address)

rloop:
    LDR r1, [r2]       		 		; Load contents of Status Register into r1
	AND r1, r1, #0x10		 		; Isolate bit RxFE for testing
	CMP r1, #0x10			 		; Is the RxFE bit = 1?
    BEQ rloop       				; If yes, loop until RxFE = 0

    ; When RxFE is 0, read the byte from the recieve register
    MOV r3, #0xC000          		; r3 = 0xC000
    MOVT r3, #0x4000         		; r3 = 0x4000C000 (Data Register address)
    LDRB r0, [r3]              		; r0 = byte from data register (one character)

    LDMFD sp!, {lr}
	mov pc, lr

;------------------------- string to integer ----------------------------------------------
; Converts string input to an integer for calculations (first operand)
string_to_int:
	STMFD SP!,{lr} 					; Store register lr on stack

	MOV r4, #0x0000
	MOVT r4, #0x2000				; r4 = 0x20000000 (base address)
	MOV r12, #10					; r12 = 10, needed for conversion

one_digit:
	LDRB r9, [r4], #1				; load first digit into r9
	SUB r9, r9, #48					; subtract 48 to get int value
	MOV r7, r9						; copy int to r7
	CMP r8, #2						; is number 2 digits long?
	BGE two_digits					; yes: branch
	B done							; no: branch to done

two_digits:
	LDRB r10, [r4], #1				; load next digit
	SUB r10, r10, #48				; subtract 48 to get int value
	MUL r9, r9, r12					; multiply 1st digit by 10
	ADD r10, r10, r9				; add r9 + r10 to get int value
	MOV r7, r10						; copy int to r7
	CMP r8, #3						; is number 3 digits long?
	BEQ three_digits				; yes: branch
	B done							; no: branch to done

three_digits:
	LDRB r11, [r4], #1				; load third digit
	SUB r11, r11, #48				; subtract 48 to get int value
	MUL r10, r10, r12				; multiply int by 10
	ADD r11, r11, r10				; r11 = r11 + r10
	MOV r7, r11						; copy int to r7

done:
	MOV r8, #0						; reset counter
	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- string to integer 2 ----------------------------------------------
; Converts string input to an integer for calculations (SECOND operand)
string_to_int2:
	STMFD SP!,{lr} 					; Store register lr on stack

	MOV r12, #10					; r12 = 10, needed for conversion


one_digit2:
	LDRB r9, [r4], #1				; load first digit into r9
	SUB r9, r9, #48					; subtract 48 to get int value
	MOV r6, r9						; move int to r6
	CMP r8, #2						; is number 2 digits long?
	BGE two_digits2					; yes: branch
	B done2							; no: branch to done

two_digits2:
	LDRB r10, [r4], #1				; load next digit
	SUB r10, r10, #48				; subtract 48 to get int value
	MUL r9, r9, r12					; multiply by 10
	ADD r10, r10, r9				; add r9 + r10 to get int value
	MOV r6, r10						; move int to r6
	CMP r8, #3						; is number 3 digits long?
	BEQ three_digits2				; yes: branch
	B done2							; no: branch to done

three_digits2:
	LDRB r11, [r4], #1				; load third digit
	SUB r11, r11, #48				; subtract 48 to get int value
	MUL r10, r10, r12				; multiply 2nd digit by 10
	ADD r11, r11, r10				; r11 = r11 + r10
	MOV r6, r11						; move int to r6

done2:
	MOV r8, #0						; reset counter
	CMP r5, #0x2B					; Is operator + ?
	BEQ addition					; Yes: branch to addition
	CMP r5, #0x2D					; Is operator - ?
	BEQ subtract					; Yes: branch to subtract
	CMP r5, #0x2F					; Is operator / ?
	BEQ divide						; Yes: branch to divide
	B complete

addition:
	ADD r7, r7, r6					; r7 = r7 + r6
	B complete

subtract:
	SUB r7, r7, r6					; r7 = r7 - r6
	B complete

divide:
	MOV r12, r6						; Move divisor into r12
	BL div_and_mod					; Do the division, remainder is in r10
	MOV r1, r10						; Move remainder to r1 for safekeeping
	B complete

complete:
	LDMFD sp!, {lr}
	mov pc, lr

;---------------------- int to string -------------------------------------
; Converts an integer back into a string for output (display)
int_to_string:
	STMFD SP!,{lr} 			; Store register lr on stack

	MOV r12, #10			; 10 needed as divisor
	BL div_and_mod			; branch to div_and_mod for conversion purposes
	ADD r3, r10, #48		; r3 = remainder + 48 (ascii value of a digit)

	LDMFD sp!, {lr}
	mov pc, lr

div_and_mod:
	STMFD SP!,{lr}

	; Clear the registers & copy needed variables to new registers
    MOV r6, #0          	; r6 = counter
    MOV r5, #0          	; r5 = remainder
	MOV r3, #0

    ADD r6, r6, #15     	; initialize r6 (counter) to 15
    MOV r2, #0          	; r2 = quotient, initialize quotient to 0
    LSL r12, r12, #15     	; Logical Left Shift Divisor 15 places
    MOV r5, r7          	; Initialize Remainder to Dividend
    B LOOP5              	; Branch to LOOP5

SUBTRACT2:
	SUB r6, r6, #1			; Decrement counter
    B LOOP5              	; Branch to LOOP5

LOOP5:
    SUB r5, r5, r12      	; Remainder:= Remainder (r5) - Divisor (r0)
    CMP r5, #0          	; Is remainder < 0 ?
    BLT YES             	; If true, branch to YES
    LSL r2, r2, #1      	; If false, Left Shift Quotient
    ADD r2, r2, #1      	; LSB = 1
    B CHECK             	; Branch to CHECK

YES:
    ADD r5, r5, r12      	; Remainder:= Remainder (r5) + Divisor (r0)
    LSL r2, r2, #1      	; Left Shift Quotient

CHECK:
	LSR r12, r12, #1      	; Right Shift Divisor
    CMP r6, #0         		; Is counter > 0 ?
    BGT SUBTRACT2

	MOV r7, r2				; copy quotient to r7

END:
	MOV r10, r5				; copy remainder to r10

	LDMFD sp!, {lr}
	mov pc, lr

;------------------------- Read from Keypad ------------------------------------------
; Checks the rows and columns of the inputted button.

read_from_keypad:
	STMFD SP!,{lr}

	MOV r9, #0x43FC			; Accessing Port A to check columns
	MOVT r9, #0x4000

; loop until a button has been pressed
wait:
	LDRB r10, [r9]			; Load data from Port A
	AND r10, r10, #0x3C		; And to isolate bits 2-5
	CMP r10, #0				; Is data greater than 0? (means button was pressed)
	BGT off					; Yes: turn off Port D pins
	B wait					; No: branch back to beginning

off:
	MOV r2, #0x73FC			; Accessing Port D
	MOVT r2, #0x4000
	LDR r1, [r2]
	MOV r1, #0x0
	STR r1, [r2]			; turn off all pins in portD
	B Row0

; executes once button press detected
Row0:
	MOV r3, #0				; Counter = 0
	MOV r1, #0x01
	STRB r1, [r2]			; turn on first row
	BL checkPortA			; Check if the button pressed was on this row
	CMP r10, r11			; if yes, branch to columns to check which button on the row was pressed
	BEQ columns

Row1:
	ADD r3, r3, #4			; Counter = 4
	MOV r1, #0x02
	STRB r1, [r2]			; turn on second row
	BL checkPortA			; Check if the button pressed was on this row
	CMP r10, r11			; if yes, branch to columns to check which button on the row was pressed
	BEQ columns

Row2:
	ADD r3, r3, #4			; Counter = 8
	MOV r1, #0x04
	STRB r1, [r2]			; turn on third row
	BL checkPortA			; Check if the button pressed was on this row
	CMP r10, r11			; if yes, branch to columns to check which button on the row was pressed
	BEQ columns

Row3:
	ADD r3, r3,  #4			; Counter = 12
	MOV r1, #0x08
	STRB r1, [r2]			; turn on fourth row
	BL checkPortA			; Check if the button pressed was on this row
	CMP r10, r11			; if yes, branch to columns to check which button on the row was pressed
	BEQ columns

checkPortA:
	STMFD SP!,{lr} 			; Store register lr on stack

	LDRB r11, [r9]			; load data in PORTA into r11
	AND r11, r11, #0x3C		; isolate bits 2-5
	AND r11, r10, r11		; AND to see if button was pressed on this row

	LDMFD sp!, {lr}
	mov pc, lr
;------------------------- columns ------------------------------------------
; checks which column was pressed & increments counter appropriately
columns:
	CMP r10, #0x04
	BEQ print
	ADD r3, r3, #1
	CMP r10, #0x08
	BEQ print
	ADD r3, r3, #1
	CMP r10, #0x10
	BEQ print
	ADD r3, r3, #1
	CMP r10, #0x20
	BEQ print

;-------------------------------------print keypad value ------------------------------------------
;Uses the counter to check which button was pressed
print:
	CMP r3, #0							; 1
	BEQ case00
	CMP r3, #1							; 2
	BEQ case01
	CMP r3, #2							; 3
	BEQ case02
	CMP r3, #3							; +
	BEQ case03
	CMP r3, #4							; 4
	BEQ case04
	CMP r3, #5							; 5
	BEQ case05
	CMP r3, #6							; 6
	BEQ case06
	CMP r3, #7							; -
	BEQ case07
	CMP r3, #8							; 7
	BEQ case08
	CMP r3, #9							; 8
	BEQ case09
	CMP r3, #10							; 9
	BEQ case10
	CMP r3, #11							; /
	BEQ case11
	CMP r3, #12							; *
	BEQ case12
	CMP r3, #13							; 0
	BEQ case13
	CMP r3, #14							; #
	BEQ case14
	CMP r3, #15							; Enter
	BEQ case15

; Cases below changes the displayed character to the one matched on the keypad
case00:
	MOV r0, #0x31						; 1
	B stoop
case01:
	MOV r0, #0x32						; 2
	B stoop
case02:
	MOV r0, #0x33						; 3
	B stoop
case03:
	MOV r0, #0x2B						; +
	B stoop
case04:
	MOV r0, #0x34						; 4
	B stoop
case05:
	MOV r0, #0x35						; 5
	B stoop
case06:
	MOV r0, #0x36						; 6
	B stoop
case07:
	MOV r0, #0x2D						; -
	B stoop
case08:
	MOV r0, #0x37						; 7
	B stoop
case09:
	MOV r0, #0x38						; 8
	B stoop
case10:
	MOV r0, #0x39						; 9
	B stoop
case11:
	MOV r0, #0x2F						; /
	B stoop
case12:
	MOV r0, #0x2A						; *
	B stoop
case13:
	MOV r0, #0x30						; 0
	B stoop
case14:
	MOV r0, #0x23						; #
	B stoop
case15:
	MOV r0, #0xD						; Enter
	B stoop

stoop:
	MOV r2, #0x73FC		; Accessing Port D
	MOVT r2, #0x4000
	LDR r1, [r2]
	MOV r1, #0xF
	STRB r1, [r2]		; turn on all pins in portD

delayy:							; delay loop for display purposes
	MOV r10, #0xFFFF
	ADD r11, r11, #1
	CMP r10, r11
	BNE delayy

	LDMFD sp!, {lr}
	mov pc, lr

	.end

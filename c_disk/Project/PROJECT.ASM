; 32-bit x86 assembly language
; TASM
;
; author:	David Blinder, Stijn Bettens
; date:		23/10/2018
; program:	Video mode 13h
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "keyb.inc"
INCLUDE "RAND.INC"
INCLUDE "GLOBAL.asm"
; global variables are stored in GLOBAL.asm


; -------------------------------------------------------------------
CODESEG
STRUC Player
x dd 160
y dd 120
width dd 20
height dd 36
ENDS Player

STRUC Enemy
x dd 80
y dd 100
width dd 12
height dd 10
spawntime dd 0
ENDS Enemy

STRUC Money
x dd 50
y dd 50
width dd 12
height dd 12
ENDS Money

; Set the video mode
PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

; Fill the background (for mode 13h)
;	* fillcolor: input color
PROC fillBackground
	ARG 	@@fillcolor:byte
	USES 	eax, ecx, edi

	; Initialize video memory address.
	mov	edi, VMEMADR

	; Scan the whole video memory and assign the background colour.
	mov	ecx, SCRWIDTH*SCRHEIGHT
	mov	al,[@@fillcolor]
	rep	stosb

	ret
ENDP fillBackground

proc wait_vblank
	ARG @@framecount: word
	USES eax, ecx, edx
	mov dx, 03dah 					; Wait for screen refresh
	movzx ecx, [@@framecount]
	
		@@VBlank_phase1:
		in al, dx 
		and al, 8
		jnz @@VBlank_phase1
		@@VBlank_phase2:
		in al, dx 
		and al, 8
		jz @@VBlank_phase2
	loop @@VBlank_phase1
	
	ret 
endp wait_vblank

; Wait for a specific keystroke.
PROC waitForSpecificKeystroke
	ARG 	@@key:byte
	USES 	eax

	@@waitForKeystroke:
		mov	ah,00h
		int	16h
		cmp	al,[@@key]
	jne	@@waitForKeystroke

	ret
ENDP waitForSpecificKeystroke

; Terminate the program.
PROC terminateProcess
	USES eax
	call __keyb_uninstallKeyboardHandler
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess


PROC ReadFile
	ARG	 @@filepathptr: dword,@@dataptr: dword,@@noofbytes: dword 
	USES eax, ebx, ecx, edx, esi, edi
	
	; open file, get filehandle in AX
	mov al, 0 ; read only
	mov edx, [@@filepathptr]
	mov ah, 3dh
	int 21h
	
	mov  edx, offset openErrorMsg
	jc @@print_error ; carry flag is set if error occurs

	; read file data 
	mov bx, ax ; move filehandle to bx
	mov ecx, [@@noofbytes]
	mov edx, [@@dataptr]
	add edx, 8 ;increment the offset of dataread with 8
	mov ah, 3fh
	int 21h

	mov  edx, offset readErrorMsg
	jc @@print_error
	
	; close file
	mov ah, 3Eh
	int 21h
	
	mov  edx, offset closeErrorMsg
	jc @@print_error
	
	ret

@@print_error:
	call setVideoMode, 03h
	mov  ah, 09h
	int  21h
	
	mov	ah,00h
	int	16h
	call terminateProcess	
ENDP ReadFile

PROC printUnsignedInteger
	ARG	@@printval:dword    ; input argument
	USES eax, ebx, ecx, edx

	mov eax, [@@printval]
	mov	ebx, 10		; divider
	xor ecx, ecx	; counter for digits to be printed

	; Store digits on stack
@@getNextDigit:
	inc	ecx         ; increase digit counter
	xor edx, edx
	div	ebx   		; divide by 10
	push dx			; store remainder on stack
	test eax, eax	; check whether zero?
	jnz	@@getNextDigit

    ; Write all digits to the standard output
	mov	ah, 2h 		; Function for printing single characters.
@@printDigits:		
	pop dx
	add	dl,'0'      	; Add 30h => code for a digit in the ASCII table, ...
	int	21h            	; Print the digit to the screen, ...
	ret
ENDP printUnsignedInteger


PROC drawKeyStrokes
	USES eax, ebx, ecx
	mov ecx, KEYCNT	; amount of keys to process
	
@@loopkeys:


; if key is on, draw red 2x2 square, otherwise draw black square
	movzx ebx, [byte ptr offset keybscancodes + ecx - 1]	; get scancode
	mov bl, [offset __keyb_keyboardState + ebx]	; obtain corresponding key state
	xor ax, ax
	sub ax, bx	; if key is pressed, AX = FFFF, otherwise AX = 0000
	
	
	loop @@loopkeys
	
	ret
ENDP drawKeyStrokes

PROC Draw
	ARG @@spritePtr : dword , \
	@@dstPtr : dword , \
	@@x: dword , \
	@@y: dword , \
	@@w: dword , \
	@@h: dword
	;LOCAL @@w: dword , @@h: dword
	USES eax , ebx , ecx , edx , esi , edi
	mov esi , [@@spritePtr]
	add esi, 8
	xor eax , eax
	mov edi , [@@dstPtr]
	mov eax , [@@y]
	mov ebx , SCRWIDTH
	mul ebx
	add edi , eax
	add edi , [@@x] ; EDI points to f i r s t p i x e l
	mov ecx , [@@h]
	@@drawLine :
	push ecx
	mov ecx , [@@w] ; need to copy a l i n e of the s p r i t e
	rep movsb ; copy from e s i to edi
	add edi , SCRWIDTH
	sub edi , [@@w] ; edi now points to the next l i n e in d s t
	pop ecx
	dec ecx
	jnz @@drawLine
	ret
ENDP Draw



PROC MovePlayer ; Check keyboard input and move character up,left,right or down , or exit the game
	USES eax, ebx, ecx
	mov ecx, offset p1
	@@moveup:
	mov     al, [__keyb_rawScanCode]
	cmp al, 48h ;; UP ARROW : go up
	jne      @@moveleft 
	cmp [ecx + Player.y] , 10	; MAP BORDERS
	jle @@done
	sub [ecx + Player.y] , 1 ; increase y
	jmp @@done
	
	@@moveleft:
	mov     al, [__keyb_rawScanCode]
    cmp al, 4Bh ;; LEFT ARROW : go left
	jne @@movedown
	cmp [ecx + Player.x], 1
	jle @@done	
	sub [ecx + Player.x], 1 ; decrease x
	jmp @@done
	
	@@movedown:
	mov al, [__keyb_rawScanCode]
	cmp al, 50h ;; DOWN ARROW : go down
	jne @@moveright
    cmp [ecx + Player.y], PLAYER_BORDERY
	jge @@done
	add [ecx + Player.y], 1 ; decrease y
	jmp @@done
	
	@@moveright: 
	mov     al, [__keyb_rawScanCode]
	cmp al, 4Dh ;; RIGHT ARROW : go right
	jne      @@done
	cmp [ecx + Player.x], PLAYER_BORDERX
	jge @@done
	add [ecx + Player.x], 1 ; increase x
	jmp @@done

	@@done:
	ret
ENDP MovePlayer

PROC MoveEnemy ; Move a specific enemy, give the enemy itself as an argument
	ARG @@Current: dword
	USES eax, ebx, ecx, edx
	mov ecx, [@@Current]
	cmp ecx, offset e1 ; e1 will move vertically with a random position
	je @@ME1
	cmp ecx, offset e2 ; e2 will move vertically with a set position and will move faster
	je @@ME2
	cmp ecx, offset e3 ; e3 will move horizontally with a random position
	je @@ME3
	cmp ecx, offset e4 ; e4 will move horizontally and vertically
	je @@ME4
	jmp @@EDone ; enemy is not recognized: nothing will be executed

	@@ME1:
	add [ecx + Enemy.y], 1 ; move 1 pixel down
    cmp [ecx + Enemy.y], SCRHEIGHT+10 
	jl @@EDone
	mov eax, edx
	@@again1:
	call rand16_x ; if borders are exceeded, reset position by putting it at the top at a random x value.
	cmp eax, edx
	je @@again1
	mov [ecx + Enemy.x], edx
	mov [ecx + Enemy.y], -10
	jmp @@EDone
	
	@@ME2:
	add [ecx + Enemy.y], 2 ; move 1 pixel down
	cmp [ecx + Enemy.y], SCRHEIGHT+10
	jl @@EDone
	mov [ecx + Enemy.y], -10 ; if borders are exceeded, reset position by putting it at the top, 20 pixels to the right, unless its completely to the right, then reset its position to the left
	add [ecx + Enemy.x], 20
	cmp [ecx + Enemy.x], SCRWIDTH+10
	jl @@EDone
	mov [ecx + Enemy.x], 0
	jmp @@EDone

	@@ME3:
	add [ecx + Enemy.x], 1 ; move 1 pixel to the right
	cmp [ecx + Enemy.x], SCRWIDTH 
	jl @@EDone
	mov eax, edx
	@@again2:
	call rand16_y
	cmp eax, edx
	je @@again2
	mov [ecx + Enemy.y], edx
	mov [ecx + Enemy.x], 0
	jmp @@EDone
	
	@@ME4:
	inc [astro_value]
	mov eax, [astro_value]
	mov ebx, 20
	cmp eax, ebx
	jl @@ME1
	mov ebx, 35
	cmp eax, ebx
	jl @@ME3
	mov [astro_value], 0

	@@EDone:
	ret
ENDP MoveEnemy


PROC CollisionsEnemy ; Check collisions of player with the enemy: if player hits the enemy, the game is over
	ARG	@@CurrEnemy: dword
	USES eax, ebx, ecx, edx
	mov ebx, offset p1
	mov eax, [@@CurrEnemy]

	; test 1: compare leftmost player with rightmost enemy
	mov edx, [eax + Enemy.x]
	add edx, [eax + Enemy.width]
	cmp edx, [ebx + Player.x] 
	jl no_collisions

	; test 2: compare leftmost enemy with rightmost player
	mov ecx, [ebx + Player.x]
	add ecx, [ebx + Player.width] 
	cmp ecx, [eax + Enemy.x] 
	jl no_collisions

	; test 3: compare lowest player with highest enemy
	mov edx, [eax + Enemy.y]
	add edx, [eax + Enemy.height]  
	cmp edx, [ebx + Player.y]
	jl no_collisions

	; test 4: compare highest player with lowest enemy
	mov ecx, [ebx + Player.y]
	add ecx, [ebx + Player.height]
	cmp ecx, [eax + Enemy.y]
	jl no_collisions

	; this piece of code will only be reached if all 4 tests are false => this implies that there is a collision, thus the game will end since the player died.
    call EndGame
    
	no_collisions: ; jump to no_collisions if there are no collisions, then we just return from the function and dont do anything.
	ret
ENDP CollisionsEnemy


PROC CollisionsCoin ; Check collisions of player with the coin: if player hits the coin, new coin spawns
	ARG @@CurrCoin: dword
	USES eax, ebx, ecx, edx
	mov ebx, offset p1
	mov eax, [@@CurrCoin]
   
	
	; test 1: compare leftmost player with rightmost coin
	mov edx, [eax + Money.x]
	add edx, [eax + Money.width]
	cmp edx, [ebx + Player.x] 
	jl no_collision

	; test 2: compare leftmost coin with rightmost player
	mov ecx, [ebx + Player.x]
	add ecx, [ebx + Player.width] 
	cmp ecx, [eax + Money.x] 
	jl no_collision

	; test 3: compare lowest player with highest coin
	mov edx, [eax + Money.y]
	add edx, [eax + Money.height]  
	cmp edx, [ebx + Player.y]
	jl no_collision

	; test 4: compare highest player with lowest coin
	mov ecx, [ebx + Player.y]
	add ecx, [ebx + Player.height]
	cmp ecx, [eax + Money.y]
	jl no_collision

	; if theres a collision with the player, then the player gains 250 score and a new coin is drawn
	add [score_int], 250
	call Draw, offset blackread, VMEMADR, [Coin.x], [Coin.y], [Coin.width], [Coin.height]
	call rand16_x
	mov [eax + Money.x], edx
	call rand16_y
	mov [eax + Money.y], edx

	
	jmp no_collision

	no_collision: ; jump to no_collisions if there are no collisions, then we just return from the function and dont do anything.
	ret
ENDP CollisionsCoin


PROC displayString
        ARG @@y:DWORD, @@x:DWORD, @@offset:DWORD
        USES EAX, EBX, EDX

        MOV EDX, [@@y] ; row in EDX
        MOV EBX, [@@x] ; column in EBX
        SHL EDX, 08H ; row in DH (00H is top)
        MOV DL, BL ; column in DL (00H is left)
        MOV AH, 09H ; write string to standard output
        MOV EDX, [@@offset] ; offset of ’$’-terminated string in EDX
        INT 21H ; raise interrupt

        RET
ENDP displayString

PROC MoveEnemies ; Move the enemy only if the current score is higher than its spawntime
	ARG @@CurrEnemy: dword
	USES ebx, ecx, eax, edx

	mov ebx, [@@CurrEnemy]
	
	mov eax, [score_int]
	
	cmp [ebx + Enemy.spawntime], eax
	jge @@skip
	inc [score_int]
	
	call MoveEnemy, ebx 
    call CollisionsEnemy, ebx 

	@@skip:
	ret
ENDP MoveEnemies


PROC CheckWin ; check if current score is higher than WINSCORE : if it is, then the player won the game, else do nothing.
	USES ebx, ecx
	mov ebx, [score_int]
	mov ecx, WINSCORE
	cmp ebx, ecx
	jl @@skip
	 @@WonGame:
	mov   al, [__keyb_rawScanCode]
	call Draw, offset youwinread, VMEMADR, 0, 0, SCRWIDTH, SCRHEIGHT
    cmp     al, 39h ;; SPACE BAR : close game tab
	jne @@WonGame
	call terminateProcess

	@@skip:
	ret
ENDP CheckWin

PROC EndGame
mov al, [__keyb_rawScanCode]
	@@GameOver:	
	mov al, [__keyb_rawScanCode]
	call Draw, offset gameoverread, VMEMADR, 0, 0, SCRWIDTH, SCRHEIGHT
	
	cmp al, 39h ;; SPACE BAR : close game tab
	jne @@GameOver
	call terminateProcess
	
	@@skip:
	ret
ENDP EndGame

PROC CheckExit ; Checks if the pressed key = ESC: if it is, exit the game, else do nothing.
	mov     al, [__keyb_rawScanCode]
	cmp     al, 01h ;; ESC : Exit game
	jne     @@skip
	call 	terminateProcess

	@@skip:
	ret
ENDP CheckExit



PROC DrawCharacters ; Draws the 4 enemies, the main character and the coin.
	call ReadFile, offset Char_image, offset dataread, GAMESIZE
	call Draw, offset dataread, VMEMADR, [p1.x], [p1.y], [p1.width], [p1.height]
	call ReadFile, offset Enemy_red, offset enemyread, GAMESIZE
	call Draw, offset enemyread, VMEMADR, [e1.x], [e1.y], [e1.width], [e1.height]
	call ReadFile, offset coin, offset coinread, GAMESIZE
	call Draw, offset coinread, VMEMADR, [Coin.x], [Coin.y], [Coin.width], [Coin.height]
	call ReadFile, offset black, offset blackread, GAMESIZE
	call ReadFile, offset Enemy_4, offset enemyread3, GAMESIZE
	call Draw, offset enemyread3, VMEMADR, [e2.x], [e2.y], [e2.width], [e2.height]
	call ReadFile, offset Enemy_blue, offset enemyread2, GAMESIZE
    call Draw, offset enemyread2, VMEMADR, [e3.x], [e3.y], [e3.width], [e3.height]
	call ReadFile, offset Last_Enemy, offset enemyread4, GAMESIZE
    call Draw, offset enemyread4, VMEMADR, [e4.x], [e4.y], [e4.width], [e4.height]
	call ReadFile, offset GameOver, offset gameoverread, GAMESIZE
	call ReadFile, offset YouWin, offset youwinread, GAMESIZE
 
	ret
ENDP DrawCharacters

PROC Startgame
	@@start:
	call ReadFile, offset Start_screen, offset startread, GAMESIZE
    call Draw, offset startread, VMEMADR, 0, 0, SCRWIDTH, SCRHEIGHT
	mov al,  [__keyb_rawScanCode]
	cmp al, 1Ch ;; ENTER; start the game
	jne @@start
	
	call fillBackground, 0
	ret
ENDP Startgame



PROC main
	sti
	cld
	push ds
	pop	es
	
	call	setVideoMode,13h
	call __keyb_installKeyboardHandler

    call drawKeyStrokes

	gameloop:
		call wait_vblank, 1

	@@start:
		call Startgame

	@@drawGameWorld: ; Responsible for drawing the game world: this includes the main character, enemies, money and the UI.
		call wait_vblank, 1
		call DrawCharacters
		
		
	@@gamelogic: ; Handles the gameplay logic: this includes enabling enemy movement, enemy collisions and coin collisions and checking if the game is won.
	    call CollisionsCoin, offset Coin
		call MoveEnemies, offset e1
		call MoveEnemies, offset e2
		call MoveEnemies, offset e3
		call MoveEnemies, offset e4	
		call CheckWin
		call CheckExit 

	@@keyboardInput: ; Registers keyboard input: The 4 arrow keys can be used to move the player (call MovePlayer), the ESC key can be used to exit the game (call CheckExit) and P can be used to pause (call CheckPause)
		call MovePlayer 
		jmp @@drawGameWorld

ENDP main

; -------------------------------------------------------------------
DATASEG
;pointers to STRUCTS
p1 Player <160, 130, 20, 32>
e1 Enemy <-30, -30, 14, 14, ENEMYSCORE1>
e2 Enemy <-30, -30, 26, 21, ENEMYSCORE2>
e3 Enemy <-30, -30, 18, 14, ENEMYSCORE3>
e4 Enemy <-30, -30, 12, 18, ENEMYSCORE4>
Coin Money <80, 120, 12, 12>


collision? db 0
score_int dd 1
astro_value dd 0

keyb_keyboardState db 128 dup(?)	; state for all 128 keys
	palette		db 768 dup (?)
	key_pressed db 0
	end_msg db "Press Space Bar to Exit the Game", '$'
	openErrorMsg db "could not open file", 13, 10, '$'
	readErrorMsg db "could not read data", 13, 10, '$'
	closeErrorMsg db "error during file closing", 13, 10, '$'
	keybscancodes db 48h
	               db 4Bh, 50h, 4Dh, 1Ch, 39h, 19h
				  
  
;bin images used for draw function
	Char_image db "Game.bin", 0
    Enemy_red db "RedM.bin", 0
	Enemy_blue db "M_blue.bin", 0
	Enemy_4 db "M4_4.bin", 0
	coin db "coin.bin", 0
    black db "black.bin", 0
	Last_Enemy db "M3.bin", 0
    Start_screen db "StartS.bin", 0
	YouWin db "YouWin.bin", 0
	GameOver db "EndG.bin", 0



	dataread dw 20, 32
	 DB GAMESIZE dup (?)
    enemyread dw 12, 10
	db GAMESIZE dup (?)
	enemyread2 dw 14, 18
	db GAMESIZE dup (?)
	enemyread3 dw 26, 21
	db GAMESIZE dup (?)
	coinread dw 12, 12
	db GAMESIZE dup (?)
    blackread dw, 12, 12
	db GAMESIZE dup (?)
	enemyread4 dw 12, 18
	db GAMESIZE dup (?)
	startread dw 320, 200
	db GAMESIZE dup (?)
	gameoverread dw 320, 200
	db GAMESIZE dup (?)
	youwinread dw 320, 200
	db GAMESIZE dup (?)
 UDATASEG
    
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main

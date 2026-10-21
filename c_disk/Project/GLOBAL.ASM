; This file contains the global variables that are needed throughout the entire code.

VMEMADR EQU 0A0000h	; video memory address
SCRWIDTH EQU 320	; screen witdth
SCRHEIGHT EQU 200	; screen height
KEYCNT EQU 6
GAMESIZE EQU 320*200
PLAYER_BORDERX EQU SCRWIDTH-20 ; x- and y- borders for the player: the player cannot go out of these bounds.
PLAYER_BORDERY EQU SCRHEIGHT-30
ENEMYSCORE1 EQU 0 ; score required for enemy 1 to spawn
ENEMYSCORE2 EQU 3000 ; score required for enemy 2 to spawn
ENEMYSCORE3 EQU 6000; score required for enemy 3 to spawn
ENEMYSCORE4 EQU 10000 ; score required for enemy 4 to spawn
WINSCORE EQU 18000 ; score required to win the game
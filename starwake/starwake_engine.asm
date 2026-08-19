; ==========================================================
; ENGINE — startup, double-buffered screen paging, low-level addressing
; Real-time action game: every frame is erase/update/draw/swap/wait,
; unlike the dungeon crawler's once-per-turn redraws. Stays in DI the
; whole game (see dungeon crawler notes - re-enabling interrupts while
; our own paging is in charge risks colliding with BASIC/ROM's ISR).
; ==========================================================

ENTRY:
    DI
    LD   SP,STACK_TOP

    IN   A,(PORT_VMPR)
    AND  &1E
    LD   (PG_BUF_A),A
    SUB  2
    LD   (PG_BUF_B),A
    SUB  2
    LD   (PG_BG),A

    LD   A,(PG_BUF_A)
    OR   VMPR_MODE4
    OUT  (PORT_VMPR),A
    LD   A,(PG_BUF_B)
    LD   (BACK_PG),A

    CALL SET_PALETTE

    JP   GAME_START

PG_BUF_A: DEFB 0
PG_BUF_B: DEFB 0
PG_BG:    DEFB 0
BACK_PG:  DEFB 0

; MAP_BACK — map BACK_PG into LMPR   CORRUPTS: A
MAP_BACK:
    LD   A,(BACK_PG)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    RET

; MAP_BG — map PG_BG into LMPR   CORRUPTS: A
MAP_BG:
    LD   A,(PG_BG)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    RET

; SWAP_BUFFERS — display the page just drawn, advance BACK_PG for next
; frame. Order matters: display first, then advance.   CORRUPTS: A
SWAP_BUFFERS:
    LD   A,(BACK_PG)
    OR   VMPR_MODE4
    OUT  (PORT_VMPR),A
    LD   A,(BACK_PG)
    XOR  2
    LD   (BACK_PG),A
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    RET

; WAIT_FRAME — vblank sync, two-phase poll on port &F9 bit 3, with a
; timeout so a missed vblank can't hang the game.   CORRUPTS: A,BC
WAIT_FRAME:
    LD   B,0
WF1:
    IN   A,(PORT_STAT)
    BIT  3,A
    JR   NZ,WF2
    DJNZ WF1
WF2:
    LD   B,0
WF3:
    IN   A,(PORT_STAT)
    BIT  3,A
    JR   Z,WF4
    DJNZ WF3
WF4:
    RET

; SCR_ADDR — compute screen byte offset from pixel X(B), Y(C)
; OUTPUT: HL = offset (0-24575)   CORRUPTS: A,DE   PRESERVES: BC
SCR_ADDR:
    LD   H,0
    LD   L,C
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL   ; HL = Y*128
    LD   A,B
    SRL  A
    LD   D,0
    LD   E,A
    ADD  HL,DE
    RET

; FILL_SCREEN — INPUT: A=fill byte   CORRUPTS: A,BC,DE,HL
FILL_SCREEN:
    LD   HL,0
    LD   (HL),A
    LD   DE,1
    LD   BC,24575
    LDIR
    RET

; SET_PALETTE — standard 16-colour CLUT
SET_PALETTE:
    LD   HL,PALETTE_DATA
    LD   B,0
SPL:
    LD   A,(HL)
    INC  HL
    LD   C,&F8
    OUT  (C),A
    INC  B
    LD   A,B
    CP   16
    JR   NZ,SPL
    RET
PALETTE_DATA:
    DEFB 0,16,32,48,64,80,96,112,25,42,59,76,93,110,119,127

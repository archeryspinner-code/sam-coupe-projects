; ==========================================================
; STARFIELD — procedural parallax background, no art needed. Gives a
; free sense of forward motion without any real scrolling/terrain
; collision (see the STARWAKE design notes on why that's the right
; trade for this hardware). Three speed layers = a cheap depth cue.
;
; Each star is a single plotted pixel, not a sprite - erase is just
; "restore the flat background colour at the old position" (no need to
; read from PG_BG at all, since the background is a known flat colour),
; which is far cheaper than ERASE_SPR's page-switching dance. Still
; needs the same per-buffer ghost tracking as any double-buffered moving
; object, and the same "erase everything before drawing anything" rule
; as the sprite entities - a star sitting under a freshly-drawn sprite
; would otherwise get erased (or drawn over) at the wrong moment.
; ==========================================================

MAX_STARS EQU 20
BG_COLOUR EQU 0          ; black - matches the &00 fill byte in GAME_START.
                          ; Blue made a weak backdrop for a starfield; black
                          ; gives the stars much better contrast.

ST_X    EQU 0
ST_Y    EQU 1
ST_LAYER EQU 2
ST_PA_X EQU 3
ST_PA_Y EQU 4
ST_PB_X EQU 5
ST_PB_Y EQU 6
STARSIZE EQU 8

STAR_POOL: DEFS MAX_STARS*STARSIZE

; INIT_STARS — scatter all stars randomly across the play area and seed
; both buffers' ghost trackers to match (so the first erase pass doesn't
; erase from a bogus position).   CORRUPTS: A,BC,DE,HL,IX
INIT_STARS:
    LD   IX,STAR_POOL
    LD   D,MAX_STARS
IST_LOOP:
    PUSH DE
    LD   A,SCR_W_PX-1         ; 255, not 256 - SCR_W_PX alone doesn't fit an
                              ; 8-bit immediate (silently truncates to 0,
                              ; which made RND_RANGE always return 0 - every
                              ; star landed at X=0, cascading down the left
                              ; edge). RND_RANGE takes a max range of 255.
    CALL RND_RANGE
    LD   (IX+ST_X),A
    LD   (IX+ST_PA_X),A
    LD   (IX+ST_PB_X),A
    LD   A,SCR_H_PX-HUD_H
    CALL RND_RANGE
    ADD  A,HUD_H
    LD   (IX+ST_Y),A
    LD   (IX+ST_PA_Y),A
    LD   (IX+ST_PB_Y),A
    LD   A,3
    CALL RND_RANGE
    LD   (IX+ST_LAYER),A
    POP  DE
    LD   BC,STARSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,IST_LOOP
    RET

; UPDATE_STARS — move each star down at a speed set by its layer, wrap
; back to the top when it leaves the bottom.   CORRUPTS: A,BC,DE,HL,IX
UPDATE_STARS:
    LD   IX,STAR_POOL
    LD   D,MAX_STARS
UST_LOOP:
    PUSH DE
    LD   A,(IX+ST_LAYER)
    INC  A                      ; speed = layer+1 -> 1,2,3 px/frame
    LD   B,A
    LD   A,(IX+ST_Y)
    ADD  A,B
    CP   SCR_H_PX
    JR   C,UST_STORE
    LD   A,HUD_H                ; wrapped past the bottom - back to the top
UST_STORE:
    LD   (IX+ST_Y),A
    POP  DE
    LD   BC,STARSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,UST_LOOP
    RET

; ERASE_STARS — restore flat background colour at every star's last
; position for the CURRENT back buffer.   CORRUPTS: A,BC,DE,HL,IX
ERASE_STARS:
    LD   IX,STAR_POOL
    LD   D,MAX_STARS
ESTR_LOOP:
    PUSH DE
    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,ESTR_USE_B
    LD   A,(IX+ST_PA_X)
    LD   B,A
    LD   A,(IX+ST_PA_Y)
    LD   C,A
    JR   ESTR_PLOT
ESTR_USE_B:
    LD   A,(IX+ST_PB_X)
    LD   B,A
    LD   A,(IX+ST_PB_Y)
    LD   C,A
ESTR_PLOT:
    LD   D,BG_COLOUR
    CALL PLOT_PIXEL
    POP  DE
    LD   BC,STARSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,ESTR_LOOP
    RET

; DRAW_STARS_ONLY — plot every star at its current position into the
; current back buffer, in a colour set by its layer (dimmer = farther),
; and update that buffer's ghost tracker. Call BEFORE the entity draws
; so sprites layer on top of stars, not the other way round.
; CORRUPTS: A,BC,DE,HL,IX
DRAW_STARS_ONLY:
    LD   IX,STAR_POOL
    LD   D,MAX_STARS
DSTR_LOOP:
    PUSH DE
    LD   A,(IX+ST_X)
    LD   B,A
    LD   A,(IX+ST_Y)
    LD   C,A
    LD   A,(IX+ST_LAYER)
    LD   HL,STAR_COLOURS
    LD   E,A
    LD   D,0
    ADD  HL,DE
    LD   A,(HL)
    LD   D,A
    CALL PLOT_PIXEL

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,DSTR_STORE_B
    LD   A,(IX+ST_X)
    LD   (IX+ST_PA_X),A
    LD   A,(IX+ST_Y)
    LD   (IX+ST_PA_Y),A
    JR   DSTR_NEXT
DSTR_STORE_B:
    LD   A,(IX+ST_X)
    LD   (IX+ST_PB_X),A
    LD   A,(IX+ST_Y)
    LD   (IX+ST_PB_Y),A
DSTR_NEXT:
    POP  DE
    LD   BC,STARSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,DSTR_LOOP
    RET
STAR_COLOURS: DEFB 7,14,15    ; dim grey, near-white, white - far to near

; PLOT_PIXEL — INPUT: B=X, C=Y, D=colour(0-15). Sets a single pixel in
; whatever page is currently mapped into LMPR.   CORRUPTS: A,HL
PLOT_PIXEL:
    LD   A,D
    LD   (PP_COLOUR),A
    CALL SCR_ADDR
    LD   A,B
    AND  1
    JR   Z,PP_LEFT
PP_RIGHT:
    LD   A,(HL)
    AND  &F0
    LD   B,A
    LD   A,(PP_COLOUR)
    OR   B
    LD   (HL),A
    RET
PP_LEFT:
    LD   A,(PP_COLOUR)
    ADD  A,A
    ADD  A,A
    ADD  A,A
    ADD  A,A
    LD   B,A
    LD   A,(HL)
    AND  &0F
    OR   B
    LD   (HL),A
    RET
PP_COLOUR: DEFB 0

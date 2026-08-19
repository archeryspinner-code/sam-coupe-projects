; ==========================================================
; PLAYER — free-form pixel movement (real-time, not grid-locked - this
; genre wants continuous motion, unlike the dungeon crawler)
; ==========================================================

PLR_X: DEFB 100
PLR_Y: DEFB 140
PLR_START_X EQU 100
PLR_START_Y EQU 140
PLR_PA_X: DEFB 100
PLR_PA_Y: DEFB 140
PLR_PB_X: DEFB 100
PLR_PB_Y: DEFB 140
FIRE_CD: DEFB 0
PLR_LIVES: DEFB START_LIVES
PLR_INVULN: DEFB 0
GAME_STATE: DEFB 0        ; 0=playing, 1=game over

; PLAYER_HIT — called when an enemy bullet connects. Loses a life; either
; respawns with a period of invulnerability, or ends the game if that was
; the last life.   CORRUPTS: A
PLAYER_HIT:
    LD   A,(PLR_LIVES)
    DEC  A
    LD   (PLR_LIVES),A
    JR   NZ,PH_RESPAWN
    LD   A,1
    LD   (GAME_STATE),A
    RET
PH_RESPAWN:
    CALL PLR_ERASE_BOTH          ; must happen BEFORE moving - see
                                  ; patterns.md "Teleporting or respawning
                                  ; a still-active sprite needs the same
                                  ; treatment" - resetting position first
                                  ; loses the only record of where to
                                  ; erase the old sprite from, leaving a
                                  ; permanent ghost in whichever buffer
                                  ; doesn't get touched this frame
    LD   A,PLR_START_X
    LD   (PLR_X),A
    LD   A,PLR_START_Y
    LD   (PLR_Y),A
    LD   A,INVULN_FRAMES
    LD   (PLR_INVULN),A
    RET

; PLR_ERASE_BOTH — erase the player from both screen buffers at its
; current (pre-teleport) ghost-tracked positions.   CORRUPTS: A,BC,DE,HL
PLR_ERASE_BOTH:
    LD   A,(BACK_PG)
    PUSH AF
    LD   A,(PG_BUF_A)
    LD   (BACK_PG),A
    LD   A,(PLR_PA_X)
    LD   B,A
    LD   A,(PLR_PA_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_SPR
    POP  DE
    LD   A,(PG_BUF_B)
    LD   (BACK_PG),A
    LD   A,(PLR_PB_X)
    LD   B,A
    LD   A,(PLR_PB_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_SPR
    POP  DE
    POP  AF
    LD   (BACK_PG),A
    CALL MAP_BACK
    RET

; UPDATE_PLAYER — apply input to position (clamped) and handle fire
; cooldown/spawn.   CORRUPTS: A,BC,DE,HL
UPDATE_PLAYER:
    LD   A,(PLR_INVULN)
    OR   A
    JR   Z,UP_NOINVULN
    DEC  A
    LD   (PLR_INVULN),A
UP_NOINVULN:
    LD   A,(INPUT_STATE)
    LD   (UP_IN),A

    BIT  0,A                     ; INP_UP
    JR   Z,UP_CKDOWN
    LD   A,(PLR_Y)
    SUB  PLR_SPEED
    CP   PLR_Y_MIN
    JR   NC,UP_YSTORE
    LD   A,PLR_Y_MIN
UP_YSTORE:
    LD   (PLR_Y),A
UP_CKDOWN:
    LD   A,(UP_IN)
    BIT  1,A                     ; INP_DOWN
    JR   Z,UP_CKLEFT
    LD   A,(PLR_Y)
    ADD  A,PLR_SPEED
    CP   PLR_Y_MAX+1
    JR   C,UP_YSTORE2
    LD   A,PLR_Y_MAX
UP_YSTORE2:
    LD   (PLR_Y),A
UP_CKLEFT:
    LD   A,(UP_IN)
    BIT  2,A                     ; INP_LEFT
    JR   Z,UP_CKRIGHT
    LD   A,(PLR_X)
    SUB  PLR_SPEED
    JR   NC,UP_XSTORE
    XOR  A
UP_XSTORE:
    LD   (PLR_X),A
UP_CKRIGHT:
    LD   A,(UP_IN)
    BIT  3,A                     ; INP_RIGHT
    JR   Z,UP_CKFIRE
    LD   A,(PLR_X)
    ADD  A,PLR_SPEED
    CP   PLR_X_MAX+1
    JR   C,UP_XSTORE2
    LD   A,PLR_X_MAX
UP_XSTORE2:
    LD   (PLR_X),A
UP_CKFIRE:
    LD   A,(FIRE_CD)
    OR   A
    JR   Z,UP_READY
    DEC  A
    LD   (FIRE_CD),A
    RET
UP_READY:
    LD   A,(UP_IN)
    BIT  4,A                     ; INP_FIRE
    RET  Z
    ; Bullet box is now much smaller than the ship (BUL_SPR_W_PX=2 vs
    ; SPR_W_PX=16) - centering it under the nose needs an explicit
    ; (SPR_W_PX-BUL_SPR_W_PX)/2 = 7px offset. The old bullet shared the
    ; ship's own 16x16 box, so PLR_X (that box's left edge) already put
    ; the bullet in the right place with no offset; that coincidence goes
    ; away once the boxes are different sizes.
    LD   A,(PLR_X)
    ADD  A,BUL_XOFF
    LD   B,A
    LD   A,(PLR_Y)
    SUB  3
    JR   NC,UP_FIREY
    XOR  A
UP_FIREY:
    LD   C,A
    CALL SPAWN_PBULLET
    LD   A,FIRE_CD_FRAMES
    LD   (FIRE_CD),A
    RET
UP_IN: DEFB 0

; RENDER_PLAYER — erase old position from the current back buffer, draw
; at the new one, update that buffer's ghost tracker. Same per-frame
; pattern as bullets/enemies.   CORRUPTS: A,BC,DE,HL,IY
; ERASE_PLAYER — erase from the current back buffer at the last-drawn
; position for that buffer.   CORRUPTS: A,BC,DE,HL
ERASE_PLAYER:
    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,EP_USE_B
    LD   A,(PLR_PA_X)
    LD   B,A
    LD   A,(PLR_PA_Y)
    LD   C,A
    JR   EP_ERASE
EP_USE_B:
    LD   A,(PLR_PB_X)
    LD   B,A
    LD   A,(PLR_PB_Y)
    LD   C,A
EP_ERASE:
    CALL ERASE_SPR
    RET

; DRAW_PLAYER_ONLY — draw at the current position into the current back
; buffer, update that buffer's ghost tracker. Call AFTER every entity's
; ERASE step this frame, never interleaved with them - see the note on
; MAIN_LOOP's ordering for why (an enemy's erase, run after the player's
; draw, was blanking the player's freshly-drawn pixels back to background
; wherever the enemy's old position happened to overlap it).
; CORRUPTS: A,BC,DE,HL,IY
DRAW_PLAYER_ONLY:
    LD   A,SPR_PLAYER
    CALL GET_SPR_PTR
    LD   A,(PLR_X)
    LD   B,A
    LD   A,(PLR_Y)
    LD   C,A
    CALL DRAW_SPR_MASKED

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,DPO_STORE_B
    LD   A,(PLR_X)
    LD   (PLR_PA_X),A
    LD   A,(PLR_Y)
    LD   (PLR_PA_Y),A
    RET
DPO_STORE_B:
    LD   A,(PLR_X)
    LD   (PLR_PB_X),A
    LD   A,(PLR_Y)
    LD   (PLR_PB_Y),A
    RET

; INIT_PLAYER_SPRITE_BOTH — draw the player into both buffers at its
; starting position and sync both ghost trackers. Call once at game
; start.   CORRUPTS: A,BC,DE,HL,IY
INIT_PLAYER_SPRITE_BOTH:
    LD   A,SPR_PLAYER
    CALL GET_SPR_PTR
    LD   (IPS_PTR),HL

    LD   A,(PG_BUF_A)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    LD   HL,(IPS_PTR)
    LD   A,(PLR_X)
    LD   B,A
    LD   A,(PLR_Y)
    LD   C,A
    CALL DRAW_SPR_MASKED
    LD   A,(PLR_X)
    LD   (PLR_PA_X),A
    LD   A,(PLR_Y)
    LD   (PLR_PA_Y),A

    LD   A,(PG_BUF_B)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    LD   HL,(IPS_PTR)
    LD   A,(PLR_X)
    LD   B,A
    LD   A,(PLR_Y)
    LD   C,A
    CALL DRAW_SPR_MASKED
    LD   A,(PLR_X)
    LD   (PLR_PB_X),A
    LD   A,(PLR_Y)
    LD   (PLR_PB_Y),A

    CALL MAP_BACK
    RET
IPS_PTR: DEFW 0

; ==========================================================
; ENEMY BULLETS — mirrors the player bullet pool but travels downward
; and can hit the player instead of enemies. Same lifecycle discipline:
; kill = erase from both buffers immediately, not deferred.
; ==========================================================

EBUL_POOL: DEFS MAX_EBUL*EBSIZE

; SPAWN_EBULLET — INPUT: B=X, C=Y   CORRUPTS: A,BC,DE,HL,IX
SPAWN_EBULLET:
    LD   A,B
    LD   (SEB_X),A
    LD   A,C
    LD   (SEB_Y),A
    LD   IX,EBUL_POOL
    LD   D,MAX_EBUL
SEB_SEARCH:
    PUSH DE
    LD   A,(IX+EB_STATE)
    OR   A
    JR   Z,SEB_FOUND
    POP  DE
    LD   BC,EBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,SEB_SEARCH
    RET                              ; pool full - drop this shot
SEB_FOUND:
    POP  DE
    LD   A,(SEB_X)
    LD   (IX+EB_X),A
    LD   (IX+EB_PA_X),A
    LD   (IX+EB_PB_X),A
    LD   A,(SEB_Y)
    LD   (IX+EB_Y),A
    LD   (IX+EB_PA_Y),A
    LD   (IX+EB_PB_Y),A
    LD   (IX+EB_STATE),STATE_ALIVE
    RET
SEB_X: DEFB 0
SEB_Y: DEFB 0

; KILL_EBULLET — INPUT: IX=record ptr. Erase from both buffers, mark
; dead.   CORRUPTS: A,BC,DE,HL
KILL_EBULLET:
    LD   A,(BACK_PG)
    PUSH AF
    LD   A,(PG_BUF_A)
    LD   (BACK_PG),A
    LD   A,(IX+EB_PA_X)
    LD   B,A
    LD   A,(IX+EB_PA_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_BULLET_SPR
    POP  DE
    LD   A,(PG_BUF_B)
    LD   (BACK_PG),A
    LD   A,(IX+EB_PB_X)
    LD   B,A
    LD   A,(IX+EB_PB_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_BULLET_SPR
    POP  DE
    POP  AF
    LD   (BACK_PG),A
    CALL MAP_BACK
    LD   (IX+EB_STATE),STATE_DEAD
    RET

; UPDATE_EBULLETS — move alive bullets down, kill on leaving the bottom
; of the play area.   CORRUPTS: A,BC,DE,HL,IX
UPDATE_EBULLETS:
    LD   IX,EBUL_POOL
    LD   D,MAX_EBUL
UEB_LOOP:
    PUSH DE
    LD   A,(IX+EB_STATE)
    OR   A
    JR   Z,UEB_NEXT
    LD   A,(IX+EB_Y)
    ADD  A,EBUL_SPEED
    CP   SCR_H_PX
    JR   C,UEB_STORE
    CALL KILL_EBULLET
    JR   UEB_NEXT
UEB_STORE:
    LD   (IX+EB_Y),A
UEB_NEXT:
    POP  DE
    LD   BC,EBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,UEB_LOOP
    RET

; ERASE_EBULLETS — erase every ALIVE enemy bullet from the current back
; buffer.   CORRUPTS: A,BC,DE,HL,IX
ERASE_EBULLETS:
    LD   IX,EBUL_POOL
    LD   D,MAX_EBUL
EEB_LOOP:
    PUSH DE
    LD   A,(IX+EB_STATE)
    OR   A
    JR   Z,EEB_NEXT

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,EEB_USE_B
    LD   A,(IX+EB_PA_X)
    LD   B,A
    LD   A,(IX+EB_PA_Y)
    LD   C,A
    JR   EEB_ERASE
EEB_USE_B:
    LD   A,(IX+EB_PB_X)
    LD   B,A
    LD   A,(IX+EB_PB_Y)
    LD   C,A
EEB_ERASE:
    CALL ERASE_BULLET_SPR
EEB_NEXT:
    POP  DE
    LD   BC,EBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,EEB_LOOP
    RET

; DRAW_EBULLETS_ONLY — draw every ALIVE enemy bullet at its current
; position, updating that buffer's ghost tracker.
; CORRUPTS: A,BC,DE,HL,IX,IY
DRAW_EBULLETS_ONLY:
    LD   IX,EBUL_POOL
    LD   D,MAX_EBUL
DEBO_LOOP:
    PUSH DE
    LD   A,(IX+EB_STATE)
    OR   A
    JR   Z,DEBO_NEXT

    LD   A,SPR_EBULLET
    CALL GET_SPR_PTR
    LD   A,(IX+EB_X)
    LD   B,A
    LD   A,(IX+EB_Y)
    LD   C,A
    PUSH IX
    CALL DRAW_BULLET_SPR
    POP  IX

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,DEBO_STORE_B
    LD   A,(IX+EB_X)
    LD   (IX+EB_PA_X),A
    LD   A,(IX+EB_Y)
    LD   (IX+EB_PA_Y),A
    JR   DEBO_NEXT
DEBO_STORE_B:
    LD   A,(IX+EB_X)
    LD   (IX+EB_PB_X),A
    LD   A,(IX+EB_Y)
    LD   (IX+EB_PB_Y),A
DEBO_NEXT:
    POP  DE
    LD   BC,EBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,DEBO_LOOP
    RET

; COLLIDE_EBULLETS_VS_PLAYER — box-distance test between every alive
; enemy bullet and the player. Threshold matches actual visible extents
; (see starwake_enemies.asm's HIT_TX/HIT_TY note on why a padded-box
; threshold makes hits feel too early, and on why the bullet's smaller
; box now needs an explicit centring offset instead of relying on the
; old same-size-box cancellation) - player ship half-extent ~6px, bullet
; dot half-extent now ~1px width/2px height (its box IS its content).
; CORRUPTS: A,BC,DE,HL,IX
HIT_PLR_TX EQU 7
HIT_PLR_TY EQU 8
CEP_XOFF EQU SPR_W_PX/2 - BUL_SPR_W_PX/2   ; player centre-X minus bullet centre-X = 7
CEP_YOFF EQU SPR_H_PX/2 - BUL_SPR_H_PX/2   ; = 6

COLLIDE_EBULLETS_VS_PLAYER:
    LD   A,(PLR_INVULN)
    OR   A
    RET  NZ                         ; can't be hit while invulnerable

    LD   IX,EBUL_POOL
    LD   D,MAX_EBUL
CEP_LOOP:
    PUSH DE
    LD   A,(IX+EB_STATE)
    OR   A
    JR   Z,CEP_NEXT

    LD   A,(IX+EB_X)
    LD   B,A
    LD   A,(PLR_X)
    SUB  B
    ADD  A,CEP_XOFF               ; recentre: (PLR_X+8)-(EB_X+1) = (PLR_X-EB_X)+7
    JP   P,CEP_XP
    NEG
CEP_XP:
    CP   HIT_PLR_TX
    JR   NC,CEP_NEXT
    LD   A,(IX+EB_Y)
    LD   B,A
    LD   A,(PLR_Y)
    SUB  B
    ADD  A,CEP_YOFF               ; recentre: (PLR_Y+8)-(EB_Y+2) = (PLR_Y-EB_Y)+6
    JP   P,CEP_YP
    NEG
CEP_YP:
    CP   HIT_PLR_TY
    JR   NC,CEP_NEXT

    CALL KILL_EBULLET
    CALL PLAYER_HIT
    POP  DE
    RET                              ; player state changed (respawn or
                                      ; game over) - stop checking more
                                      ; bullets against it this frame
CEP_NEXT:
    POP  DE
    LD   BC,EBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,CEP_LOOP
    RET

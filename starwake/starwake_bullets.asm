; ==========================================================
; PLAYER BULLETS — small pool, straight up, killed on going off-screen
; or hitting an enemy (see starwake_enemies.asm for collision).
;
; Pattern: a bullet that becomes permanently gone (off-screen or hit)
; is erased from BOTH screen buffers immediately, at the moment it dies
; - not deferred to the natural per-frame loop, which only erases+draws
; entities that are still alive. This is the pattern from patterns.md's
; "Erasing permanently-removed sprites" - skipping it leaves a ghost
; bullet on whichever buffer wasn't current when it died.
; ==========================================================

PBUL_POOL: DEFS MAX_PBUL*PBSIZE

; SPAWN_PBULLET — INPUT: B=X, C=Y   CORRUPTS: A,BC,DE,HL,IX
SPAWN_PBULLET:
    LD   A,B
    LD   (SPB_X),A
    LD   A,C
    LD   (SPB_Y),A
    LD   IX,PBUL_POOL
    LD   D,MAX_PBUL
SPB_SEARCH:
    PUSH DE
    LD   A,(IX+PB_STATE)
    OR   A
    JR   Z,SPB_FOUND
    POP  DE
    LD   BC,PBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,SPB_SEARCH
    RET                              ; pool full - drop this shot
SPB_FOUND:
    POP  DE
    LD   A,(SPB_X)
    LD   (IX+PB_X),A
    LD   (IX+PB_PA_X),A
    LD   (IX+PB_PB_X),A
    LD   A,(SPB_Y)
    LD   (IX+PB_Y),A
    LD   (IX+PB_PA_Y),A
    LD   (IX+PB_PB_Y),A
    LD   (IX+PB_STATE),STATE_ALIVE
    RET
SPB_X: DEFB 0
SPB_Y: DEFB 0

; KILL_PBULLET — INPUT: IX=record ptr. Erases from both buffers, marks
; dead.   CORRUPTS: A,BC,DE,HL
KILL_PBULLET:
    LD   A,(BACK_PG)
    PUSH AF
    LD   A,(PG_BUF_A)
    LD   (BACK_PG),A
    LD   A,(IX+PB_PA_X)
    LD   B,A
    LD   A,(IX+PB_PA_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_BULLET_SPR
    POP  DE
    LD   A,(PG_BUF_B)
    LD   (BACK_PG),A
    LD   A,(IX+PB_PB_X)
    LD   B,A
    LD   A,(IX+PB_PB_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_BULLET_SPR
    POP  DE
    POP  AF
    LD   (BACK_PG),A
    CALL MAP_BACK
    LD   (IX+PB_STATE),STATE_DEAD
    RET

; UPDATE_PBULLETS — move alive bullets up, kill on leaving the top of
; the play area.   CORRUPTS: A,BC,DE,HL,IX
UPDATE_PBULLETS:
    LD   IX,PBUL_POOL
    LD   D,MAX_PBUL
UPB_LOOP:
    PUSH DE
    LD   A,(IX+PB_STATE)
    OR   A
    JR   Z,UPB_NEXT
    LD   A,(IX+PB_Y)
    CP   PBUL_SPEED
    JR   NC,UPB_MOVE
    CALL KILL_PBULLET
    JR   UPB_NEXT
UPB_MOVE:
    SUB  PBUL_SPEED
    CP   HUD_H
    JR   NC,UPB_STORE
    CALL KILL_PBULLET
    JR   UPB_NEXT
UPB_STORE:
    LD   (IX+PB_Y),A
UPB_NEXT:
    POP  DE
    LD   BC,PBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,UPB_LOOP
    RET

; RENDER_PBULLETS — erase+redraw every ALIVE bullet in the current back
; buffer, updating that buffer's ghost tracker. Dead bullets are already
; fully erased from both buffers by KILL_PBULLET, so they're skipped
; entirely here.   CORRUPTS: A,BC,DE,HL,IX,IY
; ERASE_PBULLETS — erase every ALIVE bullet from the current back buffer
; at its last-drawn position for that buffer. Dead bullets are already
; fully erased from both buffers by KILL_PBULLET, so they're skipped.
; Call BEFORE any entity's draw step this frame - see the note on
; MAIN_LOOP's ordering.   CORRUPTS: A,BC,DE,HL,IX
ERASE_PBULLETS:
    LD   IX,PBUL_POOL
    LD   D,MAX_PBUL
EPB_LOOP:
    PUSH DE
    LD   A,(IX+PB_STATE)
    OR   A
    JR   Z,EPB_NEXT

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,EPB_USE_B
    LD   A,(IX+PB_PA_X)
    LD   B,A
    LD   A,(IX+PB_PA_Y)
    LD   C,A
    JR   EPB_ERASE
EPB_USE_B:
    LD   A,(IX+PB_PB_X)
    LD   B,A
    LD   A,(IX+PB_PB_Y)
    LD   C,A
EPB_ERASE:
    CALL ERASE_BULLET_SPR
EPB_NEXT:
    POP  DE
    LD   BC,PBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,EPB_LOOP
    RET

; DRAW_PBULLETS_ONLY — draw every ALIVE bullet at its current position
; into the current back buffer, updating that buffer's ghost tracker.
; CORRUPTS: A,BC,DE,HL,IX,IY
DRAW_PBULLETS_ONLY:
    LD   IX,PBUL_POOL
    LD   D,MAX_PBUL
DPBO_LOOP:
    PUSH DE
    LD   A,(IX+PB_STATE)
    OR   A
    JR   Z,DPBO_NEXT

    LD   A,SPR_PBULLET
    CALL GET_SPR_PTR
    LD   A,(IX+PB_X)
    LD   B,A
    LD   A,(IX+PB_Y)
    LD   C,A
    PUSH IX                       ; DRAW_BULLET_SPR uses IX as scratch -
    CALL DRAW_BULLET_SPR          ; protect our pool record pointer across it
    POP  IX

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,DPBO_STORE_B
    LD   A,(IX+PB_X)
    LD   (IX+PB_PA_X),A
    LD   A,(IX+PB_Y)
    LD   (IX+PB_PA_Y),A
    JR   DPBO_NEXT
DPBO_STORE_B:
    LD   A,(IX+PB_X)
    LD   (IX+PB_PB_X),A
    LD   A,(IX+PB_Y)
    LD   (IX+PB_PB_Y),A
DPBO_NEXT:
    POP  DE
    LD   BC,PBSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,DPBO_LOOP
    RET

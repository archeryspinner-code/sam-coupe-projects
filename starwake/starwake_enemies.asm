; ==========================================================
; ENEMIES — one straight-flying type for Phase 1. Spawner, movement,
; collision against player bullets, and per-frame render, all following
; the same "kill = erase from both buffers immediately" pattern as
; bullets.
; ==========================================================

ENEMY_POOL: DEFS MAX_ENEMIES*ENSIZE
ENEMY_SPAWN_TIMER: DEFB ENEMY_SPAWN_INT
SCORE: DEFW 0

; SPAWN_ENEMY — random X along the top.   CORRUPTS: A,BC,DE,HL,IX
SPAWN_ENEMY:
    LD   A,SCR_W_PX-SPR_W_PX+1
    CALL RND_RANGE
    LD   (SPE_X),A
    LD   IX,ENEMY_POOL
    LD   D,MAX_ENEMIES
SPE_SEARCH:
    PUSH DE
    LD   A,(IX+EN_STATE)
    OR   A
    JR   Z,SPE_FOUND
    POP  DE
    LD   BC,ENSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,SPE_SEARCH
    RET                              ; pool full - skip this spawn
SPE_FOUND:
    POP  DE
    LD   A,(SPE_X)
    LD   (IX+EN_X),A
    LD   (IX+EN_PA_X),A
    LD   (IX+EN_PB_X),A
    LD   A,HUD_H
    LD   (IX+EN_Y),A
    LD   (IX+EN_PA_Y),A
    LD   (IX+EN_PB_Y),A
    LD   (IX+EN_STATE),STATE_ALIVE
    PUSH IX
    LD   A,EFIRE_INT_RANGE
    CALL RND_RANGE
    ADD  A,EFIRE_INT_MIN
    POP  IX
    LD   (IX+EN_TIMER),A
    RET
SPE_X: DEFB 0

; UPDATE_ENEMY_SPAWNER — periodic spawn timer.   CORRUPTS: A,BC,DE,HL,IX
UPDATE_ENEMY_SPAWNER:
    LD   A,(ENEMY_SPAWN_TIMER)
    DEC  A
    LD   (ENEMY_SPAWN_TIMER),A
    JR   NZ,UES_DONE
    LD   A,ENEMY_SPAWN_INT
    LD   (ENEMY_SPAWN_TIMER),A
    CALL SPAWN_ENEMY
UES_DONE:
    RET

; KILL_ENEMY — INPUT: IX=record ptr. Erase from both buffers, mark dead.
; CORRUPTS: A,BC,DE,HL
KILL_ENEMY:
    LD   A,(BACK_PG)
    PUSH AF
    LD   A,(PG_BUF_A)
    LD   (BACK_PG),A
    LD   A,(IX+EN_PA_X)
    LD   B,A
    LD   A,(IX+EN_PA_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_SPR
    POP  DE
    LD   A,(PG_BUF_B)
    LD   (BACK_PG),A
    LD   A,(IX+EN_PB_X)
    LD   B,A
    LD   A,(IX+EN_PB_Y)
    LD   C,A
    PUSH DE
    CALL ERASE_SPR
    POP  DE
    POP  AF
    LD   (BACK_PG),A
    CALL MAP_BACK
    LD   (IX+EN_STATE),STATE_DEAD
    RET

; UPDATE_ENEMIES — move alive enemies down, kill on leaving the bottom.
; CORRUPTS: A,BC,DE,HL,IX
; UPDATE_ENEMY_FIRING — decrements each alive enemy's fire cooldown
; (EN_TIMER, reused for this rather than adding a new field); at zero,
; spawns a bullet from that enemy's current position and rolls a new
; random cooldown.   CORRUPTS: A,BC,DE,HL,IX
UPDATE_ENEMY_FIRING:
    LD   IX,ENEMY_POOL
    LD   D,MAX_ENEMIES
UEF_LOOP:
    PUSH DE
    LD   A,(IX+EN_STATE)
    OR   A
    JR   Z,UEF_NEXT
    LD   A,(IX+EN_TIMER)
    DEC  A
    LD   (IX+EN_TIMER),A
    JR   NZ,UEF_NEXT

    ; Same centering need as the player's shot (see starwake_player.asm's
    ; UP_READY) - the enemy's own box is SPR_W_PX wide, the bullet's is
    ; only BUL_SPR_W_PX, so an explicit BUL_XOFF is needed to keep the
    ; shot centred under the enemy rather than pinned to its left edge.
    ; Y is offset a few px down from the box top so the shot appears to
    ; emerge from around the enemy's body rather than its very top edge.
    LD   A,(IX+EN_X)
    ADD  A,BUL_XOFF
    LD   B,A
    LD   A,(IX+EN_Y)
    ADD  A,6
    LD   C,A
    PUSH IX
    CALL SPAWN_EBULLET
    POP  IX

    PUSH IX
    LD   A,EFIRE_INT_RANGE
    CALL RND_RANGE
    ADD  A,EFIRE_INT_MIN
    POP  IX
    LD   (IX+EN_TIMER),A
UEF_NEXT:
    POP  DE
    LD   BC,ENSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,UEF_LOOP
    RET

UPDATE_ENEMIES:
    LD   IX,ENEMY_POOL
    LD   D,MAX_ENEMIES
UEN_LOOP:
    PUSH DE
    LD   A,(IX+EN_STATE)
    OR   A
    JR   Z,UEN_NEXT
    LD   A,(IX+EN_Y)
    ADD  A,ENEMY_SPEED
    CP   SCR_H_PX
    JR   C,UEN_STORE
    CALL KILL_ENEMY
    JR   UEN_NEXT
UEN_STORE:
    LD   (IX+EN_Y),A
UEN_NEXT:
    POP  DE
    LD   BC,ENSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,UEN_LOOP
    RET

; RENDER_ENEMIES — erase+redraw every ALIVE enemy in the current back
; buffer.   CORRUPTS: A,BC,DE,HL,IX,IY
; ERASE_ENEMIES — erase every ALIVE enemy from the current back buffer at
; its last-drawn position for that buffer. Call BEFORE any entity's draw
; step this frame - see the note on MAIN_LOOP's ordering (this was the
; actual cause of the "enemy blanks the player with background colour"
; bug: erasing an enemy's old position was clobbering the player's
; freshly-drawn pixels wherever the two happened to overlap, since erase
; doesn't know or care what else is currently drawn there).
; CORRUPTS: A,BC,DE,HL,IX
ERASE_ENEMIES:
    LD   IX,ENEMY_POOL
    LD   D,MAX_ENEMIES
EEN_LOOP:
    PUSH DE
    LD   A,(IX+EN_STATE)
    OR   A
    JR   Z,EEN_NEXT

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,EEN_USE_B
    LD   A,(IX+EN_PA_X)
    LD   B,A
    LD   A,(IX+EN_PA_Y)
    LD   C,A
    JR   EEN_ERASE
EEN_USE_B:
    LD   A,(IX+EN_PB_X)
    LD   B,A
    LD   A,(IX+EN_PB_Y)
    LD   C,A
EEN_ERASE:
    CALL ERASE_SPR
EEN_NEXT:
    POP  DE
    LD   BC,ENSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,EEN_LOOP
    RET

; DRAW_ENEMIES_ONLY — draw every ALIVE enemy at its current position into
; the current back buffer, updating that buffer's ghost tracker.
; CORRUPTS: A,BC,DE,HL,IX,IY
DRAW_ENEMIES_ONLY:
    LD   IX,ENEMY_POOL
    LD   D,MAX_ENEMIES
DENO_LOOP:
    PUSH DE
    LD   A,(IX+EN_STATE)
    OR   A
    JR   Z,DENO_NEXT

    LD   A,SPR_ENEMY
    CALL GET_SPR_PTR
    LD   A,(IX+EN_X)
    LD   B,A
    LD   A,(IX+EN_Y)
    LD   C,A
    PUSH IX                       ; DRAW_SPR_MASKED uses IX as scratch -
    CALL DRAW_SPR_MASKED          ; protect our pool record pointer across it
    POP  IX

    LD   A,(BACK_PG)
    LD   B,A
    LD   A,(PG_BUF_A)
    CP   B
    JR   NZ,DENO_STORE_B
    LD   A,(IX+EN_X)
    LD   (IX+EN_PA_X),A
    LD   A,(IX+EN_Y)
    LD   (IX+EN_PA_Y),A
    JR   DENO_NEXT
DENO_STORE_B:
    LD   A,(IX+EN_X)
    LD   (IX+EN_PB_X),A
    LD   A,(IX+EN_Y)
    LD   (IX+EN_PB_Y),A
DENO_NEXT:
    POP  DE
    LD   BC,ENSIZE
    ADD  IX,BC
    DEC  D
    JR   NZ,DENO_LOOP
    RET

; COLLIDE_PBULLETS_VS_ENEMIES — box-distance test, IX=bullet loop,
; IY=enemy loop, loop counters kept in memory (not registers) so neither
; KILL_ENEMY nor KILL_PBULLET's internal DE usage can corrupt them - see
; entities.md/sound.md for what happens when a loop counter shares a
; register with something a callee clobbers.   CORRUPTS: A,BC,DE,HL,IX,IY
; Collision threshold, precisely matched to the sprites' actual visible
; pixel extents rather than their full 16x16 padded boxes.
;
; PB_X/PB_Y and EN_X/EN_Y are each sprite's box TOP-LEFT corner, not its
; visual centre. This USED to be a harmless simplification: both bullet
; and enemy shared the same 16x16 box, so comparing top-left corners gave
; the exact same delta as comparing true centres (the +8,+8 offset was
; identical for both and cancelled out in the subtraction - see
; sprites.md's warning about this exact trap). That cancellation breaks
; now that the bullet has its own much smaller BUL_SPR_W_PX x
; BUL_SPR_H_PX box (see starwake_sprites.asm) - its centre offset is
; +1,+2, not +8,+8, so the two offsets no longer match and must be
; applied explicitly (CPE_XOFF/CPE_YOFF below) rather than left to cancel.
;
; Threshold sized to the sum of each sprite's real half-extent. Enemy
; diamond half-extent ~6.5px (both axes, unchanged). The bullet's box IS
; now its visible content (no padding), so its half-extent is just half
; the box: BUL_SPR_W_PX/2=1px half-width, BUL_SPR_H_PX/2=2px half-height
; (previously ~1.5/2.5px estimated within the old padded box). Sums:
; X: 6.5+1=7.5, Y: 6.5+2=8.5 - close enough to the previous 8/9 that the
; thresholds themselves don't need to move, only the centring offset does.
HIT_TX EQU 8
HIT_TY EQU 9
CPE_XOFF EQU SPR_W_PX/2 - BUL_SPR_W_PX/2   ; enemy centre-X minus bullet centre-X offset = 8-1 = 7
CPE_YOFF EQU SPR_H_PX/2 - BUL_SPR_H_PX/2   ; = 8-2 = 6

COLLIDE_PBULLETS_VS_ENEMIES:
    LD   IX,PBUL_POOL
    LD   A,MAX_PBUL
    LD   (CPE_BCNT),A
CPE_BLOOP:
    LD   A,(IX+PB_STATE)
    OR   A
    JR   Z,CPE_BNEXT

    LD   IY,ENEMY_POOL
    LD   A,MAX_ENEMIES
    LD   (CPE_ECNT),A
CPE_ELOOP:
    LD   A,(IY+EN_STATE)
    OR   A
    JR   Z,CPE_ENEXT

    LD   A,(IX+PB_X)
    LD   B,A
    LD   A,(IY+EN_X)
    SUB  B
    ADD  A,CPE_XOFF               ; recentre: (EN_X+8)-(PB_X+1) = (EN_X-PB_X)+7
    JP   P,CPE_XP
    NEG
CPE_XP:
    CP   HIT_TX
    JR   NC,CPE_ENEXT
    LD   A,(IX+PB_Y)
    LD   B,A
    LD   A,(IY+EN_Y)
    SUB  B
    ADD  A,CPE_YOFF               ; recentre: (EN_Y+8)-(PB_Y+2) = (EN_Y-PB_Y)+6
    JP   P,CPE_YP
    NEG
CPE_YP:
    CP   HIT_TY
    JR   NC,CPE_ENEXT

    PUSH IX                       ; preserve bullet ptr across the IX reuse below
    PUSH IY
    POP  IX
    CALL KILL_ENEMY
    POP  IX                       ; IX = bullet ptr, restored
    CALL KILL_PBULLET
    CALL ADD_SCORE_ONE
    JR   CPE_BNEXT                ; this bullet is gone - stop checking it

CPE_ENEXT:
    LD   BC,ENSIZE
    ADD  IY,BC
    LD   A,(CPE_ECNT)
    DEC  A
    LD   (CPE_ECNT),A
    JR   NZ,CPE_ELOOP

CPE_BNEXT:
    LD   BC,PBSIZE
    ADD  IX,BC
    LD   A,(CPE_BCNT)
    DEC  A
    LD   (CPE_BCNT),A
    JR   NZ,CPE_BLOOP
    RET
CPE_BCNT: DEFB 0
CPE_ECNT: DEFB 0

; ADD_SCORE_ONE — SCORE += 10 (16-bit).   CORRUPTS: A,HL
ADD_SCORE_ONE:
    LD   HL,(SCORE)
    LD   DE,10
    ADD  HL,DE
    LD   (SCORE),HL
    RET

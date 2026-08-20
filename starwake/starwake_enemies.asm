; ==========================================================
; ENEMIES — one straight-flying type for Phase 1. Spawner, movement,
; collision against player bullets, and per-frame render, all following
; the same "kill = erase from both buffers immediately" pattern as
; bullets.
; ==========================================================

ENEMY_POOL: DEFS MAX_ENEMIES*ENSIZE
ENEMY_SPAWN_TIMER: DEFB ENEMY_SPAWN_MIN
SCORE: DEFW 0

; SINE_TABLE - one full weave cycle, amplitude ~10px, 16 steps. Movement
; uses this as DELTAS (next value minus current), not as an absolute X
; offset from some stored base position - that avoids needing an extra
; "base X" field per enemy (which would've meant growing ENSIZE again):
; adding consecutive differences to a starting X reproduces the same
; curve as adding absolute offsets to a fixed base would, without ever
; storing the base itself.
SINE_TABLE: DEFB 0,4,7,9,10,9,7,4,0,-4,-7,-9,-10,-9,-7,-4

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

    ; Movement pattern is randomised per-enemy, not per-wave, so a single
    ; wave can mix behaviours - RND_RANGE/CALL don't touch IX, so no
    ; PUSH/POP needed around them here (unlike the fire-timer roll above,
    ; which uses IX+d addressing before AND after the call and so does
    ; need the wrap).
    LD   A,3
    CALL RND_RANGE                 ; 0=straight 1=sine 2=zigzag
    LD   (IX+EN_TYPE),A
    CP   TYPE_SINE
    JR   NZ,SPE_CKZIGZAG
    LD   A,16
    CALL RND_RANGE                 ; random start point in the weave cycle
    JR   SPE_PHASE_SET
SPE_CKZIGZAG:
    CP   TYPE_ZIGZAG
    JR   NZ,SPE_PHASE_ZERO
    LD   A,2
    CALL RND_RANGE                 ; random initial bounce direction
    JR   SPE_PHASE_SET
SPE_PHASE_ZERO:
    XOR  A
SPE_PHASE_SET:
    LD   (IX+EN_PHASE),A
    RET
SPE_X: DEFB 0

; UPDATE_ENEMY_SPAWNER — periodic wave trigger. Each tick spawns a
; randomised BATCH of WAVE_SIZE_MIN..WAVE_SIZE_MAX enemies (each with its
; own random X and movement type via SPAWN_ENEMY) rather than always
; exactly one, and rolls a randomised delay before the next tick instead
; of a flat interval - see the constants block in starwake.asm for why.
; CORRUPTS: A,BC,DE,HL,IX
UPDATE_ENEMY_SPAWNER:
    LD   A,(ENEMY_SPAWN_TIMER)
    DEC  A
    LD   (ENEMY_SPAWN_TIMER),A
    JR   NZ,UES_DONE

    LD   A,WAVE_SIZE_MAX-WAVE_SIZE_MIN+1
    CALL RND_RANGE
    ADD  A,WAVE_SIZE_MIN
    LD   (UES_COUNT),A
UES_SPAWN_LOOP:
    CALL SPAWN_ENEMY
    LD   A,(UES_COUNT)
    DEC  A
    LD   (UES_COUNT),A
    JR   NZ,UES_SPAWN_LOOP

    LD   A,ENEMY_SPAWN_RANGE
    CALL RND_RANGE
    ADD  A,ENEMY_SPAWN_MIN
    LD   (ENEMY_SPAWN_TIMER),A
UES_DONE:
    RET
UES_COUNT: DEFB 0

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

; UPDATE_ENEMIES — moves each alive enemy down (as before), then applies
; horizontal movement according to its EN_TYPE (rolled once at spawn -
; see SPAWN_ENEMY). This is what makes waves look different from each
; other beyond just count: TYPE_STRAIGHT enemies fall straight as before;
; TYPE_SINE and TYPE_ZIGZAG weave/bounce sideways while descending.
; No CALL happens between reading and using IX here (RND_RANGE isn't
; used in this routine), so no PUSH/POP IX wrap is needed around the
; movement branch itself - only KILL_ENEMY (below) needs the usual care,
; same as before.   CORRUPTS: A,BC,DE,HL,IX
UPDATE_ENEMIES:
    LD   IX,ENEMY_POOL
    LD   D,MAX_ENEMIES
UEN_LOOP:
    PUSH DE
    LD   A,(IX+EN_STATE)
    OR   A
    JP   Z,UEN_NEXT
    LD   A,(IX+EN_Y)
    ADD  A,ENEMY_SPEED
    CP   SCR_H_PX
    JR   C,UEN_STORE
    CALL KILL_ENEMY
    JP   UEN_NEXT
UEN_STORE:
    LD   (IX+EN_Y),A

    LD   A,(IX+EN_TYPE)
    CP   TYPE_SINE
    JR   Z,UEN_SINE
    CP   TYPE_ZIGZAG
    JR   Z,UEN_ZIGZAG
    JP   UEN_NEXT                 ; TYPE_STRAIGHT - no X movement

UEN_SINE:
    ; dx = SINE_TABLE[phase+1] - SINE_TABLE[phase]; X += dx; advance phase.
    ; See SINE_TABLE's comment for why this is a delta, not an absolute
    ; offset from a stored base position.
    LD   A,(IX+EN_PHASE)
    LD   H,0
    LD   L,A
    LD   DE,SINE_TABLE
    ADD  HL,DE
    LD   B,(HL)                   ; B = SINE_TABLE[old phase]
    LD   A,(IX+EN_PHASE)
    INC  A
    AND  15                       ; wrap 0-15 (table has 16 entries)
    LD   (IX+EN_PHASE),A
    LD   H,0
    LD   L,A
    LD   DE,SINE_TABLE
    ADD  HL,DE
    LD   A,(HL)                   ; A = SINE_TABLE[new phase]
    SUB  B                        ; A = dx (signed, small magnitude ~<=4)
    LD   B,A
    ; Clamp X+dx into [0,EN_X_MAX]. IMPORTANT: this does NOT test the sign
    ; of the SUM (X+dx) via JP P/M - X itself is an unsigned 0-240 value
    ; that legitimately has bit7 set once it's >=128 (e.g. X=129 is a
    ; perfectly ordinary mid-screen position, not "negative"). Testing the
    ; sum's sign flag would misread any such value as underflow and snap
    ; it to 0 - confirmed by direct testing: a sine enemy's X collapsed to
    ; 0 the moment it first exceeded 127, instead of continuing to weave
    ; around 120-130 as it should. The fix: only ever sign-test the small
    ; DELTA (B), which is genuinely a signed value in a safe range, then
    ; clamp the unsigned X using plain CP against known bounds - never
    ; sign-test X or (X+dx) itself.
    LD   A,(IX+EN_X)
    BIT  7,B
    JR   Z,UEN_SINE_POS            ; dx >= 0
    PUSH AF                        ; dx < 0 - save old X, get |dx|
    LD   A,B
    NEG
    LD   C,A                       ; C = |dx|
    POP  AF                        ; A = old X
    CP   C
    JR   C,UEN_SINE_CLAMP0         ; old X < |dx| -> would underflow
    ADD  A,B                       ; safe: old X - |dx|, stays >= 0
    JR   UEN_XSTORE
UEN_SINE_CLAMP0:
    XOR  A
    JR   UEN_XSTORE
UEN_SINE_POS:
    ADD  A,B                       ; old X + dx, dx small so no wrap risk
    CP   EN_X_MAX+1
    JR   C,UEN_XSTORE
    LD   A,EN_X_MAX
    JR   UEN_XSTORE

UEN_ZIGZAG:
    ; EN_PHASE bit0 = current direction (0=right, 1=left). Bounce off
    ; both screen edges by flipping it and re-clamping X into range.
    ; Same sign-testing rule as the sine branch above: B (the delta) is
    ; safe to sign-test, X and X+dx are not.
    LD   A,(IX+EN_PHASE)
    LD   B,ZIGZAG_SPEED
    BIT  0,A
    JR   Z,UEN_ZZ_RIGHT
    LD   A,B
    NEG
    LD   B,A
UEN_ZZ_RIGHT:
    LD   A,(IX+EN_X)
    BIT  7,B
    JR   Z,UEN_ZZ_POS               ; dx >= 0
    PUSH AF
    LD   A,B
    NEG
    LD   C,A
    POP  AF
    CP   C
    JR   C,UEN_ZZ_CLAMP0
    ADD  A,B
    JR   UEN_XSTORE
UEN_ZZ_CLAMP0:
    XOR  A                         ; went negative - clamp to left edge
    LD   (IX+EN_PHASE),0           ; direction -> 0 (go right next time)
    JR   UEN_XSTORE
UEN_ZZ_POS:
    ADD  A,B
    CP   EN_X_MAX+1
    JR   C,UEN_XSTORE
    LD   A,EN_X_MAX
    LD   (IX+EN_PHASE),1           ; direction -> 1 (go left next time)

UEN_XSTORE:
    LD   (IX+EN_X),A
UEN_NEXT:
    POP  DE
    LD   BC,ENSIZE
    ADD  IX,BC
    DEC  D
    JP   NZ,UEN_LOOP      ; JR (relative ±127) no longer reaches UEN_LOOP
                           ; now that the sine/zigzag branches sit between
                           ; them - JP is a plain 3-byte absolute jump with
                           ; no such range limit, same effect either way
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
;
; This SUB+JP P/NEG sign test on (EN_X-PB_X)+offset is safe (unlike the
; UPDATE_ENEMIES sign-testing pitfall documented above) specifically
; because both EN_X and PB_X are bounded to [0,240] - the true difference
; can never reach the +-128 range where the two's-complement fold would
; misfire, so treating this difference as signed is fine here. That
; safety argument does NOT extend to sign-testing an absolute coordinate
; like X itself (see UEN_SINE/UEN_ZIGZAG above) - the two situations look
; similar but aren't.
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

; ==========================================================
; MAIN — game start and the real-time frame loop
; ==========================================================

GAME_START:
    ; Fill all three pages with a plain dark background, then stripe the
    ; play area (HUD_H..SCR_H_PX-1) with the palette-cycling background -
    ; DRAW_BG_STRIPES must run once per page while THAT page is still
    ; mapped, same as the black fill, so it's called right after each
    ; FILL_SCREEN rather than in a separate pass. CORRUPTS: A,BC,DE,HL
    LD   A,(PG_BG)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    LD   A,&00
    CALL FILL_SCREEN
    CALL DRAW_BG_STRIPES

    LD   A,(PG_BUF_A)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    LD   A,&00
    CALL FILL_SCREEN
    CALL DRAW_BG_STRIPES

    LD   A,(PG_BUF_B)
    OR   RAM_BIT
    OUT  (PORT_LMPR),A
    LD   A,&00
    CALL FILL_SCREEN
    CALL DRAW_BG_STRIPES

    CALL MAP_BACK
    CALL INIT_STARS
    CALL INIT_PLAYER_SPRITE_BOTH

MAIN_LOOP:
    LD   A,(GAME_STATE)
    OR   A
    JR   NZ,GAME_OVER

    CALL READ_KEYS
    CALL UPDATE_PLAYER
    CALL UPDATE_PBULLETS
    CALL UPDATE_EBULLETS
    CALL UPDATE_ENEMY_SPAWNER
    CALL UPDATE_ENEMY_FIRING
    CALL UPDATE_ENEMIES
    CALL COLLIDE_PBULLETS_VS_ENEMIES
    CALL COLLIDE_EBULLETS_VS_PLAYER
    CALL UPDATE_STARS
    CALL UPDATE_BG_CYCLE          ; palette-only - no video memory touched,
                                   ; so it doesn't need to slot into the
                                   ; erase/draw ordering below at all

    ; Erase every entity's OLD position first, before ANY entity is
    ; redrawn. Interleaving erase-then-draw per entity (the previous
    ; structure) let a later entity's erase step blank out an earlier
    ; entity's freshly-drawn pixels whenever their positions overlapped -
    ; confirmed on real hardware as the enemy sprite blanking the player
    ; out with background colour wherever it passed over. Stars follow
    ; the same rule for the same reason.
    CALL ERASE_STARS
    CALL ERASE_PLAYER
    CALL ERASE_PBULLETS
    CALL ERASE_EBULLETS
    CALL ERASE_ENEMIES

    ; Stars draw first so they sit behind the sprites, not on top of them.
    CALL DRAW_STARS_ONLY
    CALL DRAW_PLAYER_ONLY
    CALL DRAW_PBULLETS_ONLY
    CALL DRAW_EBULLETS_ONLY
    CALL DRAW_ENEMIES_ONLY

    CALL SWAP_BUFFERS
    CALL WAIT_FRAME
    JR   MAIN_LOOP

; GAME_OVER — simple border flash + halt for now. A proper game-over
; screen (with score display) is a Phase 3 item once the HUD font exists.
GAME_OVER:
    LD   A,2
    OUT  (PORT_BORDER),A
GAME_OVER_HALT:
    HALT
    JR   GAME_OVER_HALT

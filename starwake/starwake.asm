; ==========================================================
; STARWAKE — vertical shmup, Phase 1
; Ship movement, one enemy type, player bullets, collision.
; Build: pasmo starwake.asm starwake.bin starwake.lst
; Load:  LOAD "starwake" CODE 32768 : RANDOMIZE USR 32768
; ==========================================================

; ---- Hardware ports ----
PORT_LMPR   EQU 250
PORT_HMPR   EQU 251
PORT_VMPR   EQU 252
PORT_STAT   EQU 249
PORT_BORDER EQU 254
RAM_BIT     EQU &20
VMPR_MODE4  EQU (3 << 5)

STACK_TOP   EQU &EF00

; ---- Screen ----
SCR_BYTES_W EQU 128
SCR_W_PX    EQU 256
SCR_H_PX    EQU 192
HUD_H       EQU 16      ; top band reserved for score/lives (Phase 3)

; ---- Sprites (all 16x16 for phase 1 - simplest, reuses one draw path) ----
SPR_W    EQU 8
SPR_H    EQU 16
SPR_W_PX EQU 16
SPR_H_PX EQU 16

; ---- Bullets get their own much smaller box (see starwake_sprites.asm's
; DRAW_BULLET_SPR/ERASE_BULLET_SPR). The old dot used the full 16x16
; SPR_W/SPR_H box above even though its actual visible pixels only ever
; occupied a few px in the middle - erase/draw cost scales with box area,
; and bullets are the most numerous entity on screen, so a dedicated tiny
; box is a real, measurable win rather than a cosmetic one. Sized to
; 1 byte x 4 rows (2x4px) - just the tapered dot's true footprint, no
; padding - chosen over keeping the 16x16 box's per-pixel mask, which the
; dot still needs even at this size to keep its tapered top/bottom edge
; rather than becoming a plain rectangle.
BUL_SPR_W    EQU 1
BUL_SPR_H    EQU 4
BUL_SPR_W_PX EQU 2
BUL_SPR_H_PX EQU 4

; Horizontal centering offset: how far right of a shooter's own box's
; left edge (SPR_W_PX wide) a bullet's box (BUL_SPR_W_PX wide) must spawn
; to appear centred under it. Named here rather than inlined as
; "(SPR_W_PX-BUL_SPR_W_PX)/2" at each call site both for clarity and
; because pasmo can misparse an expression in parens right after an 8-bit
; ADD as an attempted indirect operand.
BUL_XOFF EQU (SPR_W_PX-BUL_SPR_W_PX)/2

SPR_PLAYER  EQU 0
SPR_PBULLET EQU 1
SPR_ENEMY   EQU 2
SPR_EBULLET EQU 3

; ---- Player ----
PLR_SPEED EQU 2
PLR_X_MIN EQU 0
PLR_X_MAX EQU SCR_W_PX-SPR_W_PX          ; 240
PLR_Y_MIN EQU HUD_H
PLR_Y_MAX EQU SCR_H_PX-SPR_H_PX          ; 176

FIRE_CD_FRAMES EQU 8

START_LIVES    EQU 3
INVULN_FRAMES  EQU 100     ; ~2 seconds @ 50Hz of no-damage after respawn

; ---- Player bullets ----
MAX_PBUL   EQU 8
PBUL_SPEED EQU 5
PB_X    EQU 0
PB_Y    EQU 1
PB_STATE EQU 2
PB_PA_X EQU 3
PB_PA_Y EQU 4
PB_PB_X EQU 5
PB_PB_Y EQU 6
PBSIZE  EQU 8

; ---- Enemy bullets ----
MAX_EBUL      EQU 8
EBUL_SPEED    EQU 3
EFIRE_INT_MIN EQU 50       ; frames between an enemy's shots (min)
EFIRE_INT_RANGE EQU 50     ; + random 0-49 more, so shots don't sync up
EB_X    EQU 0
EB_Y    EQU 1
EB_STATE EQU 2
EB_PA_X EQU 3
EB_PA_Y EQU 4
EB_PB_X EQU 5
EB_PB_Y EQU 6
EBSIZE  EQU 8

; ---- Enemies ----
MAX_ENEMIES     EQU 6
ENEMY_SPEED     EQU 1
ENEMY_SPAWN_INT EQU 60      ; frames between spawns (~1.2s @ 50Hz)
EN_X     EQU 0
EN_Y     EQU 1
EN_STATE EQU 2
EN_TIMER EQU 3              ; doubles as this enemy's fire cooldown
EN_PA_X  EQU 4
EN_PA_Y  EQU 5
EN_PB_X  EQU 6
EN_PB_Y  EQU 7
ENSIZE   EQU 8

STATE_DEAD  EQU 0
STATE_ALIVE EQU 1

; ---- Input bits ----
INP_UP    EQU &01
INP_DOWN  EQU &02
INP_LEFT  EQU &04
INP_RIGHT EQU &08
INP_FIRE  EQU &10

    ORG &8000

    INCLUDE "starwake_engine.asm"
    INCLUDE "starwake_sprites.asm"
    INCLUDE "starwake_stars.asm"
    INCLUDE "starwake_rng.asm"
    INCLUDE "starwake_input.asm"
    INCLUDE "starwake_player.asm"
    INCLUDE "starwake_bullets.asm"
    INCLUDE "starwake_ebullets.asm"
    INCLUDE "starwake_enemies.asm"
    INCLUDE "starwake_main.asm"

    END ENTRY

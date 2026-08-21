; ==========================================================
; BACKGROUND CYCLE — palette-cycling "moving surface" effect. A static
; striped pattern is drawn ONCE at startup into PG_BG and both screen
; buffers; every frame after that, only the CLUT entries controlling the
; stripe colours get rewritten (a handful of OUT writes) - the stripe
; pixels themselves are never touched again, so this costs essentially
; nothing per frame compared to any actual redraw. This is a genuine,
; documented SAM Coupe technique (period reference material for the
; machine lists "colour cycling" alongside sprites/scrolling as a
; standard graphics method), not a hack specific to this project.
;
; Uses colour indices 2,3,4,5 - confirmed unused by any sprite, bullet,
; or star (those use {0,1,6,7,9,12,13,14,15} - see SET_PALETTE's
; PALETTE_DATA in starwake_engine.asm), so cycling them can never affect
; player/enemy/bullet/star colours. Deliberately reuses PALETTE_DATA's
; EXISTING values for indices 2-5 (32,48,64,80 - already a smooth
; ascending ramp) rather than picking new ones: this file only rotates
; WHICH index shows which of those four values, it never invents new
; palette entries, so there's nothing here whose on-screen colour hasn't
; already been chosen and is sitting untested.
; ==========================================================

BAND_HEIGHT      EQU 8    ; rows per stripe band
BGCYCLE_INTERVAL EQU 4    ; rotate every N frames -> BAND_HEIGHT/N px-
                           ; equivalent apparent scroll per frame (8/4=2,
                           ; matching a mid-speed starfield layer - see
                           ; starwake_stars.asm's per-layer speeds)

BGCYCLE_TIMER: DEFB BGCYCLE_INTERVAL
BGCYCLE_VALS:  DEFB 32,48,64,80   ; live copy of PALETTE_DATA indices 2-5;
                                   ; this copy is what actually gets
                                   ; rotated and re-sent to the CLUT each
                                   ; tick - PALETTE_DATA itself is only
                                   ; ever read once, at boot, by
                                   ; SET_PALETTE, and is never touched here

; DRAW_BG_STRIPES — fills the play area (HUD_H..SCR_H_PX-1) of whatever
; page is currently mapped into LMPR with horizontal bands, each
; BAND_HEIGHT rows tall, cycling through colour indices 2,3,4,5. Solid
; fill (both nibbles the same index) since this is a plain background,
; not a masked sprite - no transparency needed. Call once per target
; page (PG_BG, then each screen buffer) at startup; this is a one-time
; setup cost, not a per-frame one, so it isn't optimised for speed the
; way the per-frame routines are.   CORRUPTS: A,BC,DE,HL
DRAW_BG_STRIPES:
    LD   A,HUD_H
    LD   (DBGS_Y),A
    XOR  A
    LD   (DBGS_BANDROW),A
    LD   A,2
    LD   (DBGS_IDX),A
DBGS_ROWLOOP:
    ; fill byte = index in both nibbles (index * 17, since 16+1=17)
    LD   A,(DBGS_IDX)
    LD   D,A
    ADD  A,A
    ADD  A,A
    ADD  A,A
    ADD  A,A
    ADD  A,D
    LD   (DBGS_FILL),A
    ; row start address = Y*128 (same shift sequence as SCR_ADDR)
    LD   A,(DBGS_Y)
    LD   H,0
    LD   L,A
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    ADD  HL,HL
    LD   A,(DBGS_FILL)
    LD   (HL),A
    LD   D,H
    LD   E,L
    INC  DE
    LD   BC,SCR_BYTES_W-1
    LDIR
    ; advance band-row counter; roll to the next colour index every
    ; BAND_HEIGHT rows, wrapping 2->3->4->5->2...
    LD   A,(DBGS_BANDROW)
    INC  A
    CP   BAND_HEIGHT
    JR   C,DBGS_NOWRAP
    XOR  A
    LD   (DBGS_BANDROW),A
    LD   A,(DBGS_IDX)
    INC  A
    CP   6
    JR   C,DBGS_IDXOK
    LD   A,2
DBGS_IDXOK:
    LD   (DBGS_IDX),A
    JR   DBGS_ROWDONE
DBGS_NOWRAP:
    LD   (DBGS_BANDROW),A
DBGS_ROWDONE:
    LD   A,(DBGS_Y)
    INC  A
    LD   (DBGS_Y),A
    CP   SCR_H_PX
    JR   NZ,DBGS_ROWLOOP
    RET
DBGS_Y:       DEFB 0
DBGS_BANDROW: DEFB 0
DBGS_IDX:     DEFB 0
DBGS_FILL:    DEFB 0

; UPDATE_BG_CYCLE — every BGCYCLE_INTERVAL frames, rotates BGCYCLE_VALS
; and re-sends the 4 palette writes. No video memory is touched.
;
; Rotation direction, worked through explicitly rather than picked by
; trial and error: band n's on-screen colour is BGCYCLE_VALS[n mod 4]
; (band 0 = topmost band of the play area, increasing n = further down
; the screen). Shifting the array RIGHT (new[k] = old[(k-1) mod 4], i.e.
; every slot takes its upstairs-neighbour's old value, slot 0 takes what
; slot 3 had) means band n's new colour = old colour of band (n-1) - the
; band just ABOVE it. So content that used to sit higher up now appears
; in a lower band: the pattern reads as moving DOWN the screen, matching
; the starfield's existing downward-appearing motion (see
; starwake_stars.asm) rather than fighting against it. To flip the
; apparent direction (e.g. for a horizontal reskin where "forward" points
; sideways instead - see the vertical-vs-horizontal shmup discussion),
; shift the array the other way instead: new[k] = old[(k+1) mod 4].
; CORRUPTS: A,BC
UPDATE_BG_CYCLE:
    LD   A,(BGCYCLE_TIMER)
    DEC  A
    LD   (BGCYCLE_TIMER),A
    JR   NZ,UBC_DONE
    LD   A,BGCYCLE_INTERVAL
    LD   (BGCYCLE_TIMER),A

    LD   A,(BGCYCLE_VALS+3)
    LD   B,A                      ; B = old slot3 (becomes new slot0)
    LD   A,(BGCYCLE_VALS+2)
    LD   (BGCYCLE_VALS+3),A
    LD   A,(BGCYCLE_VALS+1)
    LD   (BGCYCLE_VALS+2),A
    LD   A,(BGCYCLE_VALS+0)
    LD   (BGCYCLE_VALS+1),A
    LD   A,B
    LD   (BGCYCLE_VALS+0),A

    LD   C,&F8
    LD   B,2
    LD   A,(BGCYCLE_VALS+0)
    OUT  (C),A
    LD   B,3
    LD   A,(BGCYCLE_VALS+1)
    OUT  (C),A
    LD   B,4
    LD   A,(BGCYCLE_VALS+2)
    OUT  (C),A
    LD   B,5
    LD   A,(BGCYCLE_VALS+3)
    OUT  (C),A
UBC_DONE:
    RET

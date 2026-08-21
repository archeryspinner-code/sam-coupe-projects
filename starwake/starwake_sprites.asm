; ==========================================================
; SPRITES — System B (demasked). Each sprite is 256 bytes: 128 bytes
; pixel data followed immediately by 128 bytes AND mask, so per-PIXEL
; transparency works correctly (System A's plain byte-skip only checks
; transparency at 2-pixel granularity - any diagonal/curved edge has
; bytes with one transparent + one opaque pixel packed together, which
; System A draws as a solid block instead of honouring the transparent
; half. Confirmed on real hardware: a diamond-shaped enemy sprite was
; blanking out the player sprite as a solid square wherever it overlapped.
; ==========================================================

SPR_TABLE:
    DEFW SPD_PLAYER, SPD_PBULLET, SPD_ENEMY, SPD_EBULLET
SPR_COUNT EQU 4

SPD_PLAYER:
    ; pixel data
    DEFB &00,&00,&00,&1E,&E1,&00,&00,&00
    DEFB &00,&00,&00,&1E,&E1,&00,&00,&00
    DEFB &00,&00,&01,&EE,&EE,&10,&00,&00
    DEFB &00,&00,&01,&EE,&EE,&10,&00,&00
    DEFB &00,&00,&1E,&CE,&EC,&10,&00,&00
    DEFB &00,&00,&1E,&CE,&EC,&10,&00,&00
    DEFB &00,&01,&EC,&CE,&EC,&C1,&00,&00
    DEFB &00,&01,&EC,&CE,&EC,&C1,&00,&00
    DEFB &00,&1E,&CC,&CE,&EC,&CC,&10,&00
    DEFB &00,&1E,&CC,&CE,&EC,&CC,&10,&00
    DEFB &01,&EC,&CC,&C1,&1C,&CC,&C1,&00
    DEFB &01,&EC,&CC,&11,&EE,&1C,&CC,&10
    DEFB &1E,&CC,&11,&0E,&E0,&01,&1C,&C1
    DEFB &1E,&C1,&0E,&E0,&00,&0E,&E0,&1C
    DEFB &01,&10,&E0,&00,&00,&00,&0E,&01
    DEFB &00,&00,&00,&00,&00,&00,&00,&00
    ; AND mask (immediately after pixel data, per DRAW_SPR_MASKED convention)
    DEFB &FF,&FF,&FF,&00,&00,&FF,&FF,&FF
    DEFB &FF,&FF,&FF,&00,&00,&FF,&FF,&FF
    DEFB &FF,&FF,&F0,&00,&00,&0F,&FF,&FF
    DEFB &FF,&FF,&F0,&00,&00,&0F,&FF,&FF
    DEFB &FF,&FF,&00,&00,&00,&0F,&FF,&FF
    DEFB &FF,&FF,&00,&00,&00,&0F,&FF,&FF
    DEFB &FF,&F0,&00,&00,&00,&00,&FF,&FF
    DEFB &FF,&F0,&00,&00,&00,&00,&FF,&FF
    DEFB &FF,&00,&00,&00,&00,&00,&0F,&FF
    DEFB &FF,&00,&00,&00,&00,&00,&0F,&FF
    DEFB &F0,&00,&00,&00,&00,&00,&00,&FF
    DEFB &F0,&00,&00,&00,&00,&00,&00,&0F
    DEFB &00,&00,&00,&F0,&0F,&F0,&00,&00
    DEFB &00,&00,&F0,&0F,&FF,&F0,&0F,&00
    DEFB &F0,&0F,&0F,&FF,&FF,&FF,&F0,&F0
    DEFB &FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF

; SPD_PBULLET — small dedicated box (BUL_SPR_W x BUL_SPR_H = 1x4, 2x4px),
; NOT the shared 16x16 SPR_W/SPR_H box - see DRAW_BULLET_SPR/ERASE_BULLET_SPR
; below, which are the only routines that read this sprite's mask. Its
; visible shape is a tapered dot (wide middle, single-pixel top/bottom
; corners), so it still needs a per-pixel mask even at this size - a
; plain rectangle wouldn't need one, but this shape's corners do.
SPD_PBULLET:
    ; pixel data (1 byte/row x 4 rows)
    DEFB &0D
    DEFB &DD
    DEFB &DD
    DEFB &D0
    ; AND mask (immediately after pixel data, BUL_SPR_W*BUL_SPR_H bytes in)
    DEFB &F0
    DEFB &00
    DEFB &00
    DEFB &0F

SPD_ENEMY:
    ; pixel data
    DEFB &00,&00,&00,&00,&00,&00,&00,&00
    DEFB &00,&00,&00,&09,&90,&00,&00,&00
    DEFB &00,&00,&00,&99,&99,&00,&00,&00
    DEFB &00,&00,&09,&99,&99,&90,&00,&00
    DEFB &00,&00,&99,&99,&99,&99,&00,&00
    DEFB &00,&09,&99,&96,&69,&99,&90,&00
    DEFB &00,&99,&99,&66,&66,&99,&99,&00
    DEFB &09,&99,&96,&66,&66,&69,&99,&90
    DEFB &09,&99,&96,&66,&66,&69,&99,&90
    DEFB &00,&99,&99,&66,&66,&99,&99,&00
    DEFB &00,&09,&99,&96,&69,&99,&90,&00
    DEFB &00,&00,&99,&99,&99,&99,&00,&00
    DEFB &00,&00,&09,&99,&99,&90,&00,&00
    DEFB &00,&00,&00,&99,&99,&00,&00,&00
    DEFB &00,&00,&00,&09,&90,&00,&00,&00
    DEFB &00,&00,&00,&00,&00,&00,&00,&00
    ; AND mask (immediately after pixel data, per DRAW_SPR_MASKED convention)
    DEFB &FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF
    DEFB &FF,&FF,&FF,&F0,&0F,&FF,&FF,&FF
    DEFB &FF,&FF,&FF,&00,&00,&FF,&FF,&FF
    DEFB &FF,&FF,&F0,&00,&00,&0F,&FF,&FF
    DEFB &FF,&FF,&00,&00,&00,&00,&FF,&FF
    DEFB &FF,&F0,&00,&00,&00,&00,&0F,&FF
    DEFB &FF,&00,&00,&00,&00,&00,&00,&FF
    DEFB &F0,&00,&00,&00,&00,&00,&00,&0F
    DEFB &F0,&00,&00,&00,&00,&00,&00,&0F
    DEFB &FF,&00,&00,&00,&00,&00,&00,&FF
    DEFB &FF,&F0,&00,&00,&00,&00,&0F,&FF
    DEFB &FF,&FF,&00,&00,&00,&00,&FF,&FF
    DEFB &FF,&FF,&F0,&00,&00,&0F,&FF,&FF
    DEFB &FF,&FF,&FF,&00,&00,&FF,&FF,&FF
    DEFB &FF,&FF,&FF,&F0,&0F,&FF,&FF,&FF
    DEFB &FF,&FF,&FF,&FF,&FF,&FF,&FF,&FF

; SPD_EBULLET — same tapered-dot shape and small box as SPD_PBULLET, but
; red (colour 9) instead of yellow, so the two remain visually distinct
; at a glance even at this size.
SPD_EBULLET:
    ; pixel data (1 byte/row x 4 rows)
    DEFB &09
    DEFB &99
    DEFB &99
    DEFB &90
    ; AND mask
    DEFB &F0
    DEFB &00
    DEFB &00
    DEFB &0F

; GET_SPR_PTR — INPUT: A=index  OUTPUT: HL=data ptr  CORRUPTS: DE  PRESERVES: BC
GET_SPR_PTR:
    CP   SPR_COUNT
    JR   C,GSP_OK
    XOR  A
GSP_OK:
    LD   H,0
    LD   L,A
    ADD  HL,HL
    LD   DE,SPR_TABLE
    ADD  HL,DE
    LD   E,(HL)
    INC  HL
    LD   D,(HL)
    EX   DE,HL
    RET

; DRAW_SPR_MASKED — INPUT: B=X(px) C=Y(px) HL=sprite data ptr (pixel data;
; mask is the 128 bytes immediately after). AND-clears target pixels via
; the mask, then OR-stamps the sprite pixels - correct per-pixel
; transparency, unlike the plain byte-skip system.
; Draws into whatever page is currently in the LMPR window.
; CORRUPTS: A,BC,DE,HL,IX
; NOTE: uses IX as scratch internally. Any caller that walks an entity
; pool with IX as the record pointer (see entities.md's pool-iteration
; pattern) MUST wrap this call in PUSH IX / POP IX - see the callers in
; starwake_player.asm/starwake_enemies.asm for the existing wraps.
;
; PERFORMANCE: the inner AND/OR passes are unrolled (SPR_W=8, a compile-
; time constant, so this is safe to hardcode) rather than looping with
; DJNZ. The destination (screen memory, read+written every byte) is
; addressed via IX+0..IX+7 with NO increment between bytes at all, since
; the row is now straight-line code and every offset is known up front -
; that's where the real saving is, not just removing DJNZ's 13T/iteration.
; The mask/pixel SOURCE pointer stays in HL, incremented per byte as
; before: (IX+d) costs 19T per access regardless of whether IX itself
; gets incremented, so putting the source there too and dropping HL
; entirely would have made things worse, not better - HL's plain (HL)
; addressing is 7T, cheapest available, and is exactly the operand that
; still needs a genuine per-byte advance (each row uses a different mask/
; pixel byte), so it's the right one to keep as an increment-based
; pointer. Confirmed against skill's optimisation.md instruction-cost
; table: LD/AND/LD via (IX+d) is 19T vs 7T via (HL) - eliminating 8 INC
; IX instructions (10T each) per phase while keeping HL's cheap 7T access
; is worth substantially more than trying to remove HL's increments too.
DRAW_SPR_MASKED:
    LD   A,C
    CP   HUD_H
    JR   NC,DSM_OK
    LD   C,HUD_H
DSM_OK:
    PUSH HL
    LD   DE,128
    ADD  HL,DE
    LD   (DSM_MPTR),HL
    POP  HL
    LD   (DSM_PPTR),HL
    CALL SCR_ADDR
    LD   (DSM_SPTR),HL
    LD   B,SPR_H
DSM_ROW:
    PUSH BC
    LD   IX,(DSM_SPTR)
    LD   HL,(DSM_MPTR)
    LD   A,(IX+0)
    AND  (HL)
    LD   (IX+0),A
    INC  HL
    LD   A,(IX+1)
    AND  (HL)
    LD   (IX+1),A
    INC  HL
    LD   A,(IX+2)
    AND  (HL)
    LD   (IX+2),A
    INC  HL
    LD   A,(IX+3)
    AND  (HL)
    LD   (IX+3),A
    INC  HL
    LD   A,(IX+4)
    AND  (HL)
    LD   (IX+4),A
    INC  HL
    LD   A,(IX+5)
    AND  (HL)
    LD   (IX+5),A
    INC  HL
    LD   A,(IX+6)
    AND  (HL)
    LD   (IX+6),A
    INC  HL
    LD   A,(IX+7)
    AND  (HL)
    LD   (IX+7),A
    INC  HL
    LD   (DSM_MPTR),HL
    LD   IX,(DSM_SPTR)
    LD   HL,(DSM_PPTR)
    LD   A,(IX+0)
    OR   (HL)
    LD   (IX+0),A
    INC  HL
    LD   A,(IX+1)
    OR   (HL)
    LD   (IX+1),A
    INC  HL
    LD   A,(IX+2)
    OR   (HL)
    LD   (IX+2),A
    INC  HL
    LD   A,(IX+3)
    OR   (HL)
    LD   (IX+3),A
    INC  HL
    LD   A,(IX+4)
    OR   (HL)
    LD   (IX+4),A
    INC  HL
    LD   A,(IX+5)
    OR   (HL)
    LD   (IX+5),A
    INC  HL
    LD   A,(IX+6)
    OR   (HL)
    LD   (IX+6),A
    INC  HL
    LD   A,(IX+7)
    OR   (HL)
    LD   (IX+7),A
    INC  HL
    LD   (DSM_PPTR),HL
    LD   HL,(DSM_SPTR)
    LD   BC,SCR_BYTES_W
    ADD  HL,BC
    LD   (DSM_SPTR),HL
    POP  BC
    DEC  B                 ; DJNZ's range (±127) no longer reaches DSM_ROW
    JP   NZ,DSM_ROW        ; now that the row body is fully unrolled - JP
                            ; is a plain absolute jump, same effect either way
    RET
DSM_PPTR: DEFW 0
DSM_MPTR: DEFW 0
DSM_SPTR: DEFW 0

; DRAW_BULLET_SPR — identical algorithm to DRAW_SPR_MASKED, sized for the
; small BUL_SPR_W x BUL_SPR_H bullet box instead of the ship/enemy box.
; Kept as a separate routine rather than parameterising DRAW_SPR_MASKED
; because that routine's mask offset (128) is hardcoded to the shared
; SPR_W*SPR_H box size - the bullet's mask sits only BUL_SPR_W*BUL_SPR_H
; (4) bytes after its pixel data, not 128, so it needs its own offset.
; INPUT: B=X(px) C=Y(px) HL=bullet sprite data ptr (pixel data; its mask
; is the 4 bytes immediately after).   CORRUPTS: A,BC,DE,HL,IX
DRAW_BULLET_SPR:
    LD   A,C
    CP   HUD_H
    JR   NC,DBS_OK
    LD   C,HUD_H
DBS_OK:
    PUSH HL
    LD   DE,BUL_SPR_W*BUL_SPR_H
    ADD  HL,DE
    LD   (DBS_MPTR),HL
    POP  HL
    LD   (DBS_PPTR),HL
    CALL SCR_ADDR
    LD   (DBS_SPTR),HL
    LD   B,BUL_SPR_H
DBS_ROW:
    PUSH BC
    LD   IX,(DBS_SPTR)
    LD   HL,(DBS_MPTR)
    LD   B,BUL_SPR_W
DBS_AND:
    LD   A,(IX+0)
    AND  (HL)
    LD   (IX+0),A
    INC  IX
    INC  HL
    DJNZ DBS_AND
    LD   (DBS_MPTR),HL
    LD   IX,(DBS_SPTR)
    LD   HL,(DBS_PPTR)
    LD   B,BUL_SPR_W
DBS_OR:
    LD   A,(IX+0)
    OR   (HL)
    LD   (IX+0),A
    INC  IX
    INC  HL
    DJNZ DBS_OR
    LD   (DBS_PPTR),HL
    LD   HL,(DBS_SPTR)
    LD   BC,SCR_BYTES_W
    ADD  HL,BC
    LD   (DBS_SPTR),HL
    POP  BC
    DJNZ DBS_ROW
    RET
DBS_PPTR: DEFW 0
DBS_MPTR: DEFW 0
DBS_SPTR: DEFW 0

; ERASE_SPR — INPUT: B=X(px) C=Y(px). Restores background from PG_BG into
; whatever page BACK_PG currently names. Reads all SPR_H rows into a
; full-sprite scratch buffer with a SINGLE MAP_BG, then writes them all
; back with a SINGLE MAP_BACK - previously this switched pages every row
; (2 * SPR_H = 32 OUT instructions per erased sprite), which becomes
; real, measurable overhead once several entities are alive at once.
; CORRUPTS: A,BC,DE,HL
ERASE_SPR:
    LD   A,C
    CP   HUD_H
    JR   NC,ES_YOK
    LD   C,HUD_H
ES_YOK:
    CALL SCR_ADDR
    LD   (ES_ADDR),HL

    CALL MAP_BG
    LD   HL,(ES_ADDR)
    LD   (ES_ROWPTR),HL
    LD   HL,EBUF
    LD   (ES_EBUFPTR),HL
    LD   B,SPR_H
ES_READ:
    PUSH BC
    LD   HL,(ES_ROWPTR)
    LD   DE,(ES_EBUFPTR)
    LD   BC,SPR_W
    LDIR
    LD   (ES_EBUFPTR),DE
    LD   HL,(ES_ROWPTR)
    LD   BC,SCR_BYTES_W
    ADD  HL,BC
    LD   (ES_ROWPTR),HL
    POP  BC
    DJNZ ES_READ

    CALL MAP_BACK
    LD   HL,(ES_ADDR)
    LD   (ES_ROWPTR),HL
    LD   HL,EBUF
    LD   (ES_EBUFPTR),HL
    LD   B,SPR_H
ES_WRITE:
    PUSH BC
    LD   HL,(ES_EBUFPTR)
    LD   DE,(ES_ROWPTR)
    LD   BC,SPR_W
    LDIR
    LD   (ES_EBUFPTR),HL
    LD   HL,(ES_ROWPTR)
    LD   BC,SCR_BYTES_W
    ADD  HL,BC
    LD   (ES_ROWPTR),HL
    POP  BC
    DJNZ ES_WRITE
    RET
ES_ADDR:    DEFW 0
ES_ROWPTR:  DEFW 0
ES_EBUFPTR: DEFW 0
EBUF: DEFS SPR_W*SPR_H

; ERASE_BULLET_SPR — identical algorithm to ERASE_SPR, sized for the small
; BUL_SPR_W x BUL_SPR_H bullet box. Separate scratch buffer/pointers from
; ERASE_SPR's so the two sizes never share state.   INPUT: B=X(px) C=Y(px)
; CORRUPTS: A,BC,DE,HL
ERASE_BULLET_SPR:
    LD   A,C
    CP   HUD_H
    JR   NC,EBS_YOK
    LD   C,HUD_H
EBS_YOK:
    CALL SCR_ADDR
    LD   (EBS_ADDR),HL

    CALL MAP_BG
    LD   HL,(EBS_ADDR)
    LD   (EBS_ROWPTR),HL
    LD   HL,EBUF_BUL
    LD   (EBS_EBUFPTR),HL
    LD   B,BUL_SPR_H
EBS_READ:
    PUSH BC
    LD   HL,(EBS_ROWPTR)
    LD   DE,(EBS_EBUFPTR)
    LD   BC,BUL_SPR_W
    LDIR
    LD   (EBS_EBUFPTR),DE
    LD   HL,(EBS_ROWPTR)
    LD   BC,SCR_BYTES_W
    ADD  HL,BC
    LD   (EBS_ROWPTR),HL
    POP  BC
    DJNZ EBS_READ

    CALL MAP_BACK
    LD   HL,(EBS_ADDR)
    LD   (EBS_ROWPTR),HL
    LD   HL,EBUF_BUL
    LD   (EBS_EBUFPTR),HL
    LD   B,BUL_SPR_H
EBS_WRITE:
    PUSH BC
    LD   HL,(EBS_EBUFPTR)
    LD   DE,(EBS_ROWPTR)
    LD   BC,BUL_SPR_W
    LDIR
    LD   (EBS_EBUFPTR),HL
    LD   HL,(EBS_ROWPTR)
    LD   BC,SCR_BYTES_W
    ADD  HL,BC
    LD   (EBS_ROWPTR),HL
    POP  BC
    DJNZ EBS_WRITE
    RET
EBS_ADDR:    DEFW 0
EBS_ROWPTR:  DEFW 0
EBS_EBUFPTR: DEFW 0
EBUF_BUL: DEFS BUL_SPR_W*BUL_SPR_H

# SAM Coupe Projects

Two games built for the SAM Coupe (Z80, Mode 4) with heavy use of the
[sam-coupe-game-creator-skill](https://github.com/archeryspinner-code/sam-coupe-game-creator-skill),
and a lot of real bugs found and fixed along the way via actual emulator
testing rather than eyeballing assembly.

## Projects

- **`starwake/`** — vertical shmup. Free-moving ship, player + enemy
  bullets (tiny dedicated 2x4px hit box, not the full sprite box - see
  bug #12), one enemy type, parallax starfield, 3 lives with respawn and
  invulnerability, score. Double-buffered, masked sprites, real-time
  50Hz loop. Source + `run_tests.py` (35 checks) are checked in.
- **`dungeon/`** — Pixel Dungeon-style top-down roguelike. Procedural
  rooms-and-corridors dungeon, fog of war, turn-based movement with
  smooth pixel-slide animation, camera dead-zone scrolling. **Parked** -
  too slow, deprioritised in favour of STARWAKE. Source not yet checked
  into this repo.

Both build with `pasmo <name>.asm <name>.bin <name>.lst` and load via
`LOAD "<name>" CODE 32768 : RANDOMIZE USR 32768` (see each project's
`loader.bas`). `.bin` files aren't checked in (binary, trivially
regenerable) - build them yourself with pasmo.

## Testing methodology

Every routine in both projects was verified by actually executing it in
the `z80` Python package against the assembled binary - not just by
reading the assembly. `run_tests.py` in each project directory (STARWAKE:
`pip install z80 --break-system-packages`, `pasmo starwake.asm
starwake.bin starwake.lst`, then `python3 run_tests.py` from the same
directory - `z80test.py`'s `load_symbols`/`load_binary` expect
`starwake.lst`/`starwake.bin` alongside it). This caught real bugs that
looked correct on paper.

Known limitation, worth remembering if extending either project: the
`z80` package is flat-memory with no MMU/paging simulation, so it can't
verify SAM-specific paging behaviour (which page is really mapped where).
Real hardware/SimCoupe testing is still the final check for anything
involving `LMPR`/`VMPR`/page switching - see the bug list below for two
real cases this limitation let through.

Also worth remembering when *writing* new tests: a routine's `CORRUPTS`
list applies just as much between two `call()`s in the same test as it
does inside the actual game loop. Calling routine A, then routine B with
register inputs that were only valid *before* A ran (and A's `CORRUPTS`
list includes them) silently exercises B with garbage inputs instead of
what the test intended - the test can still "pass" or "fail" for the
wrong reason. Reload every register B needs, immediately before calling
B, every time - don't assume a register survives a call just because it
did in the routine's own body.

## Real bugs found this way (most are also fixed upstream in the skill repo)

1. **LFSR RNG self-stabilised to a fixed value** after one call - every
   "random" draw came back identical. Found by running it repeatedly in
   the emulator, not by reading the code. Replaced with a Galois LFSR.
2. **Colon-separated statements don't assemble in pasmo**, despite being
   used throughout the skill's own documentation. Confirmed empirically,
   fixed in every skill reference file.
3. **`DRAW_SPR` clobbered its own sprite-data pointer** - it called
   `SCR_ADDR` (which also returns its result in `HL`) without saving the
   incoming pointer first.
4. **`ERASE_SPR`'s write-back `LDIR` targeted a stale address** left over
   from the read `LDIR` just before it, instead of the real screen
   address - sprites drew fine but erase silently did nothing. This is
   the flat-memory-emulator-blind-spot case: only found via real hardware
   testing, where "sprites drew but never erased" was the reported
   symptom.
5. **`PG_BG`/`PG_BUF_A`/`PG_BUF_B` treated as compile-time constants** in
   three separate places (including the skill's own master project
   template), when they must be runtime-derived from `IN A,(&FC)` (the
   physical page depends on how much RAM is fitted).
6. **System A (byte-transparency) sprites can't handle diagonal/curved
   edges** - a byte with one transparent and one opaque pixel packed
   together still draws as fully opaque. A diamond enemy sprite was
   blanking the player out as a solid square wherever it overlapped.
   Switched to System B (per-pixel masked sprites).
7. **Render-order bug, not a masking bug**: erasing entities interleaved
   with drawing them (erase-then-draw per entity, in sequence) let a
   later entity's erase blank out an earlier entity's freshly-drawn
   pixels wherever their positions overlapped. Looked exactly like a
   transparency bug. Fixed by erasing every entity first, then drawing
   every entity.
8. **`ERASE_SPR` switched pages every row** (32 `OUT`s per erased sprite)
   instead of once per direction - real, measurable frame-rate cost once
   several entities were alive at once. Restructured to batch all rows
   through one `MAP_BG`/`MAP_BACK` pair each (2 total).
9. **Collision thresholds sized to the padded sprite box, not the actual
   visible pixel extent** - hits registered well before the shapes on
   screen looked close to touching. Fixed by measuring real sprite art
   and sizing thresholds to the sum of actual visible half-extents.
10. **8-bit-immediate overflow**: `SCR_W_PX` (256) loaded into an 8-bit
    register for a `RND_RANGE` call silently truncates to 0 - no crash,
    no warning, every "random" star landed at X=0. A bounds check alone
    doesn't catch this (0 is a valid value); checking that repeated draws
    are actually *distinct* does.
11. **Bullets used the full 16x16 sprite box** for a visual dot only a
    few pixels across - erase/draw cost scales with box area, and
    bullets are the most numerous entity on screen, so this dominated
    frame time. First pass: shrunk to 8x8, cutting worst-case frame cost
    from ~204,000 T-states (over double the ~100,000/frame budget -
    matching a reported slowdown) to ~97,600. Superseded by #12 below,
    which went smaller still once the box was measured against STARWAKE's
    actual bullet art rather than a generic default.
12. **8x8 was still bigger than the bullet actually needed** - STARWAKE's
    dot only ever occupies ~2x4px within that box. Added dedicated
    `DRAW_BULLET_SPR`/`ERASE_BULLET_SPR` routines sized to the real
    content (`BUL_SPR_W`/`BUL_SPR_H`, separate from the ship/enemy
    `SPR_W`/`SPR_H`) instead of reusing the general-purpose ones -
    per-bullet erase+draw cost dropped from ~26,000 T-states (16x16) to
    ~1,300 (~20x), which matters a lot with up to 16 bullets alive at
    once. General lesson: "shrink to 8x8" (#11) is a reasonable *default*
    when you haven't measured, but the right box size is whatever the
    sprite's own art actually needs - measure it per-sprite rather than
    stopping at the first size that's smaller than before.
13. **Different-sized sprite boxes break the "top-left corner ≈ centre"
    collision shortcut** (see #9) the moment they're actually applied -
    #9 documented the theory; this is the concrete case that hit it.
    Once the bullet's box (#12) became a different size from the
    enemy/player's box, comparing raw top-left X/Y stopped being
    equivalent to comparing true centres, because the two sprites' centre
    offsets (`box_width/2`) no longer match and stop cancelling out in
    the subtraction. Fixed by adding each pair's specific offset
    (`CPE_XOFF`/`CPE_YOFF`, `CEP_XOFF`/`CEP_YOFF`) explicitly before the
    distance check, rather than relying on same-size-box coincidence.
    Also had a second-order effect: bullet spawn code that positioned a
    new bullet by directly copying the shooter's X (correct only because
    the old bullet shared the shooter's box) needed the same explicit
    centring offset (`BUL_XOFF`) once the boxes diverged.

Full narrative/reasoning for each of these lives in the git history of
[`archeryspinner-code/sam-coupe-game-creator-skill`](https://github.com/archeryspinner-code/sam-coupe-game-creator-skill)
(commit messages are deliberately detailed) and in this repo's commit
history for the game-specific fixes.

## Status / where each project left off

**STARWAKE**: playable core loop - move, shoot, enemies spawn and shoot
back, 3 lives, respawn, score, starfield, optimised bullets (see #12).
Collision detection works but is flagged for further improvement (exact
shape/feel still TBD). Not yet built: second enemy behaviour (sine-wave
movement), wave-scripting (currently a flat random spawner - next up),
HUD font for a real score/lives display and game-over screen,
soundtrack/SFX, boss.

**Dungeon crawler**: parked (too slow). Playable core loop existed -
procedural dungeon, fog of war, turn-based movement with smooth slide
animation, camera dead-zone - but isn't checked into this repo. Not yet
built: monsters, combat, items, real HUD.

## Design notes worth keeping

- Turn-based games on this hardware can get away with much lazier
  rendering (full-viewport redraws, no need for careful frame-budget
  accounting) than real-time ones - the dungeon crawler and STARWAKE take
  deliberately different engine approaches for this reason.
- No hardware scroll register on SAM Coupe. STARWAKE sidesteps this with
  a parallax starfield (decorative, not collidable) rather than true
  scrolling terrain; the dungeon crawler uses a camera dead-zone
  (recentres only near viewport edges) rather than continuous smooth
  scroll.
- Sprite hit-boxes should be sized to actual visible content, not the
  padded sprite box - see bug #9 above.
- When different entity types end up with different-sized hit boxes
  (e.g. a shrunk bullet vs. a full-size ship), that size difference has
  to be accounted for explicitly wherever positions are compared or
  derived from each other - collision checks (#13) and spawn positioning
  both broke the same way for the same underlying reason.

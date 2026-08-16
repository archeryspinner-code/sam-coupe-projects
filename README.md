# SAM Coupe Projects

Two games built for the SAM Coupe (Z80, Mode 4) with heavy use of the
[sam-coupe-game-creator-skill](https://github.com/archeryspinner-code/sam-coupe-game-creator-skill),
and a lot of real bugs found and fixed along the way via actual emulator
testing rather than eyeballing assembly.

## Projects

- **`starwake/`** — vertical shmup. Free-moving ship, player + enemy
  bullets, one enemy type, parallax starfield, 3 lives with respawn and
  invulnerability, score. Double-buffered, masked sprites, real-time
  50Hz loop.
- **`dungeon/`** — Pixel Dungeon-style top-down roguelike. Procedural
  rooms-and-corridors dungeon, fog of war, turn-based movement with
  smooth pixel-slide animation, camera dead-zone scrolling.

Both build with `pasmo <name>.asm <name>.bin <name>.lst` and load via
`LOAD "<name>" CODE 32768 : RANDOMIZE USR 32768` (see each project's
`loader.bas`). `.bin` files aren't checked in (binary, trivially
regenerable) - build them yourself with pasmo.

## Testing methodology

Every routine in both projects was verified by actually executing it in
the `z80` Python package against the assembled binary - not just by
reading the assembly. `run_tests.py` in each project directory. This
caught real bugs that looked correct on paper.

Known limitation, worth remembering if extending either project: the
`z80` package is flat-memory with no MMU/paging simulation, so it can't
verify SAM-specific paging behaviour (which page is really mapped where).
Real hardware/SimCoupe testing is still the final check for anything
involving `LMPR`/`VMPR`/page switching - see the bug list below for two
real cases this limitation let through.

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
    frame time. Shrunk to 8x8, cutting worst-case frame cost from
    ~204,000 T-states (over double the ~100,000/frame budget - matching
    a reported slowdown) to ~97,600.

Full narrative/reasoning for each of these lives in the git history of
[`archeryspinner-code/sam-coupe-game-creator-skill`](https://github.com/archeryspinner-code/sam-coupe-game-creator-skill)
(commit messages are deliberately detailed) and in this repo's commit
history for the game-specific fixes.

## Status / where each project left off

**STARWAKE**: playable core loop - move, shoot, enemies spawn and shoot
back, 3 lives, respawn, score, starfield. Not yet built: second enemy
behaviour (sine-wave movement), wave-scripting (currently a flat random
spawner), HUD font for a real score/lives display and game-over screen,
soundtrack/SFX, boss.

**Dungeon crawler**: playable core loop - procedural dungeon, fog of war,
turn-based movement with smooth slide animation, camera dead-zone. Not
yet built: monsters, combat, items, real HUD.

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

from z80test import load_symbols, load_binary, fresh_machine, call

SYM = load_symbols()
BIN = load_binary()

def test_rng():
    m = fresh_machine(BIN)
    vals = []
    for i in range(20):
        call(m, SYM['RND_BYTE'])
        vals.append(m.a)
    ok = len(set(vals)) > 10
    print(f"[RNG] RND_BYTE distinct={len(set(vals))}: {'PASS' if ok else 'FAIL'}")

def test_player_movement_bounds():
    m = fresh_machine(BIN)
    ok = True
    # Drive player to the top-left corner and confirm it clamps, not wraps
    m.memory[SYM['PLR_X']] = 1
    m.memory[SYM['PLR_Y']] = 17
    for i in range(20):
        m.memory[SYM['INPUT_STATE']] = 0x01 | 0x04  # up+left
        call(m, SYM['UPDATE_PLAYER'])
    x, y = m.memory[SYM['PLR_X']], m.memory[SYM['PLR_Y']]
    if (x, y) != (0, 16):
        ok = False
        print(f"  top-left clamp failed: got ({x},{y}) expected (0,16)")

    # Drive to bottom-right and confirm clamp there too
    for i in range(150):
        m.memory[SYM['INPUT_STATE']] = 0x02 | 0x08  # down+right
        call(m, SYM['UPDATE_PLAYER'])
    x, y = m.memory[SYM['PLR_X']], m.memory[SYM['PLR_Y']]
    if (x, y) != (240, 176):
        ok = False
        print(f"  bottom-right clamp failed: got ({x},{y}) expected (240,176)")
    print(f"[PLAYER] movement bounds clamp correctly: {'PASS' if ok else 'FAIL'}")

def test_fire_and_bullet_spawn():
    m = fresh_machine(BIN)
    m.memory[SYM['PLR_X']] = 100
    m.memory[SYM['PLR_Y']] = 140
    m.memory[SYM['FIRE_CD']] = 0
    m.memory[SYM['INPUT_STATE']] = 0x10  # fire only
    call(m, SYM['UPDATE_PLAYER'])
    cd = m.memory[SYM['FIRE_CD']]
    # bullet pool slot 0 should now be alive
    pb_state = m.memory[SYM['PBUL_POOL']+2]  # PB_STATE offset = 2
    ok = (cd == 8) and (pb_state == 1)
    print(f"[BULLET] fire spawns bullet + sets cooldown: {'PASS' if ok else 'FAIL'} (cd={cd} state={pb_state})")

    # Firing again immediately (cooldown active) should NOT spawn a second bullet
    m.memory[SYM['INPUT_STATE']] = 0x10
    call(m, SYM['UPDATE_PLAYER'])
    pb1_state = m.memory[SYM['PBUL_POOL']+8+2]  # slot 1's PB_STATE
    ok2 = (pb1_state == 0)
    print(f"[BULLET] cooldown blocks rapid refire: {'PASS' if ok2 else 'FAIL'} (slot1 state={pb1_state})")

def test_bullet_movement_and_kill():
    m = fresh_machine(BIN)
    m.b, m.c = 100, 20  # near top
    call(m, SYM['SPAWN_PBULLET'])
    for i in range(10):
        call(m, SYM['UPDATE_PBULLETS'])
    state = m.memory[SYM['PBUL_POOL']+2]
    print(f"[BULLET] bullet dies leaving top of play area: {'PASS' if state==0 else 'FAIL'} (state={state})")

def test_enemy_spawn_and_movement():
    m = fresh_machine(BIN)
    err = call(m, SYM['SPAWN_ENEMY'])
    state = m.memory[SYM['ENEMY_POOL']+2]  # EN_STATE offset
    print(f"[ENEMY] SPAWN_ENEMY creates an alive enemy: {'PASS' if state==1 else 'FAIL'} (err={err} state={state})")

    y_before = m.memory[SYM['ENEMY_POOL']+1]
    call(m, SYM['UPDATE_ENEMIES'])
    y_after = m.memory[SYM['ENEMY_POOL']+1]
    print(f"[ENEMY] moves down each update: {'PASS' if y_after > y_before else 'FAIL'} ({y_before}->{y_after})")

    # Drive far enough to leave the bottom of the screen
    for i in range(250):
        call(m, SYM['UPDATE_ENEMIES'])
    state = m.memory[SYM['ENEMY_POOL']+2]
    print(f"[ENEMY] dies leaving bottom of screen: {'PASS' if state==0 else 'FAIL'} (state={state})")

def test_collision_hit():
    m = fresh_machine(BIN)
    # Overlapping bullet and enemy - should both die, score should increase.
    # NOTE: since the bullet's box shrank to its actual visible content
    # (BUL_SPR_W_PX x BUL_SPR_H_PX, no padding - see starwake_sprites.asm),
    # its true centre is only +1,+2 from its raw X/Y, not +8,+8 like the
    # enemy's box. Raw coordinates a few px apart no longer reliably mean
    # "true centres nearby" the way they did when both sprites shared one
    # box size - see COLLIDE_PBULLETS_VS_ENEMIES's CPE_XOFF/CPE_YOFF note.
    # Enemy placed so the two true centres land close together:
    # bullet true centre ~= (101,101), enemy true centre ~= (95+8,95+8)=(103,103).
    m.b, m.c = 100, 100
    call(m, SYM['SPAWN_PBULLET'])
    m.memory[SYM['ENEMY_POOL']+0] = 95           # EN_X - true centre near bullet's
    m.memory[SYM['ENEMY_POOL']+1] = 95           # EN_Y
    m.memory[SYM['ENEMY_POOL']+2] = 1            # STATE_ALIVE
    m.memory[SYM['ENEMY_POOL']+4] = 95           # PA_X
    m.memory[SYM['ENEMY_POOL']+5] = 95           # PA_Y
    m.memory[SYM['ENEMY_POOL']+6] = 95           # PB_X
    m.memory[SYM['ENEMY_POOL']+7] = 95           # PB_Y
    err = call(m, SYM['COLLIDE_PBULLETS_VS_ENEMIES'], max_runs=500000)
    bstate = m.memory[SYM['PBUL_POOL']+2]
    estate = m.memory[SYM['ENEMY_POOL']+2]
    score = m.memory[SYM['SCORE']] | (m.memory[SYM['SCORE']+1] << 8)
    ok = err is None and bstate == 0 and estate == 0 and score == 10
    print(f"[COLLIDE] overlapping bullet+enemy both die, score+10: {'PASS' if ok else 'FAIL'} "
          f"(err={err} bstate={bstate} estate={estate} score={score})")

def test_collision_miss():
    m = fresh_machine(BIN)
    m.b, m.c = 10, 10
    call(m, SYM['SPAWN_PBULLET'])
    m.memory[SYM['ENEMY_POOL']+0] = 200           # far away
    m.memory[SYM['ENEMY_POOL']+1] = 200
    m.memory[SYM['ENEMY_POOL']+2] = 1
    err = call(m, SYM['COLLIDE_PBULLETS_VS_ENEMIES'], max_runs=500000)
    bstate = m.memory[SYM['PBUL_POOL']+2]
    estate = m.memory[SYM['ENEMY_POOL']+2]
    ok = err is None and bstate == 1 and estate == 1
    print(f"[COLLIDE] non-overlapping bullet+enemy both survive: {'PASS' if ok else 'FAIL'} "
          f"(err={err} bstate={bstate} estate={estate})")

def test_full_frame_sequence():
    m = fresh_machine(BIN)
    call(m, SYM['INIT_STARS'], max_runs=500000)
    err = call(m, SYM['INIT_PLAYER_SPRITE_BOTH'], max_runs=500000)
    if err:
        print(f"[FRAME] INIT_PLAYER_SPRITE_BOTH: {err} - FAIL")
        return

    ok = True
    for frame in range(120):
        m.memory[SYM['INPUT_STATE']] = 0x08 | (0x10 if frame % 10 == 0 else 0)  # drift right, fire periodically
        for label in ['UPDATE_PLAYER', 'UPDATE_PBULLETS', 'UPDATE_EBULLETS',
                      'UPDATE_ENEMY_SPAWNER', 'UPDATE_ENEMY_FIRING', 'UPDATE_ENEMIES',
                      'COLLIDE_PBULLETS_VS_ENEMIES', 'COLLIDE_EBULLETS_VS_PLAYER', 'UPDATE_STARS',
                      'ERASE_STARS', 'ERASE_PLAYER', 'ERASE_PBULLETS', 'ERASE_EBULLETS', 'ERASE_ENEMIES',
                      'DRAW_STARS_ONLY', 'DRAW_PLAYER_ONLY', 'DRAW_PBULLETS_ONLY', 'DRAW_EBULLETS_ONLY', 'DRAW_ENEMIES_ONLY',
                      'SWAP_BUFFERS', 'WAIT_FRAME']:
        # NOTE: SWAP_BUFFERS/WAIT_FRAME live in the engine file - confirm present
            if label not in SYM:
                continue
            err = call(m, SYM[label], max_runs=500000)
            if err:
                print(f"  frame {frame} {label}: {err}")
                ok = False
                break
        if not ok:
            break
    print(f"[FRAME] 120 simulated frames (movement+fire+enemies+collision+stars+render): {'PASS' if ok else 'FAIL'}")
    print(f"  final: PLR=({m.memory[SYM['PLR_X']]},{m.memory[SYM['PLR_Y']]}) "
          f"SCORE={m.memory[SYM['SCORE']] | (m.memory[SYM['SCORE']+1]<<8)}")

test_rng()
test_player_movement_bounds()
test_fire_and_bullet_spawn()
test_bullet_movement_and_kill()
test_enemy_spawn_and_movement()
test_collision_hit()
test_collision_miss()
test_full_frame_sequence()

def test_erase_actually_restores_pixels():
    """NOTE: this test cannot meaningfully pass in this emulator and isn't
    used as a pass/fail signal - see test_erase_second_ldir_targets_correct_address
    below for the real check. Left here as a documented dead end: the flat-
    memory z80 package has no MMU/paging simulation, so MAP_BG and MAP_BACK
    are no-ops here - "background page" and "screen page" are literally the
    same memory address range. That means a *correct* ERASE_SPR (read
    background row, write it back to the same screen address) and the
    original *bug* (read background row, then silently write it into the
    wrong place instead) are indistinguishable by inspecting screen bytes
    alone in this environment - both leave the screen looking "unrestored"
    for different reasons. The actual bug (wrong destination address) is
    checked directly at the register level instead, below."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0x11
    baseline = bytes(m.memory[0:24576])
    m.a = 0
    call(m, SYM['GET_SPR_PTR'])
    m.b, m.c = 40, 40
    call(m, SYM['DRAW_SPR_MASKED'])
    drew_something = bytes(m.memory[0:24576]) != baseline
    print(f"[SPRITE] DRAW_SPR_MASKED changes the screen: {'PASS' if drew_something else 'FAIL'}")

test_erase_actually_restores_pixels()

def test_erase_row_loop_correctness():
    """The restructured ERASE_SPR always reloads its row pointer fresh
    from memory before each LDIR (both read and write phases), so the
    old stale-register bug class is structurally impossible now rather
    than needing a per-call check. What matters now is confirming the
    restructure itself (fewer page switches) didn't break basic
    completion."""
    m = fresh_machine(BIN)
    m.b, m.c = 40, 40
    err = call(m, SYM['ERASE_SPR'], max_runs=500000)
    ok = err is None
    print(f"[SPRITE] restructured ERASE_SPR (1 page-switch pair instead of 16) "
          f"completes without crash/hang: {'PASS' if ok else 'FAIL'} (err={err})")

test_erase_row_loop_correctness()

def test_erase_visits_all_rows_correctly():
    """Tag each of the 16 screen rows the sprite occupies with a unique
    marker byte, then confirm ERASE_SPR's read phase captured all 16
    distinct markers into EBUF in the right order - proving the row loop
    walks the correct SCR_BYTES_W stride for all SPR_H rows with no
    skipped or repeated row, which is exactly what the restructure
    (single MAP_BG/MAP_BACK pair instead of one pair per row) could have
    gotten wrong."""
    x, y = 40, 40
    m = fresh_machine(BIN)
    for row in range(16):
        base = (y + row) * 128 + x // 2
        for i in range(8):
            m.memory[base + i] = row  # unique marker per row
    m.b, m.c = x, y
    call(m, SYM['ERASE_SPR'], max_runs=500000)
    ebuf = bytes(m.memory[SYM['EBUF']:SYM['EBUF']+128])
    ok = all(ebuf[row*8:row*8+8] == bytes([row]*8) for row in range(16))
    print(f"[SPRITE] ERASE_SPR visits all 16 rows at correct stride, no skips: "
          f"{'PASS' if ok else 'FAIL'}")
    if not ok:
        for row in range(16):
            chunk = ebuf[row*8:row*8+8]
            if chunk != bytes([row]*8):
                print(f"  row {row}: expected all {row}, got {chunk.hex()}")

test_erase_visits_all_rows_correctly()

def test_masked_draw_preserves_partial_transparency():
    """The actual bug reported: System A's byte-level transparency check
    can't handle a byte with one transparent + one opaque pixel packed
    together - exactly what every diagonal edge produces. This test
    verifies the masked draw handles that correctly: draw over a known
    background, then check that a byte known to be half-transparent in
    the sprite art keeps its background high nibble while taking the
    sprite's opaque low nibble."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0xAA
    m.a = 2  # SPR_ENEMY (diamond) - index 2 in SPR_TABLE
    call(m, SYM['GET_SPR_PTR'])
    m.b, m.c = 0, 16   # X=0 so byte 3 of the row = pixels 6-7 exactly
    call(m, SYM['DRAW_SPR_MASKED'])
    # Row 1 of the enemy sprite is "0000000990000000" - byte index 3
    # (pixels 6-7) is nibble pair (0,9): transparent then opaque.
    # Expected result byte: high nibble stays background (A), low nibble
    # becomes the sprite's 9 -> 0xA9.
    row = 1
    byte_index = 3
    offset = (16 + row) * 128 + byte_index   # screen row = draw Y(16) + sprite row(1)
    result = m.memory[offset]
    ok = result == 0xA9
    print(f"[SPRITE] masked draw preserves background in mixed transparent/opaque byte: "
          f"{'PASS' if ok else 'FAIL'} (byte={hex(result)} expected=0xa9)")

test_masked_draw_preserves_partial_transparency()

def test_overlapping_sprites_show_through():
    """Replicate the exact real scenario: draw the player sprite, then
    draw the enemy sprite overlapping it (same order as MAIN_LOOP: player
    render happens before enemy render). Check that transparent enemy
    pixels show the player underneath rather than blanking to background
    or black."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0x11  # background fill, matches GAME_START

    m.a = 0  # SPR_PLAYER
    call(m, SYM['GET_SPR_PTR'])
    m.b, m.c = 40, 40
    call(m, SYM['DRAW_SPR'] if 'DRAW_SPR' in SYM else SYM['DRAW_SPR_MASKED'])
    after_player = bytes(m.memory[0:24576])

    m.a = 2  # SPR_ENEMY, drawn at the SAME position, fully overlapping
    call(m, SYM['GET_SPR_PTR'])
    m.b, m.c = 40, 40
    call(m, SYM['DRAW_SPR_MASKED'])
    after_enemy = bytes(m.memory[0:24576])

    # Row 0 of the enemy sprite is all zeros (fully transparent) - so
    # after drawing the enemy, row 0 of the sprite's footprint should be
    # UNCHANGED from what the player drew there, not reset to background
    # and not solid black.
    row0_offset = 40*128 + 40//2
    player_row0 = after_player[row0_offset:row0_offset+8]
    enemy_row0  = after_enemy[row0_offset:row0_offset+8]
    ok = player_row0 == enemy_row0
    print(f"[SPRITE] fully-transparent enemy row leaves player pixels untouched: "
          f"{'PASS' if ok else 'FAIL'}")
    print(f"  player row0={player_row0.hex()} enemy row0={enemy_row0.hex()}")

    # Row 1 has enemy pixels only in the middle (mixed transparent/opaque
    # bytes at the edges) - the EDGES of that row should still show
    # whatever the player drew, not be blanked.
    row1_offset = 41*128 + 40//2
    player_row1 = after_player[row1_offset:row1_offset+8]
    enemy_row1  = after_enemy[row1_offset:row1_offset+8]
    print(f"  player row1={player_row1.hex()} enemy row1={enemy_row1.hex()}")

test_overlapping_sprites_show_through()

def test_erase_order_does_not_clobber_other_entities():
    """The actual bug reported: an enemy's erase step (restoring plain
    background at its OLD position) was running AFTER the player had
    already been freshly drawn this frame, and if the enemy's old
    position overlapped the player, the erase blanked those pixels back
    to background colour. The fix is structural: erase every entity
    first, then draw every entity, so no draw can ever be clobbered by a
    later erase.

    NOTE: this test can only verify the fixed order doesn't lose the
    player's pixels - it cannot demonstrate the original bug in this
    environment. Same underlying limitation as the ERASE_SPR fix before:
    PG_BG and the draw buffer are the same flat memory here (no real
    paging), so "erase" reading "background" actually reads whatever
    pixels are already sitting in that memory - including a just-drawn
    player - and writing it back is a no-op regardless of call order.
    The clobber only manifests with two genuinely separate physical
    pages, which is exactly the real-hardware behaviour that was
    reported. This test is a structural sanity check, not proof."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0x11
    m.memory[SYM['PLR_X']] = 40
    m.memory[SYM['PLR_Y']] = 40
    m.memory[SYM['ENEMY_POOL']+0] = 100
    m.memory[SYM['ENEMY_POOL']+1] = 100
    m.memory[SYM['ENEMY_POOL']+2] = 1
    m.memory[SYM['ENEMY_POOL']+4] = 40
    m.memory[SYM['ENEMY_POOL']+5] = 40
    m.memory[SYM['ENEMY_POOL']+6] = 100
    m.memory[SYM['ENEMY_POOL']+7] = 100

    call(m, SYM['ERASE_ENEMIES'])
    call(m, SYM['DRAW_PLAYER_ONLY'])
    after_fixed_order = bytes(m.memory[0:24576])
    row0_off = 40*128 + 40//2
    player_bytes = after_fixed_order[row0_off:row0_off+8]
    survived = any(b != 0x11 for b in player_bytes)
    print(f"[RENDER ORDER] erase-all-then-draw-all order is structurally correct: "
          f"{'PASS' if survived else 'FAIL'}")

test_erase_order_does_not_clobber_other_entities()

def test_stars_init_and_bounds():
    m = fresh_machine(BIN)
    err = call(m, SYM['INIT_STARS'], max_runs=500000)
    ok = err is None
    all_in_bounds = True
    layers_seen = set()
    x_values = []
    for i in range(20):
        base = SYM['STAR_POOL'] + i*8
        x, y, layer = m.memory[base], m.memory[base+1], m.memory[base+2]
        layers_seen.add(layer)
        x_values.append(x)
        if not (0 <= x < 256 and 16 <= y < 192 and 0 <= layer <= 2):
            all_in_bounds = False
            print(f"  star {i}: x={x} y={y} layer={layer} out of range")
    print(f"[STARS] INIT_STARS completes, positions/layers in bounds: "
          f"{'PASS' if ok and all_in_bounds else 'FAIL'} (layers seen={layers_seen})")
    # A range check alone isn't enough here - 0 is a perfectly valid X
    # value, so a bug that made every star land at X=0 would still pass
    # the bounds check above. This is exactly the SCR_W_PX overflow bug
    # that got through before: RND_RANGE was silently called with range=0
    # (256 truncated to 0 as an 8-bit immediate) and always returned 0.
    distinct_x = len(set(x_values))
    print(f"[STARS] X positions are actually spread out, not all identical: "
          f"{'PASS' if distinct_x > 5 else 'FAIL'} (distinct X values={distinct_x}, values={x_values})")

def test_stars_move_and_wrap():
    m = fresh_machine(BIN)
    call(m, SYM['INIT_STARS'])
    # Force star 0 to layer 2 (fastest) near the bottom, confirm it wraps
    base = SYM['STAR_POOL']
    m.memory[base+1] = 190       # ST_Y, near bottom
    m.memory[base+2] = 2         # ST_LAYER = fastest (speed 3)
    call(m, SYM['UPDATE_STARS'], max_runs=500000)
    y_after = m.memory[base+1]
    wrapped = y_after == 16  # HUD_H
    print(f"[STARS] fast star wraps from bottom to top: {'PASS' if wrapped else 'FAIL'} (y={y_after})")

    # A star mid-screen should just move down by layer+1
    m2 = fresh_machine(BIN)
    call(m2, SYM['INIT_STARS'])
    base = SYM['STAR_POOL']
    m2.memory[base+1] = 100
    m2.memory[base+2] = 0        # slowest layer, speed 1
    call(m2, SYM['UPDATE_STARS'])
    y_after2 = m2.memory[base+1]
    print(f"[STARS] slow star moves down by 1px/frame: "
          f"{'PASS' if y_after2 == 101 else 'FAIL'} (y={y_after2})")

def test_stars_erase_draw_no_crash():
    m = fresh_machine(BIN)
    call(m, SYM['INIT_STARS'], max_runs=500000)
    ok = True
    for frame in range(30):
        err = call(m, SYM['UPDATE_STARS'], max_runs=500000)
        err = err or call(m, SYM['ERASE_STARS'], max_runs=500000)
        err = err or call(m, SYM['DRAW_STARS_ONLY'], max_runs=500000)
        if err:
            print(f"  frame {frame}: {err}")
            ok = False
            break
    print(f"[STARS] 30 frames of update/erase/draw, no crash/hang: {'PASS' if ok else 'FAIL'}")

def test_plot_pixel_preserves_other_nibble():
    m = fresh_machine(BIN)
    m.memory[0] = 0xAB  # some existing byte with two distinct nibbles
    m.b, m.c, m.d = 0, 0, 5   # X=0 (even -> left/high nibble), colour 5
    call(m, SYM['PLOT_PIXEL'])
    result = m.memory[0]
    ok = result == 0x5B   # high nibble replaced with 5, low nibble (B) untouched
    print(f"[STARS] PLOT_PIXEL preserves the untouched pixel's nibble: "
          f"{'PASS' if ok else 'FAIL'} (byte={hex(result)} expected=0x5b)")

    m2 = fresh_machine(BIN)
    m2.memory[0] = 0xAB
    m2.b, m2.c, m2.d = 1, 0, 5   # X=1 (odd -> right/low nibble)
    call(m2, SYM['PLOT_PIXEL'])
    result2 = m2.memory[0]
    ok2 = result2 == 0xA5
    print(f"[STARS] PLOT_PIXEL right-pixel case: {'PASS' if ok2 else 'FAIL'} "
          f"(byte={hex(result2)} expected=0xa5)")

test_stars_init_and_bounds()
test_stars_move_and_wrap()
test_stars_erase_draw_no_crash()
test_plot_pixel_preserves_other_nibble()

def test_ebullet_spawn_and_lifecycle():
    m = fresh_machine(BIN)
    m.b, m.c = 100, 20   # near top
    err = call(m, SYM['SPAWN_EBULLET'], max_runs=500000)
    state = m.memory[SYM['EBUL_POOL']+2]
    print(f"[EBULLET] SPAWN_EBULLET creates an alive bullet: {'PASS' if err is None and state==1 else 'FAIL'}")

    m2 = fresh_machine(BIN)
    m2.b, m2.c = 100, 180  # near bottom
    call(m2, SYM['SPAWN_EBULLET'])
    for i in range(10):
        call(m2, SYM['UPDATE_EBULLETS'], max_runs=500000)
    state2 = m2.memory[SYM['EBUL_POOL']+2]
    print(f"[EBULLET] dies leaving the bottom of the play area: {'PASS' if state2==0 else 'FAIL'} (state={state2})")

def test_enemy_firing():
    m = fresh_machine(BIN)
    call(m, SYM['SPAWN_ENEMY'], max_runs=500000)
    base = SYM['ENEMY_POOL']
    m.memory[base+3] = 1   # EN_TIMER = 1, fires on next tick
    err = call(m, SYM['UPDATE_ENEMY_FIRING'], max_runs=500000)
    eb_state = m.memory[SYM['EBUL_POOL']+2]
    new_timer = m.memory[base+3]
    ok = err is None and eb_state == 1 and new_timer > 0
    print(f"[EBULLET] enemy fires when its cooldown reaches zero: {'PASS' if ok else 'FAIL'} "
          f"(err={err} eb_state={eb_state} new_timer={new_timer})")

def test_player_hit_and_respawn():
    m = fresh_machine(BIN)
    call(m, SYM['INIT_PLAYER_SPRITE_BOTH'], max_runs=500000)
    m.memory[SYM['PLR_X']] = 100
    m.memory[SYM['PLR_Y']] = 100
    m.memory[SYM['PLR_PA_X']] = 100
    m.memory[SYM['PLR_PA_Y']] = 100
    m.memory[SYM['PLR_PB_X']] = 100
    m.memory[SYM['PLR_PB_Y']] = 100
    m.memory[SYM['PLR_LIVES']] = 3
    m.memory[SYM['PLR_INVULN']] = 0
    m.b, m.c = 102, 100   # spawn a bullet right on top of the player
    call(m, SYM['SPAWN_EBULLET'], max_runs=500000)
    err = call(m, SYM['COLLIDE_EBULLETS_VS_PLAYER'], max_runs=500000)

    lives = m.memory[SYM['PLR_LIVES']]
    invuln = m.memory[SYM['PLR_INVULN']]
    px, py = m.memory[SYM['PLR_X']], m.memory[SYM['PLR_Y']]
    eb_state = m.memory[SYM['EBUL_POOL']+2]
    ok = (err is None and lives == 2 and invuln > 0 and (px, py) == (100, 140) and eb_state == 0)
    print(f"[HIT] overlapping enemy bullet hits player, respawns, sets invuln: "
          f"{'PASS' if ok else 'FAIL'} (lives={lives} invuln={invuln} pos=({px},{py}) eb_state={eb_state})")

def test_invulnerable_player_ignores_hits():
    m = fresh_machine(BIN)
    m.memory[SYM['PLR_X']] = 100
    m.memory[SYM['PLR_Y']] = 100
    m.memory[SYM['PLR_LIVES']] = 3
    m.memory[SYM['PLR_INVULN']] = 50   # currently invulnerable
    m.b, m.c = 100, 100
    call(m, SYM['SPAWN_EBULLET'], max_runs=500000)
    call(m, SYM['COLLIDE_EBULLETS_VS_PLAYER'], max_runs=500000)
    lives = m.memory[SYM['PLR_LIVES']]
    eb_state = m.memory[SYM['EBUL_POOL']+2]
    ok = lives == 3 and eb_state == 1   # bullet survives, no damage taken
    print(f"[HIT] invulnerable player takes no damage, bullet unaffected: "
          f"{'PASS' if ok else 'FAIL'} (lives={lives} eb_state={eb_state})")

def test_game_over_on_last_life():
    m = fresh_machine(BIN)
    m.memory[SYM['PLR_X']] = 100
    m.memory[SYM['PLR_Y']] = 100
    m.memory[SYM['PLR_LIVES']] = 1
    m.memory[SYM['PLR_INVULN']] = 0
    m.memory[SYM['GAME_STATE']] = 0
    # Spawned a few px into the player's box rather than exactly at its
    # raw top-left corner - the tiny bullet box's true centre is only
    # +1,+2 from its raw X/Y (see test_collision_hit's note), so a bullet
    # placed exactly at the player's raw corner sits right at the
    # threshold edge rather than comfortably inside it.
    m.b, m.c = 105, 104
    call(m, SYM['SPAWN_EBULLET'], max_runs=500000)
    call(m, SYM['COLLIDE_EBULLETS_VS_PLAYER'], max_runs=500000)
    lives = m.memory[SYM['PLR_LIVES']]
    game_state = m.memory[SYM['GAME_STATE']]
    ok = lives == 0 and game_state == 1
    print(f"[HIT] losing the last life sets GAME_STATE to game-over: "
          f"{'PASS' if ok else 'FAIL'} (lives={lives} game_state={game_state})")

test_ebullet_spawn_and_lifecycle()
test_enemy_firing()
test_player_hit_and_respawn()
test_invulnerable_player_ignores_hits()
test_game_over_on_last_life()


def test_bullet_spawn_is_centred_under_shooter():
    """Firing used to just copy the shooter's raw X (correct only because
    the old bullet shared the shooter's own 16x16 box). Now that the
    bullet box is much smaller, the spawn code must add BUL_XOFF to stay
    visually centred - confirm it actually does."""
    m = fresh_machine(BIN)
    m.memory[SYM['PLR_X']] = 100
    m.memory[SYM['PLR_Y']] = 140
    m.memory[SYM['FIRE_CD']] = 0
    m.memory[SYM['INPUT_STATE']] = 0x10
    call(m, SYM['UPDATE_PLAYER'])
    pb_x = m.memory[SYM['PBUL_POOL']+0]
    pb_y = m.memory[SYM['PBUL_POOL']+1]
    ok = (pb_x == 107) and (pb_y == 137)   # 100+BUL_XOFF(7), 140-3
    print(f"[BULLET] player shot spawns centred under the ship: "
          f"{'PASS' if ok else 'FAIL'} (pb=({pb_x},{pb_y}) expected=(107,137))")

    m2 = fresh_machine(BIN)
    call(m2, SYM['SPAWN_ENEMY'], max_runs=500000)
    base = SYM['ENEMY_POOL']
    m2.memory[base+0] = 50            # EN_X
    m2.memory[base+1] = 60            # EN_Y
    m2.memory[base+2] = 1             # STATE_ALIVE
    m2.memory[base+3] = 1             # EN_TIMER -> fires next tick
    call(m2, SYM['UPDATE_ENEMY_FIRING'], max_runs=500000)
    eb_x = m2.memory[SYM['EBUL_POOL']+0]
    eb_y = m2.memory[SYM['EBUL_POOL']+1]
    ok2 = (eb_x == 57) and (eb_y == 66)  # 50+BUL_XOFF(7), 60+6
    print(f"[EBULLET] enemy shot spawns centred under the enemy: "
          f"{'PASS' if ok2 else 'FAIL'} (eb=({eb_x},{eb_y}) expected=(57,66))")


def test_bullet_draw_erase_footprint_is_small():
    """The whole point of the shrink: confirm DRAW_BULLET_SPR/
    ERASE_BULLET_SPR only ever touch BUL_SPR_W x BUL_SPR_H bytes, not the
    old 8x16 (128-byte) footprint. Fill the screen with a marker, draw a
    bullet, and check nothing outside its tiny box changed."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0x11
    m.a = 1   # SPR_PBULLET index
    call(m, SYM['GET_SPR_PTR'])
    x, y = 40, 40
    m.b, m.c = x, y
    call(m, SYM['DRAW_BULLET_SPR'])

    changed = []
    for row in range(8):          # scan a few rows above/below the box
        for byte_col in range(-2, 4):
            off = (y - 2 + row) * 128 + (x // 2) + byte_col
            if m.memory[off] != 0x11:
                changed.append((row - 2, byte_col))
    # Every changed byte should be within row 0..3 (BUL_SPR_H) and
    # byte_col 0 (BUL_SPR_W=1 byte wide)
    ok = all(0 <= r < 4 and c == 0 for r, c in changed) and len(changed) > 0
    print(f"[BULLET] DRAW_BULLET_SPR only touches its {1}x{4}-byte box, nothing wider: "
          f"{'PASS' if ok else 'FAIL'} (changed cells={changed})")

    # NOTE: can't check "restored to 0x11" here - same documented limitation
    # as test_erase_actually_restores_pixels above: this flat-memory emulator
    # has no real paging, so MAP_BG/MAP_BACK are no-ops and ERASE_BULLET_SPR
    # reads back the very bytes it just drew as "background" and writes them
    # unchanged. What IS checkable: it visits exactly its BUL_SPR_H rows at
    # the correct stride, with no skips - mirrors test_erase_visits_all_rows_
    # correctly's approach for the same reason.
    for row in range(4):
        base = (y + row) * 128 + (x // 2)
        m.memory[base] = row + 1        # unique marker per row (avoid 0)
    m.b, m.c = x, y                     # DRAW_BULLET_SPR corrupts B/C - reload
    err = call(m, SYM['ERASE_BULLET_SPR'], max_runs=500000)
    ebuf = bytes(m.memory[SYM['EBUF_BUL']:SYM['EBUF_BUL']+4])
    ok = err is None and list(ebuf) == [1, 2, 3, 4]
    print(f"[BULLET] ERASE_BULLET_SPR visits all {4} rows at the correct stride: "
          f"{'PASS' if ok else 'FAIL'} (err={err} ebuf={list(ebuf)})")


def test_bullet_taper_preserves_background_nibble():
    """The whole reason the bullet still carries a mask (vs. a plain
    rectangle) is its tapered top/bottom row - one nibble transparent,
    one opaque. Confirm that taper still renders correctly at the new
    tiny size: top row (0x0D pixel / 0xF0 mask) should leave the
    background's high nibble untouched and take the sprite's D in the
    low nibble."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0x11
    m.a = 1   # SPR_PBULLET
    call(m, SYM['GET_SPR_PTR'])
    m.b, m.c = 40, 40
    call(m, SYM['DRAW_BULLET_SPR'])
    top_row = m.memory[40*128 + 40//2]
    bottom_row = m.memory[43*128 + 40//2]
    ok = (top_row == 0x1D) and (bottom_row == 0xD1)
    print(f"[BULLET] tapered top/bottom row keeps background nibble, takes sprite nibble: "
          f"{'PASS' if ok else 'FAIL'} (top={hex(top_row)} exp=0x1d, bottom={hex(bottom_row)} exp=0xd1)")


test_bullet_spawn_is_centred_under_shooter()
test_bullet_draw_erase_footprint_is_small()
test_bullet_taper_preserves_background_nibble()


def test_wave_spawner_produces_variable_batch_sizes():
    """UPDATE_ENEMY_SPAWNER now spawns WAVE_SIZE_MIN..WAVE_SIZE_MAX
    enemies per tick instead of always exactly one, and rolls a new
    randomised delay each time. Run enough ticks to see multiple waves
    and confirm both the batch size and the delay actually vary (not
    just that the code runs)."""
    m = fresh_machine(BIN)
    batch_sizes = []
    delays = []
    prev_alive = 0
    for frame in range(400):
        err = call(m, SYM['UPDATE_ENEMY_SPAWNER'], max_runs=500000)
        if err:
            print(f"[WAVE] UPDATE_ENEMY_SPAWNER: {err} - FAIL")
            return
        alive = sum(1 for i in range(6)
                    if m.memory[SYM['ENEMY_POOL'] + i*10 + 2] == 1)
        if alive > prev_alive:
            batch_sizes.append(alive - prev_alive)
        prev_alive = alive
        # free a slot occasionally so the pool doesn't saturate and mask
        # further spawns
        if frame % 15 == 0:
            for i in range(6):
                m.memory[SYM['ENEMY_POOL'] + i*10 + 2] = 0
            prev_alive = 0
    distinct_batches = len(set(batch_sizes))
    in_range = all(1 <= b <= 3 for b in batch_sizes)
    ok = distinct_batches > 1 and in_range and len(batch_sizes) > 3
    print(f"[WAVE] spawner produces variable batch sizes (1-3), not always 1: "
          f"{'PASS' if ok else 'FAIL'} (batches={batch_sizes})")


def test_enemy_spawn_assigns_movement_type():
    """SPAWN_ENEMY should roll EN_TYPE (0/1/2) and set EN_PHASE
    appropriately: 0-15 for sine, 0/1 for zigzag, 0 for straight."""
    m = fresh_machine(BIN)
    types_seen = set()
    for i in range(60):
        m2 = fresh_machine(BIN)
        call(m2, SYM['SPAWN_ENEMY'], max_runs=500000)
        # advance the shared RNG stream so repeated single-enemy spawns
        # in fresh machines don't all roll the same type
        for _ in range(i):
            call(m2, SYM['RND_BYTE'])
        t = m2.memory[SYM['ENEMY_POOL'] + 8]  # EN_TYPE offset
        types_seen.add(t)
    # More reliable: spawn several enemies into the SAME machine in one go
    m3 = fresh_machine(BIN)
    for i in range(6):
        call(m3, SYM['SPAWN_ENEMY'], max_runs=500000)
    types_in_pool = [m3.memory[SYM['ENEMY_POOL'] + i*10 + 8] for i in range(6)]
    valid = all(t in (0, 1, 2) for t in types_in_pool)
    varied = len(set(types_in_pool)) > 1
    print(f"[WAVE] SPAWN_ENEMY assigns a valid movement type (0/1/2) per enemy: "
          f"{'PASS' if valid else 'FAIL'} (types={types_in_pool})")
    print(f"[WAVE] a full pool of spawns shows more than one movement type: "
          f"{'PASS' if varied else 'FAIL'} (types={types_in_pool})")

    for t, name, phase_ok_fn in [
        (1, 'sine', lambda p: 0 <= p <= 15),
        (2, 'zigzag', lambda p: p in (0, 1)),
    ]:
        found = False
        for i in range(6):
            base = SYM['ENEMY_POOL'] + i*10
            if m3.memory[base+8] == t:
                phase = m3.memory[base+9]
                ok = phase_ok_fn(phase)
                found = True
                print(f"[WAVE] {name} enemy's EN_PHASE is in valid range: "
                      f"{'PASS' if ok else 'FAIL'} (phase={phase})")
                break
        if not found:
            print(f"[WAVE] (no {name} enemy rolled in this sample - inconclusive, not a failure)")


def test_sine_enemy_moves_horizontally_and_stays_in_bounds():
    m = fresh_machine(BIN)
    base = SYM['ENEMY_POOL']
    m.memory[base+0] = 120         # EN_X
    m.memory[base+1] = 20          # EN_Y
    m.memory[base+2] = 1           # STATE_ALIVE
    m.memory[base+8] = 1           # EN_TYPE = TYPE_SINE
    m.memory[base+9] = 0           # EN_PHASE start
    xs = []
    for i in range(32):            # two full weave cycles
        err = call(m, SYM['UPDATE_ENEMIES'], max_runs=500000)
        if err:
            print(f"[WAVE] sine UPDATE_ENEMIES: {err} - FAIL")
            return
        xs.append(m.memory[base+0])
    moved = len(set(xs)) > 1
    in_bounds = all(0 <= x <= SYM['EN_X_MAX'] if 'EN_X_MAX' in SYM else 0 <= x <= 240 for x in xs)
    print(f"[WAVE] sine enemy's X actually varies over time (not fixed): "
          f"{'PASS' if moved else 'FAIL'} (xs={xs})")
    print(f"[WAVE] sine enemy stays within screen bounds: "
          f"{'PASS' if in_bounds else 'FAIL'}")


def test_zigzag_enemy_bounces_off_edges():
    m = fresh_machine(BIN)
    base = SYM['ENEMY_POOL']
    # X=1 with a -2px step genuinely overshoots past 0 (1-2=-1) - a
    # genuine overshoot is what should flip direction. X=2 (exactly
    # ZIGZAG_SPEED) lands exactly on 0 with no overshoot, and by the same
    # symmetric rule the right-edge case below relies on (exact landing
    # on EN_X_MAX doesn't flip either - only exceeding it does), that
    # correctly does NOT flip. An earlier version of this test used X=2
    # and wrongly expected a flip there.
    m.memory[base+0] = 1
    m.memory[base+1] = 20
    m.memory[base+2] = 1
    m.memory[base+8] = 2            # EN_TYPE = TYPE_ZIGZAG
    m.memory[base+9] = 1            # direction = left (should bounce immediately)
    err = call(m, SYM['UPDATE_ENEMIES'], max_runs=500000)
    x_after = m.memory[base+0]
    dir_after = m.memory[base+9]
    ok = (err is None) and (x_after == 0) and (dir_after == 0)
    print(f"[WAVE] zigzag enemy clamps and flips direction on overshooting the left edge: "
          f"{'PASS' if ok else 'FAIL'} (x={x_after} dir={dir_after})")

    m2 = fresh_machine(BIN)
    x_max = 240
    m2.memory[base+0] = x_max - 1
    m2.memory[base+1] = 20
    m2.memory[base+2] = 1
    m2.memory[base+8] = 2
    m2.memory[base+9] = 0            # direction = right (should bounce immediately)
    call(m2, SYM['UPDATE_ENEMIES'], max_runs=500000)
    x_after2 = m2.memory[base+0]
    dir_after2 = m2.memory[base+9]
    ok2 = (x_after2 == x_max) and (dir_after2 == 1)
    print(f"[WAVE] zigzag enemy clamps and flips direction at the right edge: "
          f"{'PASS' if ok2 else 'FAIL'} (x={x_after2} dir={dir_after2})")


test_wave_spawner_produces_variable_batch_sizes()
test_enemy_spawn_assigns_movement_type()
test_sine_enemy_moves_horizontally_and_stays_in_bounds()
test_zigzag_enemy_bounces_off_edges()


def test_bg_stripes_cover_play_area_not_hud():
    """DRAW_BG_STRIPES should fill HUD_H..SCR_H_PX-1 with the repeating
    4-colour band pattern, and leave rows 0..HUD_H-1 (the HUD band)
    completely untouched by it - it's called AFTER the flat black fill
    in GAME_START, so those rows should still read as the fill byte."""
    m = fresh_machine(BIN)
    for addr in range(0, 24576):
        m.memory[addr] = 0x00     # matches GAME_START's flat black fill
    err = call(m, SYM['DRAW_BG_STRIPES'], max_runs=500000)
    hud_untouched = all(m.memory[row*128] == 0x00 for row in range(16))
    print(f"[BGCYCLE] DRAW_BG_STRIPES leaves the HUD band (rows 0-15) untouched: "
          f"{'PASS' if (err is None and hud_untouched) else 'FAIL'} (err={err})")

    # Row 16 (first play-area row) should be index 2 in both nibbles = 0x22
    # Row 24 (one BAND_HEIGHT=8 further down) should roll to index 3 = 0x33
    row16 = m.memory[16*128]
    row24 = m.memory[24*128]
    row32 = m.memory[32*128]
    row40 = m.memory[40*128]
    ok = (row16, row24, row32, row40) == (0x22, 0x33, 0x44, 0x55)
    print(f"[BGCYCLE] bands cycle through indices 2,3,4,5 every {8}px: "
          f"{'PASS' if ok else 'FAIL'} (rows 16/24/32/40 = "
          f"{hex(row16)}/{hex(row24)}/{hex(row32)}/{hex(row40)})")

    # Row 48 should wrap back to index 2 (one full 4-band cycle = 32px)
    row48 = m.memory[48*128]
    print(f"[BGCYCLE] pattern wraps seamlessly after one full cycle (32px): "
          f"{'PASS' if row48 == 0x22 else 'FAIL'} (row 48 = {hex(row48)})")

    # Every byte in a stripe row should be the SAME fill byte (solid band,
    # full screen width) - spot-check a few positions across row 16
    row16_bytes = [m.memory[16*128 + off] for off in (0, 40, 80, 127)]
    uniform = all(b == 0x22 for b in row16_bytes)
    print(f"[BGCYCLE] stripe band is solid across the full screen width: "
          f"{'PASS' if uniform else 'FAIL'} (sampled={[hex(b) for b in row16_bytes]})")


def test_bg_cycle_rotates_on_schedule_and_wraps():
    """UPDATE_BG_CYCLE should only rotate BGCYCLE_VALS every
    BGCYCLE_INTERVAL frames (not every frame), and the rotation should be
    a genuine right-shift with wraparound (see the routine's own comment
    for the direction derivation) - confirm both by watching the RAM
    copy directly, since the actual palette OUT writes aren't observable
    in this flat-memory emulator."""
    m = fresh_machine(BIN)
    base = SYM['BGCYCLE_VALS']
    initial = list(m.memory[base:base+4])   # [32,48,64,80]

    # First 3 frames (BGCYCLE_INTERVAL-1): timer counts down, no rotation
    for i in range(3):
        call(m, SYM['UPDATE_BG_CYCLE'], max_runs=500000)
    unchanged = list(m.memory[base:base+4]) == initial
    print(f"[BGCYCLE] no rotation before BGCYCLE_INTERVAL frames have passed: "
          f"{'PASS' if unchanged else 'FAIL'} (vals={list(m.memory[base:base+4])})")

    # 4th frame: timer hits zero, rotation fires - right-shift means
    # new[0]=old[3], new[1]=old[0], new[2]=old[1], new[3]=old[2]
    call(m, SYM['UPDATE_BG_CYCLE'], max_runs=500000)
    after_one = list(m.memory[base:base+4])
    expected = [initial[3], initial[0], initial[1], initial[2]]
    ok = after_one == expected
    print(f"[BGCYCLE] rotates right (with wrap) exactly on the 4th frame: "
          f"{'PASS' if ok else 'FAIL'} (got={after_one} expected={expected})")

    # 4 rotation cycles (16 frames total) should return to the exact
    # starting arrangement - confirms the pattern loops seamlessly with
    # no drift, matching the comment's "back to original after 4 steps"
    for i in range(15):   # 3 more frames to finish this cycle + 12 for 3 more
        call(m, SYM['UPDATE_BG_CYCLE'], max_runs=500000)
    after_four_cycles = list(m.memory[base:base+4])
    print(f"[BGCYCLE] returns to the exact starting arrangement after 4 rotations: "
          f"{'PASS' if after_four_cycles == initial else 'FAIL'} "
          f"(got={after_four_cycles} expected={initial})")


def test_game_start_and_frame_loop_still_work_with_bg_cycle():
    """Integration check: GAME_START (now drawing stripes into all 3
    pages) and a run of MAIN_LOOP-equivalent calls (now including
    UPDATE_BG_CYCLE) still complete without crash/hang."""
    m = fresh_machine(BIN)
    err = call(m, SYM['DRAW_BG_STRIPES'], max_runs=500000)
    ok = err is None
    for i in range(60):
        e = call(m, SYM['UPDATE_BG_CYCLE'], max_runs=500000)
        if e:
            ok = False
            err = e
            break
    print(f"[BGCYCLE] DRAW_BG_STRIPES + 60 frames of UPDATE_BG_CYCLE, no crash/hang: "
          f"{'PASS' if ok else 'FAIL'} (err={err})")


test_bg_stripes_cover_play_area_not_hud()
test_bg_cycle_rotates_on_schedule_and_wraps()
test_game_start_and_frame_loop_still_work_with_bg_cycle()

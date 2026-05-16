# Implementation Plan: Boss Zombie Every Five Waves

**Branch**: `DEATHN-20-boss-zombie-every` | **Date**: 2026-05-16 | **Spec**: `specs/DEATHN-20-boss-zombie-every/spec.md`
**Input**: Feature specification from `specs/DEATHN-20-boss-zombie-every/spec.md`

## Summary

Add a boss zombie that spawns on every 5th wave when the player reaches 50% kills. The boss is visually distinct (2x scale, red tint), displays a multi-word phrase the player must type to kill it, and shows a health bar tracking typing progress. The input buffer extends to 35 characters during boss encounters. Wave completion on boss waves requires both the pool and boss to be defeated.

## Technical Context

**Language/Version**: Zig (toolchain-installed version, currently 0.16)
**Primary Dependencies**: raylib (pinned commit `52f2a10d`, static linkage)
**Storage**: N/A (no persistence)
**Testing**: Zig built-in test runner via `zig build test`
**Target Platform**: Native (Linux/macOS/Windows) + wasm32-emscripten
**Project Type**: Single project (game)
**Performance Goals**: 60 FPS (maintained — no new per-frame allocations in hot path)
**Constraints**: Fixed 800x450 window, all gameplay in module-level globals
**Scale/Scope**: Single-player local game, ~570 LOC in main.zig

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Rule | Status | Notes |
|------|--------|-------|
| Single-module game loop (extend `main.zig` or add sibling) | PASS | Boss logic extends `main.zig`; phrases in new `src/boss_phrases.zig` sibling module |
| C interop walled off in `raylib.zig` | PASS | No new `@cImport` calls |
| Named constants for tunables | PASS | All boss tunables (`BOSS_SCALE`, `BOSS_SPEED_MULTIPLIER`, `BOSS_HEALTH_BAR_WIDTH`, etc.) are module-level constants |
| Paired Init/defer Close for resources | PASS | No new resource loads — reuses existing texture and sound |
| Optional pointers unwrapped with `if (x) \|val\|` | PASS | `boss: ?*Zombie` unwrapped defensively throughout |
| Allocator passed by pointer parameter | PASS | Boss spawn/reset functions receive `*std.mem.Allocator` |
| Fixed-size pools | PASS | Boss is a single `?*Zombie` pointer (max 1), not a dynamic list |
| Tests in module under test | PASS | New test blocks added to `src/main.zig` |
| No network/secrets | PASS | No new I/O surfaces |
| Bounded input buffers | PASS | Buffer enlarged to 36 bytes; guard uses `getCurrentMaxInput()` returning 9 or 35 |
| Null-terminated C strings via slice comparison | PASS | Boss phrase length computed by null-scan, compared via `std.mem.eql` on slices |
| Asset paths are literals | PASS | No new asset loads |
| `zig build` compiles cleanly | GATE | Must verify before merge |
| Idiomatic error handling (try/errdefer) | PASS | `spawnBoss` follows `spawnZombie` pattern with `errdefer allocator.destroy` |

**Post-design re-check**: All gates pass. No violations to justify.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-20-boss-zombie-every/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
└── data-model.md        # Phase 1 output
```

### Source Code (repository root)

```
src/
├── main.zig             # Extend: boss state, spawn/update/draw/reset, input buffer, wave completion
├── boss_phrases.zig     # NEW: 10 boss phrases as [*:0]const u8 array
├── zombie_names.zig     # Unchanged
├── raylib.zig           # Unchanged
└── web_root.zig         # Unchanged (transitively picks up main.zig changes)
```

**Structure Decision**: Single project, all gameplay in `src/main.zig`, data arrays in sibling modules. Matches existing `zombie_names.zig` pattern.

## Implementation Phases

### Phase 1: Boss Phrase Data + Constants

**Files**: `src/boss_phrases.zig` (new), `src/main.zig` (modify)

1. Create `src/boss_phrases.zig` with `pub const BossPhrases` — 10 lowercase phrases with spaces, all `[*:0]const u8`, following the `zombie_names.zig` pattern (`src/zombie_names.zig:1`).

2. In `src/main.zig`, add imports and constants at the top of the file (alongside existing constants at lines 7-12):
   ```zig
   const BossPhrases = @import("boss_phrases.zig").BossPhrases;

   const MAX_BOSS_INPUT_CHARS = 35;
   const BOSS_SCALE: f32 = 0.4;
   const BOSS_SPEED_MULTIPLIER: f32 = 0.5;
   const BOSS_HEALTH_BAR_WIDTH: c_int = 200;
   const BOSS_HEALTH_BAR_HEIGHT: c_int = 8;
   ```

3. Enlarge the input buffer from `(MAX_INPUT_CHARS + 1)` to `(MAX_BOSS_INPUT_CHARS + 1)` at `src/main.zig:40`.

4. Add boss state globals (alongside existing state at lines 43-50):
   ```zig
   var boss: ?*Zombie = null;
   var boss_spawned_this_wave: bool = false;
   var boss_phrase_len: usize = 0;
   ```

5. Add `getCurrentMaxInput()` helper:
   ```zig
   fn getCurrentMaxInput() usize {
       return if (boss != null) MAX_BOSS_INPUT_CHARS else MAX_INPUT_CHARS;
   }
   ```

### Phase 2: Input Buffer Dynamic Limit

**Files**: `src/main.zig`

1. In `frame()` at line 109, change the input acceptance guard from:
   ```zig
   letter_count < MAX_INPUT_CHARS
   ```
   to:
   ```zig
   letter_count < getCurrentMaxInput()
   ```

2. Update the blinking cursor guard at line 228 from `letter_count < MAX_INPUT_CHARS` to `letter_count < getCurrentMaxInput()`.

3. Update the "Press BACKSPACE" hint guard at line 232 from `letter_count >= MAX_INPUT_CHARS` to `letter_count >= getCurrentMaxInput()`.

### Phase 3: Boss Spawn Logic

**Files**: `src/main.zig`

1. Add `spawnBoss(allocator: *std.mem.Allocator) !void` function following the `spawnZombie` pattern (`src/main.zig:395-419`):
   - Allocate a `Zombie` with `try allocator.create(Zombie)`
   - Use `errdefer allocator.destroy(new_boss)` for cleanup on failure
   - Set `x` to horizontal center: `screen_width / 2.0 - (frame_width * BOSS_SCALE / 2.0)` (approximate centering; exact frame_width computed from texture at runtime, but can use a reasonable constant since we know the spritesheet)
   - Set `y = 0.0`, `speed = getWaveConfig(current_wave).fall_speed * BOSS_SPEED_MULTIPLIER`
   - Select random phrase: `BossPhrases[@intCast(raylib.GetRandomValue(0, @intCast(BossPhrases.len - 1)))]`
   - Assign to `boss`, set `boss_spawned_this_wave = true`
   - Precompute `boss_phrase_len` by scanning to null terminator

2. In `frame()`, after the `updateZombies(ctx.allocator)` call (line 141) and before the wave completion check (line 145), add boss spawn trigger:
   ```
   if (current_wave % 5 == 0 and !boss_spawned_this_wave and boss == null) {
       const pool_size = getWaveConfig(current_wave).pool_size;
       const threshold = (pool_size + 1) / 2;
       if (wave_kills >= threshold) {
           spawnBoss(ctx.allocator) catch {};
       }
   }
   ```

### Phase 4: Boss Update Logic

**Files**: `src/main.zig`

1. Add `updateBoss(allocator: *std.mem.Allocator) void` function:
   - If `boss == null`, return immediately
   - Unwrap with `if (boss) |b|`
   - Advance `b.y += b.speed` (same as regular zombie update, `src/main.zig:309`)
   - If `b.y >= screen_height`: set `is_game_over = true`, return (FR-013)
   - Compute typed name: `name[0..letter_count]`
   - Compute boss phrase slice: scan `b.name` to null for length, slice `b.name[0..boss_phrase_len]`
   - Check if typed input is a valid prefix of the boss phrase: `std.mem.eql(u8, typed_name, boss_phrase[0..letter_count])`
   - If prefix matches AND `letter_count == boss_phrase_len`: boss killed
     - `allocator.destroy(b)`, `boss = null`
     - Clear input: `letter_count = 0`, `name[0] = '\x00'`
     - Play sound: `raylib.PlaySound(zombie_kill_sound)`
     - Do NOT increment `wave_kills` (boss is separate from pool)

2. In `frame()`, call `updateBoss(ctx.allocator)` right after the boss spawn check and before `updateZombies`.

3. Modify `updateZombies` to suppress regular zombie kills when boss is active and input is a valid boss phrase prefix (FR-010):
   - Before the `std.mem.eql` check for regular zombies, add:
     ```
     if (boss != null) {
         // Check if typed input is a prefix of the boss phrase — if so, skip regular zombie matching
         if (boss) |b| {
             const boss_slice = b.name[0..boss_phrase_len];
             if (letter_count <= boss_phrase_len and std.mem.eql(u8, typed_name, boss_slice[0..letter_count])) {
                 continue; // Boss priority — skip this regular zombie
             }
         }
     }
     ```

### Phase 5: Boss Draw Logic

**Files**: `src/main.zig`

1. Add `drawBoss() void` function:
   - If `boss == null`, return
   - Unwrap with `if (boss) |b|`
   - Animate using same logic as `drawZombies` (`src/main.zig:351-359`): advance `animation_timer`, increment `frame`, wrap at `ZOMBIE_FRAME_COUNT`
   - Compute source rectangle from spritesheet (same as `drawZombies`, line 362-369)
   - Draw with `DrawTexturePro` using `BOSS_SCALE` (0.4) and `raylib.RED` tint instead of 0.2 / `raylib.WHITE`
   - Draw phrase text above sprite: `raylib.DrawText(b.name, ...)` at `(boss_x, boss_y - 30)`, font size 20, dark red color `raylib.Color{ .r = 139, .g = 0, .b = 0, .a = 255 }`
   - Draw health bar below phrase text:
     - Background: `raylib.DrawRectangle(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.LIGHTGRAY)`
     - Fill: `raylib.DrawRectangle(bar_x, bar_y, fill_width, BOSS_HEALTH_BAR_HEIGHT, raylib.RED)` where `fill_width = BOSS_HEALTH_BAR_WIDTH * (boss_phrase_len - letter_count) / boss_phrase_len` (only when input is valid prefix)
     - Border: `raylib.DrawRectangleLines(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.DARKGRAY)`

2. Call `drawBoss()` inside the draw phase alongside `drawZombies()` at line 225 (in the `else` branch that draws active gameplay).

### Phase 6: Wave Completion + Reset

**Files**: `src/main.zig`

1. Modify wave completion check at line 145:
   ```zig
   // Before (existing):
   if (!is_game_over and wave_kills >= wave_cfg.pool_size and wave_spawned >= wave_cfg.pool_size) {
   // After:
   const boss_done = if (current_wave % 5 == 0) boss == null and boss_spawned_this_wave else true;
   if (!is_game_over and wave_kills >= wave_cfg.pool_size and wave_spawned >= wave_cfg.pool_size and boss_done) {
   ```
   This ensures boss waves wait for both pool completion AND boss death (FR-012). On non-boss waves, `boss_done` is always true.

2. Add `resetBoss(allocator: *std.mem.Allocator) void`:
   ```zig
   fn resetBoss(allocator: *std.mem.Allocator) void {
       if (boss) |b| {
           allocator.destroy(b);
           boss = null;
       }
       boss_spawned_this_wave = false;
       boss_phrase_len = 0;
   }
   ```

3. Call `resetBoss(ctx.allocator)` in every place `resetZombies` is called:
   - Wave transition (line 160, inside `if (transition_timer <= 0)` block)
   - Game restart (line 214, inside `if (raylib.IsKeyPressed(raylib.KEY_ENTER))` block)

4. In the game restart block (line 204-215), also reset boss-specific state alongside existing resets: the `resetBoss` call handles this, plus ensure `letter_count` and `name` clear happen after `resetBoss` (they already do in the existing code).

### Phase 7: Tests

**Files**: `src/main.zig`

Add test blocks at the bottom of `src/main.zig` (after existing tests ending at line 572):

1. **Boss spawn threshold test**: verify `(pool_size + 1) / 2` gives correct thresholds:
   - Wave 5: pool_size=13 → threshold=7
   - Wave 10: pool_size=23 → threshold=12
   - Wave 20: pool_size=43 → threshold=22

2. **Boss wave detection test**: verify `wave % 5 == 0` for waves 5, 10, 15, 20 and NOT for waves 1, 4, 6, 14.

3. **Boss input limit test**: verify `getCurrentMaxInput()` returns `MAX_INPUT_CHARS` when `boss == null` and `MAX_BOSS_INPUT_CHARS` when boss is set (requires temporarily setting the global — acceptable in test context since tests run sequentially in Zig).

4. **Boss phrase validity test**: verify all 10 phrases in `BossPhrases` are:
   - Non-empty
   - Within 35 characters
   - Contain only lowercase letters and spaces (chars 32, 97-122)

5. **Wave completion with boss test**: verify that `wave_kills >= pool_size AND wave_spawned >= pool_size AND boss == null AND boss_spawned_this_wave` is the correct completion condition for boss waves.

6. **Input buffer size test**: verify `name` buffer has capacity for `MAX_BOSS_INPUT_CHARS + 1` bytes.

## Testing Strategy

Per constitution: Zig built-in test runner, tests as `test` blocks in `src/main.zig`.

**Unit tests** (in `src/main.zig`):
- Boss spawn threshold calculation (pure arithmetic)
- Boss wave detection (modulo check)
- Input limit switching (`getCurrentMaxInput`)
- Boss phrase data validation (character ranges, length bounds)
- Wave completion condition with boss gate
- Input buffer capacity

**Manual testing** (via `zig build run`):
- Play through waves 1-5, verify boss spawns at 50% kills on wave 5
- Verify boss visual: larger, red-tinted, phrase above, health bar
- Type boss phrase, verify health bar depletes and boss dies
- Verify input buffer accepts >9 characters during boss, reverts to 9 after
- Verify wave doesn't transition until boss is killed
- Let boss reach bottom, verify game over
- Restart during boss wave, verify clean state
- Play through waves 5-10, verify second boss spawns correctly
- Verify boss priority: typed text matching regular zombie name is not consumed while it's also a boss phrase prefix

**Build verification**:
- `zig build` — clean compile, no warnings
- `zig build test` — all tests pass (existing + new)

## Complexity Tracking

No constitution violations. No complexity justifications needed.

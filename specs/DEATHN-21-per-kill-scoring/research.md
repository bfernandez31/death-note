# Research: Per-kill scoring formula with combo and HUD

**Branch**: `DEATHN-21-per-kill-scoring` | **Date**: 2026-05-16

## Unknowns Resolved

### 1. Scoring formula rounding behavior

- **Decision**: Use Zig's `@round` builtin (IEEE 754 round-to-nearest, ties-to-even)
- **Rationale**: The spec states "standard mathematical rounding (round half away from zero)," which differs from IEEE 754 only at exact `.5` boundaries. The scoring formula `100 × (y / 450)` produces `.5` only at `y = 2.25`, which is practically unreachable in gameplay. All four reference test cases produce correct results with `@round`. A custom rounding function would add complexity for no observable benefit.
- **Alternatives considered**: Custom `roundHalfAwayFromZero` function — rejected because it solves a problem that doesn't manifest in practice and adds untestable divergence risk.

### 2. Boss vs. standard zombie identification at kill time

- **Decision**: Pass an `is_boss: bool` parameter to the score calculation function, determined by context (boss kills happen in `updateBoss`, standard kills in `updateZombies`)
- **Rationale**: The `Zombie` struct has no `is_boss` field, and the boss is tracked via a separate `boss: ?*Zombie` global. Adding a field to `Zombie` would require changes to `spawnZombie` and every struct literal, with no benefit since boss and zombie kills are already handled in separate functions. The call site inherently knows whether it's a boss kill.
- **Alternatives considered**: Adding `is_boss: bool` to `Zombie` struct — rejected because it duplicates information already encoded by the `boss` global and would require touching every `Zombie` initialization.

### 3. Combo mismatch detection placement

- **Decision**: Check for mismatch after the character-input loop completes, before `updateZombies`/`updateBoss` run
- **Rationale**: The character-input loop (lines 130–138 of `src/main.zig`) processes all queued characters in one frame. At 60 FPS, typically 0–1 characters arrive per frame. Checking after the loop is functionally equivalent to per-character checking: if any character causes the typed buffer to stop matching all active enemies, the final state also won't match. This avoids adding branching inside the tight input loop.
- **Alternatives considered**: Per-character checking inside the `while (key > 0)` loop — rejected for complexity with no behavioral difference.

### 4. Score storage and float-to-integer conversion

- **Decision**: Compute base score as `f32`, convert to `u64` via `@intFromFloat` after the outer `@round`, then multiply by the integer combo multiplier
- **Rationale**: The formula's intermediate values fit comfortably in `f32` precision (max base score ≈ `(35×10 + 100) × 3.0 = 1350`). The combo multiplier is an integer (1–5), so the final multiplication is `u64 × u64` with no floating-point error accumulation. `@intFromFloat` on a rounded `f32` produces exact integer results for values in this range.
- **Alternatives considered**: Full `f64` computation — rejected as overkill for the value range involved.

### 5. Popup pool lifetime management

- **Decision**: Use a fixed-size value array `[32]ScorePopup` with a circular write index (`popup_next`), no heap allocation
- **Rationale**: Popups are short-lived (0.5s), small (5 fields), and have a fixed cap of 32. Allocating them on the heap would add error paths and allocator threading for no benefit. The circular index automatically recycles the oldest entry, matching FR-009's "oldest slot reused" requirement. This follows the constitution's "fixed-size pools, not dynamic lists" principle (mirroring the `zombies` slot array).
- **Alternatives considered**: Heap-allocated linked list — rejected per constitution rule 7 (fixed-size pools preferred).

## Existing Files

| File | Covers | Action |
|------|--------|--------|
| `src/main.zig` | Game loop, zombie lifecycle, input handling, rendering, all game state | **Extend**: add score/combo globals, scoring function, combo logic, popup pool, HUD drawing, game-over score display, mismatch detection |
| `src/zombie_names.zig` | Flat array of zombie name strings | No change |
| `src/boss_phrases.zig` | Flat array of boss phrase strings | No change |
| `src/raylib.zig` | `@cImport` wrapper for raylib/raymath/rlgl/emscripten | No change |
| `src/web_root.zig` | Emscripten entry point wrapper | No change |
| `build.zig` | Build graph, test step, raylib linkage | No change |
| `build.zig.zon` | Package manifest, raylib dependency pin | No change |

**Test files**: All tests are inline `test` blocks in `src/main.zig` (lines 613–827). New tests for scoring, combo, and popup logic will be added as additional `test` blocks in the same file, following the existing pattern.

## Patterns to Follow

### State management — module-level globals (`src/main.zig:50–62`)

All mutable game state is declared as module-level `var` with explicit initial values. Examples:
- `var is_game_over: bool = false;` (line 53)
- `var current_wave: u32 = 1;` (line 54)
- `var wave_kills: u32 = 0;` (line 55)

**Apply to**: `score: u64 = 0`, `combo_count: u32 = 0`, `popups: [MAX_POPUPS]ScorePopup`, `popup_next: usize = 0`

### Kill handling — `updateZombies` (`src/main.zig:338–375`)

When a zombie name matches the typed input:
1. `allocator.destroy(zomb)` — free the zombie
2. `slot.* = null` — clear the slot
3. `letter_count = 0; name[letter_count] = '\x00'` — clear input buffer
4. `wave_kills += 1` — increment kill counter
5. `raylib.PlaySound(zombie_kill_sound)` — play kill sound

**Apply to**: After step 4, add `score += calculateScore(...)` and `combo_count += 1` and `spawnPopup(zomb.x, zomb.y, points)`. The score calculation must capture the zombie's position and name length BEFORE the destroy call.

### Boss kill handling — `updateBoss` (`src/main.zig:474–491`)

When the boss phrase is fully typed:
1. `allocator.destroy(b)` — free the boss
2. `boss = null` — clear boss pointer
3. Clear input buffer
4. Play kill sound

**Apply to**: Before the destroy, calculate score with `is_boss = true`, capture position, increment combo, spawn popup. Note: `wave_kills` is NOT incremented for boss kills (existing behavior) — verify this is intentional.

### Game reset — restart handler (`src/main.zig:238–250`)

On Enter press during game-over, all state resets to initial values. Each variable is explicitly reset.

**Apply to**: Add `score = 0; combo_count = 0; popup_next = 0;` and deactivate all popups.

### Wave transition — (`src/main.zig:178–181`)

When wave completes, `is_transitioning` is set to true.

**Apply to**: Add `combo_count = 0;` at line 180 (when transition begins, per FR-003).

### HUD text formatting — (`src/main.zig:207–209`)

Uses `std.fmt.bufPrintZ` into a stack-allocated `[64]u8` buffer, then draws with `drawCenteredText` or `raylib.DrawText`.

**Apply to**: Score and combo HUD lines use `raylib.DrawText` (left-aligned at x=10), not `drawCenteredText`.

### Constant declarations — (`src/main.zig:8–20`)

Compile-time tunables use `SCREAMING_SNAKE_CASE` and are grouped at the top of the module.

**Apply to**: `MAX_POPUPS`, `POPUP_DURATION`, `POPUP_RISE_PX`, combo tier thresholds, HUD positions/sizes/colors.

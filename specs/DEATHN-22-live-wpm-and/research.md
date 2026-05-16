# Research: Live WPM and Accuracy with Character-Based Metrics

**Branch**: `DEATHN-22-live-wpm-and` | **Date**: 2026-05-16

## Existing Files

| Path | Covers | Action |
|------|--------|--------|
| `src/main.zig` | Game loop, input handling, zombie lifecycle, HUD rendering, all module-level state, tests | **Extend** — all new state, logic, HUD drawing, and tests go here |
| `src/raylib.zig` | C interop wrapper for raylib | No changes needed |
| `src/zombie_names.zig` | Zombie name data | No changes needed |
| `src/boss_phrases.zig` | Boss phrase data | No changes needed |
| `src/web_root.zig` | Web build entry point | No changes needed |
| `build.zig` | Build graph, test step | No changes needed |

**Test files**: All tests are `test "…" {}` blocks at the bottom of `src/main.zig` (lines 744–1053). New WPM/accuracy tests will extend this same file. No separate test files exist or are needed.

## Patterns to Follow

### Input handling pattern (`src/main.zig:152-177`)

The input loop processes all queued keypresses in a single frame via `while (key > 0)`. Each valid key (ASCII 32–125, within buffer limit) is appended to the `name` buffer and `letter_count` is incremented. After the loop, `typedMatchesAnyEnemy()` is called once per frame to detect mismatches (combo reset).

**Modification needed**: Move the mismatch check _inside_ the while loop so each keypress is individually classified as correct or incorrect per FR-001. The per-key check reuses `typedMatchesAnyEnemy()` which checks `name[0..letter_count]` against all active enemies — since `letter_count` is already incremented before the check, this works correctly for per-character tracking.

### State variable pattern (`src/main.zig:61-80`)

Module-level `var` declarations grouped by domain (input buffer, spawn state, wave state, boss state, score/combo state). New WPM/accuracy state variables follow the same grouping convention, placed as a new block after the score/combo block.

### HUD drawing pattern (`src/main.zig:244-258`)

HUD elements are drawn inside the `if (!is_game_over)` block using `std.fmt.bufPrintZ` into a stack buffer, then `raylib.DrawText` with integer positions. The existing HUD uses:
- Top-center: wave info via `drawCenteredText` (y=10)
- Top-left: score (x=10, y=5, size 24) and combo (x=10, y=35, size 18)

New WPM/accuracy HUD goes top-right (x=700, y=5 and y=30, size 18) — no overlap.

### Reset pattern (`src/main.zig:290-303`)

Game restart clears all state variables inline, then calls domain-specific reset functions (`resetScoreState`, `resetZombies`, `resetBoss`). New metrics state should have its own `resetMetricsState()` function called in the same block.

### Test pattern (`src/main.zig:744-1053`)

Tests save and restore module-level globals via `defer` to avoid test interdependence. Pure-logic tests (like `calculateScore`, `getComboMultiplier`) call the function directly. State-dependent tests (like `typedMatchesAnyEnemy`) save/restore all touched globals.

New tests for `calculateTargetWpm` and `calculateTargetAccuracy` can call these functions directly since they read from module globals that the test controls.

### Smoothing pattern (new, specified by FR-013)

`displayed_value += 0.2 * (target_value - displayed_value)` per frame, without delta-time normalization. Acceptable given the fixed 60 FPS target (auto-resolved decision in spec).

## Decisions

### Circular buffer implementation

- **Decision**: Fixed-size array `[WPM_BUFFER_SIZE]f32` with head index and count, storing `elapsed_time` timestamps.
- **Rationale**: Matches the project's "fixed-size pools, not dynamic lists" constitution principle. No allocator needed. 512 × 4 bytes = 2 KB — negligible.
- **Alternatives considered**: Dynamic array (rejected — unnecessary allocation, violates constitution), linked list (rejected — over-engineered for a fixed-size ring).

### Per-keypress tracking vs per-frame tracking

- **Decision**: Move `typedMatchesAnyEnemy()` check inside the key processing while-loop to track each keypress individually.
- **Rationale**: FR-001 explicitly requires per-keypress tracking. The existing code already increments `letter_count` inside the loop, so `typedMatchesAnyEnemy()` naturally evaluates the state after each key.
- **Alternatives considered**: Per-frame tracking (rejected — doesn't satisfy FR-001 when multiple keys arrive in one frame, though rare at 60 FPS).

### Elapsed time tracking

- **Decision**: Accumulate `raylib.GetFrameTime()` into an `elapsed_time: f32` variable each frame, gated by `!is_game_over`.
- **Rationale**: Matches the spec assumption "wall-clock game time (raylib frame time accumulation)". Same approach as `spawn_timer`. Naturally freezes on game-over since the update gate skips it.
- **Alternatives considered**: Using `std.time` (rejected — spec explicitly says game time, not wall clock).

### WPM/accuracy update timing relative to wave transitions

- **Decision**: WPM and accuracy smoothing updates run every frame where `!is_game_over`, including during wave transitions.
- **Rationale**: Auto-resolved decision in spec says "WPM window continues ticking during transition countdown." Placing the update outside the `!is_transitioning` gate achieves this.
- **Alternatives considered**: Freezing WPM during transitions (rejected — spec explicitly chose to let it decline naturally).

### Where to count correct/incorrect chars for boss typing

- **Decision**: Only count chars in the regular zombie input path. Boss typing already goes through the same `typedMatchesAnyEnemy()` function (which checks boss prefix too), so boss chars are naturally tracked.
- **Rationale**: `typedMatchesAnyEnemy()` at line 713 already checks both regular zombies AND the boss. No separate boss tracking needed.
- **Alternatives considered**: Separate boss character tracking (rejected — would double-count since `typedMatchesAnyEnemy` already covers both).

# Implementation Plan: Live WPM and Accuracy with Character-Based Metrics

**Branch**: `DEATHN-22-live-wpm-and` | **Date**: 2026-05-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/DEATHN-22-live-wpm-and/spec.md`

## Summary

Add real-time WPM (10-second sliding window) and session-wide accuracy percentage to the game HUD. WPM uses a 512-entry circular buffer of correct-character timestamps; accuracy tracks cumulative correct/incorrect keypresses. Both values are smoothed per-frame for readability. All new state, logic, drawing, and tests live in `src/main.zig`, following the existing single-module architecture.

## Technical Context

**Language/Version**: Zig (toolchain-determined, no pinned version)
**Primary Dependencies**: raylib (pinned in `build.zig.zon`)
**Storage**: N/A (in-memory module-level globals only)
**Testing**: Zig built-in test runner (`zig build test`)
**Target Platform**: Native desktop (Linux/macOS/Windows) + wasm32-emscripten
**Project Type**: Single project
**Performance Goals**: 60 FPS fixed frame rate; all new per-frame work is O(n) where n <= 512 (buffer scan)
**Constraints**: No allocations (fixed-size buffer); no new dependencies; no delta-time normalization (fixed FPS)
**Scale/Scope**: ~100 lines of new logic, ~60 lines of new tests, all in one file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Single-module game loop | PASS | All changes in `src/main.zig` |
| C interop walled in `raylib.zig` | PASS | No new `@cImport` calls |
| Named constants for tunables | PASS | `WPM_BUFFER_SIZE`, `WPM_WINDOW_SECONDS`, HUD position constants |
| Paired Init/defer for resources | PASS | No new resource loads |
| Optional pointers via `if (x) \|val\|` | PASS | No new optional pointers |
| Allocator by pointer parameter | PASS | No new allocations |
| Fixed-size pools | PASS | Circular buffer is `[512]f32` — fixed-size, no dynamic allocation |
| Zig test runner only | PASS | Tests are `test "…" {}` blocks in `src/main.zig` |
| Tests in module under test | PASS | Same file |
| No secrets/network | PASS | No external I/O added |
| Bounded input buffers | PASS | Existing input bounds unchanged |
| `zig build` compiles cleanly | VERIFY | Must confirm after implementation |
| Naming conventions | PASS | `snake_case` vars, `camelCase` functions, `SCREAMING_SNAKE_CASE` constants |

**Post-design re-check**: All gates still PASS. No violations, no complexity tracking needed.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-22-live-wpm-and/
├── plan.md              # This file
├── research.md          # Phase 0 output — existing files, patterns, decisions
├── data-model.md        # Phase 1 output — constants, state, formulas
├── spec.md              # Feature specification
└── checklists/          # Existing
```

### Source Code (repository root)

```
src/
├── main.zig             # EXTEND — all new state, logic, HUD drawing, tests
├── raylib.zig           # No changes
├── zombie_names.zig     # No changes
├── boss_phrases.zig     # No changes
└── web_root.zig         # No changes
```

**Structure Decision**: Single-file change in `src/main.zig`. This feature adds ~160 lines (state + logic + HUD + reset + tests) to the existing 1054-line file — well within reasonable single-module size.

## Implementation Phases

### Phase 1: Core Metrics State and Calculation Functions

**Goal**: Add all new state variables and pure calculation functions, with unit tests.

**Changes to `src/main.zig`**:

1. **Add constants** (after line 33, with existing constants):
   - `WPM_BUFFER_SIZE`, `WPM_WINDOW_SECONDS`, `WPM_HUD_X`, `WPM_HUD_Y`, `ACC_HUD_X`, `ACC_HUD_Y`, `METRICS_HUD_SIZE`, `SMOOTHING_FACTOR`

2. **Add state variables** (after line 80, after score/combo state block):
   - `wpm_buffer: [WPM_BUFFER_SIZE]f32` — circular buffer of timestamps
   - `wpm_buffer_head: usize`, `wpm_buffer_count: usize` — buffer management
   - `correct_chars: u32`, `wrong_chars: u32` — session counters
   - `elapsed_time: f32` — accumulated game time
   - `displayed_wpm: f32`, `displayed_accuracy: f32` — smoothed display values

3. **Add calculation functions** (near other helper functions):
   - `recordCorrectTimestamp(time: f32) void` — push timestamp into circular buffer
   - `countCharsInWindow(current_time: f32) u32` — count buffer entries within last 10 seconds
   - `calculateTargetWpm() f32` — compute raw WPM from sliding window or early-game formula
   - `calculateTargetAccuracy() f32` — compute raw accuracy percentage
   - `updateMetrics() void` — advance elapsed time, compute targets, apply smoothing
   - `resetMetricsState() void` — zero all metrics state (called on restart)

4. **Add unit tests** (at bottom of file, extending existing test block):
   - `test "WPM sliding window — 60 chars in 10 seconds"` — expects 72
   - `test "WPM early game — 12 chars in 5 seconds"` — expects 29
   - `test "accuracy — 100 correct 4 incorrect"` — expects 96
   - `test "zero input — WPM 0 accuracy 100"` — WPM=0, Acc=100
   - `test "resetMetricsState clears all metrics"` — verify all fields reset
   - `test "circular buffer wraps correctly"` — verify head/count after overflow

**Verification**: `zig build test` passes (on a machine with GL/X11 libs).

### Phase 2: Input Integration

**Goal**: Hook metrics tracking into the existing input handling path.

**Changes to `src/main.zig`**:

1. **Modify input loop** (lines 158-167 in `frame()`):
   - Inside the `while (key > 0)` loop, after `letter_count += 1`, add per-keypress classification:
     - If `typedMatchesAnyEnemy()` — call `recordCorrectTimestamp(elapsed_time)` and `correct_chars += 1`
     - Else — `wrong_chars += 1` and `combo_count = 0`

2. **Remove post-loop mismatch check** (lines 174-176):
   - Delete `if (typed_this_frame and !typedMatchesAnyEnemy()) { combo_count = 0; }` — this logic is now handled per-keypress inside the loop.

3. **Add per-frame metrics update** (after the `is_transitioning` countdown block, ~line 229, gated by `!is_game_over`):
   - Call `updateMetrics()` which advances `elapsed_time` and applies smoothing.

**Behavioral note**: Moving `typedMatchesAnyEnemy()` inside the loop changes the combo reset from per-frame to per-keypress. Since `combo_count = 0` is idempotent, multiple wrong keys in one frame behave identically to the original single-frame check.

### Phase 3: HUD Display

**Goal**: Render WPM and accuracy on the HUD.

**Changes to `src/main.zig`**:

1. **Add WPM/accuracy drawing** inside the `if (!is_game_over)` block (after existing combo HUD, ~line 257):
   - Format `displayed_wpm` as `"WPM {d}"` (rounded to integer) at position `(WPM_HUD_X, WPM_HUD_Y)`, size `METRICS_HUD_SIZE`, color `DARKGRAY`
   - Format `displayed_accuracy` as `"Acc {d}%"` (rounded to integer) at position `(ACC_HUD_X, ACC_HUD_Y)`, size `METRICS_HUD_SIZE`, color `DARKGRAY`

### Phase 4: Reset Integration

**Goal**: Ensure all metrics state resets on game restart.

**Changes to `src/main.zig`**:

1. **Add `resetMetricsState()` call** in the game-over restart block (line 300, alongside `resetScoreState()`).

**Verification**: After restart, HUD shows "WPM 0" and "Acc 100%".

## Testing Strategy

All tests are `test "…" {}` blocks in `src/main.zig`, extending the existing test section (currently lines 744-1053).

**Unit tests** (Phase 1):
- WPM calculation: 4 reference cases from FR-017
- Accuracy calculation: correct formula and zero-denominator edge case
- Circular buffer: wrap-around behavior, count cap at `WPM_BUFFER_SIZE`
- Reset: all fields return to initial values

**Manual tests** (Phase 3, noted in PR):
- Start game, type zombie names — WPM climbs smoothly, accuracy starts at 100%
- Type wrong characters — accuracy drops, combo resets
- Stop typing for 10s — WPM declines toward 0
- Game-over — WPM and accuracy freeze
- Restart — WPM shows 0, accuracy shows 100%
- Wave transition — WPM declines naturally, accuracy persists

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Buffer scan (512 entries per frame) causes frame drop | Very low | Low | 512 float comparisons is negligible at 60 FPS; profile if needed |
| `typedMatchesAnyEnemy()` called per key instead of per frame adds overhead | Very low | Low | Function is already O(zombies) and zombies <= 100; at most 2-3 calls per frame at extreme typing speed |
| Smoothing looks wrong at non-60 FPS | Low | Low | Spec explicitly accepts this; add delta-time normalization only if variable FPS is added later |
| `f32` precision drift in `elapsed_time` over very long sessions | Very low | Very low | At 60 FPS, `f32` loses 1-second precision after ~4.6 hours; acceptable for a typing game session |

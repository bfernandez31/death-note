# Implementation Plan: Per-kill scoring formula with combo and HUD

**Branch**: `DEATHN-21-per-kill-scoring` | **Date**: 2026-05-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/DEATHN-21-per-kill-scoring/spec.md`

## Summary

Add a per-kill scoring system with combo multipliers and visual feedback to the zombie typing game. Each kill earns points based on a formula incorporating name length, vertical position, enemy type, and a combo multiplier that rewards consecutive kills. The player sees a persistent HUD (score + combo with color tiers) and floating "+score" popups at each kill location. All new logic lives in `src/main.zig` as new module-level state, pure functions, and extensions to existing update/draw routines — no new files, no new dependencies, no architectural changes.

## Technical Context

**Language/Version**: Zig (0.16, determined by installed toolchain)
**Primary Dependencies**: raylib (pinned commit `52f2a10db610d0e9f619fd7c521db08a876547d0`)
**Storage**: N/A (no persistence; score resets on restart)
**Testing**: Zig built-in test runner (`zig build test`)
**Target Platform**: Native (Linux/macOS/Windows) + wasm32-emscripten
**Project Type**: Single project
**Performance Goals**: 60 FPS (existing constraint; new work adds O(1) per-frame cost)
**Constraints**: Fixed 800×450 window, no network, no file I/O beyond asset loads
**Scale/Scope**: Single-player local game, single source module (`src/main.zig`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| CP-1 | Single-module game loop | PASS | All changes extend `src/main.zig` in place |
| CP-2 | C interop walled off in `src/raylib.zig` | PASS | No new `@cImport` calls |
| CP-3 | Named constants for tunables | PASS | All new magic numbers promoted to `const` (see data-model.md) |
| CP-4 | Paired Init/defer Close for resources | PASS | No new resource loads |
| CP-5 | Optional pointers unwrapped with `if (x) \|val\|` | PASS | Popup pool uses value array (no optional pointers needed) |
| CP-6 | Allocator passed by pointer parameter | PASS | No new allocations — popup pool is a stack array |
| CP-7 | Fixed-size pools, not dynamic lists | PASS | Popup pool is `[MAX_POPUPS]ScorePopup` with circular index |
| TS-1 | Zig built-in test runner | PASS | New tests are `test` blocks in `src/main.zig` |
| TS-3 | Pure logic has tests | PASS | `calculateScore`, `getComboMultiplier`, mismatch detection all testable |
| TS-4 | Manual-test note for rendering | PASS | PR will include manual-test note for HUD and popups |
| TS-5 | Deterministic tests | PASS | No randomness in scoring/combo logic |
| SP-1 | No secrets, no network | PASS | No new I/O |
| SP-2 | Bounded input buffers | PASS | HUD text uses stack-allocated `bufPrintZ` buffers (existing pattern) |
| CQ-1 | `zig build` is the gate | PASS | |
| CQ-2 | Idiomatic error handling | PASS | `calculateScore` is pure (no errors); popup spawn is infallible |
| CQ-3 | Naming discipline | PASS | Functions: `camelCase`; constants: `SCREAMING_SNAKE_CASE`; types: `PascalCase` |
| GA-5 | Agent authority limits | PASS | No dependency changes, no network, no defer removal |

**Post-Phase-1 re-check**: All gates still PASS. No new violations introduced by the data model or design decisions.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-21-per-kill-scoring/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
└── spec.md              # Feature specification (input)
```

### Source Code (repository root)

```
src/
├── main.zig           # EXTEND: scoring state, combo logic, popup pool, HUD, mismatch detection
├── raylib.zig         # No change
├── zombie_names.zig   # No change
├── boss_phrases.zig   # No change
└── web_root.zig       # No change
```

**Structure Decision**: Single-module extension of `src/main.zig`. The scoring system touches multiple game-loop phases (input, update, draw, reset) and shares state with existing zombie/boss/wave systems. Splitting it into a separate module would require exporting 10+ globals and functions, adding coupling without reducing complexity. This matches constitution CP-1 ("extend that structure in place").

## Complexity Tracking

No constitution violations — this section is intentionally empty.

## Implementation Phases

### Phase A: Core scoring and combo logic (pure functions + state)

**Files modified**: `src/main.zig`

1. **Add constants** (top of module, after existing constants):
   - `MAX_POPUPS = 32`, `POPUP_DURATION: f32 = 0.5`, `POPUP_RISE_PX: f32 = 30.0`
   - `SCORE_HUD_X/Y`, `COMBO_HUD_X/Y`, font sizes, colors
   - `BOSS_TYPE_MULTIPLIER: f32 = 3.0`, `STANDARD_TYPE_MULTIPLIER: f32 = 1.0`
   - `POPUP_FONT_SIZE: c_int = 20`

2. **Add `ScorePopup` struct** (after `Zombie` struct definition):
   ```zig
   const ScorePopup = struct { x: f32, y: f32, points: u64, timer: f32, active: bool };
   ```

3. **Add module-level state** (after existing game state variables):
   - `var score: u64 = 0;`
   - `var combo_count: u32 = 0;`
   - `var popups: [MAX_POPUPS]ScorePopup = [_]ScorePopup{.{ .x = 0, .y = 0, .points = 0, .timer = 0, .active = false }} ** MAX_POPUPS;`
   - `var popup_next: usize = 0;`

4. **Add `getComboMultiplier` function**:
   - Input: `combo: u32` → Output: `u64`
   - Tier lookup: 0–4→1, 5–9→2, 10–14→3, 15–19→4, 20+→5

5. **Add `calculateScore` function**:
   - Input: `name_len: usize, y_pos: f32, is_boss: bool, combo: u32` → Output: `u64`
   - Formula: `@intFromFloat(@round((@as(f32, @floatFromInt(name_len)) * 10.0 + @round(100.0 * (y_pos / screen_height))) * type_mult)) * getComboMultiplier(combo)`

6. **Add `spawnPopup` function**:
   - Input: `x: f32, y: f32, points: u64`
   - Write to `popups[popup_next]`, set active/timer, advance circular index

7. **Add `typedMatchesAnyEnemy` function**:
   - Input: none (reads globals `name`, `letter_count`, `zombies`, `boss`, `boss_phrase_len`)
   - Returns `true` if `letter_count == 0` or the typed text is a prefix of any active zombie name or boss phrase
   - Used for combo mismatch detection

### Phase B: Integration into game loop

**Files modified**: `src/main.zig`

1. **Extend `updateZombies`** (at the kill site, ~line 365):
   - Before `allocator.destroy(zomb)`: capture `zomb.x`, `zomb.y`, compute name length
   - Calculate score: `const points = calculateScore(name_len, zomb.y, false, combo_count);`
   - `score += points;`
   - `combo_count += 1;`
   - `spawnPopup(zomb.x, zomb.y, points);`

2. **Extend `updateBoss`** (at the kill site, ~line 484):
   - Before `allocator.destroy(b)`: capture `b.x`, `b.y`
   - Calculate score: `const points = calculateScore(boss_phrase_len, b.y, true, combo_count);`
   - `score += points;`
   - `combo_count += 1;`
   - `spawnPopup(b.x, b.y, points);`

3. **Add combo mismatch check in `frame()`** (after the character-input loop, before `updateZombies`):
   - Track whether any new character was typed (flag set inside the input loop)
   - If flag is set and `!typedMatchesAnyEnemy()`: `combo_count = 0;`

4. **Add combo reset on wave transition** (line 179, when `is_transitioning = true`):
   - `combo_count = 0;`

5. **Extend game restart handler** (lines 238–250):
   - Add `score = 0; combo_count = 0; popup_next = 0;`
   - Deactivate all popups: `for (&popups) |*p| p.active = false;`

6. **Add popup timer update** in the update phase of `frame()` (after `updateBoss`, outside the `!is_game_over` gate so popups fade naturally during game-over):
   - For each active popup: decrement `timer` by `raylib.GetFrameTime()`; if `timer <= 0`, set `active = false`

### Phase C: HUD and popup rendering

**Files modified**: `src/main.zig`

1. **Add score HUD** in the draw section (inside the `!is_game_over` block, after existing wave HUD):
   - Format: `"Score: {d}"` using `std.fmt.bufPrintZ` into a `[32]u8` buffer
   - Draw at `(SCORE_HUD_X, SCORE_HUD_Y)`, font size `SCORE_HUD_SIZE`, color `raylib.DARKGREEN`

2. **Add combo HUD** (below score HUD):
   - Format: `"Combo: {d} x{d}"` using `std.fmt.bufPrintZ`
   - Draw at `(COMBO_HUD_X, COMBO_HUD_Y)`, font size `COMBO_HUD_SIZE`
   - Color selection: combo < 5 → `raylib.DARKGRAY`, 5–14 → `raylib.ORANGE`, 15+ → `raylib.RED`

3. **Add `drawPopups` function**:
   - For each active popup:
     - Compute progress: `1.0 - (timer / POPUP_DURATION)`
     - Draw Y: `y - (POPUP_RISE_PX × progress)`
     - Alpha: `@intFromFloat((timer / POPUP_DURATION) × 255.0)`
     - Color: `raylib.Color{ .r = 255, .g = 203, .b = 0, .a = alpha }` (GOLD with fading alpha)
     - Format text: `"+{d}"` via `bufPrintZ`
     - Draw with `raylib.DrawText`

4. **Call `drawPopups()`** in the draw section alongside `drawZombies()` and `drawBoss()` (in the active-gameplay else branch)

5. **Add score to game-over screen** (after existing wave/WPM display):
   - Format: `"Score: {d}"` using `bufPrintZ`
   - Draw centered below existing game-over info using `drawCenteredText`

### Phase D: Tests

**Files modified**: `src/main.zig`

1. **Test `calculateScore` with all four reference cases** (FR-013):
   - Case 1: `calculateScore(4, 0, false, 0)` → 40
   - Case 2: `calculateScore(4, 0, false, 20)` → 200
   - Case 3: `calculateScore(4, 440, false, 0)` → 138
   - Case 4: `calculateScore(19, 300, true, 10)` → 2313

2. **Test `getComboMultiplier` at all tier boundaries**:
   - combo 0→x1, 4→x1, 5→x2, 9→x2, 10→x3, 14→x3, 15→x4, 19→x4, 20→x5, 100→x5

3. **Test combo increment and reset logic**:
   - Verify combo increments by 1 (unit: test the logic pattern)
   - Verify mismatch detection returns false when typed text doesn't match any enemy

4. **Test popup pool circular recycling**:
   - Spawn 33 popups, verify slot 0 is overwritten (popup_next wraps)

5. **Test score reset on game restart**:
   - Verify score and combo reset to 0 (unit: test the reset logic pattern)

## Testing Strategy

**Framework**: Zig built-in test runner (`zig build test`)

**Test location**: All new tests as `test "..." { ... }` blocks at the bottom of `src/main.zig`, following the existing 12 test blocks (lines 613–827).

| Test | Type | What it covers | Extends existing? |
|------|------|----------------|-------------------|
| Score formula reference cases | Unit | FR-013: all 4 expected values | New |
| Combo multiplier tiers | Unit | FR-004: all 5 tier boundaries | New |
| Combo increment pattern | Unit | FR-002: +1 per kill | New |
| Mismatch detection | Unit | FR-003: prefix matching logic | New |
| Popup pool recycling | Unit | FR-009: circular overwrite at 32 | New |
| Score/combo reset | Unit | FR-011: zero on restart | New |
| HUD rendering | Manual | FR-005/006/007: visual verification | N/A |
| Popup animation | Manual | FR-008: rise + fade visual | N/A |
| Game-over score display | Manual | FR-012: score on game-over screen | N/A |

**Manual test note** (for PR description): After implementation, run `zig build run` and verify:
1. Score HUD appears at top-left, updates on each kill
2. Combo HUD appears below score, color changes at 5/15 kills
3. Floating "+score" popups appear at kill positions, rise and fade
4. Score and combo reset on game restart
5. Score is displayed on game-over screen
6. Combo resets when typing a character that doesn't match any enemy
7. Combo resets at wave transition
8. Backspace does not reset combo

## Artifacts Generated

| Artifact | Path | Description |
|----------|------|-------------|
| Research | `specs/DEATHN-21-per-kill-scoring/research.md` | Unknowns resolved, existing files, patterns |
| Data Model | `specs/DEATHN-21-per-kill-scoring/data-model.md` | Entity definitions, scoring formula, relationships |
| Plan | `specs/DEATHN-21-per-kill-scoring/plan.md` | This file |

No contracts or workflows generated — the game has no external interfaces or internal process automation.

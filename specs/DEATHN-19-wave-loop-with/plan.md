# Implementation Plan: Wave Loop with Per-Wave Difficulty Table

**Branch**: `DEATHN-19-wave-loop-with` | **Date**: 2026-05-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/DEATHN-19-wave-loop-with/spec.md`

## Summary

Add a wave-based progression system to the zombie typing game. Waves 1–15 follow an explicit difficulty table controlling spawn delay, fall speed, and pool size. Waves 16+ scale endlessly. A 3-second transition countdown separates waves. A HUD displays wave number, target WPM, and kill progress. The game-over screen shows wave reached and required WPM. All changes are in `src/main.zig` — no new files, no new dependencies.

## Technical Context

**Language/Version**: Zig (0.16.0+ per build.zig.zon)
**Primary Dependencies**: raylib (pinned at commit 52f2a10d)
**Storage**: N/A (no persistence)
**Testing**: Zig built-in test runner (`zig build test`)
**Target Platform**: Native (Linux/macOS/Windows) + wasm32-emscripten
**Project Type**: Single-module game
**Performance Goals**: 60 FPS maintained
**Constraints**: All gameplay in `src/main.zig`, no new dependencies, no network/file I/O
**Scale/Scope**: Single-player local game, ~434 lines of Zig

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Single-module game loop | PASS | All changes in `src/main.zig` |
| C interop walled off in raylib.zig | PASS | No new `@cImport` calls |
| Named constants for tunables | PASS | `WAVE_TABLE`, `WAVE_TRANSITION_DURATION` at module top |
| Paired Init/defer Close | PASS | No new resource loads |
| Optional pointer unwrapping with `if` | PASS | Existing zombie iteration unchanged |
| Allocator passed by pointer | PASS | `spawnZombie` signature unchanged |
| Fixed-size pools | PASS | Using existing `[MAX_ZOMBIES]?*Zombie` pool |
| Test location in module under test | PASS | New tests added in `src/main.zig` |
| No secrets, no network | PASS | No I/O changes |
| Bounded input buffers | PASS | Input handling unchanged |
| `zig build` gate | PASS | Must compile cleanly |
| Naming discipline | PASS | `snake_case` vars, `SCREAMING_SNAKE_CASE` consts, `camelCase` fns, `PascalCase` types |

**Post-Phase-1 Re-check**: All principles still satisfied. The `WaveConfig` struct follows `PascalCase` type convention. The `getWaveConfig` function follows `camelCase` convention. The `WAVE_TABLE` constant follows `SCREAMING_SNAKE_CASE`. No constitution violations.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-19-wave-loop-with/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
└── spec.md              # Feature specification
```

### Source Code (repository root)

```
src/
├── main.zig             # MODIFY: add wave state, difficulty table, HUD, transition
├── raylib.zig           # No change
├── zombie_names.zig     # No change
└── web_root.zig         # No change
```

**Structure Decision**: Single-module game. All wave logic goes into `src/main.zig` alongside existing gameplay code. No new files needed — the feature is an extension of the existing game loop, not a new module.

## Complexity Tracking

No constitution violations. Table intentionally left empty.

## Implementation Phases

### Phase 1: Data Foundation — WaveConfig + difficulty table

**Files**: `src/main.zig`

**Changes**:
1. Add `WaveConfig` struct definition after the `Zombie` struct (around line 33)
2. Add `WAVE_TABLE` compile-time constant array (15 entries matching the spec table)
3. Add `WAVE_TRANSITION_DURATION: f32 = 3.0` constant
4. Add `getWaveConfig(wave: u32) WaveConfig` function that indexes `WAVE_TABLE` for waves 1–15 and computes the scaling formula for 16+
5. Remove `const ZOMBIE_FALL_SPEED: f32 = 0.5` (line 12)
6. Remove `const spawn_delay: f32 = 3.0` (line 19)

**Tests to add**:
- `"getWaveConfig returns correct values for wave 1"` — verify all four fields
- `"getWaveConfig returns correct values for wave 15"` — boundary of explicit table
- `"getWaveConfig scales correctly for wave 16+"` — verify pool_size=35 for wave 16, pool_size=43 for wave 20; verify WPM/speed/delay are capped

**Patterns**: follows `src/main.zig:7-12` (named constants at module top), `PascalCase` for the struct

### Phase 2: Wave State Variables

**Files**: `src/main.zig`

**Changes**:
1. Add module-level globals after `is_game_over` (line 22):
   - `var current_wave: u32 = 1;`
   - `var wave_kills: u32 = 0;`
   - `var wave_spawned: u32 = 0;`
   - `var is_transitioning: bool = false;`
   - `var transition_timer: f32 = 0.0;`
2. Update `spawnZombie` (line 326): change `.speed = ZOMBIE_FALL_SPEED` to `.speed = getWaveConfig(current_wave).fall_speed`
3. Update spawn delay check (line 99): change `spawn_timer >= spawn_delay` to `spawn_timer >= getWaveConfig(current_wave).spawn_delay`

**Patterns**: follows `src/main.zig:14-22` (module-level `var` declarations with initial values)

### Phase 3: Wave Lifecycle — Spawn Tracking + Completion Detection

**Files**: `src/main.zig`

**Changes**:
1. In spawn logic (around line 103-104): after successful spawn, increment `wave_spawned += 1`. Gate spawning on `wave_spawned < getWaveConfig(current_wave).pool_size` — stop spawning once pool is exhausted for this wave.
2. In `updateZombies` kill detection (around line 248): after marking zombie inactive, increment `wave_kills += 1`.
3. After `updateZombies()` call (line 108): check wave completion condition:
   ```
   const cfg = getWaveConfig(current_wave);
   if (wave_kills >= cfg.pool_size and wave_spawned >= cfg.pool_size) {
       is_transitioning = true;
       transition_timer = WAVE_TRANSITION_DURATION;
   }
   ```
4. Gate the entire update block: change `if (!is_game_over)` to `if (!is_game_over and !is_transitioning)` — during transition, no input, no spawning, no zombie movement.

**Tests to add**:
- `"wave completes when kills equals pool size"` — verify the completion condition logic

### Phase 4: Wave Transition Countdown

**Files**: `src/main.zig`

**Changes**:
1. In the `frame` function, add a transition update block (after the `!is_game_over and !is_transitioning` block, before draw):
   ```
   if (is_transitioning) {
       transition_timer -= raylib.GetFrameTime();
       if (transition_timer <= 0) {
           current_wave += 1;
           wave_kills = 0;
           wave_spawned = 0;
           spawn_timer = 0.0;
           is_transitioning = false;
           resetZombies(ctx.allocator);
       }
   }
   ```
2. In the draw phase, add transition screen rendering. Inside the existing `if (is_game_over) { ... } else { ... }` block, expand the else to check `is_transitioning`:
   - If transitioning: draw "WAVE {n} — {wpm} WPM challenge — {countdown}..." centered on screen
   - Countdown displays as integer ceiling of `transition_timer` (3, 2, 1)
   - No zombies drawn during transition (they were cleared by `resetZombies`)

**Patterns**: follows `src/main.zig:128-142` (game-over screen rendering with `DrawText` and centered positioning)

### Phase 5: HUD Display

**Files**: `src/main.zig`

**Changes**:
1. In the draw phase, after `ClearBackground` (line 114) and before the textbox drawing (line 116), add HUD rendering:
   - Format string: "WAVE {current_wave} — {target_wpm} WPM — {wave_kills} / {pool_size}"
   - Use `std.fmt.bufPrint` into a stack buffer to build the text, then pass to `raylib.DrawText`
   - Position: centered horizontally at y=10, font size 20, DARKGRAY color
   - Use `raylib.MeasureText` to compute width for centering
2. HUD renders during both playing and transitioning states (not during game-over)

### Phase 6: Game-Over Screen Update

**Files**: `src/main.zig`

**Changes**:
1. Replace game-over text (lines 130-131):
   - Line 1: "GAME OVER" (keep as-is, centered, 40pt, RED)
   - Line 2: "Wave reached: {current_wave}" (new, 20pt, GRAY)
   - Line 3: "Required WPM: {target_wpm}" (new, 20pt, GRAY)
   - Line 4: "Press ENTER to Restart" (keep, 20pt, GRAY)
   - Use `std.fmt.bufPrint` for dynamic text
2. Update restart logic (lines 134-141) to also reset wave state:
   - `current_wave = 1`
   - `wave_kills = 0`
   - `wave_spawned = 0`
   - `is_transitioning = false`
   - `transition_timer = 0.0`

### Phase 7: Integration Verification

**Manual testing checklist** (no automated GUI tests per constitution):
1. `zig build test` — all unit tests pass
2. `zig build run` — start game, verify wave 1 parameters feel correct (slow spawns, slow fall)
3. Type all 5 names in wave 1 → verify 3-second countdown appears with "WAVE 2 — 18 WPM challenge"
4. Verify wave 2 spawns faster (4.0s delay) with faster zombies (0.6 speed)
5. Let a zombie reach the bottom → verify game-over shows wave number and WPM
6. Press ENTER → verify restart at wave 1
7. Verify HUD updates kill counter in real time
8. `zig build web` — verify WASM build still compiles

## Testing Strategy

**Framework**: Zig built-in test runner (`zig build test`)
**Location**: All tests in `src/main.zig` (reachable from root test file per constitution)

### Unit Tests (new)

| Test | Covers | FR |
|------|--------|----|
| `"getWaveConfig returns correct values for wave 1"` | Table lookup boundary | FR-001 |
| `"getWaveConfig returns correct values for wave 15"` | Table lookup end | FR-001 |
| `"getWaveConfig scales correctly for wave 16+"` | Endless scaling formula | FR-015 |
| `"wave completes when kills equals pool size"` | Completion detection | FR-005 |

### Existing Tests (unchanged)

| Test | Still Valid |
|------|------------|
| `"name match equality"` | Yes — kill matching logic unchanged |
| `"input buffer bounds"` | Yes — input handling unchanged |
| `"frame index wraps after ZOMBIE_FRAME_COUNT"` | Yes — animation unchanged |

### Manual Tests (required per constitution)

Any PR changing rendering, input, or audio must include a manual-test note. The Phase 7 checklist above serves as the manual test plan.

## Dependencies and Risks

| Risk | Mitigation |
|------|------------|
| `std.fmt.bufPrint` for HUD text — must null-terminate for raylib's `DrawText` | Use a buffer of sufficient size and append `\x00` after formatting, or use `bufPrintZ` if available |
| Wave transition clears zombies but some may still be allocated | `resetZombies` already handles full deallocation; called at transition end |
| Emscripten build uses `GetFrameTime()` which may differ from 1/60 | Already used for `spawn_timer`; wave transition timer uses same mechanism |
| `MeasureText` with runtime-formatted C string for HUD centering | Ensure null-termination of the formatted buffer before passing to raylib |

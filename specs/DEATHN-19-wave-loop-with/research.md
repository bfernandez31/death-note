# Research: Wave Loop with Per-Wave Difficulty Table

**Branch**: `DEATHN-19-wave-loop-with` | **Date**: 2026-05-16

## Existing Files

| File | Covers | Action |
|------|--------|--------|
| `src/main.zig` | Game loop, zombie lifecycle, input, rendering, game-over, all module-level state | **Extend** — add wave state machine, difficulty table, HUD, transition screen, parameterized spawning |
| `src/zombie_names.zig` | Static array of 49 zombie names | **No change** |
| `src/raylib.zig` | C interop wrapper for raylib | **No change** |
| `src/web_root.zig` | Emscripten entry point | **No change** |
| `build.zig` | Build graph, test step, web step | **No change** |
| `build.zig.zon` | Package manifest | **No change** |

### Existing Test Blocks (in `src/main.zig`)

| Line | Test | Relevance |
|------|------|-----------|
| 349–360 | `"name match equality"` | Still valid; no change needed |
| 363–419 | `"input buffer bounds"` | Still valid; no change needed |
| 422–433 | `"frame index wraps after ZOMBIE_FRAME_COUNT"` | Still valid; no change needed |

New tests should be added in `src/main.zig` for: difficulty table lookup, wave completion logic, wave advancement, endless scaling formula.

## Patterns to Follow

### Error handling: allocator + errdefer (`src/main.zig:313-337`)

`spawnZombie` uses `try allocator.create(Zombie)` with `errdefer allocator.destroy(new_zombie)` on the next line. Any new allocation sites (none expected for this feature) must follow this pattern.

### State management: module-level globals (`src/main.zig:14-22, 36-39`)

All mutable game state is module-level `var` declarations. The wave state (current wave number, kills count, transition timer, spawned count) should follow this pattern — declared alongside `is_game_over`, `spawn_timer`, etc.

### Tunable constants (`src/main.zig:7-12, 41-47`)

Compile-time constants use `SCREAMING_SNAKE_CASE` and live at the top of the module. The difficulty table should be a `const` array of structs at module level. The current `const spawn_delay: f32 = 3.0` and `const ZOMBIE_FALL_SPEED: f32 = 0.5` will be replaced by wave-dependent lookups.

### Game loop gating (`src/main.zig:75`)

The update phase is gated by `if (!is_game_over)`. The wave transition state should add a second gate: updates skip when `is_transitioning` is true (no spawning, no zombie movement, no input processing).

### Spawn control (`src/main.zig:96-105`)

Spawn timer increments by `raylib.GetFrameTime()` and resets to 0 on successful spawn. The spawn delay comparison (`spawn_timer >= spawn_delay`) must switch from the fixed constant to a per-wave value looked up from the difficulty table.

### Zombie speed assignment (`src/main.zig:326`)

Currently hardcoded: `.speed = ZOMBIE_FALL_SPEED`. Must change to use the current wave's `fall_speed` value from the difficulty table.

### Game-over and restart (`src/main.zig:128-142`)

Restart clears `is_game_over`, `letter_count`, `spawn_timer`, and calls `resetZombies()`. Must also reset all wave state: `current_wave = 1`, `wave_kills = 0`, `wave_spawned = 0`, `is_transitioning = false`, `transition_timer = 0`.

### Draw phase structure (`src/main.zig:111-155`)

Drawing always executes regardless of game state. The HUD should be drawn after `ClearBackground` and before the textbox. The transition screen should be drawn inside the `if (is_game_over) … else …` block as a third branch.

## Decisions

### Decision: Difficulty table as compile-time struct array

- **Decision**: Use a `const` array of `WaveConfig` structs for waves 1-15, with a function for wave 16+ scaling
- **Rationale**: Zig's comptime evaluation makes a `const` array zero-cost. A function handles the unbounded wave 16+ case cleanly. Matches the project convention of named constants at module scope.
- **Alternatives considered**: (1) Runtime HashMap — unnecessary overhead, table is fixed. (2) Inline formulas only — harder to verify against the spec table. (3) Separate config file — no file I/O in this project.

### Decision: Wave state as module-level globals (not a struct)

- **Decision**: Add `current_wave`, `wave_kills`, `wave_spawned`, `is_transitioning`, `transition_timer` as module-level `var` declarations alongside existing globals
- **Rationale**: Consistent with how `is_game_over`, `spawn_timer`, and `letter_count` are managed. The game is single-module by constitution; introducing a state struct would be premature abstraction.
- **Alternatives considered**: (1) WaveState struct — cleaner grouping but breaks consistency with existing state. (2) Separate wave module — constitution says "extend main.zig in place" for gameplay features.

### Decision: Three-state game loop (playing, transitioning, game_over)

- **Decision**: Add `is_transitioning: bool` alongside `is_game_over`. The update phase checks both: `if (!is_game_over and !is_transitioning)` for normal gameplay. Transition has its own timer decrement logic.
- **Rationale**: Minimal change to existing control flow. The transition state is inherently different from game-over (auto-advances vs waits for input).
- **Alternatives considered**: (1) Enum state machine (`GameState = enum { playing, transitioning, game_over }`) — cleaner semantically, but requires refactoring all existing `is_game_over` checks. Could be done in a future cleanup.

### Decision: HUD rendering position

- **Decision**: Draw HUD text centered at y=10, font size 20, DARKGRAY — exactly as specified in FR-009
- **Rationale**: Spec is explicit. The textbox is at y=400, so y=10 is non-overlapping.
- **Alternatives considered**: None needed; spec is unambiguous.

### Decision: Wave completion detection

- **Decision**: Track `wave_spawned` (incremented on each spawn) and `wave_kills` (incremented on each kill). Wave is complete when `wave_kills >= current_pool_size` AND `wave_spawned >= current_pool_size` (all spawned and all killed).
- **Rationale**: FR-005 states "complete only when all zombies in the pool have been spawned AND killed." Tracking both counters independently handles the edge case where kills outpace spawns.
- **Alternatives considered**: (1) Only track kills — wouldn't handle spawns still pending. (2) Count active zombies = 0 — doesn't confirm all were spawned.

### Decision: Spawn delay source change

- **Decision**: Replace `const spawn_delay: f32 = 3.0` with a function `fn getWaveConfig(wave: u32) WaveConfig` that returns the appropriate config. `spawn_timer` comparison changes from the constant to `getWaveConfig(current_wave).spawn_delay`.
- **Rationale**: Single lookup function keeps the wave-dependent values co-located. Avoids storing redundant copies of config in mutable state.
- **Alternatives considered**: (1) Cache current wave config in a mutable global — redundant since lookup is O(1) array index.

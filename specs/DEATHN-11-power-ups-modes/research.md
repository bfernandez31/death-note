# Research: Power-ups, Game Modes & Main Menu

**Branch**: `DEATHN-11-power-ups-modes` | **Date**: 2026-05-17

## Existing Files

### Source files to modify

| File | Covers | Action |
|------|--------|--------|
| `src/main.zig` | Game loop, update/draw, input, state machine, HUD, all gameplay logic | Extend: add `GameScreen` enum, pause/menu states, power-up logic, zen mode branching |
| `src/highscore.zig` | Single-mode high score persistence (native + web) | Extend: parameterize by `GameMode`, add zen record variant, backward-compatible migration |
| `src/zombie_types.zig` | `ZombieType`, speed multipliers, spawn/name weight tables | Extend: add `PowerUpType` enum (co-located with zombie types for shared access) |

### Source files unchanged

| File | Covers | Reason |
|------|--------|--------|
| `src/name_lists.zig` | Name selection, trap clusters | No changes needed; selectName API unaffected |
| `src/boss_phrases.zig` | Boss phrase array | Unchanged |
| `src/raylib.zig` | C interop wrapper | Unchanged |
| `src/web_root.zig` | WASM entry point | Unchanged |
| `src/zombie_names.zig` | Legacy name array (superseded) | Unchanged |

### Build files

| File | Action |
|------|--------|
| `build.zig` | No changes; test step already discovers all modules transitively from `src/main.zig` |
| `build.zig.zon` | No changes; no new dependencies |

### Test files

| File | Action |
|------|--------|
| `src/main.zig` (test blocks) | Extend: add tests for GameScreen transitions, power-up state, pause logic, zen mode config, per-mode high scores |
| `src/highscore.zig` (test blocks) | Extend: add tests for multi-mode file naming, disk size changes, backward compatibility |
| `src/zombie_types.zig` (test blocks) | Extend: add tests for PowerUpType enum if placed here |

### Asset files

| File | Action |
|------|--------|
| `assets/` | No new assets required; power-up icons use procedural text glyphs (CRT aesthetic) |

## Patterns to Follow

### State management pattern (src/main.zig:144-186)

Game state is tracked via module-level boolean flags (`is_game_over`, `is_transitioning`, `is_dying`). The frame function gates update/draw logic on these flags (line 287: `if (!is_game_over and !is_transitioning and !is_dying)`). New states (menu, paused, zen_select) follow this same gating pattern.

**Decision**: Replace ad-hoc booleans with a `GameScreen` enum (`main_menu`, `wpm_select`, `playing`, `paused`, `game_over`) for the new states. The existing boolean-gated branches map cleanly to enum arms. This is justified because the feature adds 3+ new states — booleans would create a combinatorial explosion of impossible states.

### Resource lifetime pattern (src/main.zig:566-578)

Every `raylib.Load*` is paired with `defer raylib.Unload*` on the next line. No new asset loads are planned (power-up icons are drawn procedurally), so this pattern is preserved by not introducing new loads.

### Allocator threading pattern (src/main.zig:725, 856, 950, 993, 1002)

All functions that allocate/free take `allocator: *std.mem.Allocator` as their first parameter. New functions that manage power-up state or zombie lifecycle must follow this — no reaching into `std.heap.page_allocator` from helpers.

### Error handling pattern (src/main.zig:769-770)

Allocation uses `try` + `errdefer allocator.destroy(...)` for cleanup on partial failure. `spawnZombie` returns `!bool`; callers use `catch false`. New spawn/creation functions must follow this pattern.

### High score persistence pattern (src/highscore.zig:28-41, 43-67, 99-107)

Cross-platform dispatcher: `load()` and `save()` branch at comptime on `is_web`. Native uses `std.c.fopen/fread/fwrite` with a fixed-size binary format (`DISK_SIZE = 17` bytes). Web uses `localStorage` via `emscripten_run_script` with JSON encoding. Both paths clamp untrusted values before downcast.

**Pattern for multi-mode**: Parameterize filename/localStorage key by mode. Native: `highscore.dat` (survival, backward-compatible) and `highscore-zen.dat`. Web: `death-note.highscore` (survival) and `death-note.highscore.zen`.

### Input handling pattern (src/main.zig:291-318)

Input is processed in the frame function's update phase, gated by game state. `GetCharPressed()` loop captures printable ASCII (32-125), `IsKeyPressed()` handles special keys. Space (ASCII 32) currently enters the input buffer — it must be intercepted before the typing buffer when a power-up is held.

### Zombie kill flow (src/main.zig:647-660)

On name match: calculate score → increment combo → spawn popup → `allocator.destroy(zomb)` → null slot → clear input → increment kills → play sound. Power-up drop check inserts between "increment kills" and "play sound" (after the kill is confirmed but before the frame ends).

### Draw layering (src/main.zig:411-543)

Draw order: background → text box → game state content → cursor → CRT overlay → HUD → popups. New draw elements (menu, pause overlay, power-up HUD, freeze timer) must respect this layering — menu/pause draw in the game state content section; power-up HUD draws after the CRT overlay alongside existing HUD.

## Research Findings

### R1: Space bar conflict with typing input

- **Decision**: Intercept `KEY_SPACE` (raylib constant) via `IsKeyPressed()` before the `GetCharPressed()` loop when the player holds a power-up. When no power-up is held, let space pass through to the typing buffer as it does today.
- **Rationale**: Space is used in boss phrases ("the dead walk again") and must remain typeable. The interception is conditional on inventory state.
- **Alternatives considered**: Tab key (less discoverable), separate key like 'Q' (conflicts with typing). Space with conditional pass-through is the cleanest.

### R2: Freeze interaction with timers

- **Decision**: During freeze, skip `zomb.y += zomb.speed` for all zombies and the boss. Do NOT skip `spawn_timer` accumulation — new zombies still spawn but are frozen immediately. The freeze timer decrements independently from the game's `GetFrameTime()` (it should still tick even though zombie movement is paused).
- **Rationale**: Freezing spawns too would make freeze duration effectively longer (no new threats). Freezing the freeze timer itself is a logic error (it would never expire).
- **Alternatives considered**: Freeze spawns too (overpowered), freeze everything including timers (timer deadlock).

### R3: Pause implementation approach

- **Decision**: When `GameScreen == .paused`, skip the entire update phase (line 287 block) and additionally skip `updateMetrics()` and popup timer decrements. Store `previous_screen` to know whether to resume to `.playing` or `.game_over`.
- **Rationale**: The existing frame function already gates updates behind state flags. Pause is another gate. All timers that use `GetFrameTime()` are in the update phase, so they automatically stop.
- **Alternatives considered**: Storing all timer values on pause and restoring on resume (unnecessary complexity since timers just stop accumulating).

### R4: Zen mode zombie-at-bottom behavior

- **Decision**: In zen mode, when a zombie reaches `y >= screen_height`, destroy it silently (free + null slot). Do not set `is_dying` or `is_game_over`. Decrement a zen-specific counter or simply let new spawns fill the gap.
- **Rationale**: Spec FR-025 requires zombies to "disappear without triggering game-over". The simplest implementation is a mode check in `updateZombies` at the `y >= screen_height` branch.
- **Alternatives considered**: Wrapping the zombie off-screen (confusing), making zombie speed exactly match type rate so none ever reach bottom (fragile).

### R5: Per-mode high score backward compatibility

- **Decision**: Survival mode keeps the existing file/key (`highscore.dat` / `death-note.highscore`). Zen mode uses a new file/key (`highscore-zen.dat` / `death-note.highscore.zen`). The `load()` and `save()` functions gain a `GameMode` parameter. Zen mode uses the same `Record` struct but only populates `wpm` and `accuracy` fields (score=0, wave=0).
- **Rationale**: FR-030 mandates existing saves remain accessible. Using the same filename for survival ensures zero migration.
- **Alternatives considered**: Single file with mode prefix bytes (breaks existing saves), in-memory mode map (unnecessary abstraction).

### R6: GameScreen enum vs. boolean flags

- **Decision**: Introduce `GameScreen` enum with values: `main_menu`, `wpm_select`, `playing`, `paused`, `game_over`. Replace `is_game_over` and `is_transitioning` (but keep `is_dying` as a sub-state of `.playing` since it's a brief animation, not a user-facing screen). The `is_transitioning` flag also remains as a sub-state of `.playing`.
- **Rationale**: The feature adds 3 new states (menu, WPM select, paused). Encoding all as booleans creates 2^5=32 combinations, most invalid. An enum makes impossible states unrepresentable.
- **Alternatives considered**: Keep all booleans (combinatorial explosion), full state machine library (overkill for 5 states).

### R7: Power-up carrier designation

- **Decision**: Add a `power_up: ?PowerUpType` field to the `Zombie` struct. On spawn, roll a random number; if the zombie is designated as a carrier, assign a random PowerUpType. On kill, check `zomb.power_up != null` and offer it to the player's inventory.
- **Rationale**: Storing the power-up on the zombie itself is the simplest approach — no separate carrier tracking data structure needed. The field is `?PowerUpType` (1 byte) so the struct growth is minimal.
- **Alternatives considered**: Separate carrier index array (harder to keep in sync with zombie lifecycle), bitmap (obscure).

### R8: Power-up visual indicators

- **Decision**: Draw a text glyph above the zombie's name for carriers: `*` for Freeze (CRT_ACCENT), `!` for Bomb (CRT_ERR), `+` for Shield (CRT_WARN). Pulse the glyph alpha using a sine wave tied to `GetTime()`. For HUD inventory, draw a larger version of the same glyph in a dedicated HUD slot.
- **Rationale**: Text glyphs match the CRT aesthetic. No new texture assets needed. The pulsing alpha draws attention without obscuring the name (glyph is drawn above the name, which is already above the sprite).
- **Alternatives considered**: Colored rectangle behind zombie name (obscures readability), particle effects (requires new rendering infrastructure).

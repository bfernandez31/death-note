# Research: Game-Over Stats Screen and High Score Persistence

**Branch**: `DEATHN-24-copy-of-game` | **Date**: 2026-05-17

## Existing Files

| Path | Covers | Action |
|------|--------|--------|
| `src/main.zig` | Game loop, update/draw phases, game-over state, restart logic, all gameplay globals, WPM/accuracy metrics, score/combo system, all existing tests | Extend — add new state variables, modify game-over drawing, add persistence functions, add new tests |
| `src/raylib.zig` | C interop wrapper for raylib/emscripten headers | Extend — add emscripten localStorage interop (`emscripten_run_script`, `emscripten_run_script_int`) if not already importable via existing `@cInclude("emscripten/emscripten.h")` |
| `src/web_root.zig` | wasm32-emscripten entry point shim | No change |
| `src/zombie_names.zig` | Zombie name data | No change |
| `src/boss_phrases.zig` | Boss phrase data | No change |
| `build.zig` | Build graph (exe, test, web steps) | No change |
| `build.zig.zon` | Package manifest, raylib pin | No change |

### Test Files

All tests are in `src/main.zig` as `test "..." { ... }` blocks (Zig convention). New tests for this feature will be added there. 26 test blocks currently exist.

## Unknowns Resolved

### U-1: How to persist binary data from Zig

- **Decision**: Use `std.fs.cwd().createFile` / `openFile` with `std.fs.File.writeAll` / `readAll` for native. The `highscore.dat` file is a fixed-size struct written as raw bytes.
- **Rationale**: Zig's `std.fs` provides all needed file I/O. `@bitSizeOf(HighScoreRecord)` gives the exact expected size for corruption validation (FR-011).
- **Alternatives considered**: JSON text file (simpler but inconsistent with spec FR-008 which mandates binary); `std.io.Writer` streaming (unnecessary complexity for a fixed-size write).

### U-2: How to access localStorage from wasm32-emscripten

- **Decision**: Use `emscripten_run_script_int()` and `emscripten_run_script()` (already importable via `emscripten/emscripten.h` in `src/raylib.zig`). These execute arbitrary JavaScript strings.
- **Rationale**: Emscripten's `emscripten_run_script` family is the standard way to call JS from C/Zig. No additional headers or libraries needed.
- **Alternatives considered**: Emscripten's `EM_ASM` macro (not usable from Zig); custom JS library file linked via `--js-library` (more infrastructure than needed for two simple calls).

### U-3: Game-over transition timing (1-second pause with red-tinted zombie)

- **Decision**: Introduce a new state `is_dying: bool` with `dying_timer: f32` (counts down from 1.0). During this state: no spawns, no zombie movement, no input processing. The zombie that triggered game-over is tracked by index (`dying_zombie_index: ?usize`). After timer expires, transition to stats screen (`is_game_over = true`).
- **Rationale**: Cleanest separation of the 1s transition from the existing `is_game_over` flag. The existing code already gates updates behind `!is_game_over`; adding `!is_dying` to those gates is minimal.
- **Alternatives considered**: Reusing `is_game_over` with a sub-state (conflates two distinct visual states); using a callback timer (unnecessarily complex for a simple countdown).

### U-4: Kill counter tracking

- **Decision**: Add a `total_kills: u32` global that increments in both `updateZombies` (regular kill) and `updateBoss` (boss kill). Reset in the restart handler alongside other session counters.
- **Rationale**: The spec says kills include both regular and boss zombies (FR-006). `wave_kills` already tracks per-wave kills but resets each wave — a separate cumulative counter is needed.
- **Alternatives considered**: Summing wave_kills across waves (would require tracking wave history, more complex).

### U-5: Average WPM calculation for stats screen

- **Decision**: Use `(correct_chars / 5.0) / (elapsed_time / 60.0)` as specified in FR-005. Guard against division by zero when `elapsed_time < 1.0` → return 0. This uses the existing `correct_chars` and `elapsed_time` globals.
- **Rationale**: Direct implementation of the spec formula using already-tracked values.
- **Alternatives considered**: Using the smoothed `displayed_wpm` value (inaccurate for a final summary); using the sliding window WPM (spec explicitly defines the formula differently).

### U-6: Accuracy for stats screen

- **Decision**: Use `(correct_chars * 100) / (correct_chars + wrong_chars)`, returning 0 when both are 0 (per edge case spec). Uses existing `correct_chars` and `wrong_chars` globals.
- **Rationale**: `calculateTargetAccuracy()` already computes this but returns 100.0 for zero input; the spec edge case says 0%. Use a new inline calculation for the stats screen.

## Patterns to Follow

### Error handling pattern — `spawnZombie` (`src/main.zig:534-558`)
- Fallible allocation: `const new_zombie = try allocator.create(Zombie);`
- Immediate cleanup guard: `errdefer allocator.destroy(new_zombie);`
- **Apply to**: `loadHighScore` / `saveHighScore` functions. File open/read/write should use `try` + `errdefer` for any acquired file handles. On failure, default to zero values rather than propagating (game must not crash on corrupt files).

### Resource lifetime pattern — `main()` (`src/main.zig:391-434`)
- Every `Init...`/`Load...` is paired with `defer Close.../Unload...`
- **Apply to**: No new resources to load for this feature. The high score is loaded into a global struct at startup — no raylib handle involved, so no `defer` cleanup needed. File handles are opened, read, and closed within a single function scope.

### State management pattern — game-over restart (`src/main.zig:331-344`)
- Full manual reset of all session state variables when ENTER is pressed
- Each counter is explicitly zeroed; helper functions `resetScoreState()` and `resetMetricsState()` encapsulate groups
- **Apply to**: The restart handler must also reset `total_kills`, `dying_timer`, `dying_zombie_index`, and `is_dying`. The `best_score` (persisted high score record) is NOT reset — it survives restarts.

### Drawing pattern — game-over screen (`src/main.zig:313-328`)
- Uses `std.fmt.bufPrintZ` into stack-local `[N]u8` buffers to format text
- Uses `drawCenteredText` for horizontally centered lines, or `raylib.DrawText` for positioned text
- **Apply to**: The new stats screen replaces the existing game-over drawing code (lines 313-328). Use the same `bufPrintZ` → `drawCenteredText` pattern for all stat lines.

### Global state pattern (`src/main.zig:76-101`)
- Module-level `var` declarations for mutable game state
- Grouped by concern (game flow, boss, score, metrics)
- **Apply to**: New globals (`total_kills`, `is_dying`, `dying_timer`, `dying_zombie_index`, `best_score`) should be declared in a new group near the existing state declarations.

### Conditional compilation — emscripten (`src/main.zig:411-428`)
- `if (comptime @import("builtin").target.os.tag == .emscripten)` for platform-specific code
- **Apply to**: High score persistence must branch on this condition: native uses `std.fs` file I/O, emscripten uses `emscripten_run_script` for localStorage.

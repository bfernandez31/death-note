# death-note

Typing-game where falling zombies are destroyed by typing their displayed names before they reach the bottom of the screen. Written in Zig with raylib for windowing, rendering, input, and audio.

## Tech Stack

- **Language**: Zig (version determined by the toolchain installed; no `.zig-version` file is pinned)
- **Build system**: Zig's built-in build system (`build.zig` + `build.zig.zon`)
- **Package manager**: Zig package manager (declared in `build.zig.zon`)
- **Graphics / input / audio**: [raylib](https://github.com/raysan5/raylib) pinned to commit `52f2a10db610d0e9f619fd7c521db08a876547d0`, linked as a static library via `exe.linkLibrary(raylib_dep.artifact("raylib"))`
- **C interop**: raylib headers (`raylib.h`, `raymath.h`, `rlgl.h`), plus `stdlib.h` (for `atexit`) and `stdio.h` (for high score file I/O), are imported with `@cImport` in `src/raylib.zig`
- **Executable name**: `death-note`
- **Target window**: 800×450 @ 60 FPS (constants in `src/main.zig`)

## Commands

All commands run from the repository root.

| Purpose | Command |
| --- | --- |
| Build (installs to `zig-out/`) | `zig build` |
| Build + run the game | `zig build run` |
| Pass args to the game | `zig build run -- <args>` |
| Run unit tests (declared in `src/main.zig`) | `zig build test` |
| **Build WebAssembly bundle** (requires Emscripten SDK 3.1.64) | `zig build web` |
| Web release build (recommended for deploy) | `zig build web -Doptimize=ReleaseSmall` |
| Serve web bundle locally | `python3 -m http.server 8000 --directory zig-out/web` |
| Release build (optimize for speed) | `zig build -Doptimize=ReleaseFast` |
| Release build (optimize raylib separately) | `zig build -Draylib-optimize=ReleaseFast` |
| Strip debug info | `zig build -Dstrip=true` |
| List build steps | `zig build --help` |

There are no lint or type-check commands wired up separately — `zig build` compiles and type-checks in one step. Zig does not require a separate linter config in this project.

## Architecture

```
├── build.zig              # Declarative build graph (executable, test step, raylib linkage)
├── build.zig.zon          # Package manifest; pins the raylib dependency by URL + hash
├── src/
│   ├── main.zig           # Entry point, game loop, wave system, scoring, HUD, stats, high score persistence
│   ├── raylib.zig         # @cImport wrapper: raylib.h, raymath.h, rlgl.h, stdlib.h, stdio.h (+emscripten.h on web)
│   ├── zombie_names.zig   # Flat array of zero-terminated C strings used as zombie names (49 entries)
│   └── boss_phrases.zig   # Flat array of zero-terminated C strings used as boss zombie phrases (15 entries)
└── assets/                # Runtime-loaded resources (spritesheet, sounds, fonts) loaded by relative path
```

### Runtime flow (`src/main.zig`)

1. `main()` initializes the raylib window and audio device (both paired with `defer` for teardown), loads assets, and calls `loadHighScore()` to restore the persisted best score.
2. The allocator is `std.heap.c_allocator` on emscripten (page_allocator fails on WASM) or `std.heap.page_allocator` on native.
3. The main loop calls `frame(&ctx)` each iteration. The update phase branches on `is_game_over` and `is_wave_transitioning`:
   - **Wave active**: input polling with combo/accuracy tracking, spawn timer (wave-scaled delay via `waveSpawnDelay`), `updateZombies()`, wave completion detection, boss spawning on every 5th wave.
   - **Wave transitioning**: 5-second recap screen + 3-second countdown, then advance to next wave.
   - **Game over**: stats screen with high score save, restart on Enter via `resetGameState`.
4. `spawnZombie` allocates a new `Zombie` and stores it in the `[MAX_ZOMBIES]?*Zombie` pool, respecting `waveMaxActive(current_wave)`. `spawnBoss` does the same for boss zombies (larger, slower, phrase-based). `resetZombies` frees and nulls every slot on wave transition or restart.
5. `updateZombies` advances each zombie's `y`, triggers game-over on `y >= screen_height`, awards score with combo multiplier on kill, and records kill timestamps for WPM.
6. `drawZombies` animates the spritesheet (`ZOMBIE_FRAME_COUNT = 17` frames), scales normal zombies by `0.2` and bosses by `0.35` with a red tint, and draws a progress bar for boss phrase completion. `drawHud()` renders wave, score, combo, WPM, accuracy, and timer.

### Key state (module-level globals in `src/main.zig`)

- `name: [MAX_INPUT_CHARS + 1]u8` — null-terminated input buffer, max 40 chars.
- `zombies: [MAX_ZOMBIES]?*Zombie` — fixed pool; `MAX_ZOMBIES = 100`.
- `spawn_timer: f32` — seconds since last spawn; compared against `waveSpawnDelay(current_wave)`.
- `is_game_over: bool` — controls update-phase skipping and game-over stats screen.
- `current_wave: u32`, `wave_timer: f32`, `wave_kill_count: u32`, `is_wave_transitioning: bool` — wave lifecycle.
- `score: u64`, `combo: u32`, `best_score: u64` — scoring and persistence.
- `total_keystrokes: u64`, `correct_keystrokes: u64`, `total_kills: u32` — accuracy and kill stats.
- `wpm_kill_times: [WPM_BUFFER_SIZE]f64` — circular buffer of kill timestamps for rolling WPM.
- `boss_alive: bool`, `boss_spawned_this_wave: bool` — boss wave tracking.
- `zombie_texture: raylib.Texture2D`, `zombie_kill_sound: raylib.Sound` — loaded once, reused.

## Data Models

No database or ORM. The primary data shape is the `Zombie` struct in `src/main.zig`:

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8, // pointer into ZombieNames or BossPhrases, zero-terminated
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    is_boss: bool,
    phrase_progress: usize,
};
```

Names come from `ZombieNames` in `src/zombie_names.zig` (49 short first names) for normal zombies, and from `BossPhrases` in `src/boss_phrases.zig` (15 multi-word phrases) for boss zombies. Pointers are never copied, only referenced.

### High score persistence

The best score is persisted as a single 8-byte LE u64:
- **Native**: `highscore.dat` file in the working directory, read/written via C stdio (`fopen`/`fread`/`fwrite`/`fclose`).
- **Web**: `localStorage` key `death-note-highscore`, accessed via `emscripten_run_script_int` / `emscripten_run_script`.
- Loaded once at startup (`loadHighScore`), saved on game over when score exceeds best (`saveHighScore`). Errors silently ignored.

## Testing Patterns

- Testing framework: Zig's built-in test runner (`zig build test`). A `test_step` is wired up in `build.zig` against `src/main.zig` as the root test file.
- 21 `test "..." {}` blocks exist in `src/main.zig`, covering: name-match equality, input-buffer bounds, frame-index wrap, `cstrLen`, `comboMultiplier` tier boundaries, difficulty scaling functions (`waveSpawnDelay`, `waveFallSpeed`, `waveMaxActive`, `waveKillTarget`, `waveDuration`), `calculateWpm` (empty/partial/expired), score calculation with combo, wave completion bonus, accuracy calculation, WPM window expiry, high score monotonicity, boss wave detection, boss fall speed, wave state resets, and wave transition timer.
- All tests are pure-logic with no raylib dependencies. Pure functions (`comboMultiplier`, `waveSpawnDelay`, etc.) are tested directly.
- When adding tests, write them as top-level `test "name" { ... }` blocks inside the module under test (Zig convention). Reachability from `src/main.zig` is required for the `test_step` to pick them up.
- No end-to-end / GUI testing: the game is exercised manually via `zig build run`.

## Conventions

Observed across `src/main.zig`, `src/zombie_names.zig`, and `build.zig`:

- **Identifier casing**: `snake_case` for variables and constants (`spawn_timer`, `is_game_over`, `MAX_ZOMBIES` in SCREAMING_SNAKE_CASE for compile-time constants). Functions use `camelCase` (`spawnZombie`, `updateZombies`, `drawZombies`, `resetZombies`). Types use `PascalCase` (`Zombie`, `ZombieNames`). Raylib identifiers keep the upstream C style (`InitWindow`, `LoadTexture`, `DrawTexturePro`).
- **Imports**: `const std = @import("std");` first, then local modules (`const raylib = @import("raylib.zig").c;`). C interop is consolidated in `src/raylib.zig` via `pub const c = @cImport({...})` (Zig 0.15+ removed `pub usingnamespace`); never call `@cImport` directly from game code.
- **Resource lifetime**: every raylib `Init…` / `Load…` call is immediately followed by a matching `defer` for `Close…` / `Unload…` — keep this pattern for new resources.
- **Error handling**: functions that allocate return `!T` and are called with `try`. Allocation sites use `errdefer allocator.destroy(new_zombie)` to avoid leaks on partial failure. Prefer `errdefer` over manual cleanup branches.
- **Allocator**: `std.heap.c_allocator` on emscripten, `std.heap.page_allocator` on native. Pass it through as `*std.mem.Allocator` parameters rather than re-fetching it inside helpers.
- **Optional pointers**: zombies are stored as `?*Zombie` and unwrapped with `if (zombie) |zomb| { … }`. Follow this pattern instead of `.?` force-unwrapping.
- **C-string interop**: names kept as `[*:0]const u8` (null-terminated) so they can be passed straight to `raylib.DrawText`. When comparing to the input buffer, compute length with a terminator scan and use `std.mem.eql(u8, typed, zomb_name_slice)`.
- **Magic numbers**: gameplay tunables are declared as module-level `const` at the top of `src/main.zig`, grouped by concern: wave system (`WAVE_TRANSITION_*`, `BOSS_WAVE_INTERVAL`, `BOSS_FALL_SPEED_FACTOR`), scoring (`BASE_KILL_SCORE`, `BOSS_KILL_SCORE`, `WAVE_COMPLETION_BONUS_PER_WAVE`), difficulty scaling (`BASE_SPAWN_DELAY`, `MIN_SPAWN_DELAY`, `BASE_FALL_SPEED`, `MAX_FALL_SPEED`, etc.), stats (`WPM_WINDOW_SECONDS`, `WPM_BUFFER_SIZE`), and high score (`HIGHSCORE_FILE`). Add new tunables alongside them rather than inlining.
- **Assets**: loaded by relative path from the working directory (`"assets/zombie-hit.wav"`, `"assets/z_spritesheet.png"`). The game therefore must be run from the repo root, or `zig build run` (which runs from the install directory) with assets copied — keep this in mind when adding new asset loads.
- **Comments**: short `//` comments near non-obvious game-loop transitions. Avoid doc-comment walls; the code in `src/main.zig` favors inline single-line comments at branch points.

## Web / WASM build

The game has a second build target: `wasm32-emscripten`. The `zig build web` step (defined in `build.zig`) compiles the game as a static library for `wasm32-emscripten`, builds raylib for `PLATFORM_WEB` via its Makefile, and links everything with `emcc` into `zig-out/web/`.

Key files:
- `src/web/shell.html` — Emscripten `--shell-file`; loading spinner, WebGL guard, canvas focus
- `src/raylib.zig` — conditionally includes `emscripten/emscripten.h` when target is emscripten
- `src/main.zig` — `FrameContext` struct and `frame()` helper; `main()` branches on `comptime builtin.target.os.tag == .emscripten` to call `emscripten_set_main_loop_arg` instead of the native `while` loop; `cleanup_on_exit` registered via `atexit()` for resource teardown on web
- `.github/workflows/deploy-web.yml` — builds and publishes to GitHub Pages on every push to `main`

Deployment instructions: `specs/DEATHN-1-build-and-deploy/deployment-guide.md`

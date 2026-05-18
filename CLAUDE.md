# death-note

Typing-game where falling zombies are destroyed by typing their displayed names before they reach the bottom of the screen. Written in Zig with raylib for windowing, rendering, input, and audio.

## Tech Stack

- **Language**: Zig (version determined by the toolchain installed; no `.zig-version` file is pinned)
- **Build system**: Zig's built-in build system (`build.zig` + `build.zig.zon`)
- **Package manager**: Zig package manager (declared in `build.zig.zon`)
- **Graphics / input / audio**: [raylib](https://github.com/raysan5/raylib) pinned to commit `52f2a10db610d0e9f619fd7c521db08a876547d0`, linked as a static library via `exe.linkLibrary(raylib_dep.artifact("raylib"))`
- **C interop**: raylib headers (`raylib.h`, `raymath.h`, `rlgl.h`) are imported with `@cImport` in `src/raylib.zig`
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
│   ├── main.zig           # Entry point, game loop, zombie lifecycle, input handling, rendering
│   ├── raylib.zig         # Thin @cImport wrapper exposing raylib.h / raymath.h / rlgl.h
│   ├── zombie_names.zig   # Original 49-name array (superseded by name_lists.zig for spawning)
│   └── name_lists.zig     # Expanded name data: PrimaryNames (349+), CompoundNames (31), TrapGroups (15); selectName logic
└── assets/                # Runtime-loaded resources (spritesheet, sounds, fonts) loaded by relative path
```

### Runtime flow (`src/main.zig`)

1. `main()` seeds a `std.Random.DefaultPrng` from `std.c.clock_gettime(.REALTIME, …)` (`std.time.milliTimestamp` was removed in Zig 0.16), then initializes the raylib window and audio device (both paired with `defer` for teardown).
2. Assets are loaded once up-front via `raylib.LoadSound` / `raylib.LoadTexture`, also paired with `defer Unload…`.
3. The main loop (`while (!raylib.WindowShouldClose())`) is split into an **update** phase (gated by `!is_game_over`) and an always-on **draw** phase inside `BeginDrawing`/`EndDrawing`.
4. When `spawn_timer >= wave_cfg.spawn_delay`, a burst of `wave_cfg.burst_size` zombies fires simultaneously via `spawnZombieInZone`, distributing zombies across equal-width screen zones. `spawnZombie` is a thin wrapper around `spawnZombieInZone` for single-zombie use. Each spawn selects a `ZombieType` (standard/runner/tank) via wave-weighted probabilities and calls `name_lists.selectName()`. Allocates each `Zombie` from `std.heap.page_allocator`; freed immediately on kill; `resetZombies` clears remaining slots on wave transition or restart.
5. `updateZombies` advances each active zombie's `y`, triggers game-over when one passes `screen_height`, and kills a zombie when the typed input buffer matches its name byte-for-byte (`std.mem.eql(u8, …)`).
6. `drawZombies` animates the shared spritesheet by slicing a horizontal strip (`ZOMBIE_FRAME_COUNT = 17` frames), scales each zombie by `0.2`, and applies a color tint based on `zombie_type`: `CRT_FG` (#d48aff, violet) for standard, `CRT_WARN` (#ffb13a, amber) for runner, `CRT_DIM` (#3a1a5a, deep violet) for tank (`CRT_ERR` #ff5a8a overrides all during the dying state). A `drawCrtOverlay()` call at the end of `frame()` composites scanlines, corner vignette, and a double bezel border over the final frame.

### Key state (module-level globals in `src/main.zig`)

- `name: [MAX_BOSS_INPUT_CHARS + 1]u8` — null-terminated input buffer, max 20 chars normally (35 while boss active).
- `zombies: [MAX_ZOMBIES]?*Zombie` — fixed pool; `MAX_ZOMBIES = 100`. Slots are set to `null` immediately on zombie kill (memory freed via `allocator.destroy`), not just at restart.
- `spawn_timer` — seconds since last zombie spawn; compared against `getWaveConfig(current_wave).spawn_delay` each frame.
- `trap_cluster_group: ?usize` / `trap_cluster_remaining: u8` — tracks an active trap-name cluster; when non-zero, the next 1–2 spawns preferentially draw from the same `TrapGroup`.
- `prng: std.Random.DefaultPrng` — module-level PRNG seeded at startup via `std.c.clock_gettime`; used for zombie type selection and name selection.
- `is_dying: bool` / `dying_timer: f32` / `dying_zombie_index: ?usize` — 1-second pause state after a zombie crosses the bottom; the indexed zombie is tinted red.
- `is_game_over: bool` — controls update-phase skipping and stats overlay display; set after `is_dying` timer expires.
- `current_wave: u32` — active wave number; starts at 1, advances after each wave transition.
- `wave_kills: u32` / `wave_spawned: u32` — per-wave counters; wave completes when both reach `pool_size`.
- `total_kills: u32` — session-wide kill count (regular + boss); shown on stats screen; reset on restart.
- `is_transitioning: bool` / `transition_timer: f32` — 3-second inter-wave countdown state.
- `best_score: HighScoreRecord` — persisted best performance; loaded at startup, preserved across restarts.
- `is_new_high_score: bool` — set when current session score exceeds `best_score.score`; controls "NEW HIGH SCORE!" display.
- `zombie_texture: raylib.Texture2D`, `zombie_kill_sound: raylib.Sound` — loaded once, reused. All text rendering uses raylib's built-in bitmap font (chunky arcade pixels) via the `drawText()` / `measureText()` wrappers — call these instead of `raylib.DrawText` / `raylib.MeasureText` directly so the wrapper stays the single substitution point if a custom font is ever reintroduced.

## Data Models

No database or ORM. The key data shapes in `src/main.zig` are:

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,                        // fall_speed * type multiplier (1.0x/1.3x/0.5x)
    name: [*:0]const u8,               // pointer into name_lists arrays, zero-terminated
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    zombie_type: ZombieType = .standard, // .standard | .runner | .tank
};

const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
    burst_size: u32,
};

const HighScoreRecord = struct {
    score: u64 = 0,
    wave: u32 = 0,
    wpm: u32 = 0,
    accuracy: u8 = 0,
};
```

`WaveConfig` values come from the compile-time `WAVE_TABLE` (waves 1–15) or a scaling formula (`target_wpm = min(250, 100 + (wave-15)×5)`, waves 16+) via `getWaveConfig(wave: u32)`. The two-lever model derives `fall_speed` from `time_on_screen = clamp(6.0 - 0.15×(wave-1), 2.5, 6.0)` and `spawn_delay` from `burst_size = ceil(wave/4)` and `target_wpm`. Names come from `name_lists.zig` — `PrimaryNames` (349+ first names), `CompoundNames` (31 hyphenated names, e.g. `"Jean-Pierre"`), and `TrapGroups` (15 groups of 3–5 visually similar names). Name pointers are never copied, only referenced. `src/zombie_names.zig` still exists but is no longer the active spawn source — its 49 names are included in `PrimaryNames`.

`HighScoreRecord` is persisted as a 17-byte binary file (`highscore.dat`) on native builds using `std.c.fopen`/`fread`/`fwrite` (use `std.c` for file I/O — `std.fs` was removed in Zig 0.16). On web (Emscripten) builds it is stored in `localStorage` under `"death-note.highscore"` as JSON, accessed via `emscripten_run_script_int` / `emscripten_run_script`.

## Testing Patterns

- Testing framework: Zig's built-in test runner (`zig build test`). A `test_step` is wired up in `build.zig` against `src/main.zig` as the root test file; `src/name_lists.zig` is also discovered because it is transitively imported.
- Test blocks in `src/main.zig` cover: name-match equality, input-buffer bounds (now 20 chars), `getWaveConfig` correctness, wave completion logic, animation-frame wrap-around, dying state transition, WPM/accuracy calculation, `HighScoreRecord` struct size, high score comparison, `ZombieType` speed multipliers, spawn/name weight table bracket checks, zombie type selection distribution, tint colors, hyphen input acceptance, and trap cluster state reset.
- Test blocks in `src/name_lists.zig` cover: primary list size (≥349), all-ASCII validation, compound name validity, trap group sizes, sufficient runner/tank name counts, anti-doublon enforcement, length filtering per type, forced trap-group preference, and weight table sum validation.
- When adding tests, write them as top-level `test "name" { ... }` blocks inside the module under test (Zig convention). Reachability from `src/main.zig` is required for the existing `test_step` to pick them up; other files only run when imported (transitively) from `src/main.zig`.
- No end-to-end / GUI testing: the game is exercised manually via `zig build run`.

## Conventions

Observed across `src/main.zig`, `src/zombie_names.zig`, and `build.zig`:

- **Identifier casing**: `snake_case` for variables and constants (`spawn_timer`, `is_game_over`, `MAX_ZOMBIES` in SCREAMING_SNAKE_CASE for compile-time constants). Functions use `camelCase` (`spawnZombie`, `updateZombies`, `drawZombies`, `resetZombies`). Types use `PascalCase` (`Zombie`, `ZombieNames`). Raylib identifiers keep the upstream C style (`InitWindow`, `LoadTexture`, `DrawTexturePro`).
- **Imports**: `const std = @import("std");` first, then local modules (`const raylib = @import("raylib.zig").c;`). C interop is consolidated in `src/raylib.zig` via `pub const c = @cImport({...})` (Zig 0.15+ removed `pub usingnamespace`); never call `@cImport` directly from game code.
- **Resource lifetime**: every raylib `Init…` / `Load…` call is immediately followed by a matching `defer` for `Close…` / `Unload…` — keep this pattern for new resources.
- **Error handling**: functions that allocate return `!T` and are called with `try`. Allocation sites use `errdefer allocator.destroy(new_zombie)` to avoid leaks on partial failure. Prefer `errdefer` over manual cleanup branches.
- **Allocator**: `std.heap.page_allocator` is the sole allocator today. Pass it through as `*std.mem.Allocator` parameters rather than re-fetching it inside helpers.
- **Optional pointers**: zombies are stored as `?*Zombie` and unwrapped with `if (zombie) |zomb| { … }`. Follow this pattern instead of `.?` force-unwrapping.
- **C-string interop**: names kept as `[*:0]const u8` (null-terminated) so they can be passed straight to `drawText()`. When comparing to the input buffer, compute length with a terminator scan and use `std.mem.eql(u8, typed, zomb_name_slice)`.
- **Text rendering**: never call `raylib.DrawText` or `raylib.MeasureText` directly in game code — always use the `drawText()` / `measureText()` wrappers (one substitution point if a custom font is later reintroduced).
- **Magic numbers**: gameplay tunables (`MAX_ZOMBIES`, `MAX_INPUT_CHARS`, `ZOMBIE_FRAME_COUNT`, `WAVE_TRANSITION_DURATION`, `WAVE_TABLE`, `screen_width`, `screen_height`) are declared as module-level `const`/`var` at the top of `src/main.zig`. Add new tunables alongside them rather than inlining.
- **Color palette**: all render colors use named `CRT_*` semantic constants (`CRT_FG`, `CRT_DIM`, `CRT_DIM_TEXT`, `CRT_BG`, `CRT_ACCENT`, `CRT_WARN`, `CRT_ERR`, `CRT_BEZEL_OUTER`, `CRT_BEZEL_INNER`, `CRT_SCANLINE`, `CRT_VIGNETTE_OUTER`, `CRT_VIGNETTE_INNER`) declared at the top of `src/main.zig`. **`CRT_DIM` is fill-only** (text-box backgrounds, boss health-bar background) — for secondary/unselected text use `CRT_DIM_TEXT`, which has enough luminance to be readable on `CRT_BG`. Never use raw raylib color names (`WHITE`, `RED`, `DARKGRAY`, etc.) for game rendering — always pick the appropriate `CRT_*` constant.
- **Assets**: loaded by relative path from the working directory (`"assets/zombie-hit.wav"`, `"assets/z_spritesheet.png"`). The game therefore must be run from the repo root, or `zig build run` (which runs from the install directory) with assets copied — keep this in mind when adding new asset loads.
- **Comments**: short `//` comments near non-obvious game-loop transitions. Avoid doc-comment walls; the code in `src/main.zig` favors inline single-line comments at branch points.

## Web / WASM build

The game has a second build target: `wasm32-emscripten`. The `zig build web` step (defined in `build.zig`) compiles the game as a static library for `wasm32-emscripten`, builds raylib for `PLATFORM_WEB` via its Makefile, and links everything with `emcc` into `zig-out/web/`.

Key files added by DEATHN-1:
- `src/web/shell.html` — Emscripten `--shell-file`; loading spinner, WebGL guard, canvas focus
- `src/raylib.zig` — conditionally includes `emscripten/emscripten.h` when target is emscripten
- `src/main.zig` — `FrameContext` struct and `frame()` helper; `main()` branches on `comptime builtin.target.os.tag == .emscripten` to call `emscripten_set_main_loop_arg` instead of the native `while` loop
- `.github/workflows/deploy-web.yml` — builds and publishes to GitHub Pages on every push to `main`

Deployment instructions: `specs/DEATHN-1-build-and-deploy/deployment-guide.md`

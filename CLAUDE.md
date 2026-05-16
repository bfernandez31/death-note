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
│   └── zombie_names.zig   # Flat array of zero-terminated C strings used as zombie names
└── assets/                # Runtime-loaded resources (spritesheet, sounds, fonts) loaded by relative path
```

### Runtime flow (`src/main.zig`)

1. `main()` seeds a `std.Random.DefaultPrng` from `std.time.milliTimestamp()`, then initializes the raylib window and audio device (both paired with `defer` for teardown).
2. Assets are loaded once up-front via `raylib.LoadSound` / `raylib.LoadTexture`, also paired with `defer Unload…`.
3. The main loop (`while (!raylib.WindowShouldClose())`) is split into an **update** phase (gated by `!is_game_over`) and an always-on **draw** phase inside `BeginDrawing`/`EndDrawing`.
4. `spawnZombie` allocates a new `Zombie` from `std.heap.page_allocator` and stores it in a fixed-size `[MAX_ZOMBIES]?*Zombie` slot array. `resetZombies` frees and nulls every slot on restart.
5. `updateZombies` advances each active zombie's `y`, triggers game-over when one passes `screen_height`, and kills a zombie when the typed input buffer matches its name byte-for-byte (`std.mem.eql(u8, …)`).
6. `drawZombies` animates the shared spritesheet by slicing a horizontal strip (`ZOMBIE_FRAME_COUNT = 17` frames) and scales each zombie by `0.2`.

### Key state (module-level globals in `src/main.zig`)

- `name: [MAX_INPUT_CHARS + 1]u8` — null-terminated input buffer, max 9 chars.
- `zombies: [MAX_ZOMBIES]?*Zombie` — fixed pool; `MAX_ZOMBIES = 100`.
- `spawn_timer` — seconds since last zombie spawn; compared against `getWaveConfig(current_wave).spawn_delay` each frame.
- `is_game_over: bool` — controls update-phase skipping and restart prompt.
- `current_wave: u32` — active wave number; starts at 1, advances after each wave transition.
- `wave_kills: u32` / `wave_spawned: u32` — per-wave counters; wave completes when both reach `pool_size`.
- `is_transitioning: bool` / `transition_timer: f32` — 3-second inter-wave countdown state.
- `zombie_texture: raylib.Texture2D`, `zombie_kill_sound: raylib.Sound` — loaded once, reused.

## Data Models

No database or ORM. The two key data shapes in `src/main.zig` are:

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,          // set from WaveConfig.fall_speed at spawn
    name: [*:0]const u8, // pointer into ZombieNames, zero-terminated
    is_active: bool,
    frame: f32,
    animation_timer: f32,
};

const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
};
```

`WaveConfig` values come from the compile-time `WAVE_TABLE` (waves 1–15) or a scaling formula (waves 16+) via `getWaveConfig(wave: u32)`. Names come from `ZombieNames` in `src/zombie_names.zig` — a compile-time `[_][*:0]const u8{ ... }` array of 49 short first names. `spawnZombie` picks an index at random; names are never copied, only referenced.

## Testing Patterns

- Testing framework: Zig's built-in test runner (`zig build test`). A `test_step` is wired up in `build.zig` against `src/main.zig` as the root test file.
- Seven `test { ... }` blocks exist in `src/main.zig`: name-match equality, input-buffer bounds, `getWaveConfig` correctness for waves 1/15/16+, wave completion logic, and animation-frame wrap-around.
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
- **C-string interop**: names kept as `[*:0]const u8` (null-terminated) so they can be passed straight to `raylib.DrawText`. When comparing to the input buffer, compute length with a terminator scan and use `std.mem.eql(u8, typed, zomb_name_slice)`.
- **Magic numbers**: gameplay tunables (`MAX_ZOMBIES`, `MAX_INPUT_CHARS`, `ZOMBIE_FRAME_COUNT`, `WAVE_TRANSITION_DURATION`, `WAVE_TABLE`, `screen_width`, `screen_height`) are declared as module-level `const`/`var` at the top of `src/main.zig`. Add new tunables alongside them rather than inlining.
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

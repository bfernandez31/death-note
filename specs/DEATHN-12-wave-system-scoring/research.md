# Research: Wave System, Scoring and Difficulty Progression

**Feature**: DEATHN-12 | **Date**: 2026-05-16

## 1. Unknowns Resolved

### 1.1 High Score Persistence — Native (File I/O)

**Decision**: Use `std.fs.cwd().createFile` / `openFile` to write/read a single `u64` (score) to a file named `highscore.dat` in the working directory. The file contains the score as an 8-byte little-endian integer — no header, no versioning for V1.

**Rationale**: Zig's `std.fs` is available on all native targets. Writing a raw `u64` avoids pulling in any serialization. The working directory is where assets already live (constitution §Security Practices/4 — asset paths are literals from `assets/`), so `highscore.dat` co-located there is consistent. The file is created on first save, not on startup, so fresh installs have no dangling file.

**Alternatives considered**:
- **JSON / text format**: Human-readable but adds parsing; overkill for a single integer.
- **XDG data dir / AppData**: Correct for installable apps, but this game runs from its build directory and has no installer. Can be added later if packaging is introduced.

### 1.2 High Score Persistence — Web (localStorage)

**Decision**: Use Emscripten's `emscripten_run_script` (already importable via `raylib.zig`) to execute `localStorage.setItem("death-note-highscore", score.toString())` and `localStorage.getItem("death-note-highscore")`. Alternatively, use Emscripten's File System API with `--idbfs-persist` — but the simpler path is direct JS eval for a single value.

**Rationale**: `emscripten_run_script` is the lightest cross-boundary call for a trivial value. No extra Emscripten flags needed. Graceful degradation is handled by catching a null/empty return from `getItem`.

**Alternatives considered**:
- **IDBFS + emscripten_idb_store/load**: Full filesystem emulation; heavy for one integer.
- **Cookies**: Size-limited, sent on every request if a server is involved; worse than localStorage.

### 1.3 WPM Rolling Window Implementation

**Decision**: Maintain a circular buffer of timestamps (frame-time based, not wall-clock) recording when each zombie was killed. WPM = (kills in last 30 seconds) / 0.5 (since 30 seconds = 0.5 minutes). The buffer size is capped at 200 entries (more than enough for 30 seconds of kills at any realistic rate).

**Rationale**: A circular buffer is O(1) insert and O(n) scan (where n ≤ 200 is trivially fast per frame). Using elapsed game time (`raylib.GetTime()`) avoids wall-clock issues and paused states. The 30-second window from ARD-3 is standard for typing tests.

**Alternatives considered**:
- **Exponential moving average**: Smooths nicely but doesn't match the "30-second window" spec literally — harder to validate in tests.
- **Count every word ever / elapsed time**: Simple but not responsive — a player who stops typing still shows high WPM until the average dilutes.

### 1.4 Prefix-Match for Accuracy (Keystroke Correctness)

**Decision**: On each `GetCharPressed` event, check if appending the character to the current input buffer creates a string that is a prefix of at least one active zombie's name (or the boss phrase). If yes → correct keystroke. If no → incorrect keystroke, combo resets. The character is still added to the buffer regardless (existing behavior: the buffer accepts all printable ASCII up to the limit).

**Rationale**: This matches ARD-8's definition: "A keystroke is correct if the typed character extends a prefix match against any active zombie's name." It preserves the existing single-buffer design where the player doesn't explicitly target a zombie. The prefix check is a simple loop over active zombies with `std.mem.startsWith`.

**Alternatives considered**:
- **Only count keystrokes on full match (kill)**: Simpler but accuracy would only reflect completed words, not typing precision during entry.
- **Lock onto a target zombie**: Would require UI changes and break the existing freeform typing model.

### 1.5 Wave Timer vs Kill Target Interaction

**Decision**: Each wave has both a `kill_target` and a `wave_duration` (seconds). The wave ends when either condition is met. If kill target is met first → wave-completion bonus awarded. If timer expires first → no bonus, remaining non-boss zombies are cleared, proceed to transition. If a boss is alive when timer would expire → timer pauses (boss must be defeated).

**Rationale**: Directly from ARD-1. The timer-pause for bosses prevents unwinnable situations. Clearing non-boss zombies on timer expiry prevents stale zombies from carrying over.

### 1.6 Boss Input Buffer and Normal Zombie Interaction

**Decision**: Increase the input buffer from `MAX_INPUT_CHARS = 9` to `MAX_INPUT_CHARS = 40`. Both normal zombies and bosses use the same single input buffer. When the typed text matches a normal zombie's name exactly, that zombie dies and the buffer clears. When it matches the boss phrase exactly, the boss dies and the buffer clears. The prefix-match for accuracy checking checks against all active entities (normal + boss).

**Rationale**: From ARD-4. A single buffer keeps the design simple. The boss phrase is just a longer name — the matching logic is identical. 40 characters accommodates phrases up to 40 chars (ARD-4 specifies 10–30 character phrases, so 40 provides headroom).

## 2. Existing Files

### 2.1 Source Files

| Path | Covers | Action |
|---|---|---|
| `src/main.zig` (434 lines) | Game loop, zombie lifecycle, input handling, rendering, tests | **Extend heavily** — add wave state, scoring state, combo state, stats tracking, HUD drawing, game-over screen stats, high score persistence, boss spawning, difficulty scaling |
| `src/zombie_names.zig` (1 line) | 49 short zombie names as `[*:0]const u8` | **Reuse as-is** — normal zombie names stay unchanged |
| `src/raylib.zig` (16 lines) | C interop wrapper | **Extend minimally** — may need to expose additional Emscripten JS eval functions if not already available; otherwise unchanged |
| `src/web_root.zig` (33 lines) | Emscripten entry point shim | **Unchanged** |
| `build.zig` (148 lines) | Build graph: native exe, test step, web step | **Unchanged** — no new build steps needed for this feature |
| `build.zig.zon` | Package manifest with raylib pin | **Unchanged** (constitution §Security Practices/5) |

### 2.2 New Files Required

| Path | Purpose |
|---|---|
| `src/boss_phrases.zig` | Predefined list of boss phrases (`[*:0]const u8` array, same pattern as `zombie_names.zig`) |

### 2.3 Asset Files

| Path | Action |
|---|---|
| `assets/z_spritesheet.png` | Reuse for normal zombies; boss zombie uses the same sprite (scaled larger or tinted — no new asset needed for V1) |
| `assets/zombie-hit.wav` | Reuse for normal kills; boss kill could reuse or use a distinct sound — V1 reuses |

No new asset files are required for this feature. Boss visual distinction is achieved through code (larger scale, progress bar overlay, tint).

### 2.4 Test Files

| Path | Current Coverage | Action |
|---|---|---|
| `src/main.zig` (lines 349–433) | `T003` name-match equality, `T004` input-buffer bounds, `T005` frame-index wrap | **Extend** — add tests for combo multiplier calculation, difficulty scaling formulas, WPM calculation, wave kill-target logic, score calculation |

No separate test files exist. Per constitution §Testing Standards/2, tests go in the module under test. All new tests will be added to `src/main.zig`.

### 2.5 Spec / Config Files

| Path | Action |
|---|---|
| `src/web/shell.html` | **Unchanged** |
| `.github/workflows/deploy-web.yml` | **Unchanged** |
| `.ai-board/config.yml` | **Unchanged** |

## 3. Patterns to Follow

### 3.1 Module-Level Globals for Game State (`src/main.zig:15–42`)

**Pattern**: All mutable game state is declared as module-level `var` at the top of `main.zig`. Constants are `const`. New tunables (wave parameters, scoring constants) must follow this placement.

```zig
// src/main.zig:7-20
const MAX_ZOMBIES = 100;
const MAX_INPUT_CHARS = 9;
var spawn_timer: f32 = 0.0;
var is_game_over: bool = false;
```

**How to apply**: Wave state (`current_wave`, `wave_timer`, `wave_kill_count`, `wave_kill_target`), scoring state (`score`, `combo`, `multiplier`), and stats (`total_keystrokes`, `correct_keystrokes`, `wpm_kill_times` buffer) all go as module-level globals at the top of `main.zig`, grouped by concern with one-line comments separating groups.

### 3.2 Allocator Threading (`src/main.zig:313,339`)

**Pattern**: Functions that allocate take `allocator: *std.mem.Allocator` as a parameter. See `spawnZombie` (line 313) and `resetZombies` (line 339).

**How to apply**: If boss zombie allocation differs from normal zombie allocation, it still goes through the same allocator parameter. The reset function must clear boss state alongside normal zombies.

### 3.3 Zombie Spawn Pattern (`src/main.zig:313-337`)

**Pattern**: `spawnZombie` scans the `zombies` array for a `null` slot, allocates with `try allocator.create(Zombie)`, initializes all fields, assigns to the slot, and returns `true`. If no slot found, returns `false`. Uses `errdefer allocator.destroy(new_zombie)` for cleanup on partial failure.

```zig
fn spawnZombie(allocator: *std.mem.Allocator) !bool {
    for (zombies, 0..) |zombie, i| {
        if (zombie == null) {
            const new_zombie = try allocator.create(Zombie);
            errdefer allocator.destroy(new_zombie);
            // ... initialize fields ...
            zombies[i] = new_zombie;
            return true;
        }
    }
    return false;
}
```

**How to apply**: Boss zombies should be stored in the same `zombies` pool (they are zombies with different properties). The `Zombie` struct gets extended with fields for boss state (`is_boss: bool`, `phrase_progress: usize`). `spawnZombie` gains a parameter or variant for boss spawning that sets different speed, name (phrase), and boss flags.

### 3.4 Update Loop Gating (`src/main.zig:75`)

**Pattern**: The update phase is gated by `if (!is_game_over)`. All spawn, movement, and input logic lives inside this gate.

**How to apply**: Wave transitions, scoring, and stats updates all go inside the `!is_game_over` gate. A new intermediate state for wave transitions (`is_wave_transitioning`) gates out normal spawn/input but still draws the transition screen.

### 3.5 Input Handling (`src/main.zig:79-93`)

**Pattern**: `GetCharPressed` is called in a `while` loop to drain the queue. Each character is validated (`key >= 32 and key <= 125`) and bounds-checked (`letter_count < MAX_INPUT_CHARS`) before writing to the buffer. Backspace is handled separately via `IsKeyPressed(KEY_BACKSPACE)`.

**How to apply**: The accuracy tracking hooks into this exact loop — each accepted character increments `total_keystrokes` and is checked for prefix validity. The `MAX_INPUT_CHARS` constant increases to 40 for boss phrase support. The character validation range stays the same (ASCII 32–125).

### 3.6 Name Matching (`src/main.zig:234-254`)

**Pattern**: After each character input, `updateZombies` compares the full typed buffer against each active zombie's name using `std.mem.eql`. On match: deactivate zombie, clear buffer, play sound.

```zig
const typed_name = name[0..letter_count];
// ... compute zomb_name_length by scanning to '\x00' ...
const zomb_name_slice = zomb.name[0..zomb_name_length];
if (std.mem.eql(u8, typed_name, zomb_name_slice)) {
    zomb.is_active = false;
    letter_count = 0;
    name[letter_count] = '\x00';
    raylib.PlaySound(zombie_kill_sound);
}
```

**How to apply**: This matching logic stays the same for both normal zombies and bosses. Boss phrases are stored as `[*:0]const u8` just like normal names. On boss kill: additional scoring (500 base points), wave-completion check, progress indicator removal. The prefix check for accuracy is a separate function that uses `std.mem.startsWith` instead of `std.mem.eql` — it runs before the full-match check on each keystroke.

### 3.7 Draw Phase Structure (`src/main.zig:111-155`)

**Pattern**: `BeginDrawing` → `ClearBackground` → draw text box → draw game content (zombies or game-over overlay) → draw cursor → `EndDrawing`. The game-over screen is drawn inside the `if (is_game_over)` branch.

**How to apply**: HUD elements are drawn after zombies but before the cursor (so they don't overlap the input box). The wave transition screen replaces zombie drawing during transitions. The game-over screen is expanded with stats display. All draw calls use `raylib.DrawText` with explicit pixel positions — layout the HUD in the top margin area (y < 30) to stay clear of the zombie play area (y 30–400) and input box (y 400–450).

### 3.8 Game Restart (`src/main.zig:134-142`)

**Pattern**: On Enter during game-over: reset `is_game_over`, clear input buffer, reset spawn timer, call `resetZombies`.

**How to apply**: Restart must additionally reset: `current_wave = 1`, `score = 0`, `combo = 0`, `wave_timer = 0`, `wave_kill_count = 0`, all stats counters, WPM buffer. The `resetZombies` call already handles the zombie pool. Add a `resetGameState` function that wraps all resets including `resetZombies`.

### 3.9 C-String Length Computation (`src/main.zig:238-241`)

**Pattern**: Zombie name length is computed by scanning to `'\x00'`:
```zig
var zomb_name_length: usize = 0;
while (zomb.name[zomb_name_length] != '\x00') zomb_name_length += 1;
```

**How to apply**: Extract this into a helper function `cstrLen(name: [*:0]const u8) usize` to avoid duplication as more places need name/phrase lengths (boss progress display, HUD text). This is a pure function — easy to test.

## 4. Technology Best Practices

### 4.1 Zig Module-Level State for Game Systems

For a Zig game with multiple interacting systems (waves, scoring, stats), the idiomatic approach within the "single-module game loop" constraint is:
- Group related state into structs but keep instances as module-level `var` (matches existing `Zombie` pattern).
- Functions that modify state are free functions taking pointers to the relevant globals (not methods on the structs).
- New tunables as `const` at module top.

### 4.2 Frame-Time-Based Timers

The existing `spawn_timer += raylib.GetFrameTime()` pattern is the correct approach for wave timers, transition countdowns, and animation. Use `raylib.GetTime()` for absolute timestamps (WPM kill-time recording).

### 4.3 Emscripten JavaScript Interop

For localStorage access, Emscripten provides:
- `emscripten_run_script(code)` — fire-and-forget JS eval
- `emscripten_run_script_int(code)` — returns an `c_int`
- `emscripten_run_script_string(code)` — returns a `[*:0]const u8`

These are available through `raylib.zig`'s conditional `@cInclude("emscripten/emscripten.h")`. Use `emscripten_run_script_int` to load the high score (parse as int in JS, return via C bridge).

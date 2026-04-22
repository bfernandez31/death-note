# Endpoints & Interface Reference

## Table of Contents

- [1. API Overview](#1-api-overview)
- [2. Alternative Interfaces](#2-alternative-interfaces)
  - [2.1 CLI Arguments](#21-cli-arguments)
  - [2.2 Asset Filesystem Reads](#22-asset-filesystem-reads)
  - [2.3 User Input Surface](#23-user-input-surface)
  - [2.4 Audio Output](#24-audio-output)
  - [2.5 Window and Graphics Output](#25-window-and-graphics-output)
- [3. Authentication & Authorization](#3-authentication--authorization)
- [4. Error Handling](#4-error-handling)
- [5. Request/Response Schemas](#5-requestresponse-schemas)
- [6. Input Flow Diagram](#6-input-flow-diagram)

---

## 1. API Overview

**No network API exists in this project.**

`death-note` is a self-contained native desktop game compiled to a single executable (`death-note`). It runs entirely on the local machine, communicates with no remote services, and exposes no listening socket of any kind.

The following API surface types were searched for and confirmed absent:

| Surface type | Where searched | Result |
|---|---|---|
| HTTP/REST routes | `src/main.zig`, `src/raylib.zig`, `build.zig` | Not present. No HTTP library is imported or linked. |
| GraphQL schema | All `.zig` source files and `build.zig.zon` | Not present. No GraphQL dependency is declared. |
| gRPC service definitions | All `.zig` source files and `build.zig.zon` | Not present. No gRPC library is imported or linked. |
| Message-bus subscriptions (MQTT, AMQP, NATS, etc.) | All `.zig` source files and `build.zig.zon` | Not present. |
| Unix-domain sockets / named pipes | `src/main.zig` | Not present. |
| Shared-memory IPC | `src/main.zig` | Not present. |

The only external dependency declared in `build.zig.zon` is raylib, a graphics/input/audio library that operates entirely in-process.

---

## 2. Alternative Interfaces

Because no traditional API exists, the meaningful external surfaces are documented below.

### 2.1 CLI Arguments

**Mechanism:** `zig build run -- <args>` forwards extra arguments to the compiled binary via the build graph.

**Build-side wiring (`build.zig` lines 62–64):**

```zig
if (b.args) |args| {
    run_cmd.addArgs(args);
}
```

`run_cmd` is the `b.addRunArtifact(exe)` step. Any tokens placed after `--` on the `zig build run` command line are collected into `b.args` and appended verbatim to the child-process argument vector.

**Binary-side behavior (`src/main.zig`):** `pub fn main() !void` (line 46) never calls `std.process.argsAlloc` or any equivalent. The process argv is accepted by the OS and passed through, but the game code never reads or acts on any argument. All CLI arguments are silently ignored at runtime.

**Summary:**

| Field | Value |
|---|---|
| Invocation | `zig build run -- [arg1 arg2 …]` |
| Forwarded by | `build.zig:63` (`run_cmd.addArgs(args)`) |
| Consumed by game | No — `src/main.zig` does not read argv |
| Effect | None |

### 2.2 Asset Filesystem Reads

Assets are loaded once at startup using relative paths. The game must therefore be launched from the repository root (or from the install directory into which assets are copied by `zig build`).

**Actively loaded assets:**

| Path | Loader call | Location in source | Stored in |
|---|---|---|---|
| `assets/zombie-hit.wav` | `raylib.LoadSound(...)` | `src/main.zig:57` | `zombie_kill_sound: raylib.Sound` |
| `assets/z_spritesheet.png` | `raylib.LoadTexture(...)` | `src/main.zig:60` | `zombie_texture: raylib.Texture2D` |

Each load is immediately paired with a `defer` unload:

```zig
zombie_kill_sound = raylib.LoadSound("assets/zombie-hit.wav");
defer raylib.UnloadSound(zombie_kill_sound);          // src/main.zig:58

zombie_texture = raylib.LoadTexture("assets/z_spritesheet.png");
defer raylib.UnloadTexture(zombie_texture);           // src/main.zig:61
```

**Files present in `assets/` but NOT referenced by any source code:**

| File | Notes |
|---|---|
| `assets/alagard.png` | Present on disk; no `LoadTexture` / `LoadFont` call references it |
| `assets/page.png` | Present on disk; unreferenced |
| `assets/plume.png` | Present on disk; unreferenced |
| `assets/spritesheet.png` | Present on disk; distinct from `z_spritesheet.png`; unreferenced |
| `assets/JetBrainsMonoNerdFont-Thin.ttf` | Present on disk; no `LoadFont` call references it |

All asset reads are **read-only** and occur at process startup. No asset is written, created, or modified at runtime.

### 2.3 User Input Surface

Input is polled every frame inside the main game loop (`src/main.zig:71`). Input is only processed when `!is_game_over` (line 73) and when the mouse cursor is inside the text-box rectangle (line 76).

**Mouse input:**

| raylib call | Location | Purpose |
|---|---|---|
| `raylib.GetMousePosition()` | `src/main.zig:76` | Obtain current cursor coordinates |
| `raylib.CheckCollisionPointRec(pos, text_box)` | `src/main.zig:76` | Determine whether cursor is over the input box |
| `raylib.SetMouseCursor(MOUSE_CURSOR_IBEAM)` | `src/main.zig:78` | Change cursor appearance when over box |
| `raylib.SetMouseCursor(MOUSE_CURSOR_DEFAULT)` | `src/main.zig:99` | Restore cursor when outside box |

**Keyboard input (active when mouse is on text box):**

| Key / range | raylib call | Location | Effect |
|---|---|---|---|
| Printable ASCII 32–125 | `raylib.GetCharPressed()` (polled in a loop) | `src/main.zig:80–90` | Appends character to `name[]` buffer; null-terminates; rejects input beyond `MAX_INPUT_CHARS` (9) |
| `KEY_BACKSPACE` | `raylib.IsKeyPressed(raylib.KEY_BACKSPACE)` | `src/main.zig:93` | Removes last character from `name[]`; null-terminates |

**Keyboard input (active only when `is_game_over`):**

| Key | raylib call | Location | Effect |
|---|---|---|---|
| `KEY_ENTER` | `raylib.IsKeyPressed(raylib.KEY_ENTER)` | `src/main.zig:141` | Clears `is_game_over`, resets input buffer and spawn timer, calls `resetZombies` |

**Input buffer constraints:**

- Buffer: `var name = [_]u8{0} ** (MAX_INPUT_CHARS + 1)` — 10 bytes, always null-terminated.
- Maximum typed length: 9 characters (`MAX_INPUT_CHARS = 9`, `src/main.zig:8`).
- Match check: performed each frame in `updateZombies` (`src/main.zig:193`) via `std.mem.eql(u8, typed_name, zomb_name_slice)`.

### 2.4 Audio Output

| Item | Detail |
|---|---|
| Device init | `raylib.InitAudioDevice()` — `src/main.zig:53`; closed with `defer raylib.CloseAudioDevice()` |
| Sound file | `assets/zombie-hit.wav` (loaded at startup, see §2.2) |
| Playback trigger | `raylib.PlaySound(zombie_kill_sound)` — `src/main.zig:199`, called when a zombie's name matches the typed input |
| Output channel | System default audio device via raylib's miniaudio backend |

No background music, no volume control, and no additional sound effects exist in the current codebase.

### 2.5 Window and Graphics Output

| Property | Value | Source |
|---|---|---|
| Window title | `"Zombie Game"` | `src/main.zig:49` |
| Resolution | 800 × 450 pixels | `screen_width`/`screen_height` constants, `src/main.zig:43–44` |
| Target frame rate | 60 FPS | `raylib.SetTargetFPS(60)` — `src/main.zig:67` |
| Rendering API | raylib (OpenGL backend) | `build.zig:42` — `exe.linkLibrary(raylib_dep.artifact("raylib"))` |
| Window close | Standard OS close button or `WindowShouldClose()` returning true | `src/main.zig:71` |

---

## 3. Authentication & Authorization

Not applicable. This is a single-player local desktop game. There are no user accounts, no login flow, no sessions, no tokens, no roles, and no permission checks of any kind.

---

## 4. Error Handling

The game uses Zig's native error-union mechanism exclusively. There is no logging framework and no user-visible error messages beyond the in-game GAME OVER screen.

| Scenario | Mechanism | Location |
|---|---|---|
| Top-level failure propagation | `pub fn main() !void` — unhandled errors bubble to the Zig runtime, which prints the error name to stderr and exits with a non-zero code | `src/main.zig:46` |
| Zombie allocation failure | `spawnZombie` returns `!void`; called with `try spawnZombie(...)` — allocation errors propagate to `main` and terminate the process | `src/main.zig:113`, `src/main.zig:260` |
| Partial-allocation leak prevention | `errdefer allocator.destroy(new_zombie)` inside `spawnZombie` ensures the allocation is freed if subsequent initialisation fails | `src/main.zig:265` |
| Zombie reaches bottom of screen | `is_game_over = true` is set; the update phase is skipped on subsequent frames; the GAME OVER screen is rendered | `src/main.zig:176`, `src/main.zig:73` |
| Restart | `KEY_ENTER` on the GAME OVER screen resets all mutable state and calls `resetZombies` to free all heap-allocated `Zombie` structs | `src/main.zig:141–149` |

No error logging to files, no crash reporters, and no user-facing diagnostic messages beyond what the Zig runtime prints to stderr on a fatal error.

---

## 5. Request/Response Schemas

Not applicable. This project has no network communication layer and therefore no request or response message schemas.

For the in-memory data shape of the `Zombie` struct (the only persistent runtime data model), refer to **data-model.md** or the inline definition at `src/main.zig:27–35`.

---

## 6. Input Flow Diagram

The diagram below substitutes for a conventional API sequence diagram. It traces the path from a user keystroke through to either a zombie kill (with audio feedback) or a game-over condition.

```mermaid
sequenceDiagram
    participant User
    participant OS as OS / raylib event queue
    participant Loop as main game loop
    participant Input as Input handler
    participant Buffer as name[] buffer
    participant Update as updateZombies()
    participant Audio as raylib audio device

    User->>OS: Physical keystroke (printable ASCII 32–125)
    OS->>Loop: raylib polls via GetCharPressed() each frame
    Loop->>Input: mouse_on_text == true AND !is_game_over
    Input->>Buffer: Append character; null-terminate (src/main.zig:85–87)
    Buffer->>Update: typed_name slice = name[0..letter_count]

    alt Typed name matches a zombie's name
        Update->>Update: zomb.is_active = false (src/main.zig:194)
        Update->>Buffer: Reset: letter_count = 0, name[0] = 0 (src/main.zig:195–196)
        Update->>Audio: raylib.PlaySound(zombie_kill_sound) (src/main.zig:199)
        Audio-->>User: WAV playback via system audio device
    else Zombie reaches screen_height (y >= 450)
        Update->>Loop: is_game_over = true (src/main.zig:176)
        Loop-->>User: Renders "GAME OVER" + "Press ENTER to Restart" (src/main.zig:137–138)
    else No match yet
        Update->>Loop: Continue next frame; zombie y += speed
    end

    opt User presses KEY_BACKSPACE
        Input->>Buffer: letter_count -= 1; null-terminate (src/main.zig:94–96)
    end

    opt is_game_over AND User presses KEY_ENTER
        Loop->>Loop: is_game_over = false; reset state (src/main.zig:142–149)
        Loop->>Loop: resetZombies() — free all heap Zombie structs (src/main.zig:148)
    end
```

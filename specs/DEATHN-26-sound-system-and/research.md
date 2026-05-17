# Research: Sound System and Audio Settings Menu

**Feature Branch**: `DEATHN-26-sound-system-and`
**Date**: 2026-05-17

## Existing Files

### Source files that will be modified

| File | What it covers | Action |
|------|---------------|--------|
| `src/main.zig` (2547 lines) | Game loop, input handling, rendering, menus, pause, game state, power-up activation, zombie lifecycle | Extend: add sound triggers at keystroke (line 333–358), power-up activation (line 790–825), zombie kill (line 1001, 1250), wave/game-over transitions. Add `GameScreen.sound_settings` screen. Add music playback management in update/draw phases. Load new sound assets in `main()` (line 886–937). |
| `src/highscore.zig` (143 lines) | Dual-backend persistence (native binary + web localStorage) | Pattern reference: reuse the native/web dispatch pattern for SoundConfig persistence. Do NOT modify — create a new `src/sound_config.zig` following the same structure. |
| `src/zombie_types.zig` (87 lines) | Shared enums (ZombieType, GameMode, PowerUpType), spawn weight tables | Extend: add `SoundPack` and `ErrorPack` enums if needed by multiple modules. Otherwise keep sound types in `sound_config.zig`. |
| `src/raylib.zig` (16 lines) | C interop wrapper — `@cImport` for raylib.h, raymath.h, rlgl.h, emscripten.h | No changes needed — raylib audio API (LoadSound, PlaySound, SetSoundVolume, LoadMusicStream, PlayMusicStream, etc.) is already exposed via `raylib.h`. |

### Source files NOT modified

| File | Why untouched |
|------|---------------|
| `src/name_lists.zig` | Zombie name data — no audio concern |
| `src/boss_phrases.zig` | Boss phrase data — no audio concern |
| `src/zombie_names.zig` | Legacy name data — no audio concern |
| `src/web_root.zig` | Emscripten entry — no audio concern |
| `build.zig` | No new dependencies or build steps needed; raylib already links audio |

### Asset files (already committed)

| Path | Samples | Status |
|------|---------|--------|
| `assets/sounds/typewriter/1-6.wav` | 6 | Ready — typing pack |
| `assets/sounds/click/1-3.wav` | 3 | Ready — typing pack |
| `assets/sounds/hitmarker/1-3.wav` | 3 | Ready — typing pack |
| `assets/sounds/damage/1.wav` | 1 | Ready — error pack |
| `assets/sounds/square/1.wav` | 1 | Ready — error pack |
| `assets/sounds/missed-punch/1-2.wav` | 2 | Ready — error pack |
| `assets/sounds/bomb/1.wav` | 1 | Ready — power-up activation |
| `assets/sounds/freeze/1.wav` | 1 | Ready — power-up activation |
| `assets/sounds/shield/1.wav` | 1 | Ready — power-up activation |
| `assets/music/nightmare-pulse.wav` | 1 (88s) | Ready — background music |
| `assets/zombie-hit.wav` | 1 | Already loaded (line 895) — kill sound |

### Test files to extend

| File | Coverage | Action |
|------|----------|--------|
| `src/main.zig` (tests at line 2375+) | 50+ tests: input matching, wave config, state transitions, metrics, power-ups | Extend with: SoundConfig default values, toggle behavior, volume clamping, pack enum exhaustiveness, round-robin index wrapping |
| `src/highscore.zig` (tests at line 119+) | Disk size, web signatures, filenames, webKeys | Pattern reference for sound_config.zig tests |

### New files to create

| File | Justification |
|------|---------------|
| `src/sound_config.zig` | Constitution #1(b): dual-backend persistence (native binary + web localStorage) is a genuinely distinct concern — same split rationale as `highscore.zig`. Contains SoundConfig struct, default values, load/save with native + web backends. |
| `THIRD_PARTY_LICENSES` | FR-021: required before merge — GPL-3.0 attribution for Monkeytype sound packs, Pixabay Content License for music |

## Patterns to Follow

### 1. Paired Init/Load + defer Unload pattern (main.zig:891–896)

Every raylib resource is loaded and immediately paired with a `defer Unload...`:

```zig
// main.zig:891-896
raylib.InitAudioDevice();
defer raylib.CloseAudioDevice();
zombie_kill_sound = raylib.LoadSound("assets/zombie-hit.wav");
defer raylib.UnloadSound(zombie_kill_sound);
```

**How to apply**: All new `LoadSound` calls for typing packs, error packs, power-up sounds, and `LoadMusicStream` for background music MUST follow this exact pattern. For web builds where defers don't fire, the `cleanup_on_exit` function (line 876–884) must also be updated.

### 2. Dual-backend persistence dispatch (highscore.zig:40–53)

```zig
// highscore.zig:40-53
pub fn load(mode: GameMode) Record {
    if (comptime is_web) {
        return loadWeb(mode);
    }
    return loadNative(mode) catch Record{};
}

pub fn save(mode: GameMode, record: Record) void {
    if (comptime is_web) {
        saveWeb(mode, record);
        return;
    }
    saveNative(mode, record) catch {};
}
```

**How to apply**: `sound_config.zig` must use the identical comptime dispatch pattern: `load()` → `loadNative()` / `loadWeb()`, `save()` → `saveNative()` / `saveWeb()`. Native uses `std.c.fopen`/`fread`/`fwrite` with field-by-field little-endian serialization. Web uses `localStorage` via `emscripten_run_script`. Errors are caught and silently fall back to defaults (constitution: no network, no secrets).

### 3. Fixed-size binary serialization (highscore.zig:55–79)

```zig
// highscore.zig:69-79 (saveNative)
var buf: [DISK_SIZE]u8 = undefined;
std.mem.writeInt(u64, buf[0..8], record.score, .little);
std.mem.writeInt(u32, buf[8..12], record.wave, .little);
// ...
const n = std.c.fwrite(&buf, 1, DISK_SIZE, fp);
```

**How to apply**: SoundConfig native persistence must use the same field-by-field `std.mem.writeInt` / `std.mem.readInt` approach with a compile-time `DISK_SIZE` constant, not `@sizeOf(SoundConfig)` (which includes padding). Validate `DISK_SIZE` in a test.

### 4. Menu navigation pattern (main.zig:672–710)

```zig
// main.zig:672-694 (updatePause)
if (raylib.IsKeyPressed(raylib.KEY_UP)) {
    pause_selection = (pause_selection +% PAUSE_ITEM_COUNT -% 1) % PAUSE_ITEM_COUNT;
}
if (raylib.IsKeyPressed(raylib.KEY_DOWN)) {
    pause_selection = (pause_selection +% 1) % PAUSE_ITEM_COUNT;
}
if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
    switch (pause_selection) { ... }
}
```

**How to apply**: The Sound settings screen must use the same wrapping-modular-arithmetic navigation with UP/DOWN keys, ENTER for selection/toggle, ESCAPE to exit back. Use a `sound_menu_selection` variable and a `SOUND_MENU_ITEM_COUNT` constant.

### 5. drawMenu rendering pattern (main.zig:614–637)

```zig
// main.zig:621-628
for (MENU_ITEMS, 0..) |item, i| {
    const y = menu_start_y + @as(c_int, @intCast(i)) * menu_spacing;
    const color = if (i == menu_selection) CRT_ACCENT else CRT_DIM;
    var buf: [32]u8 = undefined;
    const prefix: []const u8 = if (i == menu_selection) "> " else "  ";
    const text = std.fmt.bufPrintZ(&buf, "{s}{s}", .{ prefix, item }) catch "???";
    drawCenteredText(text.ptr, y, 30, color);
}
```

**How to apply**: Sound settings rendering must follow the same CRT_ACCENT/CRT_DIM selected/unselected color scheme, `"> "` prefix for focused item, `drawCenteredText` for layout. Volume sliders render as `[====------]` style bars using the same color conventions.

### 6. Power-up activation dispatch (main.zig:790–825)

```zig
// main.zig:790-825
fn activatePowerUp(allocator: *std.mem.Allocator) void {
    if (held_power_up) |pu| {
        switch (pu) {
            .freeze => { freeze_timer = FREEZE_DURATION; },
            .bomb => { /* kill logic + PlaySound */ },
            .shield => { shield_active = true; },
        }
        held_power_up = null;
    }
}
```

**How to apply**: Add `PlaySound(freeze_sound)` / `PlaySound(bomb_sound)` / `PlaySound(shield_sound)` inside each switch arm, guarded by the power-up toggle check. The bomb arm already calls `PlaySound(zombie_kill_sound)` at line 817 — the new bomb activation sound is an ADDITIONAL play, not a replacement.

### 7. Keystroke input loop (main.zig:333–358)

```zig
// main.zig:333-358
var key = raylib.GetCharPressed();
while (key > 0) {
    if ((key >= 32) and (key <= 125)) {
        // ... letter_count guard, name buffer write ...
        if (typedMatchesAnyEnemy()) {
            correct_chars += 1;
        } else {
            wrong_chars += 1;
        }
    }
    key = raylib.GetCharPressed();
}
```

**How to apply**: Insert sound triggers at the correct/wrong branch points. After `correct_chars += 1` → play next typing pack sample (round-robin). After `wrong_chars += 1` → play error pack sound. Both guarded by their respective toggle checks.

### 8. GameScreen enum + screen state machine (main.zig:201–207, 289–470)

```zig
const GameScreen = enum { main_menu, wpm_select, playing, paused, game_over };
```

**How to apply**: Add `.sound_settings` variant. In `frame()`, add an update branch that calls `updateSoundSettings()` and a draw branch that calls `drawSoundSettings()`. Transition to `.sound_settings` from pause menu and main menu; ESCAPE returns to the previous screen.

## Decisions

### D-1: New module for sound config persistence

- **Decision**: Create `src/sound_config.zig` as a new sibling module
- **Rationale**: Constitution Code Patterns #1(b) explicitly endorses splitting when there's "a genuinely distinct concern with its own surface (e.g. dual-backend persistence)". SoundConfig has native file I/O + web localStorage, exactly paralleling `highscore.zig`.
- **Alternatives considered**: (a) Inline everything in main.zig — rejected because it would add ~150 lines of persistence logic to an already 2547-line file, and the dual-backend concern is identical to the rationale that justified `highscore.zig`. (b) Extend `highscore.zig` into a general "settings" module — rejected because highscore and sound config have different schemas, different file names, and different default-fallback behavior.

### D-2: Sound assets loaded as global variables in main.zig

- **Decision**: Load all sound handles as module-level `var` globals in `main.zig`, alongside `zombie_kill_sound` and `zombie_texture`
- **Rationale**: Follows existing pattern — all raylib resources are globals loaded once in `main()`. Constitution warns against "interfaces, registries, event buses" — a SoundManager abstraction would violate this.
- **Alternatives considered**: (a) Pass sound handles through FrameContext — rejected because FrameContext is already specific to text-box rendering and adding 20+ sound fields would bloat it. (b) A SoundManager struct — rejected per constitution "do not introduce indirection layers".

### D-3: Music loaded via LoadMusicStream (not LoadSound)

- **Decision**: Use `raylib.LoadMusicStream` for the background music track, `raylib.UpdateMusicStream` in the game loop
- **Rationale**: `LoadSound` loads the entire file into memory at once. The 88-second WAV at ~3.8MB would be fine for native, but `LoadMusicStream` streams from disk and is the raylib-idiomatic choice for music. It also provides `PauseMusicStream`/`ResumeMusicStream` which the spec requires (FR-007). On web/Emscripten, raylib's MusicStream works with preloaded files.
- **Alternatives considered**: `LoadSound` + manual pause tracking — rejected because raylib already provides the pause/resume API on MusicStream.

### D-4: Sound settings screen as new GameScreen variant

- **Decision**: Add `GameScreen.sound_settings` to the screen enum with `updateSoundSettings()` / `drawSoundSettings()` functions
- **Rationale**: Follows the exact pattern used for all existing screens (main_menu, wpm_select, playing, paused, game_over). The pause menu and main menu both need to route to it and back.
- **Alternatives considered**: (a) Overlay on top of pause screen — rejected because the settings UI has enough items (5 toggles, 2 selectors, 3 sliders) that it needs its own full-screen layout. (b) Sub-state within pause — rejected because the main menu also needs access (FR-015).

### D-5: Volume applied via SetSoundVolume per-play

- **Decision**: Call `raylib.SetSoundVolume(sound, volume)` before each `raylib.PlaySound(sound)` call, reading the current volume from the loaded SoundConfig
- **Rationale**: Raylib's `SetSoundVolume` sets volume on the Sound handle itself — it persists until changed. Setting it before each play ensures changes from the settings menu take effect immediately (FR: settings apply on next trigger) without needing a "refresh volumes" step.
- **Alternatives considered**: (a) Set volume once on load and re-set on settings change — adds complexity tracking which sounds need updating when a slider moves. (b) raylib `SetMasterVolume` — only one global knob, can't distinguish typing/effects/music.

### D-6: SoundConfig persistence format

- **Decision**: Native: fixed-size binary file `soundconfig.dat` (field-by-field little-endian, same as highscore.dat). Web: `localStorage` JSON under key `"death-note.soundconfig"`.
- **Rationale**: Mirrors the proven dual-backend pattern from `highscore.zig`. Binary on native avoids any string parsing; JSON on web works with the existing `emscripten_run_script` helpers.
- **Alternatives considered**: (a) JSON on both platforms — rejected because the project has no JSON parser for native Zig. (b) Shared binary format on both — rejected because web localStorage is string-only.

### D-7: Round-robin index stored as module-level global

- **Decision**: `var typing_round_robin: u8 = 0` and `var error_round_robin: u8 = 0` as module-level globals in main.zig
- **Rationale**: Follows the pattern of all other per-session counters (combo_count, wave_kills, spawn_timer). Reset to 0 when pack changes. Simple modular increment: `typing_round_robin = (typing_round_robin + 1) % pack_sample_count`.
- **Alternatives considered**: Embedding index in SoundConfig — rejected because round-robin position is ephemeral session state, not a persisted setting.

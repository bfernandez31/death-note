# Implementation Plan: Sound System and Audio Settings Menu

**Branch**: `DEATHN-26-sound-system-and` | **Date**: 2026-05-17 | **Spec**: `specs/DEATHN-26-sound-system-and/spec.md`
**Input**: Feature specification from `specs/DEATHN-26-sound-system-and/spec.md`

## Summary

Add a complete audio layer to the death-note typing game: keystroke feedback sounds (3 selectable packs with round-robin sample cycling), error sounds (3 packs), power-up activation sounds (bomb/freeze/shield), background music with seamless looping, a kill sound volume system, and a full Sound settings menu accessible from both pause and main menu. All settings are persisted via dual-backend storage (native binary file + web localStorage), following the `highscore.zig` persistence pattern. The implementation extends the existing game loop in `src/main.zig` and creates one new module `src/sound_config.zig` for settings persistence.

## Technical Context

**Language/Version**: Zig (0.16+, version determined by installed toolchain)
**Primary Dependencies**: raylib (pinned at commit `52f2a10`, linked as static library via `build.zig`)
**Storage**: Native binary file (`soundconfig.dat`) + web `localStorage` (`"death-note.soundconfig"`)
**Testing**: `zig build test` (Zig built-in test runner, wired in `build.zig`)
**Target Platform**: Native (Linux/macOS/Windows) + wasm32-emscripten (GitHub Pages)
**Project Type**: Single Zig project with raylib dependency
**Performance Goals**: Stable 60 FPS during sustained rapid typing (10+ chars/sec) with all sounds enabled (SC-006)
**Constraints**: No new dependencies — raylib audio API covers all needs. All sound assets already committed. Asset paths are literals (constitution Security #4).
**Scale/Scope**: ~22 sound files to load, 1 music stream, 1 new 10-byte persistence file, 1 new settings screen with 10 menu items

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Rule | Status | Notes |
|---|------|--------|-------|
| CP-1 | Single-module game loop; split only for (a) dedup, (b) distinct concern, (c) pure data | PASS | Only new module is `sound_config.zig` — justified under (b): dual-backend persistence, same rationale as `highscore.zig` |
| CP-1 | Dependency direction: siblings MUST NOT import main.zig | PASS | `sound_config.zig` imports only `std`, `raylib.zig`. No circular deps. |
| CP-2 | C interop stays walled off in raylib.zig | PASS | No new `@cImport` calls. All raylib audio API accessed via existing `raylib.zig` |
| CP-3 | Named constants for tunables | PASS | All volume defaults, sample counts, menu dimensions declared as `const` |
| CP-4 | Paired Init/Load + defer Close/Unload | PASS | Every LoadSound/LoadMusicStream paired with defer Unload; cleanup_on_exit updated for web |
| CP-5 | Optional pointers unwrapped with `if (x) \|val\|` | PASS | No new optional pointers needed |
| CP-6 | Allocator passed by pointer parameter | N/A | Sound system uses no heap allocation — all sounds are raylib-managed |
| CP-7 | Fixed-size pools, not dynamic lists | PASS | Sound arrays are fixed-size at comptime; no dynamic allocation |
| TS-1 | Framework: zig build test | PASS | All new tests use standard `test "..." { }` blocks |
| TS-2 | Test location: in the module under test | PASS | sound_config.zig tests in sound_config.zig; main.zig tests extend existing block |
| TS-3 | Pure logic has tests; raylib calls tested manually | PASS | Config defaults, validation, round-robin, persistence format tested. Audio playback verified via `zig build run`. |
| TS-4 | No e2e harness; manual requirements documented | PASS | Plan includes Manual Requirements section |
| TS-5 | Determinism in tests | PASS | No PRNG usage in sound system tests |
| SP-1 | No secrets, no network | PASS | Only local file I/O + localStorage. No network. |
| SP-2 | Bounded input buffers | N/A | Sound settings use fixed enum/u8 ranges, not text input |
| SP-3 | Null-terminated C strings | N/A | No new C-string handling |
| SP-4 | Asset paths are literals | PASS | All LoadSound/LoadMusicStream paths are string literals |
| SP-5 | Pinned dependency hash | PASS | No dependency changes |
| CQ-1 | zig build is the gate | PASS | |
| CQ-2 | Idiomatic error handling | PASS | sound_config load returns defaults on error; save catches silently |
| CQ-3 | Naming discipline | PASS | snake_case vars, camelCase fns, PascalCase types, SCREAMING consts |
| CQ-4 | Comments explain intent | PASS | |
| CQ-5 | No unused imports/dead code | PASS | |
| G-5 | Agent: no change to pinned raylib, no network, no removal of defer cleanup | PASS | |

**Gate result**: ALL PASS — no violations.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-26-sound-system-and/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output: codebase inventory, patterns, decisions
├── data-model.md        # Phase 1 output: entity definitions, persistence format
└── checklists/          # Existing checklists directory
```

### Source Code (repository root)

```
src/
├── main.zig             # MODIFY: load sounds, wire triggers, add settings screen, music management
├── sound_config.zig     # NEW: SoundConfig struct, TypingPack/ErrorPack enums, load/save persistence
├── highscore.zig        # UNCHANGED (pattern reference only)
├── zombie_types.zig     # UNCHANGED
├── raylib.zig           # UNCHANGED
├── name_lists.zig       # UNCHANGED
├── boss_phrases.zig     # UNCHANGED
├── zombie_names.zig     # UNCHANGED
└── web_root.zig         # UNCHANGED

assets/
├── music/
│   └── nightmare-pulse.wav    # EXISTING: background music (88s loop)
├── sounds/
│   ├── click/1-3.wav          # EXISTING: typing pack
│   ├── typewriter/1-6.wav     # EXISTING: typing pack
│   ├── hitmarker/1-3.wav      # EXISTING: typing pack
│   ├── damage/1.wav           # EXISTING: error pack
│   ├── square/1.wav           # EXISTING: error pack
│   ├── missed-punch/1-2.wav   # EXISTING: error pack
│   ├── bomb/1.wav             # EXISTING: power-up SFX
│   ├── freeze/1.wav           # EXISTING: power-up SFX
│   └── shield/1.wav           # EXISTING: power-up SFX
└── zombie-hit.wav             # EXISTING: kill sound

THIRD_PARTY_LICENSES           # NEW: GPL-3.0 + Pixabay attribution (FR-021)
```

**Structure Decision**: Single project. One new `src/sound_config.zig` module for persistence, all other changes in `src/main.zig`. No new directories under `src/`.

## Implementation Phases

### Phase 1: Sound Config Persistence (`src/sound_config.zig`)

**Goal**: Create the SoundConfig data type and dual-backend persistence, fully testable without raylib.

**Files**: `src/sound_config.zig` (NEW), `src/main.zig` (add `@import`)

**Steps**:
1. Create `src/sound_config.zig` with:
   - `TypingPack` enum (u8 backing: click=0, typewriter=1, hitmarker=2)
   - `ErrorPack` enum (u8 backing: damage=0, square=1, missed_punch=2)
   - `SoundConfig` struct with defaults matching FR-018
   - `DISK_SIZE = 10` constant
   - `load()` / `save()` dispatching to native/web via `comptime is_web`
   - `loadNative()` / `saveNative()` using `std.c.fopen` + field-by-field `std.mem.readInt`/`writeInt` (pattern: `highscore.zig:55–79`)
   - `loadWeb()` / `saveWeb()` using `emscripten_run_script` (pattern: `highscore.zig:96–117`)
   - Validation: clamp volume to 0..20, validate enum ordinals, fallback to defaults on any failure
2. Add `@import("sound_config.zig")` to `src/main.zig` (near line 8, alongside `highscore` import)
3. Add `var sound_cfg: sound_config.SoundConfig = undefined;` as module-level global
4. In `main()`, after highscore load (line 909): `sound_cfg = sound_config.load();`

**Tests** (in `sound_config.zig`):
- `DISK_SIZE` equals 10
- Default SoundConfig values match FR-018 (typewriter, damage, 14/16/10, all toggles true)
- Volume clamping: value 25 clamps to 20, value 255 clamps to 20
- Invalid enum ordinal falls back to default
- `TypingPack` has 3 variants, `ErrorPack` has 3 variants
- Load/save function signatures stay wired (same pattern as highscore tests)

**Constitution compliance**: CP-1(b) split for dual-backend persistence. No main.zig import. All naming conventions followed.

### Phase 2: Sound Asset Loading

**Goal**: Load all sound files and music stream in `main()`, paired with defers.

**Files**: `src/main.zig`

**Steps**:
1. Declare module-level sound handle globals (after `zombie_kill_sound` at line 245):
   - `click_sounds: [3]raylib.Sound`
   - `typewriter_sounds: [6]raylib.Sound`
   - `hitmarker_sounds: [3]raylib.Sound`
   - `damage_sounds: [1]raylib.Sound`
   - `square_sounds: [1]raylib.Sound`
   - `missed_punch_sounds: [2]raylib.Sound`
   - `bomb_sound: raylib.Sound`
   - `freeze_sound: raylib.Sound`
   - `shield_sound: raylib.Sound`
   - `music: raylib.Music`
2. In `main()`, after existing `LoadSound` (line 895), add load calls for each sound:
   - Each `LoadSound` immediately followed by `defer raylib.UnloadSound(...)` (pattern: line 895–896)
   - `LoadMusicStream("assets/music/nightmare-pulse.wav")` + `defer raylib.UnloadMusicStream(music)`
   - Set `music.looping = true` after load
3. Update `cleanup_on_exit()` (line 876–884) to unload all new sounds for web builds
4. Declare round-robin state: `var typing_round_robin: u8 = 0;` and `var error_round_robin: u8 = 0;`

**Tests**: Asset loading is raylib-dependent — verified manually. Add compile-time tests for sample count constants matching array sizes.

### Phase 3: Keystroke and Error Sound Triggers

**Goal**: Play typing feedback and error sounds in the input loop (User Story 1, FR-001–003).

**Files**: `src/main.zig`

**Steps**:
1. Create helper `fn playTypingSound()` that:
   - Checks `sound_cfg.keystrokes_enabled` (FR-019)
   - Gets the active pack's sound array and sample count based on `sound_cfg.typing_pack`
   - Calls `raylib.SetSoundVolume(sound, @as(f32, @floatFromInt(sound_cfg.typing_volume)) * 0.05)` (D-5)
   - Calls `raylib.PlaySound(sound)` on the current round-robin sample
   - Advances `typing_round_robin` with modular wrap (FR-002)
2. Create helper `fn playErrorSound()` that:
   - Checks `sound_cfg.errors_enabled` (FR-019)
   - Same pattern as above for error pack
   - Advances `error_round_robin`
3. In the keystroke loop (line 333–358):
   - After `correct_chars += 1` (line 347): call `playTypingSound()`
   - After `wrong_chars += 1` (lines 349, 353): call `playErrorSound()`
4. Handle rapid input (FR-020): raylib handles concurrent `PlaySound` natively via multi-channel mixing — no special code needed. Verify via manual testing.

**Tests**:
- Round-robin wrapping: after N calls, index returns to 0 (test with mock counter logic)
- Pack sample count lookup returns correct value for each enum variant

### Phase 4: Kill Sound Integration

**Goal**: Route existing kill sound through the volume/toggle system (User Story 5, FR-004).

**Files**: `src/main.zig`

**Steps**:
1. Create helper `fn playKillSound()` that:
   - Checks `sound_cfg.kills_enabled` (FR-019)
   - Calls `raylib.SetSoundVolume(zombie_kill_sound, @as(f32, @floatFromInt(sound_cfg.effects_volume)) * 0.05)`
   - Calls `raylib.PlaySound(zombie_kill_sound)`
2. Replace all 3 existing `raylib.PlaySound(zombie_kill_sound)` calls:
   - Line 817 (bomb kills) → `playKillSound()` — plays once, not per zombie (FR: bomb kills play once)
   - Line 1001 (standard zombie kill) → `playKillSound()`
   - Line 1250 (boss kill) → `playKillSound()`

**Tests**: No new tests — behavior is toggle/volume gating only, tested via manual verification.

### Phase 5: Power-Up Activation Sounds

**Goal**: Add distinct sounds per power-up type (User Story 3, FR-005).

**Files**: `src/main.zig`

**Steps**:
1. Create helper `fn playPowerUpSound(pu_type: PowerUpType)` that:
   - Checks `sound_cfg.power_ups_enabled` (FR-019)
   - Sets volume: `raylib.SetSoundVolume(sound, @as(f32, @floatFromInt(sound_cfg.effects_volume)) * 0.05)`
   - Plays the type-specific sound: freeze → `freeze_sound`, bomb → `bomb_sound`, shield → `shield_sound`
2. In `activatePowerUp()` (line 790–825):
   - At the top of the function, before the switch: `playPowerUpSound(pu)` — plays regardless of which branch runs
   - The bomb arm already plays `zombie_kill_sound` at line 817 — this is retained as a separate kill sound event

**Tests**: No new logic to unit test. Manual verification of each power-up sound.

### Phase 6: Background Music

**Goal**: Seamless music loop during gameplay with pause/resume support (User Story 2, FR-006–007).

**Files**: `src/main.zig`

**Steps**:
1. In `startGame()` (line 845): if `sound_cfg.music_enabled`, call:
   - `raylib.SetMusicVolume(music, @as(f32, @floatFromInt(sound_cfg.music_volume)) * 0.05)`
   - `raylib.StopMusicStream(music)` (reset to start if replaying)
   - `raylib.PlayMusicStream(music)`
2. In the `.playing` update phase (line 298): call `raylib.UpdateMusicStream(music)` every frame to feed the audio buffer and enable seamless looping
3. When transitioning to `.paused` (line 323–325): call `raylib.PauseMusicStream(music)` (FR-007)
4. When resuming from pause (updatePause, line 681): call `raylib.ResumeMusicStream(music)` (FR-007)
5. When game ends (dying_timer expires, line 424–425): call `raylib.StopMusicStream(music)` (ARD-4)
6. When quitting to menu from pause (line 684–689): call `raylib.StopMusicStream(music)` (ARD-4)
7. Music toggle off: `raylib.StopMusicStream(music)`. Music toggle on during gameplay: play from start.
8. Configure looping: `music.looping = true` after `LoadMusicStream` (raylib auto-loops when this is set)

**Tests**: Music streaming is raylib-dependent — manual verification. Test: listen through 3+ consecutive loops to verify seamless loop point (SC-002).

### Phase 7: Sound Settings Screen

**Goal**: Full settings UI accessible from pause menu and main menu (User Story 4, FR-008–016).

**Files**: `src/main.zig`

**Steps**:
1. Add `sound_settings` to `GameScreen` enum (line 201–207)
2. Add module-level state: `var sound_menu_selection: u8 = 0;` and `var sound_menu_return_screen: GameScreen = .paused;`
3. Add "SOUND" item to `PAUSE_ITEMS` (line 584): `["RESUME", "SOUND", "QUIT TO MENU"]`, update `PAUSE_ITEM_COUNT` to 3
4. Add "SOUND" item to `MENU_ITEMS` (line 582): `["SURVIVAL", "ZEN", "SOUND", "QUIT"]`, update `MENU_ITEM_COUNT` to 4
5. Update `updateMenu()` selection indices (line 594–611) to handle the new item routing to `.sound_settings`
6. Update `updatePause()` selection indices (line 679–693) to handle the new item routing to `.sound_settings`
7. Create `fn updateSoundSettings()`:
   - UP/DOWN: navigate `sound_menu_selection` (0..9, wrapping)
   - ENTER: toggle boolean items (toggles 0,3,5,6,8)
   - LEFT/RIGHT: for pack selectors (items 1,4), cycle enum. For sliders (items 2,7,9), adjust ±1 step clamped to 0..20
   - ESCAPE: save config via `sound_config.save(sound_cfg)`, return to `sound_menu_return_screen`
   - On pack change: reset corresponding round-robin index to 0
   - On focus change for pack selectors: play preview sample (ARD-5) at 50% of typing volume (min 30% if slider is 0)
   - On slider release (key up after LEFT/RIGHT): play representative sound at new volume (FR-014)
8. Create `fn drawSoundSettings()`:
   - Title: "SOUND SETTINGS" in CRT_FG
   - 10 menu items rendered with selected/unselected CRT_ACCENT/CRT_DIM pattern (pattern: `drawMenu`, line 621–628)
   - Toggles: show `[ON]` / `[OFF]`
   - Pack selectors: show current pack name with `< name >` arrows
   - Volume sliders: render as `[████░░░░░░░░░░░░░░░░] 70%` bar using CRT_ACCENT fill / CRT_DIM empty
   - Footer: "ESC: BACK" hint in CRT_DIM
9. Wire into `frame()`:
   - Update phase (after `.paused` branch at line 458): add `.sound_settings => { updateSoundSettings(); }`
   - Draw phase (after `.paused` branch at line 526): add `.sound_settings => { drawSoundSettings(); }`

**Tests**:
- Sound menu selection wraps correctly (0 → 9 → 0)
- Volume step clamping: can't go below 0 or above 20

### Phase 8: THIRD_PARTY_LICENSES File

**Goal**: Satisfy FR-021 — GPL-3.0 and Pixabay attribution before merge.

**Files**: `THIRD_PARTY_LICENSES` (NEW, repo root)

**Steps**:
1. Create `THIRD_PARTY_LICENSES` at repo root documenting:
   - Monkeytype-sourced WAV files: GPL-3.0 license, attribution, which files are covered
   - nightmare-pulse.wav: Pixabay Content License, attribution
   - Links to original sources

### Phase 9: Integration Testing & Polish

**Goal**: Verify all audio features work together, no regressions.

**Steps**:
1. Run `zig build test` — all unit tests pass
2. Run `zig build` — clean compile, no warnings
3. Manual testing checklist (see Manual Requirements below)

## Testing Strategy

### Unit Tests (automated via `zig build test`)

**Extend** `src/main.zig` tests (line 2375+):
- Round-robin index wrapping for typing and error packs
- Pack sample count correctness per enum variant
- Sound menu selection wrapping (0..9)
- Volume step clamping (0..20 bounds)

**New** `src/sound_config.zig` tests:
- `DISK_SIZE` stability (10 bytes)
- Default values match FR-018
- Volume clamping on invalid input
- Enum validation with fallback
- Enum variant counts (3 each)
- Load/save function signature wiring

### Manual Requirements

Verify with `zig build run`:

1. **Keystroke sounds**: Type correct letters → hear typing pack sounds cycling. Type wrong letter → hear error sound. Toggle off → silence. Switch packs mid-game → new sounds on next keystroke.
2. **Music**: Starts on game begin. Loops seamlessly (listen through 3+ loops). Pauses on ESC. Resumes on unpause. Stops on game-over and quit-to-menu.
3. **Kill sounds**: Kill a zombie → hear kill sound at effects volume. Toggle off → silence. Bomb kills → one kill sound (not per zombie).
4. **Power-up sounds**: Activate each power-up → hear distinct sound. Toggle off → silence.
5. **Settings menu**: Open from pause (ESC → SOUND) and from main menu. Navigate all 10 items. Toggle each category. Cycle packs with preview. Adjust each slider. ESC saves and returns.
6. **Persistence**: Change settings, quit, relaunch → settings preserved. Delete `soundconfig.dat` → defaults restored.
7. **Performance**: Type rapidly (10+ chars/sec) with all sounds on → stable 60 FPS (SC-006).
8. **Web build**: `zig build web` compiles. Music and sounds work in browser. Settings persist in localStorage.

## Complexity Tracking

No constitution violations — table not needed.

## Dependency Order

```
Phase 1 (sound_config.zig)
    │
    ▼
Phase 2 (asset loading)
    │
    ├──────────────┬──────────────┐
    ▼              ▼              ▼
Phase 3        Phase 4        Phase 5
(keystrokes)   (kill sound)   (power-ups)
    │              │              │
    └──────────────┴──────────────┘
                   │
                   ▼
              Phase 6 (music)
                   │
                   ▼
              Phase 7 (settings UI)
                   │
                   ▼
              Phase 8 (licenses)
                   │
                   ▼
              Phase 9 (integration)
```

Phases 3, 4, 5 are independent of each other and can be implemented in any order after Phase 2. Phase 6 (music) depends on Phase 2. Phase 7 (settings UI) depends on all sound triggers being wired (Phases 3–6) so the settings screen can control them. Phase 8 is independent but blocked before merge.

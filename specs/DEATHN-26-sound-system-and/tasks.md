# Tasks: Sound System and Audio Settings Menu

**Feature**: DEATHN-26 — Sound system and audio settings menu
**Branch**: `DEATHN-26-sound-system-and`
**Generated**: 2026-05-17
**Spec**: `specs/DEATHN-26-sound-system-and/spec.md`
**Plan**: `specs/DEATHN-26-sound-system-and/plan.md`

## Phase 1: Setup

- [X] T001 Create `src/sound_config.zig` with `TypingPack` enum (u8 backing: click=0, typewriter=1, hitmarker=2), `ErrorPack` enum (u8 backing: damage=0, square=1, missed_punch=2), `SoundConfig` struct with all default values per FR-018, and `DISK_SIZE = 10` constant
- [X] T002 Implement `loadNative() !SoundConfig` and `saveNative(cfg: SoundConfig) !void` in `src/sound_config.zig` using `std.c.fopen`/`fread`/`fwrite` with field-by-field little-endian serialization (10-byte binary format per data-model.md), following the pattern in `src/highscore.zig:55–79`
- [X] T003 Implement `loadWeb() SoundConfig` and `saveWeb(cfg: SoundConfig) void` in `src/sound_config.zig` using `emscripten_run_script` with `localStorage` JSON under key `"death-note.soundconfig"`, following the pattern in `src/highscore.zig:96–117`
- [X] T004 Implement public `load() SoundConfig` and `save(cfg: SoundConfig) void` dispatchers in `src/sound_config.zig` using `comptime is_web` to route to native/web backends, with validation: clamp volumes to 0..20, validate enum ordinals with fallback to defaults, return `SoundConfig{}` on any load failure
- [X] T005 Add `@import("sound_config.zig")` to `src/main.zig` (near line 8, alongside highscore import), declare `var sound_cfg: sound_config.SoundConfig = undefined;` as module-level global, and call `sound_cfg = sound_config.load();` in `main()` after highscore loads (after line 909)

### Phase 1 Tests

- [X] T006 [P] Add tests in `src/sound_config.zig`: `DISK_SIZE` equals 10, default `SoundConfig{}` values match FR-018 (typewriter pack, damage pack, typing_volume=14, effects_volume=16, music_volume=10, all toggles true), `TypingPack` has 3 variants, `ErrorPack` has 3 variants
- [X] T007 [P] Add tests in `src/sound_config.zig`: volume clamping (value 25 clamps to 20, value 255 clamps to 20), invalid enum ordinal (e.g. ordinal 5) falls back to default, load/save function signatures stay wired (same pattern as `src/highscore.zig:123–126`)

## Phase 2: Foundational — Sound Asset Loading

- [X] T008 Declare module-level sound handle globals in `src/main.zig` (after `zombie_kill_sound` at line 245): `click_sounds: [3]raylib.Sound`, `typewriter_sounds: [6]raylib.Sound`, `hitmarker_sounds: [3]raylib.Sound`, `damage_sounds: [1]raylib.Sound`, `square_sounds: [1]raylib.Sound`, `missed_punch_sounds: [2]raylib.Sound`, `bomb_sound: raylib.Sound`, `freeze_sound: raylib.Sound`, `shield_sound: raylib.Sound`, `music: raylib.Music`
- [X] T009 Declare sample count constants in `src/main.zig`: `CLICK_SAMPLE_COUNT = 3`, `TYPEWRITER_SAMPLE_COUNT = 6`, `HITMARKER_SAMPLE_COUNT = 3`, `DAMAGE_SAMPLE_COUNT = 1`, `SQUARE_SAMPLE_COUNT = 1`, `MISSED_PUNCH_SAMPLE_COUNT = 2`
- [X] T010 In `main()` of `src/main.zig`, after existing `LoadSound` (line 895), add `LoadSound` calls for all 22 sound files with literal asset paths (`"assets/sounds/click/1.wav"` through `"assets/sounds/shield/1.wav"`), each immediately followed by `defer raylib.UnloadSound(...)`, following the paired load/defer pattern at lines 895–896
- [X] T011 In `main()` of `src/main.zig`, add `LoadMusicStream("assets/music/nightmare-pulse.wav")` with `defer raylib.UnloadMusicStream(music)`, and set `music.looping = true` after load
- [X] T012 Update `cleanup_on_exit()` in `src/main.zig` (line 879–884) to unload all new sounds and music stream for web builds
- [X] T013 Declare round-robin state in `src/main.zig`: `var typing_round_robin: u8 = 0;` and `var error_round_robin: u8 = 0;`

### Phase 2 Tests

- [X] T014 [P] Add tests in `src/main.zig`: sample count constants match array sizes (e.g. `CLICK_SAMPLE_COUNT == 3`, `TYPEWRITER_SAMPLE_COUNT == 6`, etc.)

## Phase 3: User Story 1 — Keystroke Audio Feedback (P1)

**Story Goal**: Play typing pack sounds on correct keystrokes and error pack sounds on mistyped letters, cycling through samples with round-robin selection.

**Independent Test**: Start a game with default settings. Type correct letters → hear typewriter clicks cycling. Type wrong letter → hear damage sound. Toggle sounds off → silence.

- [ ] T015 [US1] Create helper `fn getTypingSounds() []raylib.Sound` in `src/main.zig` that returns the active pack's sound slice based on `sound_cfg.typing_pack` (click_sounds, typewriter_sounds, or hitmarker_sounds)
- [ ] T016 [US1] Create helper `fn getTypingSampleCount() u8` in `src/main.zig` that returns the sample count for the active typing pack
- [ ] T017 [US1] Create helper `fn playTypingSound()` in `src/main.zig` that checks `sound_cfg.keystrokes_enabled`, gets active pack sounds, calls `SetSoundVolume` with `sound_cfg.typing_volume * 0.05`, calls `PlaySound` on current round-robin sample, and advances `typing_round_robin` with modular wrap
- [ ] T018 [US1] Create helper `fn getErrorSounds() []raylib.Sound` in `src/main.zig` that returns the active error pack's sound slice based on `sound_cfg.error_pack`
- [ ] T019 [US1] Create helper `fn getErrorSampleCount() u8` in `src/main.zig` that returns the sample count for the active error pack
- [ ] T020 [US1] Create helper `fn playErrorSound()` in `src/main.zig` that checks `sound_cfg.errors_enabled`, gets active error sounds, calls `SetSoundVolume` with `sound_cfg.typing_volume * 0.05`, calls `PlaySound`, and advances `error_round_robin` with modular wrap
- [ ] T021 [US1] Wire `playTypingSound()` after `correct_chars += 1` (line 347) and `playErrorSound()` after both `wrong_chars += 1` sites (lines 349 and 353) in the keystroke input loop of `src/main.zig`

### Phase 3 Tests

- [ ] T022 [P] [US1] Add tests in `src/main.zig`: round-robin wrapping — verify `(index + 1) % count` returns to 0 for each pack sample count (3, 6, 3, 1, 1, 2)
- [ ] T023 [P] [US1] Add tests in `src/main.zig`: `getTypingSampleCount()` returns correct value for each `TypingPack` variant, `getErrorSampleCount()` returns correct value for each `ErrorPack` variant

## Phase 4: User Story 2 — Background Music Loop (P1)

**Story Goal**: Play seamless background music during gameplay with pause/resume support and game-over stop.

**Independent Test**: Start a game. Music begins. Let it loop 3+ times — no gap. Pause → music pauses. Resume → music resumes. Game over → music stops.

- [ ] T024 [US2] In `startGame()` (line 845) of `src/main.zig`, add: if `sound_cfg.music_enabled`, call `SetMusicVolume(music, sound_cfg.music_volume * 0.05)`, `StopMusicStream(music)` (reset), `PlayMusicStream(music)`
- [ ] T025 [US2] In the `.playing` update phase (line 298) of `src/main.zig`, add `raylib.UpdateMusicStream(music)` call every frame to feed the audio buffer for seamless looping
- [ ] T026 [US2] In `src/main.zig`, add `raylib.PauseMusicStream(music)` when transitioning to `.paused` (at the `KEY_ESCAPE` handler, line 323–325)
- [ ] T027 [US2] In `updatePause()` of `src/main.zig`, add `raylib.ResumeMusicStream(music)` when resume is selected (line 682, the `0 =>` branch)
- [ ] T028 [US2] In `src/main.zig`, add `raylib.StopMusicStream(music)` when dying_timer expires and transitions to game_over (line 424–425) and when quitting to menu from pause (line 684–689)

## Phase 5: User Story 3 — Power-Up Activation Sounds (P2)

**Story Goal**: Play a distinct activation sound for each power-up type (Bomb, Freeze, Shield) when triggered.

**Independent Test**: Collect each power-up and activate. Hear distinct sounds per type. Toggle off → silence.

- [ ] T029 [US3] Create helper `fn playPowerUpSound(pu_type: PowerUpType)` in `src/main.zig` that checks `sound_cfg.power_ups_enabled`, sets volume via `SetSoundVolume` with `sound_cfg.effects_volume * 0.05`, and plays type-specific sound (freeze→freeze_sound, bomb→bomb_sound, shield→shield_sound)
- [ ] T030 [US3] Wire `playPowerUpSound(pu)` at the top of `activatePowerUp()` in `src/main.zig` (line 791, before the switch statement), so it fires regardless of which power-up branch runs

## Phase 6: User Story 5 — Kill Sound Feedback (P3)

**Story Goal**: Route the existing kill sound through the volume/toggle system so it respects settings.

**Independent Test**: Kill a zombie → hear kill sound. Toggle off → silence. Adjust effects volume → volume changes.

- [ ] T031 [US5] Create helper `fn playKillSound()` in `src/main.zig` that checks `sound_cfg.kills_enabled`, calls `SetSoundVolume(zombie_kill_sound, sound_cfg.effects_volume * 0.05)`, and calls `PlaySound(zombie_kill_sound)`
- [ ] T032 [US5] Replace all 3 existing `raylib.PlaySound(zombie_kill_sound)` calls in `src/main.zig` with `playKillSound()`: line 817 (bomb kills), line 1001 (standard zombie kill), line 1250 (boss kill)

## Phase 7: User Story 4 — Sound Settings Menu (P2)

**Story Goal**: Full settings UI with 10 items (5 toggles, 2 pack selectors, 3 volume sliders) accessible from pause and main menu, with immediate preview and session persistence.

**Independent Test**: Open Sound from pause menu. Navigate all items. Toggle each category. Cycle packs with preview. Adjust sliders. ESC saves and returns. Quit and relaunch → settings preserved.

- [ ] T033 [US4] Add `sound_settings` to `GameScreen` enum in `src/main.zig` (line 201–207)
- [ ] T034 [US4] Add module-level state in `src/main.zig`: `var sound_menu_selection: u8 = 0;`, `var sound_menu_return_screen: GameScreen = .paused;`, and `const SOUND_MENU_ITEM_COUNT: u8 = 10;`
- [ ] T035 [US4] Update `MENU_ITEMS` to `["SURVIVAL", "ZEN", "SOUND", "QUIT"]` and `MENU_ITEM_COUNT` to 4 in `src/main.zig` (line 582–583)
- [ ] T036 [US4] Update `PAUSE_ITEMS` to `["RESUME", "SOUND", "QUIT TO MENU"]` and `PAUSE_ITEM_COUNT` to 3 in `src/main.zig` (line 584–585)
- [ ] T037 [US4] Update `updateMenu()` switch indices in `src/main.zig` (line 594–611): 0=SURVIVAL, 1=ZEN, 2=set `sound_menu_return_screen = .main_menu` then `current_screen = .sound_settings`, 3=QUIT
- [ ] T038 [US4] Update `updatePause()` switch indices in `src/main.zig` (line 679–693): 0=RESUME, 1=set `sound_menu_return_screen = .paused` then `current_screen = .sound_settings`, 2=QUIT TO MENU
- [ ] T039 [US4] Create `fn updateSoundSettings()` in `src/main.zig`: UP/DOWN navigate `sound_menu_selection` (0..9 wrapping), ENTER toggles boolean items (indices 0,3,5,6,8), LEFT/RIGHT cycles pack selectors (indices 1,4) and adjusts volume sliders ±1 step clamped 0..20 (indices 2,7,9), ESCAPE saves via `sound_config.save(sound_cfg)` and returns to `sound_menu_return_screen`
- [ ] T040 [US4] In `updateSoundSettings()`: on pack change reset corresponding round-robin to 0; on pack selector focus change play preview sample at 50% of typing volume (min 30% if slider is 0); on slider key release play representative sound at new volume (FR-014)
- [ ] T041 [US4] Create `fn drawSoundSettings()` in `src/main.zig`: title "SOUND SETTINGS" in CRT_FG, 10 items with CRT_ACCENT/CRT_DIM selected/unselected pattern (matching `drawMenu` at line 621–628), toggles show `[ON]`/`[OFF]`, pack selectors show `< name >` arrows, volume sliders render as filled/empty bar with percentage, footer "ESC: BACK" in CRT_DIM
- [ ] T042 [US4] Wire `updateSoundSettings()` and `drawSoundSettings()` into `frame()` of `src/main.zig`: add `.sound_settings` branches in both the update phase (after `.paused` at line 458) and draw phase (after `.paused` draw branch)

### Phase 7 Tests

- [ ] T043 [P] [US4] Add tests in `src/main.zig`: sound menu selection wraps correctly (0 → 9 → 0 with modular arithmetic), volume step clamping (can't go below 0 or above 20)

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T044 Create `THIRD_PARTY_LICENSES` file at repo root documenting GPL-3.0 attribution for Monkeytype-sourced WAV files (click, typewriter, hitmarker packs) and Pixabay Content License for `assets/music/nightmare-pulse.wav`, with links to original sources (FR-021)
- [ ] T045 Run `zig build test` — verify all existing and new unit tests pass in `src/main.zig` and `src/sound_config.zig`
- [ ] T046 Run `zig build` — verify clean compile with no warnings
- [ ] T047 Manual integration test: verify keystroke sounds, error sounds, music loop (3+ loops), pause/resume, kill sounds, power-up sounds, settings menu navigation, persistence across restart, and 60 FPS under rapid input per the Manual Requirements in plan.md

## Dependencies

```
Phase 1 (T001–T007): Setup — sound_config.zig
    │
    ▼
Phase 2 (T008–T014): Foundational — asset loading
    │
    ├──────────────────┬──────────────────┐
    ▼                  ▼                  ▼
Phase 3 (T015–T023)  Phase 4 (T024–T028) Phase 5 (T029–T030)
US1: Keystrokes      US2: Music          US3: Power-ups
    │                  │                  │
    ├──────────────────┴──────────────────┤
    ▼                                     ▼
Phase 6 (T031–T032)                Phase 7 (T033–T043)
US5: Kill sounds                   US4: Settings menu
    │                                     │
    └──────────────┬──────────────────────┘
                   ▼
             Phase 8 (T044–T047)
             Polish & integration
```

### Key Constraints

- **Phase 2 blocks everything**: All sound trigger phases need loaded sound handles.
- **Phase 7 (settings UI) depends on Phases 3–6**: The settings screen needs all sound triggers wired so toggles/sliders have observable effects.
- **Phases 3, 4, 5 are independent**: Can be implemented in any order after Phase 2.
- **Phase 6 (kill sounds) is independent of Phases 3–5** but logically follows them.

## Parallel Execution Opportunities

### Within Phase 1
- T006 and T007 (tests) can be written in parallel once T001–T004 are complete.

### After Phase 2
- **Phase 3** (US1: keystrokes), **Phase 4** (US2: music), and **Phase 5** (US3: power-ups) can all be implemented in parallel — they modify different functions/locations in `src/main.zig` with no overlapping lines.

### Within Phase 7
- T033–T036 (enum + menu items) can be done as a batch, then T037–T038 (routing), then T039–T042 (settings logic/rendering).

### Test tasks marked [P]
- T006, T007, T014, T022, T023, T043 are all independently writable once their corresponding implementation tasks are done.

## Implementation Strategy

### MVP Scope (User Stories 1 + 2)
Phases 1–4 deliver the core audio experience: keystroke sounds and background music. This is a playable, testable increment that covers the two P1 stories.

### Incremental Delivery
1. **MVP**: Phases 1–4 (keystrokes + music) — P1 stories complete
2. **+Power-ups**: Phase 5 — adds P2 activation sounds
3. **+Kill sounds**: Phase 6 — integrates existing kill sound into volume system (P3)
4. **+Settings UI**: Phase 7 — full player control over all audio (P2)
5. **+Polish**: Phase 8 — licensing, final tests, integration verification

## Summary

| Metric | Value |
|--------|-------|
| **Total tasks** | 47 |
| **Phase 1 (Setup)** | 7 tasks (T001–T007) |
| **Phase 2 (Foundational)** | 7 tasks (T008–T014) |
| **Phase 3 / US1 (Keystrokes)** | 9 tasks (T015–T023) |
| **Phase 4 / US2 (Music)** | 5 tasks (T024–T028) |
| **Phase 5 / US3 (Power-ups)** | 2 tasks (T029–T030) |
| **Phase 6 / US5 (Kill sounds)** | 2 tasks (T031–T032) |
| **Phase 7 / US4 (Settings menu)** | 11 tasks (T033–T043) |
| **Phase 8 (Polish)** | 4 tasks (T044–T047) |
| **Parallel opportunities** | 8 tasks marked [P]; Phases 3/4/5 fully parallelizable |
| **New files** | `src/sound_config.zig`, `THIRD_PARTY_LICENSES` |
| **Modified files** | `src/main.zig` |
| **Suggested MVP** | Phases 1–4 (US1 + US2) |

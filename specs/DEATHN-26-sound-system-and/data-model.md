# Data Model: Sound System and Audio Settings Menu

**Feature Branch**: `DEATHN-26-sound-system-and`
**Date**: 2026-05-17

## Entities

### 1. SoundConfig

The player's full audio preference state. Persisted as a single record across sessions.

```zig
pub const TypingPack = enum(u8) {
    click = 0,
    typewriter = 1,
    hitmarker = 2,
};

pub const ErrorPack = enum(u8) {
    damage = 0,
    square = 1,
    missed_punch = 2,
};

pub const SoundConfig = struct {
    // Category toggles (FR-008)
    keystrokes_enabled: bool = true,
    errors_enabled: bool = true,
    kills_enabled: bool = true,
    power_ups_enabled: bool = true,
    music_enabled: bool = true,

    // Pack selections (FR-011, FR-012)
    typing_pack: TypingPack = .typewriter,
    error_pack: ErrorPack = .damage,

    // Volume levels: 0–20 representing 0%–100% in 5% increments (FR-009, FR-010)
    // Stored as u8 step index (0..20). Actual float volume = step * 0.05.
    typing_volume: u8 = 14,   // 70% default
    effects_volume: u8 = 16,  // 80% default
    music_volume: u8 = 10,    // 50% default
};
```

**Default values** (FR-018): typewriter pack at 70%, damage pack at 70%, effects 80%, music 50%, all toggles on.

**Validation rules**:
- `typing_volume`, `effects_volume`, `music_volume`: must be in range 0..20 (clamped on load)
- `typing_pack`: must be a valid `TypingPack` enum value (fallback to `.typewriter` on invalid)
- `error_pack`: must be a valid `ErrorPack` enum value (fallback to `.damage` on invalid)
- Boolean toggles: any non-zero byte reads as `true` on native load

### 2. Sound Pack Sample Counts

Compile-time constants defining how many samples each pack has (determines round-robin wrap point).

```zig
// Typing pack sample counts
const CLICK_SAMPLE_COUNT: u8 = 3;       // click/1.wav – click/3.wav
const TYPEWRITER_SAMPLE_COUNT: u8 = 6;  // typewriter/1.wav – typewriter/6.wav
const HITMARKER_SAMPLE_COUNT: u8 = 3;   // hitmarker/1.wav – hitmarker/3.wav

// Error pack sample counts
const DAMAGE_SAMPLE_COUNT: u8 = 1;       // damage/1.wav
const SQUARE_SAMPLE_COUNT: u8 = 1;       // square/1.wav
const MISSED_PUNCH_SAMPLE_COUNT: u8 = 2; // missed-punch/1.wav – missed-punch/2.wav
```

### 3. Sound Handle Arrays

Module-level globals in `main.zig` holding loaded raylib Sound handles. Indexed by sample number for round-robin access.

```zig
// Typing packs — max 6 samples across all packs
const MAX_TYPING_SAMPLES = 6;
var click_sounds: [CLICK_SAMPLE_COUNT]raylib.Sound = undefined;
var typewriter_sounds: [TYPEWRITER_SAMPLE_COUNT]raylib.Sound = undefined;
var hitmarker_sounds: [HITMARKER_SAMPLE_COUNT]raylib.Sound = undefined;

// Error packs
var damage_sounds: [DAMAGE_SAMPLE_COUNT]raylib.Sound = undefined;
var square_sounds: [SQUARE_SAMPLE_COUNT]raylib.Sound = undefined;
var missed_punch_sounds: [MISSED_PUNCH_SAMPLE_COUNT]raylib.Sound = undefined;

// Power-up activation sounds
var bomb_sound: raylib.Sound = undefined;
var freeze_sound: raylib.Sound = undefined;
var shield_sound: raylib.Sound = undefined;

// Background music
var music: raylib.Music = undefined;

// Existing (already loaded)
var zombie_kill_sound: raylib.Sound = undefined;  // assets/zombie-hit.wav
```

### 4. Round-Robin State

Ephemeral per-session state (not persisted).

```zig
var typing_round_robin: u8 = 0;
var error_round_robin: u8 = 0;
```

**Behavior**:
- Incremented after each play: `typing_round_robin = (typing_round_robin + 1) % getSampleCount(config.typing_pack)`
- Reset to 0 when pack selection changes (FR: pack change resets round-robin)

### 5. Sound Settings Menu State

Ephemeral UI navigation state (not persisted).

```zig
var sound_menu_selection: u8 = 0;
var sound_menu_return_screen: GameScreen = .paused;  // tracks where to go on ESC
```

**Menu items** (10 total, navigated with UP/DOWN):

| Index | Item | Type | Controls |
|-------|------|------|----------|
| 0 | Keystroke sounds | Toggle | ENTER to toggle on/off |
| 1 | Typing pack | Selector | LEFT/RIGHT to cycle packs |
| 2 | Typing volume | Slider | LEFT/RIGHT to adjust ±5% |
| 3 | Error sounds | Toggle | ENTER to toggle on/off |
| 4 | Error pack | Selector | LEFT/RIGHT to cycle packs |
| 5 | Kill sounds | Toggle | ENTER to toggle on/off |
| 6 | Power-up sounds | Toggle | ENTER to toggle on/off |
| 7 | Effects volume | Slider | LEFT/RIGHT to adjust ±5% |
| 8 | Music | Toggle | ENTER to toggle on/off |
| 9 | Music volume | Slider | LEFT/RIGHT to adjust ±5% |

### 6. GameScreen Extension

```zig
const GameScreen = enum {
    main_menu,
    wpm_select,
    playing,
    paused,
    game_over,
    sound_settings,  // NEW
};
```

## Persistence Format

### Native (binary file: `soundconfig.dat`)

Field-by-field little-endian serialization, matching `highscore.zig` pattern.

| Offset | Size | Field | Encoding |
|--------|------|-------|----------|
| 0 | 1 | keystrokes_enabled | u8: 0=off, 1=on |
| 1 | 1 | errors_enabled | u8: 0=off, 1=on |
| 2 | 1 | kills_enabled | u8: 0=off, 1=on |
| 3 | 1 | power_ups_enabled | u8: 0=off, 1=on |
| 4 | 1 | music_enabled | u8: 0=off, 1=on |
| 5 | 1 | typing_pack | u8 enum ordinal |
| 6 | 1 | error_pack | u8 enum ordinal |
| 7 | 1 | typing_volume | u8 (0..20) |
| 8 | 1 | effects_volume | u8 (0..20) |
| 9 | 1 | music_volume | u8 (0..20) |

**Total: 10 bytes** (`DISK_SIZE = 10`)

### Web (localStorage JSON)

Key: `"death-note.soundconfig"`

```json
{
  "keystrokes": 1,
  "errors": 1,
  "kills": 1,
  "powerups": 1,
  "music": 1,
  "typingPack": 1,
  "errorPack": 0,
  "typingVol": 14,
  "effectsVol": 16,
  "musicVol": 10
}
```

### Corruption / Missing File Handling

On load failure (file not found, wrong size, invalid enum value), return `SoundConfig{}` (all defaults per FR-018). No error displayed to the player.

## State Transitions

### Music State Machine

```
                    startGame()
  [STOPPED] ───────────────────── [PLAYING]
      ▲                              │  ▲
      │ game_over / quit_to_menu     │  │ resume (ESC)
      │                              │  │
      └────────────────────────── [PAUSED]
                                  pause (ESC)
```

- **STOPPED → PLAYING**: `PlayMusicStream(music)` when `startGame()` is called and `config.music_enabled` is true
- **PLAYING → PAUSED**: `PauseMusicStream(music)` when `current_screen` transitions to `.paused`
- **PAUSED → PLAYING**: `ResumeMusicStream(music)` when resuming from pause
- **PLAYING → STOPPED**: `StopMusicStream(music)` on game-over or quit-to-menu
- **PAUSED → STOPPED**: `StopMusicStream(music)` on quit-to-menu from pause

### SoundConfig Persistence Lifecycle

```
  App launch
      │
      ▼
  sound_config.load()
      │
      ├── File exists + valid ──► Use loaded values
      │
      └── Missing / corrupt ───► Use SoundConfig{} defaults
      
  Settings change (any toggle/slider/pack)
      │
      ▼
  sound_config.save(config)
      │
      ├── Native: write soundconfig.dat
      └── Web: localStorage.setItem(...)
```

Save triggers: every individual settings change (toggle, slider step, pack switch) writes immediately. No "apply" or "save" button.

## Relationships

```
main.zig
  ├── imports sound_config.zig  (SoundConfig, TypingPack, ErrorPack, load, save)
  ├── imports zombie_types.zig  (PowerUpType — already imported)
  ├── imports highscore.zig     (already imported — unchanged)
  └── imports raylib.zig        (Sound, Music, PlaySound, etc. — already imported)

sound_config.zig
  ├── imports raylib.zig        (for emscripten_run_script on web)
  └── imports std               (for c.fopen, mem.writeInt, etc.)
```

No circular dependencies. `sound_config.zig` does not import `main.zig` (constitution: dependency direction).

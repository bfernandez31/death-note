# Data Model: Wave System, Scoring and Difficulty Progression

**Feature**: DEATHN-12 | **Date**: 2026-05-16

## 1. Data Layer Overview

All game state remains in module-level globals in `src/main.zig` — no database, no ORM, no schema. This feature adds new state groups (wave, scoring, stats) alongside the existing zombie pool and input buffer. The only new persistence is a single high score value written to a local file (native) or localStorage (web).

## 2. Entity Catalog

### 2.1 Zombie (MODIFIED)

Existing struct in `src/main.zig`, extended with boss-related fields:

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    // --- new fields for DEATHN-12 ---
    is_boss: bool,
    phrase_progress: usize,  // characters typed so far (boss only; 0 for normal)
};
```

| Field | Type | Source | Validation |
|---|---|---|---|
| `x` | `f32` | Random in `[ZOMBIE_SPAWN_X_MIN, ZOMBIE_SPAWN_X_MAX]` | Clamped at spawn |
| `y` | `f32` | Starts at `0.0`, incremented by `speed` per frame | Game over when `>= screen_height` |
| `speed` | `f32` | Computed from wave difficulty; boss = 0.5× normal speed | Floor 0.1, cap per wave formula |
| `name` | `[*:0]const u8` | Pointer into `ZombieNames` (normal) or `BossPhrases` (boss) | Null-terminated, never copied |
| `is_active` | `bool` | `true` on spawn, `false` on kill | — |
| `frame` | `f32` | Animation frame counter | Wraps at `ZOMBIE_FRAME_COUNT` |
| `animation_timer` | `f32` | Time accumulator for frame advance | Reset on frame step |
| `is_boss` | `bool` | `true` for boss zombies (every 5th wave) | Set at spawn, immutable |
| `phrase_progress` | `usize` | Characters of the boss phrase matched so far | `0` for normal zombies; `0..phrase_len` for boss |

### 2.2 WaveState (NEW)

Module-level globals representing the current wave:

```zig
var current_wave: u32 = 1;
var wave_timer: f32 = 0.0;
var wave_kill_count: u32 = 0;
var is_wave_transitioning: bool = false;
var wave_transition_timer: f32 = 0.0;
var boss_alive: bool = false;
```

| Variable | Type | Initial | Reset on restart | Description |
|---|---|---|---|---|
| `current_wave` | `u32` | `1` | Yes | Current wave number (1-indexed) |
| `wave_timer` | `f32` | `0.0` | Yes | Seconds elapsed in current wave |
| `wave_kill_count` | `u32` | `0` | Yes (also per-wave) | Kills in the current wave |
| `is_wave_transitioning` | `bool` | `false` | Yes | True during the inter-wave recap/countdown |
| `wave_transition_timer` | `f32` | `0.0` | Yes | Seconds into the transition (0→8s total: 5s recap + 3s countdown) |
| `boss_alive` | `bool` | `false` | Yes | True while a boss zombie is active; pauses wave timer |

### 2.3 WaveDifficultyParams (NEW — computed, not stored)

Pure functions of `current_wave`, not stored as state. Computed each time they are needed:

```zig
fn waveSpawnDelay(wave: u32) f32;      // 3.0 * 0.85^(wave-1), floor 0.5
fn waveFallSpeed(wave: u32) f32;       // 0.5 * 1.10^(wave-1), cap 2.0
fn waveMaxActive(wave: u32) u32;       // 5 + 2*(wave-1), cap 30
fn waveKillTarget(wave: u32) u32;      // 5 + 2*(wave-1), cap 40
fn waveDuration(wave: u32) f32;        // 30.0 + 5.0*(wave-1), cap 120.0
```

### 2.4 ScoreState (NEW)

```zig
var score: u64 = 0;
var combo: u32 = 0;
var best_score: u64 = 0;
var best_score_loaded: bool = false;
```

| Variable | Type | Initial | Reset on restart | Description |
|---|---|---|---|---|
| `score` | `u64` | `0` | Yes | Cumulative score this session |
| `combo` | `u32` | `0` | Yes | Current kill streak without errors |
| `best_score` | `u64` | `0` | No (persisted) | Loaded on startup, updated on game over |
| `best_score_loaded` | `bool` | `false` | No | Whether persistence loaded successfully |

**Scoring formula**:
- Normal kill: `100 × comboMultiplier(combo)`
- Boss kill: `500 × comboMultiplier(combo)`
- Wave completion bonus: `200 × current_wave` (only if kill target met before timer)

**Combo multiplier tiers** (from ARD-5):

| Combo range | Multiplier |
|---|---|
| 0–4 | 1× |
| 5–9 | 2× |
| 10–14 | 3× |
| 15–19 | 4× |
| 20+ | 5× |

```zig
fn comboMultiplier(c: u32) u32 {
    if (c >= 20) return 5;
    if (c >= 15) return 4;
    if (c >= 10) return 3;
    if (c >= 5) return 2;
    return 1;
}
```

### 2.5 PlayerStats (NEW)

```zig
var total_keystrokes: u64 = 0;
var correct_keystrokes: u64 = 0;
var total_kills: u32 = 0;

const WPM_BUFFER_SIZE = 200;
var wpm_kill_times: [WPM_BUFFER_SIZE]f64 = [_]f64{0.0} ** WPM_BUFFER_SIZE;
var wpm_kill_index: usize = 0;
var wpm_kill_count: usize = 0;
```

| Variable | Type | Initial | Reset on restart | Description |
|---|---|---|---|---|
| `total_keystrokes` | `u64` | `0` | Yes | All keystrokes (excluding backspace) |
| `correct_keystrokes` | `u64` | `0` | Yes | Keystrokes that extended a valid prefix |
| `total_kills` | `u32` | `0` | Yes | Total zombies killed (normal + boss) |
| `wpm_kill_times` | `[200]f64` | all `0.0` | Yes | Circular buffer of kill timestamps (game-time seconds via `raylib.GetTime()`) |
| `wpm_kill_index` | `usize` | `0` | Yes | Next write position in circular buffer |
| `wpm_kill_count` | `usize` | `0` | Yes | Total entries written (min of actual kills and buffer size for wraparound detection) |

**WPM calculation**:
```
current_time = raylib.GetTime()
kills_in_window = count entries in wpm_kill_times where (current_time - entry) < 30.0
wpm = kills_in_window / 0.5   (30 seconds = 0.5 minutes)
```

**Accuracy calculation**:
```
accuracy = if (total_keystrokes > 0) (correct_keystrokes * 100) / total_keystrokes else 100
```

### 2.6 BossPhrases (NEW — compile-time data)

New file `src/boss_phrases.zig`, same pattern as `zombie_names.zig`:

```zig
pub const BossPhrases = [_][*:0]const u8{
    "undead apocalypse",
    "brains for dinner",
    "rise from the grave",
    "night of the dead",
    "zombie horde attacks",
    "flesh eating fiend",
    "walking nightmare",
    "escape the cemetery",
    "dawn of darkness",
    "cursed reanimation",
    "unholy resurrection",
    "graveyard shift now",
    "rotting with rage",
    "shambling menace",
    "tomb of terror",
};
```

All phrases are 15–25 characters, ASCII printable (32–125), well under the 40-character buffer limit.

### 2.7 HighScoreRecord (NEW — persistence)

| Platform | Storage | Key/Path | Format |
|---|---|---|---|
| Native | File in working directory | `highscore.dat` | 8 bytes, little-endian `u64` |
| Web | `localStorage` | `"death-note-highscore"` | Decimal string (JS `Number.toString()`) |

**State transitions**:
1. On game startup: attempt to load `best_score`. If successful, set `best_score_loaded = true`. If not (file missing, localStorage empty/disabled), leave `best_score = 0` and `best_score_loaded = false`.
2. On game over: if `score > best_score`, update `best_score = score` and attempt to persist. If persist fails, `best_score` is still updated in memory for the current session.
3. On restart: `best_score` and `best_score_loaded` are NOT reset — they persist across game sessions within the same process.

## 3. State Machine

### 3.1 Game State Machine (MODIFIED)

```
                    ┌─────────────────────────────────────────┐
                    │                                         │
                    ▼                                         │
             ┌──────────┐    kill target    ┌────────────┐    │
   start ──▶ │  WAVE    │───── met ────────▶│ TRANSITION │────┘
             │  ACTIVE  │                   │  (8 sec)   │  next wave
             │          │◄── timer expires ─┤            │
             │          │   (no bonus,      └────────────┘
             │          │    clear zombies)
             │          │
             │          │── zombie reaches ──▶ GAME_OVER
             │          │     bottom
             │          │
             │          │── boss wave (5th) ──▶ WAVE_ACTIVE
             │          │   (boss spawns,       (timer paused
             │          │    normal zombies      while boss
             │          │    continue)           alive)
             └──────────┘
                    │
                    │ zombie reaches bottom
                    ▼
             ┌──────────┐
             │ GAME     │── Enter ──▶ WAVE_ACTIVE (wave 1)
             │ OVER     │             (full state reset)
             └──────────┘
```

States are encoded via the existing `is_game_over: bool` plus new `is_wave_transitioning: bool`:
- `WAVE_ACTIVE`: `!is_game_over and !is_wave_transitioning`
- `TRANSITION`: `!is_game_over and is_wave_transitioning`
- `GAME_OVER`: `is_game_over`

## 4. Constants and Tunables

All declared as module-level `const` in `src/main.zig`:

```zig
// Wave system
const WAVE_TRANSITION_RECAP_DURATION: f32 = 5.0;
const WAVE_TRANSITION_COUNTDOWN_DURATION: f32 = 3.0;
const WAVE_TRANSITION_TOTAL_DURATION: f32 = 8.0;
const BOSS_WAVE_INTERVAL: u32 = 5;
const BOSS_FALL_SPEED_FACTOR: f32 = 0.5;

// Scoring
const BASE_KILL_SCORE: u64 = 100;
const BOSS_KILL_SCORE: u64 = 500;
const WAVE_COMPLETION_BONUS_PER_WAVE: u64 = 200;
const COMBO_TIER_SIZE: u32 = 5;
const MAX_COMBO_MULTIPLIER: u32 = 5;

// Difficulty scaling
const BASE_SPAWN_DELAY: f32 = 3.0;
const SPAWN_DELAY_DECAY: f32 = 0.85;
const MIN_SPAWN_DELAY: f32 = 0.5;
const BASE_FALL_SPEED: f32 = 0.5;
const FALL_SPEED_GROWTH: f32 = 1.10;
const MAX_FALL_SPEED: f32 = 2.0;
const BASE_MAX_ACTIVE: u32 = 5;
const MAX_ACTIVE_INCREMENT: u32 = 2;
const CAP_MAX_ACTIVE: u32 = 30;
const BASE_KILL_TARGET: u32 = 5;
const KILL_TARGET_INCREMENT: u32 = 2;
const CAP_KILL_TARGET: u32 = 40;
const BASE_WAVE_DURATION: f32 = 30.0;
const WAVE_DURATION_INCREMENT: f32 = 5.0;
const CAP_WAVE_DURATION: f32 = 120.0;

// Stats
const WPM_WINDOW_SECONDS: f64 = 30.0;
const WPM_BUFFER_SIZE: usize = 200;

// Input (modified)
const MAX_INPUT_CHARS = 40;  // increased from 9 for boss phrases

// High score persistence
const HIGHSCORE_FILE = "highscore.dat";
const HIGHSCORE_LOCALSTORAGE_KEY = "death-note-highscore";
```

## 5. Data Integrity Rules

1. **Combo resets on error**: Any keystroke that fails the prefix-match check against all active zombies sets `combo = 0`. This is enforced at the keystroke-handling site, not deferred.
2. **Wave kill count bounded by kill target**: `wave_kill_count` increments on kill and is compared against `waveKillTarget(current_wave)`. It resets to 0 at wave start.
3. **Boss blocks wave completion**: `boss_alive` flag is set when a boss spawns and cleared when the boss is killed. Wave timer advancement is gated by `!boss_alive`.
4. **Best score monotonic**: `best_score` is only updated when `score > best_score`. Never decremented.
5. **Circular buffer overflow**: `wpm_kill_index` wraps via modulo `WPM_BUFFER_SIZE`. Entries older than 30 seconds are ignored during WPM calculation, not deleted.
6. **Input buffer null-termination**: The buffer is always null-terminated after the last character (`name[letter_count] = '\x00'`). This invariant is maintained on every write, backspace, and clear operation.

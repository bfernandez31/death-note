# Data Model

## Table of Contents

- [1. Data Layer Overview](#1-data-layer-overview)
- [2. Entity-Relationship Diagram](#2-entity-relationship-diagram)
- [3. Entity Catalog](#3-entity-catalog)
  - [3.1 Zombie](#31-zombie)
  - [3.2 ZombieNames](#32-zombienames)
  - [3.3 InputBuffer](#33-inputbuffer)
  - [3.4 GameState](#34-gamestate)
  - [3.5 WaveConfig](#35-waveconfig)
  - [3.6 BossPhrases](#36-bossphrases)
  - [3.7 ScorePopup](#37-scorepopup)
  - [3.8 HighScoreRecord](#38-highscorerecord)
  - [3.9 PowerUpInventory](#39-powerupinventory)
- [4. Enums and Constants](#4-enums-and-constants)
- [5. State Machines](#5-state-machines)
  - [5.1 Game State Machine](#51-game-state-machine)
  - [5.2 Zombie Lifecycle State Machine](#52-zombie-lifecycle-state-machine)
- [6. Migration History](#6-migration-history)
- [7. Data Integrity Rules](#7-data-integrity-rules)

---

## 1. Data Layer Overview

**There is no database or ORM.** Most game state lives in module-level global variables in `src/main.zig` and does not survive process exit. One exception: the best score is persisted across sessions.

The data containers in the project are:

| Container | Location | Nature |
|---|---|---|
| `zombies[MAX_ZOMBIES]` pool | `src/main.zig` (runtime) | Fixed array of heap-allocated `?*Zombie` pointers; slot freed and set to `null` immediately on zombie kill |
| `boss` pointer | `src/main.zig` (runtime) | Single `?*Zombie` pointer for the active boss zombie; null when no boss is present |
| `popups[MAX_POPUPS]` pool | `src/main.zig` (runtime) | Fixed stack-allocated array of 32 `ScorePopup` value-type entries; mutable at runtime |
| `best_score_survival` / `best_score_zen` | `src/main.zig` (runtime) | Two `highscore.Record` values, one per `GameMode`; both loaded via `highscore.load(.survival)` / `highscore.load(.zen)` at startup so the menu can display the relevant record for `last_played_mode`; each persisted via `highscore.save()` when its mode's session beats it |
| `PrimaryNames` | `src/name_lists.zig` (compile-time) | Read-only array of 349+ null-terminated first-name C string pointers |
| `CompoundNames` | `src/name_lists.zig` (compile-time) | Read-only array of 31 null-terminated hyphenated-name pointers (e.g. `"Jean-Pierre"`) |
| `TrapGroups` | `src/name_lists.zig` (compile-time) | Read-only array of 15 `TrapGroup` structs, each containing 3–5 visually similar names |
| `ZombieNames` | `src/zombie_names.zig` (compile-time) | Original 49-name array; superseded by `PrimaryNames` for spawning (still imported) |
| `BossPhrases` | `src/boss_phrases.zig` (compile-time) | Read-only, compile-time array of 10 null-terminated multi-word phrase pointers |

**Persistence layer.** The high score is the sole persisted state. Each game mode maintains its own record. Survival uses `highscore.dat` (native) / `death-note.highscore` (web). Zen uses `highscore-zen.dat` (native) / `death-note.highscore.zen` (web). Both are 17-byte little-endian binary files on native, JSON in localStorage on web. All persistence is handled by `src/highscore.zig` via `load(GameMode)` and `save(GameMode, Record)`. All other assets are unchanged.

---

## 2. Entity-Relationship Diagram

```mermaid
erDiagram
    GAME_STATE {
        bool is_game_over
        bool is_dying
        f32 dying_timer
        usize dying_zombie_index
        f32 spawn_timer
        u32 current_wave
        u32 wave_kills
        u32 wave_spawned
        bool is_transitioning
        f32 transition_timer
        usize frames_counter
        bool mouse_on_text
        ptr boss
        bool boss_spawned_this_wave
        usize boss_phrase_len
        u64 score
        u32 combo_count
        u32 total_kills
        bool is_new_high_score
        GameScreen current_screen
        GameMode game_mode
        PowerUpType held_power_up
        f32 freeze_timer
        bool shield_active
        usize popup_next
        f32_array wpm_buffer
        usize wpm_buffer_head
        usize wpm_buffer_count
        u32 correct_chars
        u32 wrong_chars
        f32 elapsed_time
        f32 displayed_wpm
        f32 displayed_accuracy
    }

    HIGHSCORE_RECORD {
        u64 score
        u32 wave
        u32 wpm
        u8 accuracy
    }

    SCORE_POPUP {
        f32 x
        f32 y
        u64 points
        f32 timer
        bool active
    }

    POPUP_POOL {
        int capacity
    }

    INPUT_BUFFER {
        u8_array name
        usize letter_count
        usize effective_max
    }

    ZOMBIE_POOL {
        int capacity
    }

    ZOMBIE {
        f32 x
        f32 y
        f32 speed
        ptr name
        bool is_active
        f32 frame
        f32 animation_timer
        ZombieType zombie_type
        PowerUpType power_up
    }

    POWER_UP_TYPE {
        enum freeze
        enum bomb
        enum shield
    }

    GAME_SCREEN {
        enum main_menu
        enum wpm_select
        enum playing
        enum paused
        enum game_over
    }

    GAME_MODE {
        enum survival
        enum zen
    }

    ZOMBIE_TYPE {
        enum standard
        enum runner
        enum tank
    }

    NAME_LISTS {
        cstr primary_entries
        int primary_count
        cstr compound_entries
        int compound_count
        TrapGroup trap_groups
        int trap_group_count
    }

    BOSS_PHRASES {
        cstr entries
        int count
    }

    WAVE_CONFIG {
        u32 target_wpm
        f32 spawn_delay
        f32 fall_speed
        u32 pool_size
    }

    GAME_STATE ||--|| INPUT_BUFFER : "controls input into"
    GAME_STATE ||--|| ZOMBIE_POOL : "governs lifecycle of"
    GAME_STATE ||--|| WAVE_CONFIG : "resolves per wave"
    GAME_STATE ||--o| ZOMBIE : "boss pointer (0 or 1)"
    GAME_STATE ||--|| POPUP_POOL : "governs lifecycle of"
    GAME_STATE ||--|| HIGHSCORE_RECORD : "best_score (loaded at startup)"
    ZOMBIE_POOL ||--o{ ZOMBIE : "holds up to 100"
    ZOMBIE }|--|| ZOMBIE_TYPE : "categorised by"
    ZOMBIE }o--o| POWER_UP_TYPE : "carries (optional)"
    GAME_STATE ||--|| GAME_SCREEN : "current_screen"
    GAME_STATE ||--|| GAME_MODE : "game_mode"
    GAME_STATE ||--o| POWER_UP_TYPE : "held_power_up (optional)"
    ZOMBIE }o--|| NAME_LISTS : "name points into (regular)"
    ZOMBIE }o--o| BOSS_PHRASES : "name points into (boss)"
    WAVE_CONFIG ||--o{ ZOMBIE : "fall_speed set at spawn"
    POPUP_POOL ||--o{ SCORE_POPUP : "holds up to 32"
```

---

## 3. Entity Catalog

### 3.1 Zombie

**Source:** `src/main.zig`, lines 27–35

**Definition:**

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    zombie_type: ZombieType = .standard,
    power_up: ?PowerUpType = null,
};
```

**Pool location:** `var zombies: [MAX_ZOMBIES]?*Zombie = undefined` — a fixed 100-slot array of optional pointers declared at module scope. Each occupied slot holds a pointer to a heap-allocated `Zombie` created via `std.heap.page_allocator.create(Zombie)`.

**There is no persistent ID field.** A zombie's identity is its slot index within `zombies[]`; this index is not stored inside the struct.

| Field | Type | Meaning | Constraints |
|---|---|---|---|
| `x` | `f32` | Horizontal screen position (pixels from left edge) | Set at spawn via `raylib.GetRandomValue(ZOMBIE_SPAWN_X_MIN, ZOMBIE_SPAWN_X_MAX)` → [10, 749]; never mutated after spawn |
| `y` | `f32` | Vertical screen position (pixels from top edge) | Initialised to `0.0`; incremented by `speed` every frame in `updateZombies` |
| `speed` | `f32` | Pixels per frame the zombie descends | Set once at spawn: `getWaveConfig(current_wave).fall_speed × getSpeedMultiplier(zombie_type)` — standard×1.0, runner×1.8, tank×0.5; never mutated after spawn |
| `name` | `[*:0]const u8` | Pointer to a null-terminated C string from `name_lists.zig` | Never copied; points into `PrimaryNames`, `CompoundNames`, or a `TrapGroup` entry; never null |
| `is_active` | `bool` | Whether the zombie is alive and should be updated/drawn | `true` at spawn; set to `false` when the player types the matching name; **heap memory freed immediately on kill** (`allocator.destroy`; slot set to `null`) |
| `frame` | `f32` | Current animation frame index (0–16) | Incremented in `drawZombies` every 0.1 s; wraps to `0` when it reaches `ZOMBIE_FRAME_COUNT` (17) |
| `animation_timer` | `f32` | Accumulated time since last frame advance (seconds) | Starts at `0`; reset to `0` each time a frame advance occurs |
| `zombie_type` | `ZombieType` | Categorises the zombie as `.standard`, `.runner`, or `.tank` | Determines speed multiplier and color tint; defaults to `.standard`; set by `selectZombieType` at spawn |
| `power_up` | `?PowerUpType` | Power-up carried by this zombie (Survival mode only) | `null` by default; set at spawn with 10% probability (`POWER_UP_DROP_CHANCE`) in Survival mode only; transferred to `held_power_up` on kill if the inventory slot is empty; lost if the zombie reaches the bottom |

**Relationships:**
- `name` references one entry in the compile-time `name_lists.zig` arrays (pointer, not a copy).
- The `Zombie` instance lives in heap memory obtained from `std.heap.page_allocator`; the pointer is stored in `zombies[i]`.
- On kill, `allocator.destroy(zomb)` is called and `zombies[i]` is set to `null` immediately, freeing the slot for reuse within the same wave.

---

### 3.2 NameLists

**Source:** `src/name_lists.zig`

`name_lists.zig` is the active source of zombie names for all regular spawning. It exposes three compile-time name arrays and a `selectName` function that handles wave-weighted category selection, type-based length filtering, and anti-doublon enforcement.

#### PrimaryNames

```zig
pub const PrimaryNames = [_][*:0]const u8{ ... };
```

| Attribute | Value |
|---|---|
| Element type | `[*:0]const u8` — null-terminated, read-only C string pointer |
| Element count | 349+ (49 original + 300+ additions) |
| Mutability | Immutable (compile-time constant) |
| Character set | ASCII alphanumeric only (no accents, spaces, or hyphens) |
| Access pattern | Via `selectName()` with wave-weighted category selection and anti-doublon retry |

The 49 original names from `zombie_names.zig` are included as the first entries.

#### CompoundNames

```zig
pub const CompoundNames = [_][*:0]const u8{ ... };
```

| Attribute | Value |
|---|---|
| Element count | 31 |
| Character set | ASCII letters and hyphens only; no spaces |
| Maximum length | 20 characters |
| Wave availability | Wave 4+ (5% probability); increasing to 25% in wave 13+ |
| Examples | `"Jean-Pierre"`, `"Anne-Sophie"`, `"Marie-Claire"` |

#### TrapGroups

```zig
pub const TrapGroups = [_]TrapGroup{ ... };
pub const TrapGroup = struct { names: []const [*:0]const u8 };
```

| Attribute | Value |
|---|---|
| Group count | 15 |
| Names per group | 3–5 |
| Purpose | Visually similar names (e.g. `"Liam"`, `"Lila"`, `"Lina"`) that cluster together in later waves to increase typing attention required |
| Wave availability | Wave 4+ (10% probability); increasing to 25% in wave 13+ |

#### selectName

`pub fn selectName(wave: u32, zombie_type: ZombieType, active_names: [][*:0]const u8, forced_group: ?usize, rng: std.Random) ?NameSelection`

- Applies wave weights from `NAME_WEIGHT_TABLE` to choose a category (primary/compound/trap).
- Filters by length for Runners (≤5 chars) and Tanks (≥8 chars); falls back to full list if insufficient names pass the filter.
- Retries up to `MAX_SPAWN_RETRIES` (10) times on anti-doublon collision; returns `null` if all retries fail.
- Returns a `NameSelection` with the chosen `name`, its `category`, and `trap_group_index` (for cluster tracking).

**Relationships:**
- `Zombie.name` holds a pointer into one of these arrays. No two active zombies share the same name (anti-doublon enforced at spawn).
- `src/zombie_names.zig` still exists and is imported but is no longer the active spawn source — its 49 names are contained within `PrimaryNames`.

---

### 3.3 InputBuffer

**Source:** `src/main.zig`, lines 33–34

**Definition:**

```zig
var name = [_]u8{0} ** (MAX_BOSS_INPUT_CHARS + 1);  // 36 bytes, zero-initialised
var letter_count: usize = 0;
```

The active input buffer is exclusively `name` + `letter_count`. The buffer is sized to the maximum boss-phrase length to support both modes without reallocation.

| Component | Type | Size | Meaning |
|---|---|---|---|
| `name` | `[36]u8` | 36 bytes | Null-terminated character buffer; bytes `0..letter_count-1` hold the typed characters; `name[letter_count]` is always `'\x00'` |
| `letter_count` | `usize` | — | Count of valid characters currently in `name`; doubles as the null-terminator index |

**Invariants:**
- `name[letter_count]` is always `'\x00'` — enforced after every write and after backspace.
- `letter_count` never exceeds `getCurrentMaxInput()`: 20 normally, 35 while `boss != null`. The 20-character limit accommodates compound names (e.g. `"Jean-Christophe"`, 15 chars). The character-append branch checks `letter_count < getCurrentMaxInput()` before writing.
- Only characters in the range `[32, 125]` (printable ASCII) are accepted; this range includes the hyphen (ASCII 45) required for compound names.
- On regular zombie kill: `letter_count = 0`, `name[0] = '\x00'`.
- On boss kill: `letter_count = 0`, `name[0] = '\x00'` (cleared by `updateBoss`).
- On game restart: `letter_count = 0`, `name[0] = '\x00'`.

---

### 3.4 GameState

**Source:** `src/main.zig`, module-level globals and `FrameContext`

These variables collectively represent the running state of the game session.

| Variable | Type | Initial value | Reset on restart | Meaning |
|---|---|---|---|---|
| `is_game_over` | `bool` | `false` | `false` | When `true`, the update phase is skipped and the stats overlay is rendered. Set to `true` after the `is_dying` countdown expires. Reset on `KEY_ENTER` press. |
| `is_dying` | `bool` | `false` | `false` | When `true`, all updates (movement, input, spawning) are paused for `DYING_DURATION` (1 s). Set by `updateZombies` / `updateBoss` when a zombie/boss crosses `screen_height`. Cleared when `dying_timer <= 0`. Reset by `resetSessionState` on restart. |
| `dying_timer` | `f32` | `0.0` | `0.0` | Counts down from `DYING_DURATION` (1.0 s) while `is_dying` is true. When it reaches ≤ 0, `is_game_over` is set and the high score comparison runs. Reset by `resetSessionState` on restart. |
| `dying_zombie_index` | `?usize` | `null` | `null` | Slot index in `zombies[]` of the regular zombie that triggered the dying state, used to draw a red tint during the pause. `null` when the boss triggered the dying state. Reset by `resetSessionState` on restart. |
| `spawn_timer` | `f32` | `0.0` | `0.0` | Accumulated seconds since the last zombie spawn. Incremented each frame by `raylib.GetFrameTime()`. Reset when `spawnZombie` claims a slot, on wave advance, and on game restart. |
| `current_wave` | `u32` | `1` | `1` | The currently active wave number. Incremented at the end of each wave transition. Reset to `1` on game restart. |
| `wave_kills` | `u32` | `0` | `0` | Count of zombies killed by the player in the current wave. Incremented in `updateZombies` on each name match. Reset to `0` at wave advance and restart. |
| `wave_spawned` | `u32` | `0` | `0` | Count of zombies spawned in the current wave. Incremented in `frame()` on each successful spawn. Reset to `0` at wave advance and restart. |
| `is_transitioning` | `bool` | `false` | `false` | `true` during the 3-second inter-wave countdown. Blocks spawning, zombie movement, and input. |
| `transition_timer` | `f32` | `0.0` | `0.0` | Seconds remaining in the current wave transition. Decremented each frame while `is_transitioning`. |
| `boss` | `?*Zombie` | `null` | `null` | Pointer to the active boss `Zombie` struct, or `null` when no boss is alive. Freed by `resetBoss`. |
| `boss_spawned_this_wave` | `bool` | `false` | `false` | `true` once `spawnBoss` has been called for the current wave. Used in the wave-completion gate to distinguish "boss not yet spawned" from "boss already killed". |
| `boss_phrase_len` | `usize` | `0` | `0` | Length of the active boss phrase (number of characters before the null terminator), precomputed at spawn. Used by `updateBoss` and `drawBoss` to compute health bar fill and detect full-phrase match. |
| `score` | `u64` | `0` | `0` | Accumulated points earned across all kills in the current game session. Incremented by `calculateScore` result on each kill. Reset to 0 by `resetScoreState` on game restart. |
| `combo_count` | `u32` | `0` | `0` | Consecutive kill count without a mismatch. Determines the active combo multiplier tier (x1–x5 via `getComboMultiplier`). Reset to 0 on mismatch only — **persists across wave transitions** so a clean session keeps growing the multiplier. Also reset by `resetScoreState` on restart. |
| `max_combo` | `u32` | `0` | `0` | Session-wide peak `combo_count`. Updated inline whenever `combo_count` grows after a regular or boss kill. Displayed in the `MAX COMBO` cell of the game-over grid. Reset by `resetScoreState` on restart. |
| `total_kills` | `u32` | `0` | `0` | Session-wide count of all enemies destroyed (regular zombies and boss). Incremented in `updateZombies` and `updateBoss` on each successful kill. Displayed on the stats screen as "Kills". Reset to 0 by `resetSessionState` on restart. |
| `best_score` | `HighScoreRecord` | zeroed | preserved | Best session record loaded at startup. Updated in memory (and persisted to `highscore.dat` / localStorage) at the `is_dying → is_game_over` transition if the current session score exceeds `best_score.score`. Not reset on restart — survives across sessions in memory for the lifetime of the process. |
| `is_new_high_score` | `bool` | `false` | `false` | Set to `true` at the `is_dying → is_game_over` transition when `score > best_score.score`. Controls whether the stats screen shows "NEW HIGH SCORE!" (gold) or "Best: N" (dark gray). Reset to `false` by `resetSessionState` on restart. |
| `current_screen` | `GameScreen` | `.main_menu` | `.main_menu` | Current UI/gameplay screen. `.main_menu` at startup; drives which update/draw path runs. |
| `game_mode` | `GameMode` | `.survival` | — | Active game mode. `.survival` or `.zen`; set by `startGame(mode)`. |
| `last_played_mode` | `GameMode` | `.survival` | — | Last mode started. `.survival` at startup; updated at each `startGame` call; used by main menu to display the relevant best score. |
| `held_power_up` | `?PowerUpType` | `null` | `null` | Currently held power-up. `null` when empty; set on carrier kill; cleared on activation or reset. |
| `freeze_timer` | `f32` | `0.0` | `0.0` | Remaining freeze seconds. `0.0` when not active; set to `FREEZE_DURATION (3.0)` on Freeze activation; decremented each playing-frame. |
| `shield_active` | `bool` | `false` | `false` | Whether shield is armed. `false` by default; `true` after Shield activation; `false` after absorbing a zombie. |
| `trap_cluster_group` | `?usize` | `null` | `null` | Index into `TrapGroups` of the currently active trap cluster, or `null` when no cluster is in progress. Set when a trap-list name is spawned; cleared when `trap_cluster_remaining` reaches 0. Reset by `resetZombies` and on restart. |
| `trap_cluster_remaining` | `u8` | `0` | `0` | Number of additional trap-cluster spawns still pending. When >0, `spawnZombie` passes the forced group index to `selectName`. Decremented on each spawn; reset when it reaches 0. |
| `prng` | `std.Random.DefaultPrng` | seeded at startup | seeded at startup | Module-level PRNG seeded via `std.c.clock_gettime(.REALTIME, …)` at startup. Used by `selectZombieType` and `name_lists.selectName` for type/name selection. Not reset between waves or restarts. |
| `popup_next` | `usize` | `0` | `0` | Circular write index for the `popups` pool. Advances by 1 modulo `MAX_POPUPS` on each `spawnPopup` call. Reset to 0 by `resetScoreState` on restart. |
| `wpm_buffer` | `[512]f32` | `[_]f32{0} ** 512` | all-zero | Circular buffer of `elapsed_time` timestamps recording when each correct character was typed. Managed by `wpm_buffer_head` and `wpm_buffer_count`. Reset to all-zero by `resetMetricsState`. |
| `wpm_buffer_head` | `usize` | `0` | `0` | Write cursor into `wpm_buffer`; advances modulo `WPM_BUFFER_SIZE` on each `recordCorrectTimestamp` call. Reset to 0 by `resetMetricsState`. |
| `wpm_buffer_count` | `usize` | `0` | `0` | Number of valid entries in `wpm_buffer`; capped at `WPM_BUFFER_SIZE` (512). Reset to 0 by `resetMetricsState`. |
| `correct_chars` | `u32` | `0` | `0` | Session-wide count of keypresses classified as correct (matches next expected character of at least one active enemy). Incremented per keypress in the input loop. Reset by `resetMetricsState`. |
| `wrong_chars` | `u32` | `0` | `0` | Session-wide count of keypresses classified as incorrect (matches no active enemy prefix). Incremented per keypress in the input loop; also resets `combo_count` to 0. Reset by `resetMetricsState`. |
| `elapsed_time` | `f32` | `0.0` | `0.0` | Accumulated *typing* time in seconds, advanced by `raylib.GetFrameTime()` inside `updateMetrics()` only while `wpm_timer_started` is true. The timer arms on the first printable keypress of each wave and is reset (along with the rest of the metrics) at the end of every wave transition, so each wave reads as its own typing-test segment. Used as the timestamp for correct-character events and as the reference point for the sliding WPM window. Reset by `resetMetricsState`. |
| `wpm_timer_started` | `bool` | `false` | `false` | Gate flag for the `elapsed_time` increment. Set to `true` by the input loop on the first printable keypress; cleared by `resetMetricsState` at the end of each wave transition and on game restart. Ensures the displayed WPM doesn't drift down during pre-typing idle. |
| `displayed_wpm` | `f32` | `0.0` | `0.0` | Smoothed WPM value shown in the HUD. Interpolates toward `calculateTargetWpm()` at rate `SMOOTHING_FACTOR = 0.2` per frame. Frozen on game-over. Reset to 0.0 by `resetMetricsState`. |
| `displayed_accuracy` | `f32` | `100.0` | `100.0` | Smoothed accuracy percentage shown in the HUD. Interpolates toward `calculateTargetAccuracy()` at rate `SMOOTHING_FACTOR = 0.2` per frame. Frozen on game-over. Reset to 100.0 by `resetMetricsState`. |
| `frames_counter` | `usize` | `0` (in `FrameContext`) | — | Counts frames while the mouse is over the text input box. Drives the blink via `(frames_counter / 20) % 2 == 0`; reset to `0` when the mouse leaves. |
| `mouse_on_text` | `bool` | `false` (in `FrameContext`) | — | `true` when the mouse cursor is over `text_box`. Controls cursor icon and the blinking-underscore overlay. |

**Note on `frames_counter` and `mouse_on_text`:** These live on the `FrameContext` struct allocated in `main()`, not at module scope. They constitute observable game state, but their scoping differs from the other globals.

**Additional module-level resource handles** (not game logic state, but part of the global module):

| Variable | Type | Meaning |
|---|---|---|
| `zombie_texture` | `raylib.Texture2D` | GPU texture handle for the zombie spritesheet, loaded once from `assets/z_spritesheet.png` |
| `zombie_kill_sound` | `raylib.Sound` | Audio handle loaded once from `assets/zombie-hit.wav`; played via `raylib.PlaySound` on zombie kill |

---

### 3.5 WaveAuthoring / WaveConfig

**Source:** `src/main.zig` — struct definitions at the top of the file, `WAVE_TABLE` compile-time array, `deriveWaveTiming`/`getWaveConfig` lookup functions.

**Definitions:**

```zig
// Authored per-wave knobs — the only values edited by hand.
const WaveAuthoring = struct {
    target_wpm: u32,
    pool_size: u32,
};

// Full runtime config — spawn_delay and fall_speed are derived from target_wpm.
const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
};
```

Both types are value types — never heap-allocated. `WaveConfig` is returned by value from `getWaveConfig(wave: u32)`.

| Field | Type | Meaning | Range |
|---|---|---|---|
| `target_wpm` | `u32` | Target typing speed for the wave in words per minute | 15 (wave 1) – 110 (wave 16+) |
| `spawn_delay` | `f32` | Seconds between zombie spawns — **derived** from `target_wpm` | ≈ 4.80s (wave 1, target 15) – ≈ 0.66s (wave 16+, target 110) |
| `fall_speed` | `f32` | Pixels per frame each zombie descends — **derived** from `target_wpm` and `screen_height` | ≈ 1.74 (wave 1) – ≈ 11.6 (wave 16+) at `screen_height = 1000` |
| `pool_size` | `u32` | Total zombies to spawn in the wave | 5 (wave 1) – 33+2*(wave-15) (wave 16+), capped at `MAX_ZOMBIES` |

**Derivation formula (`deriveWaveTiming`):**

```
chars_per_sec = target_wpm × CHARS_PER_WORD / SECONDS_PER_MINUTE
time_to_type  = AVG_NAME_CHARS / chars_per_sec       // seconds to type an average name at target WPM
spawn_delay   = time_to_type                          // one zombie per type-cycle → sustained WPM pressure
fall_speed    = screen_height / (time_to_type × FALL_GRACE_FACTOR × FRAMES_PER_SECOND)
```

Constants (compile-time):
- `AVG_NAME_CHARS = 6.0` — average name length across all zombie types.
- `FALL_GRACE_FACTOR = 2.0` — a player typing exactly at `target_wpm` reaches each zombie with one full type-cycle of grace before it lands.
- `FRAMES_PER_SECOND = 60.0`.

The per-type speed multipliers (`runner ×1.8`, `tank ×0.5`) and per-type name-length filters (runners ≤5 chars, tanks ≥8 chars) layer **on top** of the derived `fall_speed`, so runners are tighter than baseline and tanks are looser.

**Lookup:** `fn getWaveConfig(wave: u32) WaveConfig` reads the authoring tuple — `WAVE_TABLE[wave - 1]` for waves 1–15, or a scaling formula clamped to `MAX_ZOMBIES` for waves 16+ — and runs `deriveWaveTiming` to produce the full config.

**Storage:** `WAVE_TABLE` is a `[15]WaveAuthoring` compile-time constant array (`target_wpm` + `pool_size` only). No runtime allocation occurs.

---

### 3.6 BossPhrases

**Source:** `src/boss_phrases.zig`, line 1

**Definition:**

```zig
pub const BossPhrases = [_][*:0]const u8{ ... };
```

This is a compile-time constant array of 10 null-terminated C string pointers. It is the sole source of boss phrase strings. The strings live in the binary's read-only data segment; no allocation occurs at runtime.

| Attribute | Value |
|---|---|
| Element type | `[*:0]const u8` — null-terminated, read-only C string pointer |
| Element count | 10 |
| Mutability | Immutable (compile-time constant) |
| Character set | Lowercase ASCII letters (97–122) and spaces (32) only |
| Maximum length | 35 characters (fits within `MAX_BOSS_INPUT_CHARS`) |
| Access pattern | Random index via `raylib.GetRandomValue(0, BossPhrases.len - 1)` at boss spawn time |

**Phrases:** "the dead walk again", "bones remember every step", "silence feeds the horde", "no grave holds them long", "they rise when sun falls", "cold hands reach for you", "the earth spits them out", "shadows crawl at midnight", "a whisper wakes the dead", "run before they find you"

**Relationships:**
- `boss.name` (when a boss is alive) holds a pointer into this array. The pointer is assigned at `spawnBoss` time and is never copied.

---

### 3.7 ScorePopup

**Source:** `src/main.zig`, lines 93–98

**Definition:**

```zig
const ScorePopup = struct {
    x: f32,
    y: f32,
    points: u64,
    timer: f32,
    active: bool,
};
```

**Pool location:** `var popups: [MAX_POPUPS]ScorePopup` — a fixed 32-slot stack-allocated value array at module scope. No heap allocation is used; the pool is initialised at compile time to all-inactive entries. The write head `var popup_next: usize = 0` advances circularly on each `spawnPopup` call.

| Field | Type | Meaning | Constraints |
|---|---|---|---|
| `x` | `f32` | Horizontal screen position inherited from the killed enemy at the moment of death | Set by `spawnPopup`; never mutated after spawn |
| `y` | `f32` | Vertical starting position inherited from the killed enemy | Set by `spawnPopup`; the draw position shifts upward each frame: `draw_y = y - POPUP_RISE_PX × (1 - timer / POPUP_DURATION)` |
| `points` | `u64` | Score value shown in the popup text (formatted as `"+{d}"`) | Result of `calculateScore` at the kill moment |
| `timer` | `f32` | Remaining lifetime in seconds; initialised to `POPUP_DURATION` (0.5 s) and decremented each frame by `GetFrameTime()` | When `timer <= 0`, `active` is set to `false` |
| `active` | `bool` | Whether this slot is currently animating | `true` at spawn; `false` when the timer expires or the slot is overwritten by a new kill |

**Circular recycling:** `popup_next = (popup_next + 1) % MAX_POPUPS` after each write. When all 32 slots are active and a new kill occurs, the oldest slot is silently overwritten. `popup_next` and all `active` flags are reset in `resetScoreState` on game restart.

**Relationships:**
- `spawnPopup` is called from the kill sites in `updateZombies` and `updateBoss` immediately after the score is computed.
- `drawPopups` reads the pool each frame and renders every active entry with fading gold color.

---

### 3.8 HighScoreRecord

**Source:** `src/highscore.zig`

**Definition:**

```zig
pub const Record = struct {
    score: u64 = 0,
    wave: u32 = 0,
    wpm: u32 = 0,
    accuracy: u8 = 0,
};
```

**Runtime instance:** `var best_score: highscore.Record = .{}` — a single value-type struct at module scope in `src/main.zig`. Loaded once at startup via `highscore.load(game_mode)`; updated in memory and conditionally written to the persistence store at the `is_dying → is_game_over` transition via `highscore.save(game_mode, best_score)`. Two separate records are maintained, one per `GameMode`.

| Field | Type | Meaning | Constraints |
|---|---|---|---|
| `score` | `u64` | Best session score ever achieved | 0 if no record exists |
| `wave` | `u32` | Wave reached when the best score was set | 0 if no record exists |
| `wpm` | `u32` | Average WPM of the session that set the best score | 0 if no record exists |
| `accuracy` | `u8` | Accuracy percentage (0–100) of the session that set the best score | 0 if no record exists |

**Native persistence:**

The file path depends on game mode: `highscore.filename(.survival)` returns `"highscore.dat"` and `highscore.filename(.zen)` returns `"highscore-zen.dat"`. Existing `highscore.dat` files from before the multi-mode update are read by the Survival mode load path without modification.

| Offset | Size | Field |
|---|---|---|
| 0 | 8 bytes | `score` (u64, little-endian) |
| 8 | 4 bytes | `wave` (u32, little-endian) |
| 12 | 4 bytes | `wpm` (u32, little-endian) |
| 16 | 1 byte | `accuracy` (u8) |

Total: `HIGHSCORE_DISK_SIZE` = 17 bytes. The on-disk format is independent of the in-memory struct layout: load/save serialize each field via `std.mem.readInt`/`writeInt` through a fixed 17-byte buffer. On load, the read length is compared to `HIGHSCORE_DISK_SIZE`; a mismatch treats the file as corrupt and defaults all fields to 0. Written via `std.c.fopen`/`std.c.fwrite`; read via `std.c.fopen`/`std.c.fread`.

**Web persistence (`localStorage`):**

Key depends on game mode: `highscore.webKey(.survival)` returns `"death-note.highscore"` and `highscore.webKey(.zen)` returns `"death-note.highscore.zen"`. Value: a JSON object `{"score":N,"wave":N,"wpm":N,"accuracy":N}`. Per-field reads use `emscripten_run_script_int` with inline JavaScript. Writes use `emscripten_run_script` with `localStorage.setItem`. On parse failure or missing key, all fields default to 0.

**Relationships:**
- All persistence logic is owned by `src/highscore.zig` via `load(GameMode)` and `save(GameMode, Record)`.
- `best_score` in `src/main.zig` holds the in-memory record for the currently active mode.
- `is_new_high_score` flag controls stats screen display and is set at the same transition.

---

### 3.9 PowerUpInventory

**Source:** `src/main.zig` (runtime state), `src/zombie_types.zig` (`PowerUpType` enum)

The power-up inventory is a single-slot optional value. It is not a struct — it is represented directly by:

```zig
var held_power_up: ?PowerUpType = null;
```

| Field | Type | Meaning | Constraints |
|---|---|---|---|
| `held_power_up` | `?PowerUpType` | Currently held power-up, or `null` | Only populated in Survival mode; set to `null` after activation or on session reset |

The three power-up types and their activation effects:

| Type | Activation Effect | Affects Boss? |
|---|---|---|
| `.freeze` | Sets `freeze_timer = FREEZE_DURATION (3.0)`; all zombie/boss y-advancement blocked while `freeze_timer > 0` | Yes — boss movement also frozen |
| `.bomb` | Iterates `zombies[]`; destroys every non-null slot immediately (score + popup per kill) | No — boss pointer untouched |
| `.shield` | Sets `shield_active = true`; next zombie crossing the bottom is destroyed instead of triggering game-over | No — boss-crossing path not intercepted |

---

## 4. Enums and Constants

### Enums

#### ZombieType (`src/zombie_types.zig`)

```zig
pub const ZombieType = enum { standard, runner, tank };
```

| Value | Speed multiplier | Color tint | Name length rule |
|---|---|---|---|
| `.standard` | 1.0× base `fall_speed` | WHITE (no tint) | Any length |
| `.runner` | 1.8× base `fall_speed` | GREEN | ≤ 5 characters preferred |
| `.tank` | 0.5× base `fall_speed` | BLUE | ≥ 8 characters preferred |

#### GameMode (`src/zombie_types.zig`)

```zig
pub const GameMode = enum { survival, zen };
```

Determines which gameplay rules apply (power-ups, bosses, game-over, scoring).

#### GameScreen (`src/main.zig`)

```zig
const GameScreen = enum { main_menu, wpm_select, playing, paused, game_over };
```

Top-level UI state; gates which update and draw paths run each frame.

#### PowerUpType (`src/zombie_types.zig`)

```zig
pub const PowerUpType = enum { freeze, bomb, shield };
```

Identifies the power-up type in `Zombie.power_up` and `held_power_up`.

#### NameCategory (`src/name_lists.zig`)

```zig
pub const NameCategory = enum { primary, compound, trap };
```

Identifies which name list a spawned name was drawn from, used by `spawnZombie` to update trap cluster state.

---

All other constants are compile-time `const` values declared at module scope in `src/main.zig`.

### Gameplay Constants

| Constant | Value | Type | Purpose |
|---|---|---|---|
| `MAX_ZOMBIES` | `100` | `comptime_int` | Size of the `zombies` fixed pool array; also the maximum number of simultaneously live zombies |
| `MAX_INPUT_CHARS` | `20` | `comptime_int` | Maximum characters the player can type during normal play; raised from 9 to accommodate compound names up to 20 characters |
| `RUNNER_SPEED_MULTIPLIER` | `1.8` | `f32` | Speed multiplier for Runner zombie type; applied to `fall_speed` at spawn |
| `TANK_SPEED_MULTIPLIER` | `0.5` | `f32` | Speed multiplier for Tank zombie type; applied to `fall_speed` at spawn |
| `RUNNER_MAX_NAME_LEN` | `5` | `usize` | Maximum name length (inclusive) preferred for Runner zombies; `selectName` filters by this threshold |
| `TANK_MIN_NAME_LEN` | `8` | `usize` | Minimum name length (inclusive) preferred for Tank zombies; `selectName` filters by this threshold |
| `MAX_SPAWN_RETRIES` | `10` | `u32` | Maximum number of name re-rolls in the anti-doublon loop; spawn deferred if all retries collide |
| `MAX_BOSS_INPUT_CHARS` | `35` | `comptime_int` | Maximum characters accepted while a boss is active; accommodates the longest boss phrase; the `name` buffer is `MAX_BOSS_INPUT_CHARS + 1` bytes |
| `BOSS_SCALE` | `0.4` | `f32` | Render scale for the boss sprite (double the normal zombie scale of 0.2) |
| `BOSS_SPEED_MULTIPLIER` | `0.5` | `f32` | Boss fall speed as a fraction of the wave's normal `fall_speed` |
| `BOSS_HEALTH_BAR_WIDTH` | `200` | `c_int` | Pixel width of the boss health bar drawn below the boss phrase |
| `BOSS_HEALTH_BAR_HEIGHT` | `8` | `c_int` | Pixel height of the boss health bar |
| `ZOMBIE_FRAME_COUNT` | `17` | `comptime_int` | Number of horizontal animation frames in `z_spritesheet.png`; used to compute `frame_width` and to wrap the animation counter |
| `ZOMBIE_ANIMATION_FRAME_DURATION` | `0.1` | `f32` | Seconds between animation frame advances in `drawZombies` |
| `WAVE_TRANSITION_DURATION` | `3.0` | `f32` | Seconds the inter-wave countdown lasts before the next wave begins |
| `WAVE_TABLE` | `[15]WaveAuthoring` | compile-time array | Authored `target_wpm` + `pool_size` for waves 1–15; `spawn_delay`/`fall_speed` are derived from `target_wpm` |
| `AVG_NAME_CHARS` | `6.0` | `f32` | Average name length used in the WPM-driven timing formula |
| `FALL_GRACE_FACTOR` | `2.0` | `f32` | On-screen time = `time_to_type × FALL_GRACE_FACTOR`; at 2.0 a player at target WPM has one full type-cycle of grace before a zombie lands |
| `FRAMES_PER_SECOND` | `60.0` | `f32` | Frame-rate reference used to convert seconds into the per-frame `fall_speed` |
| `ZOMBIE_SPAWN_X_MIN` | `10` | `c_int` | Left boundary for random zombie spawn x position (pixels from left edge) |
| `ZOMBIE_SPAWN_X_MAX` | `749` | `c_int` | Right boundary for random zombie spawn x position (screen_width - 51) |
| `screen_width` | `800` | `comptime_int` | Window width in pixels; passed to `raylib.InitWindow` and used for centering UI |
| `screen_height` | `450` | `comptime_int` | Window height in pixels; a zombie or boss reaching `y >= screen_height` triggers game over |
| `MAX_POPUPS` | `32` | `comptime_int` | Size of the `popups` fixed stack-allocated pool; also the maximum number of simultaneously animated score popups |
| `POPUP_DURATION` | `0.5` | `f32` | Lifetime in seconds of each score popup; popup fades from full to zero opacity over this interval |
| `POPUP_RISE_PX` | `30.0` | `f32` | Total upward travel in pixels a popup makes from spawn position to end of animation |
| `POPUP_FONT_SIZE` | `20` | `c_int` | Font size for the floating `"+{score}"` popup text |
| `BOSS_TYPE_MULTIPLIER` | `3.0` | `f32` | Score formula type multiplier applied to boss kills |
| `STANDARD_TYPE_MULTIPLIER` | `1.0` | `f32` | Score formula type multiplier applied to standard zombie kills |
| `SCORE_HUD_X` | `10` | `c_int` | X pixel position of the score HUD line |
| `SCORE_HUD_Y` | `5` | `c_int` | Y pixel position of the score HUD line |
| `SCORE_HUD_SIZE` | `24` | `c_int` | Font size for the score HUD line |
| `COMBO_HUD_X` | `10` | `c_int` | X pixel position of the combo HUD line |
| `COMBO_HUD_Y` | `35` | `c_int` | Y pixel position of the combo HUD line |
| `COMBO_HUD_SIZE` | `18` | `c_int` | Font size for the combo HUD line |
| `WPM_BUFFER_SIZE` | `512` | `usize` | Capacity of the circular correct-character timestamp buffer; far exceeds any achievable typing rate within a 10-second window |
| `WPM_WINDOW_SECONDS` | `10.0` | `f32` | Duration of the sliding WPM window in seconds; timestamps older than this are excluded from the count |
| `WPM_HUD_X` | `screen_width − 100` | `c_int` | X pixel position of the WPM HUD label (top-right area) |
| `WPM_HUD_Y` | `5` | `c_int` | Y pixel position of the WPM HUD label |
| `ACC_HUD_X` | `screen_width − 100` | `c_int` | X pixel position of the accuracy HUD label (same column as WPM) |
| `ACC_HUD_Y` | `30` | `c_int` | Y pixel position of the accuracy HUD label (below WPM) |
| `METRICS_HUD_SIZE` | `18` | `c_int` | Font size for both WPM and accuracy HUD labels |
| `SMOOTHING_FACTOR` | `0.2` | `f32` | Per-frame interpolation rate applied to both `displayed_wpm` and `displayed_accuracy`; at 60 FPS, display converges to within 1% of target in ~21 frames |
| `DYING_DURATION` | `1.0` | `f32` | Seconds the dying state lasts before transitioning to game-over; during this time the responsible regular zombie is drawn with a red tint |
| `STATS_TITLE_Y` | `30` | `c_int` | Y pixel position of the "GAME OVER" title on the stats overlay |
| `STATS_LINE_START_Y` | `80` | `c_int` | Y pixel position of the first stat line on the stats overlay |
| `STATS_LINE_SPACING` | `35` | `c_int` | Vertical pixel spacing between stat lines on the stats overlay |
| `STATS_FONT_SIZE` | `24` | `c_int` | Font size for the six stat lines (wave, score, best/high score, WPM, accuracy, kills) |
| `HIGHSCORE_FILENAME` | `"highscore.dat"` | string literal | Filename for native high score persistence; written to and read from the working directory |

### Raylib Constants in Use

These are C constants imported from `raylib.h` via `src/raylib.zig` and referenced directly in `src/main.zig`:

| Constant | Category | Usage |
|---|---|---|
| `KEY_BACKSPACE` | Input / keyboard | Detects backspace to remove the last typed character |
| `KEY_ENTER` | Input / keyboard | Detects Enter on the game-over screen to restart |
| `MOUSE_CURSOR_IBEAM` | Input / cursor | Set when the mouse hovers over the text input box |
| `MOUSE_CURSOR_DEFAULT` | Input / cursor | Restored when the mouse leaves the text input box |
| `RAYWHITE` | Color | Background clear color (`ClearBackground`) |
| `LIGHTGRAY` | Color | Fill color for the text input box rectangle |
| `RED` | Color | Outline of the text box when active; "GAME OVER" text |
| `DARKGRAY` | Color | Outline of the text box when inactive |
| `MAROON` | Color | Typed text drawn inside the input box and the blinking cursor |
| `GRAY` | Color | "Press ENTER to Restart" and overflow hint text |
| `DARKGREEN` | Color | Zombie name labels above each zombie sprite; also used for the score HUD line |
| `WHITE` | Color | Tint passed to `DrawTexturePro` when rendering zombie sprites |
| `ORANGE` | Color | Combo HUD line color when combo count is 5–14 |

---

## 5. State Machines

### 5.1 Game State Machine

```mermaid
stateDiagram-v2
    [*] --> MainMenu : main() initialises (current_screen=.main_menu)

    MainMenu --> Playing : Survival selected\n(game_mode=.survival, current_screen=.playing)
    MainMenu --> WpmSelect : Zen selected\n(current_screen=.wpm_select)

    WpmSelect --> Playing : WPM target chosen\n(game_mode=.zen, current_screen=.playing)

    Playing --> Paused : Escape pressed\n(current_screen=.paused)
    Paused --> Playing : Resume selected\n(current_screen=.playing)
    Paused --> MainMenu : Quit to Menu\n(session discarded, current_screen=.main_menu)

    Playing --> Dying : zombie.y >= screen_height\nAND game_mode==.survival\nAND !shield_active\n(is_dying=true, dying_timer=1.0)
    Dying --> GameOver : dying_timer <= 0\n(current_screen=.game_over,\nhigh score compared and saved)

    Playing --> Transitioning : wave_kills >= pool_size\nAND wave_spawned >= pool_size\nAND boss_done\n(is_transitioning=true)
    Transitioning --> Playing : transition_timer <= 0\n(current_wave += 1, resetZombies)

    GameOver --> MainMenu : KEY_ENTER or Escape\n(current_screen=.main_menu,\nsession state reset)
```

**Notes:**
- `current_screen` is the primary dispatch variable; every frame the update and draw paths are selected based on its value.
- `is_dying` and `is_transitioning` are sub-states within `.playing` — they pause certain update paths while `current_screen` remains `.playing`.
- While in the `Playing` state the update phase runs every frame: input is captured, `spawn_timer` accumulates, `spawnZombie` fires up to `pool_size` times, and `updateZombies` runs.
- While `is_dying` is true all updates are paused; only `dying_timer` decrements and the responsible regular zombie (if any) is tinted red.
- While `is_transitioning` is true the update phase is skipped; only the transition countdown draw and the timer decrement run.
- While `current_screen == .game_over` the update phase is entirely skipped; only the draw phase runs, showing the stats overlay.
- `resetZombies` frees all heap-allocated `Zombie` instances and sets every pool slot to `null` before re-entering `Playing`.

---

### 5.2 Zombie Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> Spawned : spawnZombie allocates Zombie,\nsets is_active = true, places in zombies[i]

    Spawned --> Killed : player types matching name\n(is_active = false, sound played,\nmemory NOT freed)

    Spawned --> ReachedBottom : zomb.y >= screen_height\n(triggers GameOver transition)

    Killed --> Freed : game-over restart\n(resetZombies: allocator.destroy + slot = null)

    ReachedBottom --> Freed : game-over restart\n(resetZombies: allocator.destroy + slot = null)

    Freed --> [*]
```

**Notes:**
- The transition from `Spawned` to `Killed` leaves the `Zombie` struct in heap memory with `is_active = false`; the slot in `zombies[]` remains non-null. The allocation is only reclaimed by `resetZombies`.
- `drawZombies` and `updateZombies` both skip zombies where `!zomb.is_active`, so a `Killed` zombie is invisible and not processed, but its memory is live.
- `spawnZombie` scans for the first `null` slot. A `Killed` zombie (slot still non-null) does not free up a spawn slot until `resetZombies` runs.

---

## 6. Migration History

**None.**

This project has no database, no schema versioning tool (no Flyway, Liquibase, Alembic, or equivalent), and no migration files of any kind. The in-memory data layout is defined entirely in source code. Any change to the `Zombie` struct or `ZombieNames` array is a direct source-code edit; there is no migration concept applicable.

---

## 7. Data Integrity Rules

The following invariants are enforced in code. They are not checked by a schema validator or database constraint — they rely entirely on the logic in `src/main.zig`.

### Input Buffer

- **Null-termination always maintained.** Every character append sets `name[letter_count + 1] = '\x00'` immediately after writing `name[letter_count]`. Every backspace sets `name[letter_count] = '\x00'` after decrementing `letter_count`. Both zombie kill and boss kill set `name[0] = '\x00'` and `letter_count = 0`. Game restart also clears the buffer.
- **Dynamic maximum length enforced at the append site.** Characters are only written when `letter_count < getCurrentMaxInput()`, which returns 35 while a boss is active and 9 otherwise. Once full, `DrawText("Press BACKSPACE to delete chars...", ...)` is shown.
- **Accepted character range `[32, 125]`** (printable ASCII, inclusive). Characters outside this range returned by `GetCharPressed` are silently discarded.
- **`letter_count` never goes below zero.** The backspace branch checks `letter_count > 0` before decrementing.

### Zombie Name Matching

- Comparison is performed as a byte-exact slice equality via `std.mem.eql(u8, typed_name, zomb_name_slice)`.
- `typed_name` is `name[0..letter_count]` — excludes the null terminator.
- `zomb_name_slice` length is computed by scanning `zomb.name` byte-by-byte until `'\x00'` is reached; the resulting slice also excludes the terminator.
- Match is case-sensitive; no normalization is applied.
- Hyphens are valid input characters (codepoint 45 falls within the accepted `[32, 125]` range) and are matched byte-for-byte in compound names such as `"Jean-Pierre"`.

### Zombie Pool

- `spawnZombie` scans `zombies[]` from index 0 for the first `null` slot. If no null slot is found, the function returns `false` (no spawn this cycle).
- Killed zombies free their slot immediately (`allocator.destroy` + `slot = null`), so the pool refills naturally without waiting for restart.
- `errdefer allocator.destroy(new_zombie)` is in place in `spawnZombie` to prevent a leak if `Zombie` initialization were to fail after allocation.
- Name selection enforces anti-doublon: `selectName` receives the slice of all currently active zombie names and retries up to `MAX_SPAWN_RETRIES` (10) times to avoid duplicates. If all retries fail, `spawnZombie` returns `false` and the spawn is deferred to the next timer tick.

### Memory Lifecycle

- **Freed on kill.** When a zombie is killed, `updateZombies` calls `allocator.destroy(zomb)` and sets `zombies[i] = null` immediately. The slot is available for a new spawn in the same wave without requiring a restart.
- **Full reclaim on wave transition and restart.** `resetZombies` iterates every slot, calls `allocator.destroy(z)` for every non-null pointer (covering zombies still falling at wave end), and sets the slot to `null`. After `resetZombies` returns, all 100 slots are `null` and no `Zombie` heap memory is outstanding.

### Boss Memory Lifecycle

- **Single allocation per boss encounter.** `spawnBoss` allocates exactly one `Zombie` struct via `allocator.create(Zombie)`. `errdefer allocator.destroy(new_boss)` prevents a leak if initialization fails after allocation.
- **Freed on boss kill.** `updateBoss` calls `allocator.destroy(b)` and sets `boss = null` when the full phrase is typed.
- **Freed on wave transition and restart.** `resetBoss` is called alongside `resetZombies` in both the wave-transition block and the game-restart block. It calls `allocator.destroy(b)` if `boss` is non-null, then resets `boss`, `boss_spawned_this_wave`, and `boss_phrase_len` to defaults. After `resetBoss` returns, no boss heap memory is outstanding.

### Asset Paths

- Asset paths are string literals embedded in the binary: `"assets/zombie-hit.wav"` and `"assets/z_spritesheet.png"`. There is no runtime path construction and no user-supplied path input. The game must be run from the repository root for these relative paths to resolve correctly.

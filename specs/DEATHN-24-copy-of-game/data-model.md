# Data Model: Game-Over Stats Screen and High Score Persistence

**Branch**: `DEATHN-24-copy-of-game` | **Date**: 2026-05-17

## Entities

### HighScoreRecord

Persisted best-performance record. Survives across sessions (file on native, localStorage on web). Only overwritten when the current session score strictly exceeds the stored value (FR-010).

```zig
const HighScoreRecord = struct {
    score: u64,    // Best session score
    wave: u32,     // Wave reached when best score was set
    wpm: u32,      // Average WPM when best score was set
    accuracy: u8,  // Accuracy percentage (0–100) when best score was set
};
```

**Size**: 17 bytes (u64 + u32 + u32 + u8 = 8 + 4 + 4 + 1). Used as the exact expected file size for corruption validation (FR-011, ARD-2).

**Binary layout** (`highscore.dat`, native only):
| Offset | Size | Field |
|--------|------|-------|
| 0 | 8 | score (u64, native endian) |
| 8 | 4 | wave (u32, native endian) |
| 12 | 4 | wpm (u32, native endian) |
| 16 | 1 | accuracy (u8) |

**JSON layout** (localStorage `death-note.highscore`, web only):
```json
{"score":12345,"wave":7,"wpm":65,"accuracy":92}
```

**Validation rules**:
- File size must equal `@sizeOf(HighScoreRecord)` exactly; otherwise treat as corrupt → all-zero defaults
- On web, JSON parse failure or missing key → all-zero defaults
- On web, localStorage unavailable or full → all-zero defaults, no save attempted

### Session Statistics (in-memory only)

Not a new struct — these are the existing module-level globals plus one new addition. Listed here for completeness of the stats screen data sources.

| Field | Source | Type | Reset on restart? |
|-------|--------|------|-------------------|
| `current_wave` | existing global | `u32` | Yes (to 1) |
| `score` | existing global | `u64` | Yes (to 0) |
| `correct_chars` | existing global | `u32` | Yes (to 0) |
| `wrong_chars` | existing global | `u32` | Yes (to 0) |
| `elapsed_time` | existing global | `f32` | Yes (to 0.0) |
| `total_kills` | **new global** | `u32` | Yes (to 0) |

### Game-Over Transition State (in-memory only)

New module-level globals controlling the 1-second death animation before the stats screen.

| Field | Type | Purpose |
|-------|------|---------|
| `is_dying` | `bool` | True during the 1s pause; gates updates like `is_game_over` |
| `dying_timer` | `f32` | Counts down from 1.0; when ≤ 0 → `is_game_over = true` |
| `dying_zombie_index` | `?usize` | Slot index of the zombie that crossed the bottom (for red tint) |

## State Transitions

```
PLAYING ──zombie crosses bottom──► DYING (1s countdown, red tint on culprit)
                                      │
                                      ▼ timer ≤ 0
                                   GAME_OVER (stats screen displayed)
                                      │
                                      │ compare score > best_score?
                                      │   yes → save to persistence, update best_score in memory
                                      │   no  → keep existing best_score
                                      │
                                      ▼ ENTER pressed
                                   PLAYING (all session state reset, best_score preserved)
```

## Relationships

- `HighScoreRecord` is loaded once at startup into `best_score: HighScoreRecord` global
- `HighScoreRecord` is conditionally overwritten at game-over when `score > best_score.score`
- Stats screen reads from both session globals and `best_score` to render all 8 lines
- `dying_zombie_index` references a slot in `zombies[MAX_ZOMBIES]`; the zombie at that index receives a red tint during the DYING state

# Data Model: Live WPM and Accuracy with Character-Based Metrics

**Branch**: `DEATHN-22-live-wpm-and` | **Date**: 2026-05-16

## New Constants

```zig
const WPM_BUFFER_SIZE: usize = 512;
const WPM_WINDOW_SECONDS: f32 = 10.0;
const WPM_HUD_X: c_int = screen_width - 100;  // 700
const WPM_HUD_Y: c_int = 5;
const ACC_HUD_X: c_int = screen_width - 100;   // 700
const ACC_HUD_Y: c_int = 30;
const METRICS_HUD_SIZE: c_int = 18;
const SMOOTHING_FACTOR: f32 = 0.2;
```

## New State Variables

All module-level in `src/main.zig`, grouped as a "metrics state" block after the existing score/combo block (after line 80):

```zig
// WPM sliding window — circular buffer of correct-character timestamps
var wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
var wpm_buffer_head: usize = 0;
var wpm_buffer_count: usize = 0;

// Session-wide character counters
var correct_chars: u32 = 0;
var wrong_chars: u32 = 0;

// Elapsed game time (seconds, accumulated from frame time)
var elapsed_time: f32 = 0.0;

// Smoothed display values
var displayed_wpm: f32 = 0.0;
var displayed_accuracy: f32 = 100.0;
```

## Entity Relationships

```
elapsed_time ──────────> wpm_buffer[512]  (timestamps stored as elapsed_time values)
                              │
                              ▼
                     countCharsInWindow()  (count entries within last 10s)
                              │
                              ▼
correct_chars ──────> calculateTargetWpm()
                              │
                              ▼
                        displayed_wpm ──────> HUD "WPM {value}"
                        (smoothed per frame)

correct_chars ──┐
                ├────> calculateTargetAccuracy()
wrong_chars ────┘              │
                               ▼
                        displayed_accuracy ──> HUD "Acc {value}%"
                        (smoothed per frame)
```

## Validation Rules

| Variable | Type | Initial | Reset Value | Constraints |
|----------|------|---------|-------------|-------------|
| `wpm_buffer` | `[512]f32` | all 0 | all 0 | Entries are `elapsed_time` values; old entries silently overwritten on wraparound |
| `wpm_buffer_head` | `usize` | 0 | 0 | Range [0, 511]; advances by 1 per correct character |
| `wpm_buffer_count` | `usize` | 0 | 0 | Range [0, 512]; only increases until buffer is full, then stays at 512 |
| `correct_chars` | `u32` | 0 | 0 | Monotonically increasing within a session; reset on restart |
| `wrong_chars` | `u32` | 0 | 0 | Monotonically increasing within a session; reset on restart |
| `elapsed_time` | `f32` | 0.0 | 0.0 | Monotonically increasing within a session; frozen on game-over |
| `displayed_wpm` | `f32` | 0.0 | 0.0 | Interpolated toward target; never negative |
| `displayed_accuracy` | `f32` | 100.0 | 100.0 | Interpolated toward target; range [0, 100] |

## State Transitions

### On correct keypress
1. `correct_chars += 1`
2. `wpm_buffer[wpm_buffer_head] = elapsed_time`
3. `wpm_buffer_head = (wpm_buffer_head + 1) % WPM_BUFFER_SIZE`
4. `if (wpm_buffer_count < WPM_BUFFER_SIZE) wpm_buffer_count += 1`

### On incorrect keypress
1. `wrong_chars += 1`
2. `combo_count = 0` (existing behavior, moved into per-key check)

### Each frame (when `!is_game_over`)
1. `elapsed_time += GetFrameTime()`
2. Compute `target_wpm` via sliding window or early-game formula
3. `displayed_wpm += 0.2 * (target_wpm - displayed_wpm)`
4. Compute `target_accuracy = correct / (correct + wrong) * 100` (or 100 if zero)
5. `displayed_accuracy += 0.2 * (target_accuracy - displayed_accuracy)`

### On game restart
All variables reset to their initial values via `resetMetricsState()`.

## Formulas

### WPM (sliding window, elapsed >= 10s)
```
chars_in_window = count of wpm_buffer entries where timestamp >= (elapsed_time - 10.0)
WPM = chars_in_window * 1.2
```
Derivation: 1 word = 5 characters; 10-second window → `chars / 5 * (60 / 10) = chars * 1.2`

### WPM (early game, elapsed < 10s)
```
WPM = (correct_chars / 5) / (elapsed_time / 60)
    = correct_chars * 12 / elapsed_time
```

### Accuracy
```
total = correct_chars + wrong_chars
accuracy = if (total == 0) 100.0 else (correct_chars / total) * 100.0
```

### Reference test cases
| Scenario | Inputs | Expected |
|----------|--------|----------|
| Sliding window | 60 chars in 10s window | WPM = 72 |
| Early game | 12 chars in 5s elapsed | WPM = 28.8 → rounds to 29 |
| Accuracy | 100 correct + 4 wrong | 96.15% → rounds to 96% |
| Zero input | 0 chars | WPM = 0, Acc = 100% |

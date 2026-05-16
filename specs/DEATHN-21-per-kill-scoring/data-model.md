# Data Model: Per-kill scoring formula with combo and HUD

**Branch**: `DEATHN-21-per-kill-scoring` | **Date**: 2026-05-16

## New Entities

### Score (module-level global)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `score` | `u64` | `0` | Cumulative points earned across all kills in the current game session |

**Validation rules**:
- Stored as 64-bit unsigned integer (FR-010), no overflow guard needed (max practical value is far below `maxInt(u64)`)
- Resets to `0` on game restart (FR-011)

**State transitions**:
- `0` → incremented by `calculateScore()` result on each kill (zombie or boss)
- Any value → `0` on game restart (Enter pressed during game-over)

---

### Combo Counter (module-level global)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `combo_count` | `u32` | `0` | Consecutive successful kills without a typing mismatch |

**Validation rules**:
- Increments by exactly 1 per kill (FR-002)
- Resets to 0 on mismatch or wave transition start (FR-003)
- Does NOT reset on backspace (FR-014)

**State transitions**:
- `N` → `N + 1` on any kill (standard zombie or boss)
- `N` → `0` when typed input doesn't match the prefix of any active enemy
- `N` → `0` when wave transition begins (`is_transitioning` set to true)
- Any value → `0` on game restart

**Derived value — combo multiplier** (FR-004):

| Combo range | Multiplier |
|-------------|------------|
| 0–4         | x1         |
| 5–9         | x2         |
| 10–14       | x3         |
| 15–19       | x4         |
| 20+         | x5         |

Computed by `getComboMultiplier(combo: u32) u64`.

---

### ScorePopup (fixed-size value array)

```zig
const ScorePopup = struct {
    x: f32,
    y: f32,
    points: u64,
    timer: f32,
    active: bool,
};
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `x` | `f32` | `0` | Screen X position (inherited from killed enemy) |
| `y` | `f32` | `0` | Screen Y position at spawn (inherited from killed enemy) |
| `points` | `u64` | `0` | Score value to display as "+{points}" |
| `timer` | `f32` | `0` | Remaining lifetime in seconds (starts at `POPUP_DURATION`) |
| `active` | `bool` | `false` | Whether this slot is currently visible |

**Pool management**:
- Fixed array of `MAX_POPUPS` (32) entries (FR-009)
- Circular write index `popup_next: usize = 0`
- On spawn: write to `popups[popup_next]`, set `active = true`, `timer = POPUP_DURATION`, advance `popup_next = (popup_next + 1) % MAX_POPUPS`
- Oldest slot is automatically overwritten when pool is full (circular recycling)

**State transitions**:
- Inactive → Active: on enemy kill, slot populated with enemy position and calculated score
- Active → Inactive: when `timer` reaches 0 (after 0.5 seconds)
- Active → Overwritten: when a new popup recycles this slot before timer expires

**Rendering rules** (FR-008):
- Text: "+{points}" in gold color, font size 20
- Position: rises linearly from spawn Y by `POPUP_RISE_PX` (30) pixels over `POPUP_DURATION` (0.5s)
- Opacity: fades linearly from 255 to 0 over `POPUP_DURATION`
- Draw Y: `y - (POPUP_RISE_PX × (1.0 - timer / POPUP_DURATION))`
- Alpha: `@intFromFloat((timer / POPUP_DURATION) × 255.0)`

---

## New Constants

| Name | Type | Value | Source |
|------|------|-------|--------|
| `MAX_POPUPS` | `comptime_int` | `32` | FR-009 |
| `POPUP_DURATION` | `f32` | `0.5` | FR-008 |
| `POPUP_RISE_PX` | `f32` | `30.0` | FR-008 |
| `SCORE_HUD_X` | `c_int` | `10` | FR-005 |
| `SCORE_HUD_Y` | `c_int` | `5` | FR-005 |
| `SCORE_HUD_SIZE` | `c_int` | `24` | FR-005 |
| `COMBO_HUD_X` | `c_int` | `10` | FR-006 |
| `COMBO_HUD_Y` | `c_int` | `35` | FR-006 |
| `COMBO_HUD_SIZE` | `c_int` | `18` | FR-006 |
| `POPUP_FONT_SIZE` | `c_int` | `20` | FR-008 |
| `BOSS_TYPE_MULTIPLIER` | `f32` | `3.0` | FR-001 |
| `STANDARD_TYPE_MULTIPLIER` | `f32` | `1.0` | FR-001 |

---

## Scoring Formula

```
calculateScore(name_len, y_pos, is_boss, combo) → u64

  height_score  = @round(100.0 × (y_pos / screen_height))
  base_score    = @as(f32, name_len) × 10.0 + height_score
  typed_score   = @round(base_score × type_multiplier)
  combo_mult    = getComboMultiplier(combo)
  final_score   = @intFromFloat(typed_score) × combo_mult
```

**Reference test cases** (FR-013):

| Case | Name | Length | Y | Type | Combo | Expected |
|------|------|--------|---|------|-------|----------|
| 1 | Alex | 4 | 0 | standard | 0 | 40 |
| 2 | Alex | 4 | 0 | standard | 20 | 200 |
| 3 | Alex | 4 | 440 | standard | 0 | 138 |
| 4 | the dead walk again | 19 | 300 | boss | 10 | 2313 |

---

## Relationships

```
Kill Event
  ├── updates Score (adds calculateScore result)
  ├── updates Combo Counter (increments by 1)
  └── spawns ScorePopup (at enemy position with score value)

Character Input
  └── may reset Combo Counter (if typed text doesn't prefix-match any active enemy)

Wave Transition Start
  └── resets Combo Counter to 0

Game Restart
  ├── resets Score to 0
  ├── resets Combo Counter to 0
  └── deactivates all ScorePopups
```

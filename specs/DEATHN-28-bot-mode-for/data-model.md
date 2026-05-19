# Data Model: Bot Mode for Difficulty Validation and Auto-Pilot Watching

**Branch**: `DEATHN-28-bot-mode-for` | **Date**: 2026-05-18

## Entities

### 1. Bot State (new module-level variables in `src/main.zig`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bot_active` | `bool` | `false` | Whether the bot is currently controlling input. Toggled by F2 or set on BOT menu selection. |
| `bot_tainted` | `bool` | `false` | Session-level flag. Set to `true` when `bot_active` becomes `true`. Never cleared until `startGame()`. Gates `highscore.save()` calls. |
| `bot_target_index` | `?usize` | `null` | Index into `zombies` array of the bot's current target. `null` when targeting boss or idle. |
| `bot_targeting_boss` | `bool` | `false` | `true` when the bot is typing a boss phrase. |
| `bot_char_index` | `usize` | `0` | How many characters of the target's name the bot has typed so far. |
| `bot_type_timer` | `f32` | `0.0` | Accumulated time since the last character injection. When `>= 1.0 / chars_per_second`, inject next character and reset. |
| `bot_reaction_timer` | `f32` | `0.0` | Countdown timer after a target-change event (target killed, new wave, activation). Bot idles until this reaches 0. |

### 2. Bot Constants (new compile-time constants in `src/main.zig`)

| Constant | Type | Value | Description |
|----------|------|-------|-------------|
| `BOT_REACTION_DELAY` | `f32` | `0.2` | Default reaction delay in seconds (200 ms). Tunable per FR-015. |
| `BOT_CHARS_PER_WORD` | `f32` | `5.0` | Standard typing-test convention. Matches existing `CHARS_PER_WORD`. |
| `BOT_SECONDS_PER_MINUTE` | `f32` | `60.0` | Matches existing `SECONDS_PER_MINUTE`. |

Note: `BOT_CHARS_PER_WORD` and `BOT_SECONDS_PER_MINUTE` can reuse the existing `CHARS_PER_WORD` and `SECONDS_PER_MINUTE` constants — no duplication needed.

### 3. Derived Formulas

**Characters per second** (per-frame calculation):
```
target_wpm = getWaveConfig(current_wave).target_wpm
chars_per_second = @as(f32, @floatFromInt(target_wpm)) * CHARS_PER_WORD / SECONDS_PER_MINUTE
// Simplifies to: target_wpm / 12.0
// At wave 1 (20 WPM): 1.67 chars/sec → one character every 0.6s
// At wave 47 (250 WPM): 20.83 chars/sec → one character every 0.048s
```

**Character injection interval**:
```
interval = 1.0 / chars_per_second = SECONDS_PER_MINUTE / (target_wpm * CHARS_PER_WORD)
// Equivalent to: 12.0 / target_wpm
```

### 4. State Transitions

```
                    ┌──────────┐
     startGame()    │  IDLE    │  bot_active=false
     resetBot()  ──►│  (no     │  bot_target_index=null
                    │  target) │  bot_char_index=0
                    └────┬─────┘
                         │ bot_active set to true
                         │ (menu BOT or F2 toggle)
                         ▼
                    ┌──────────┐
                    │ REACTION │  bot_reaction_timer = BOT_REACTION_DELAY
                    │  DELAY   │  Waiting before first target selection
                    └────┬─────┘
                         │ bot_reaction_timer <= 0
                         │ selectBotTarget() picks closest zombie
                         ▼
                    ┌──────────┐
              ┌────►│ TYPING   │  bot_type_timer accumulates
              │     │          │  inject char when timer >= interval
              │     └────┬─────┘
              │          │ target killed (name fully typed)
              │          │ OR target zombie removed (bomb)
              │          ▼
              │     ┌──────────┐
              └─────│ REACTION │  Clear input buffer
                    │  DELAY   │  bot_reaction_timer = BOT_REACTION_DELAY
                    └──────────┘

  F2 toggle (bot_active = false):
    → Return to IDLE, clear bot state, leave input buffer as-is
    → Player resumes from current buffer state

  State gates (bot pauses, does not reset):
    - is_dying = true → bot stops typing, resumes on next wave
    - is_transitioning = true → bot stops typing, resumes after countdown
    - current_screen != .playing → bot inactive
```

### 5. Menu Array Change

Before:
```zig
const MENU_ITEMS = [_][]const u8{ "SURVIVAL", "ZEN", "SOUND", "QUIT" };
const MENU_ITEM_COUNT: u8 = 4;
```

After:
```zig
const MENU_ITEMS = [_][]const u8{ "SURVIVAL", "ZEN", "BOT", "SOUND", "QUIT" };
const MENU_ITEM_COUNT: u8 = 5;
```

Switch cases shift:
- 0 → SURVIVAL (unchanged)
- 1 → ZEN (unchanged)
- 2 → BOT (new: `bot_active = true; startGame(.survival, allocator);`)
- 3 → SOUND (was 2)
- 4 → QUIT (was 3)

### 6. High Score Gating

Two write sites must be guarded:

1. **Survival game-over** (`src/main.zig:597-606`):
   ```zig
   if (score > best_score_survival.score) {
       is_new_high_score = true;
       best_score_survival = highscore.Record{ ... };
       if (!bot_tainted) highscore.save(.survival, best_score_survival);
   }
   ```

2. **Zen score save** (`saveZenScoreIfBest`, ~line 1210-1220):
   - Guard with `if (!bot_tainted)` before `highscore.save(.zen, ...)`.
   - Though bot is survival-only (FR-016), this is a safety net.

### 7. Relationships to Existing Entities

| Bot State Field | Related Existing State | Relationship |
|----------------|----------------------|--------------|
| `bot_target_index` | `zombies[MAX_ZOMBIES]?*Zombie` | Index into the zombie pool |
| `bot_targeting_boss` | `boss: ?*Zombie` | Flags that the bot is typing the boss phrase |
| `bot_char_index` | `name[MAX_BOSS_INPUT_CHARS+1]u8`, `letter_count` | Bot injects into the same input buffer |
| `bot_type_timer` | `getWaveConfig(current_wave).target_wpm` | Cadence derived from wave config |
| `bot_active` | `current_screen`, `is_dying`, `is_transitioning` | Bot respects all existing state gates |
| `bot_tainted` | `highscore.save()` | Guards persistence calls |

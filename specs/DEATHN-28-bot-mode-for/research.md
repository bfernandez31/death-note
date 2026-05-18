# Research: Bot Mode for Difficulty Validation and Auto-Pilot Watching

**Branch**: `DEATHN-28-bot-mode-for` | **Date**: 2026-05-18

## Existing Files

### Source Files (will be modified)

| File | What it covers | Action |
|------|---------------|--------|
| `src/main.zig` (3271 lines) | Game loop, input handling, menu, HUD, zombie lifecycle, wave transitions, high-score gating | Extend: add bot state variables, bot update logic, menu entry, HUD badge, F2 toggle, high-score gating |
| `src/zombie_types.zig` (87 lines) | `GameMode` enum, `ZombieType`, `PowerUpType`, spawn/name weight tables | No change needed — bot mode uses `.survival` game mode, not a new enum variant |
| `src/highscore.zig` (143 lines) | `Record` struct, `load()`/`save()` for native + web backends | No change — high-score gating is done at the call sites in `main.zig`, not inside `highscore.zig` |

### Source Files (read-only — pattern references)

| File | What it covers | Used as pattern for |
|------|---------------|---------------------|
| `src/name_lists.zig` (470 lines) | Name selection, `selectName()` | Not directly relevant, but bot targets zombies by their `.name` field — same string format |
| `src/boss_phrases.zig` | `BossPhrases` array | Bot must handle boss phrases via same input buffer path |
| `src/sound_config.zig` | `SoundConfig` struct, volume/pack persistence | Pattern for adding a session-level config (though bot state doesn't persist) |

### Test Files (will be extended)

| File | Existing tests | Action |
|------|---------------|--------|
| `src/main.zig` (test blocks at ~line 2108) | 74 test blocks covering input, waves, scoring, metrics, power-ups, menu, pause | Extend: add tests for bot state, bot target selection, bot typing cadence, bot-tainted flag, high-score gating |
| `src/name_lists.zig` (test blocks at ~line 303) | 12 test blocks | No changes needed |
| `src/highscore.zig` (test blocks at ~line 119) | 6 test blocks | No changes needed — gating logic lives in main.zig |

### No new source files needed

The feature adds module-level state and functions to `src/main.zig`, following constitution Code Patterns §1: "New features should extend that structure in place." Bot mode is not a genuinely distinct concern warranting a split — it is deeply coupled to the game loop (input buffer, zombie array, wave state, boss state, HUD drawing).

## Patterns to Follow

### 1. Menu System Pattern (`src/main.zig:756-788`)

The menu is defined by a fixed-size array + count constant, with a switch on `menu_selection` for handling Enter:

```zig
const MENU_ITEMS = [_][]const u8{ "SURVIVAL", "ZEN", "SOUND", "QUIT" };
const MENU_ITEM_COUNT: u8 = 4;
// ...
switch (menu_selection) {
    0 => startGame(.survival, allocator),
    1 => current_screen = .wpm_select,
    2 => { sound settings... },
    3 => { quit... },
}
```

**How to apply**: Add `"BOT"` at index 2 (between ZEN and SOUND), bump `MENU_ITEM_COUNT` to 5, shift SOUND to case 3 and QUIT to case 4. BOT case calls `startGame(.survival, allocator)` with an additional `bot_active = true` flag set.

### 2. Input Handling Pattern (`src/main.zig:490-523`)

Character input is processed via `raylib.GetCharPressed()` in a while loop, with ASCII range validation, buffer bounds check, and match tracking:

```zig
var key = raylib.GetCharPressed();
while (key > 0) {
    if ((key >= 32) and (key <= 125)) {
        if (letter_count < getCurrentMaxInput()) {
            name[letter_count] = @intCast(key);
            name[letter_count + 1] = '\x00';
            letter_count += 1;
            // ... match check ...
        }
    }
    key = raylib.GetCharPressed();
}
```

**How to apply**: When bot is active, skip the `GetCharPressed()` loop entirely and instead inject synthetic characters in the bot update function using the same buffer write pattern: `name[letter_count] = char; name[letter_count + 1] = '\x00'; letter_count += 1;`. The bot must also call `typedMatchesAnyEnemy()` and `recordCorrectTimestamp()` / `playTypingSound()` to maintain the same metrics/sound side effects.

### 3. State Gating Pattern (`src/main.zig:476`)

The update phase is gated by: `if (!is_transitioning and !is_dying)`. All gameplay updates (input, spawning, zombie movement, boss) are inside this block. The playing screen state is checked via `current_screen == .playing` at the top-level switch.

**How to apply**: Bot update must respect the same gates: only type when `current_screen == .playing and !is_transitioning and !is_dying`. Additionally, the bot must not type while paused (`current_screen == .paused`).

### 4. High Score Write Pattern (`src/main.zig:597-606`)

High score is written when `is_dying` timer expires and score exceeds best:

```zig
if (score > best_score_survival.score) {
    is_new_high_score = true;
    best_score_survival = highscore.Record{ ... };
    highscore.save(.survival, best_score_survival);
}
```

**How to apply**: Guard the `highscore.save()` call with `and !bot_tainted`. In-memory `best_score_survival` can still update (FR-012 allows in-memory tracking). The `bot_tainted` flag must be checked at both write sites: line 605 (survival game-over) and line 1219 (`saveZenScoreIfBest` — though bot is survival-only, guard both for safety).

### 5. Session Reset Pattern (`src/main.zig:1223-1255`)

`startGame()` resets all session state via helper functions (`resetSessionState`, `resetScoreState`, `resetMetricsState`, `resetZombies`, `resetBoss`), then front-loads the starter pack.

**How to apply**: `startGame()` must also reset bot state (`bot_active`, `bot_target_index`, `bot_char_index`, `bot_type_timer`, `bot_reaction_timer`) and clear `bot_tainted` (new session = clean slate). When called from the BOT menu entry, additionally set `bot_active = true` after the reset.

### 6. HUD Drawing Pattern (`src/main.zig:1083-1132`)

HUD elements are drawn with `drawText()` using `CRT_*` colors, positioned via constant coordinates. Power-up status uses a stacking pattern (shield Y shifts down when freeze is active).

**How to apply**: Draw the "BOT" badge using the same `drawText()` wrapper, positioned in a non-overlapping area (e.g., top-center or near the wave info line). Use `CRT_WARN` (amber) for high visibility. Only draw when `bot_active == true`.

### 7. F-Key Check Pattern

No F-keys are currently bound. The pattern for key checks throughout the code is `raylib.IsKeyPressed(raylib.KEY_*)`.

**How to apply**: Add `if (raylib.IsKeyPressed(raylib.KEY_F2))` in the playing screen update, outside the `!is_transitioning and !is_dying` gate (so F2 works during transitions but not during dying/game-over). Set `bot_active = !bot_active` and `if (bot_active) bot_tainted = true`.

## Decisions

### D-1: Bot State Location

- **Decision**: All bot state as module-level variables in `src/main.zig`, adjacent to existing game state variables (around line 230)
- **Rationale**: Follows constitution §1 — bot mode is tightly coupled to the game loop, not a separable concern. Splitting would require passing 15+ game state variables through function parameters.
- **Alternatives considered**: Separate `src/bot.zig` module — rejected because it would need to import or receive virtually all game state (zombies, boss, input buffer, wave config), violating the "no import main.zig" rule and requiring massive parameter threading.

### D-2: Bot Typing Mechanism

- **Decision**: Bot accumulates a `bot_type_timer` each frame (incremented by `GetFrameTime()`). When the timer exceeds `1.0 / chars_per_second`, inject one character into the shared input buffer and reset the timer. `chars_per_second = target_wpm / 12.0` (5 chars/word ÷ 60 seconds × target_wpm).
- **Rationale**: Matches the spec's formula exactly. Using `GetFrameTime()` keeps the bot frame-rate-independent, same as all other timers in the game.
- **Alternatives considered**: (a) Inject entire name at once with delay — rejected, doesn't simulate typing cadence. (b) Use a fixed character interval ignoring WPM — rejected, breaks the validation purpose.

### D-3: Bot Target Selection

- **Decision**: Each frame (when no target is active and reaction delay has elapsed), scan `zombies` array for the active zombie with the highest Y (closest to bottom). Ties broken by shortest name length, then lowest X. Store the selected zombie's index in `bot_target_index`. For boss waves, target the boss when it exists (boss takes priority).
- **Rationale**: Spec FR-005 defines this exact priority. Scanning all 100 slots per frame is negligible at 60 FPS.
- **Alternatives considered**: Maintaining a sorted priority queue — rejected as unnecessary complexity for 100-slot array.

### D-4: Player Input Suppression

- **Decision**: When `bot_active == true`, skip the `GetCharPressed()` loop and backspace handling entirely. The bot exclusively controls the input buffer.
- **Rationale**: Spec edge case says "Player keypresses are ignored while the bot is active." Simplest approach: just don't read them. `GetCharPressed()` returns queued events — unread events are discarded by raylib on the next frame.
- **Alternatives considered**: Reading and discarding events — unnecessary, raylib handles this.

### D-5: Bot-Tainted Flag Scope

- **Decision**: `bot_tainted` is a module-level `bool`, set to `true` when `bot_active` is set to `true`, cleared only in `startGame()` (which is called from menu selection or game-over restart).
- **Rationale**: Spec ARD-7 defines this exact lifecycle. Clearing in `startGame()` is the right place because that's where all session state resets.
- **Alternatives considered**: Never clearing it (persist across sessions) — rejected, spec says "reset only on full game restart (returning to main menu and starting a new session)."

### D-6: Power-Up Suppression

- **Decision**: Guard the Space-key power-up activation with `and !bot_active`. The bot never issues Space input.
- **Rationale**: Spec FR-008 says bot must never activate power-ups. Since the bot injects characters directly into the buffer (not via GetCharPressed), it naturally never generates Space as a power-up trigger. The guard on the explicit Space check at line 485 handles the edge case where GetCharPressed could theoretically queue a space event.
- **Alternatives considered**: Having the bot intentionally skip Space in its character injection — the bot already only types the target's name characters, so Space as power-up trigger can't occur. The explicit guard is belt-and-suspenders.

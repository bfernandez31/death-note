# Implementation Plan: Bot Mode for Difficulty Validation and Auto-Pilot Watching

**Branch**: `DEATHN-28-bot-mode-for` | **Date**: 2026-05-18 | **Spec**: `specs/DEATHN-28-bot-mode-for/spec.md`
**Input**: Feature specification from `specs/DEATHN-28-bot-mode-for/spec.md`

## Summary

Add an AI bot that can play Survival mode autonomously, typing zombie names at the wave's announced WPM cadence. The bot validates that the survival-floor math is genuinely survivable by observation, serves as an auto-pilot demo, and can be toggled on/off mid-game with F2. A session-level "bot-tainted" flag permanently disables high-score persistence whenever bot mode has been active. Implementation is entirely within `src/main.zig` — no new source files, no new dependencies.

## Technical Context

**Language/Version**: Zig (0.16+ toolchain, no pinned version)
**Primary Dependencies**: raylib (pinned commit `52f2a10d` via `build.zig.zon`)
**Storage**: Binary file (`highscore.dat`) on native, `localStorage` on web — no changes to storage layer, only gating at call sites
**Testing**: Zig built-in test runner (`zig build test`), 74 existing tests in `main.zig`
**Target Platform**: Desktop (Linux/macOS/Windows) + WebAssembly (Emscripten)
**Project Type**: Single executable (Zig + raylib)
**Performance Goals**: 60 FPS maintained — bot adds negligible per-frame work (one array scan of ≤100 slots)
**Constraints**: No new dependencies, no new source files, no network access
**Scale/Scope**: ~200 lines of new code in `src/main.zig` (bot state vars, update function, target selection, menu/HUD changes, tests)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Rule | Status | Notes |
|------|------|--------|-------|
| Code Patterns §1 | Single-module game loop; extend in place | **PASS** | All bot logic in `src/main.zig`; no new module needed (bot is tightly coupled to game loop state) |
| Code Patterns §1 | Split only for distinct concern, duplication, or pure data | **PASS** | Not splitting — bot state is deeply interleaved with input buffer, zombie array, wave config, boss state |
| Code Patterns §1 | No indirection layers until concrete duplication | **PASS** | No interfaces, registries, or event buses introduced |
| Code Patterns §2 | C interop walled off in `raylib.zig` | **PASS** | No new `@cImport` calls; bot uses existing `raylib.IsKeyPressed()` via the re-export |
| Code Patterns §3 | Explicit named constants for tunables | **PASS** | `BOT_REACTION_DELAY` as named constant, not inline `0.2` |
| Code Patterns §5 | Optional pointers unwrapped with `if (x) \|val\|` | **PASS** | Bot target selection uses `if (zombies[i]) \|zomb\|` pattern |
| Code Patterns §7 | Fixed-size pools, not dynamic lists | **PASS** | Bot state is scalar variables, not new collections |
| Testing §1 | Zig built-in test runner only | **PASS** | All new tests are `test "..." { ... }` blocks in `main.zig` |
| Testing §3 | Pure logic has test blocks | **PASS** | Bot target selection, cadence calc, state transitions covered |
| Testing §4 | Manual requirements for rendering changes | **PASS** | BOT badge and menu entry require manual verification |
| Security §1 | No secrets, no network | **PASS** | Bot is purely local logic |
| Security §2 | Bounded input buffers | **PASS** | Bot respects `getCurrentMaxInput()` same as human input |
| Code Quality §3 | Naming discipline | **PASS** | `bot_active`, `bot_tainted` (snake_case vars), `BOT_REACTION_DELAY` (SCREAMING_SNAKE), `updateBot` (camelCase fn), `BotState` not used as a type name (kept as raw vars per existing pattern) |
| Agent Authority | No pinned dependency changes | **PASS** | No `build.zig.zon` changes |
| Agent Authority | No network/filesystem-write additions | **PASS** | Only *prevents* existing writes (high-score gating) |

**Post-Phase 1 re-check**: All gates still pass. No design decisions introduced architectural violations.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-28-bot-mode-for/
├── plan.md              # This file
├── research.md          # Phase 0 output: existing files, patterns, decisions
├── data-model.md        # Phase 1 output: entity definitions, state transitions
└── tasks.md             # Phase 2 output (not created by /plan)
```

### Source Code (repository root)

```
src/
├── main.zig           # ALL changes here: bot state vars, updateBot(), selectBotTarget(),
│                      #   resetBotState(), menu entry, F2 toggle, HUD badge, HS gating, tests
├── zombie_types.zig   # Unchanged
├── highscore.zig      # Unchanged
├── name_lists.zig     # Unchanged
├── boss_phrases.zig   # Unchanged
├── raylib.zig         # Unchanged
├── sound_config.zig   # Unchanged
└── zombie_names.zig   # Unchanged (legacy)
```

**Structure Decision**: Single file modification (`src/main.zig`) per constitution §1. Bot mode is deeply coupled to the game loop — it reads/writes the shared input buffer, scans the zombie array, checks wave config, targets boss, and draws on the HUD. All of these are module-level state in `main.zig`.

## Implementation Phases

### Phase 1: Bot State & Core Logic (foundation — no UI yet)

**Goal**: Bot can type zombie names at the correct cadence when activated programmatically.

1. **Add bot state variables** (~line 232, after `game_mode`):
   - `bot_active`, `bot_tainted`, `bot_target_index`, `bot_targeting_boss`, `bot_char_index`, `bot_type_timer`, `bot_reaction_timer`
   - Add `BOT_REACTION_DELAY` constant near other timing constants (~line 62)

2. **Add `resetBotState()` function**:
   - Clears all bot variables to defaults. Called from `startGame()`.
   - Pattern: follows `resetSessionState()` at line 1951

3. **Add `selectBotTarget()` function**:
   - Scans `zombies` array for highest-Y active zombie
   - Tie-break: shortest name, then lowest X (FR-005, ARD-6)
   - Boss priority: if `boss != null`, target boss instead (FR-007)
   - Returns: sets `bot_target_index` or `bot_targeting_boss`

4. **Add `updateBot()` function**:
   - Gate: only run when `bot_active and !is_transitioning and !is_dying and current_screen == .playing`
   - Reaction delay: if `bot_reaction_timer > 0`, decrement by `GetFrameTime()` and return
   - Target acquisition: if no current target, call `selectBotTarget()`, start reaction delay
   - Validate target still exists (zombie may have been killed by bomb)
   - Cadence: accumulate `bot_type_timer += GetFrameTime()`. When timer >= interval, inject next character
   - Character injection: write to shared `name` buffer using same pattern as line 498-501
   - Side effects: call `typedMatchesAnyEnemy()`, `recordCorrectTimestamp()`, `playTypingSound()` to maintain metrics
   - On target killed (match detected in `updateZombies`): reset `bot_char_index`, clear target, start reaction delay

5. **Wire `updateBot()` into game loop**:
   - Call inside the `.playing` screen case, after the `!is_transitioning and !is_dying` block
   - When `bot_active`, skip the human input path (GetCharPressed loop + backspace)

6. **Add bot-aware high-score gating**:
   - Guard `highscore.save(.survival, ...)` at ~line 605 with `!bot_tainted`
   - Guard `highscore.save(.zen, ...)` in `saveZenScoreIfBest()` with `!bot_tainted`

### Phase 2: Menu, Toggle, & HUD (user-facing integration)

**Goal**: Player can start bot mode from the menu, toggle with F2, and see the BOT badge.

1. **Update menu array and handler** (~line 756-788):
   - Insert `"BOT"` at index 2 in `MENU_ITEMS`
   - Bump `MENU_ITEM_COUNT` to 5
   - Add case 2: `bot_active = true; bot_tainted = true; startGame(.survival, allocator);`
   - Shift SOUND to case 3, QUIT to case 4

2. **Add F2 toggle in playing screen** (~line 476):
   - Inside `.playing` case, *before* the `!is_transitioning and !is_dying` gate (so F2 works during transitions)
   - But *after* the `is_dying` check (F2 has no effect during dying animation)
   - `if (raylib.IsKeyPressed(raylib.KEY_F2) and !is_dying)`: toggle `bot_active`, set `bot_tainted = true` if activating
   - On deactivation: leave input buffer as-is (player resumes from current state)
   - On activation: clear input buffer (`letter_count = 0; name[0] = '\x00'`), start reaction delay

3. **Draw BOT badge in HUD** (in `drawPlayingHud()`, ~line 1083):
   - When `bot_active`, draw `"BOT"` using `drawText()` with `CRT_WARN` color
   - Position: top-center area, below the wave info line (e.g., y=35, centered)
   - Visible in both survival HUD and during transitions

4. **Suppress player input when bot active**:
   - Wrap the `GetCharPressed` loop and backspace handler in `if (!bot_active) { ... }`
   - Wrap the Space power-up activation in `if (!bot_active) { ... }` (FR-008)

### Phase 3: Edge Cases & Polish

**Goal**: Handle all edge cases from spec, add robustness.

1. **Bot state on wave transition**:
   - When `is_transitioning` becomes true, clear `bot_target_index` and `bot_char_index`
   - When transition ends (wave advances), start reaction delay for new wave

2. **Bot target invalidation**:
   - In `updateBot()`, verify target zombie still exists before typing
   - If target slot is `null` (killed by bomb), clear target, start reaction delay, clear partial input

3. **F2 during pause/game-over**:
   - F2 only works in `.playing` screen state (spec edge case: "F2 has no effect while pause menu is open")

4. **Bot and Zen mode**:
   - F2 toggle only activates bot when `game_mode == .survival` (FR-016)
   - If in Zen mode, F2 is a no-op

5. **`startGame()` bot state reset**:
   - `resetBotState()` called in `startGame()` clears `bot_active`, but NOT `bot_tainted` (cleared separately at start of `startGame()` since it's a new session)
   - Actually per spec: `bot_tainted` cleared on new session → clear in `startGame()` alongside other session state

### Phase 4: Tests

**Goal**: Cover all bot logic with unit tests.

New test blocks in `src/main.zig`:

1. `test "bot reaction delay constant is 0.2"` — verify `BOT_REACTION_DELAY == 0.2`
2. `test "bot chars per second at wave 1"` — verify `20 * 5.0 / 60.0 ≈ 1.667`
3. `test "bot chars per second at max wave"` — verify formula at 250 WPM
4. `test "bot target selection picks highest Y"` — create test zombies, verify selection
5. `test "bot target tie-break: shortest name then leftmost"` — equidistant zombies
6. `test "bot_tainted blocks high score save"` — verify gating logic
7. `test "bot_tainted cleared on startGame"` — verify session reset
8. `test "bot_tainted persists through F2 toggle off"` — set tainted, toggle off, verify still tainted
9. `test "menu has 5 items with BOT at index 2"` — verify menu array
10. `test "bot state reset clears all fields"` — verify `resetBotState()`
11. `test "bot does not type during transition"` — verify state gating
12. `test "bot does not type during dying"` — verify state gating

## Testing Strategy

### Unit Tests (in `src/main.zig`, extend existing test blocks)

- **Bot cadence formula**: Verify `chars_per_second` calculation matches `target_wpm / 12.0` at multiple wave values
- **Target selection**: Test the selection priority (highest Y → shortest name → leftmost X) with mock zombie data
- **Bot-tainted flag lifecycle**: Set on activation, persists through toggle-off, cleared on `startGame()`
- **High-score gating**: When `bot_tainted == true`, verify `highscore.save()` is not called (test the condition, not the call — we can't mock the function)
- **State reset**: `resetBotState()` clears all bot variables
- **Menu structure**: Array has 5 items, BOT is at index 2

### Manual Verification (via `zig build run`)

- [ ] Select BOT from main menu → survival session starts with bot typing
- [ ] BOT badge visible on HUD in CRT_WARN color
- [ ] Bot types at correct cadence (visually verify ~1 char/0.6s at wave 1)
- [ ] Bot clears wave 1 (all zombies killed before reaching bottom)
- [ ] Bot handles wave transition (stops during countdown, resumes after)
- [ ] Bot handles boss wave (types full boss phrase)
- [ ] Bot does NOT activate power-ups (power-ups sit in inventory)
- [ ] F2 toggles bot on/off mid-game, badge appears/disappears
- [ ] F2 during pause has no effect
- [ ] F2 in Zen mode has no effect
- [ ] No high-score written after bot-tainted game-over (check `highscore.dat` not created/updated)
- [ ] Player can type normally after toggling bot off with F2
- [ ] Starting new game from menu clears bot-tainted flag

## Complexity Tracking

No constitution violations. No complexity justifications needed.

## Risks

1. **Bot slightly faster/slower than intended** — The `GetFrameTime()` accumulation may cause the bot to inject a character one frame early or late, creating micro-variance in effective WPM. Acceptable: the game's own WPM display uses the same smoothed calculation, so displayed WPM will match the target within ±1 WPM.

2. **Bot fails late waves** — At very high WPM (200+), the reaction delay (200ms) may matter more. The delay is tunable per FR-015, so developers can set it to 0ms for pure-cadence validation.

3. **Input buffer state on F2 toggle** — When deactivating, the partially-typed name stays in the buffer. The player must backspace or finish it. This matches spec: "the player resumes manual typing from the current input buffer state."

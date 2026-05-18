# Tasks: Bot Mode for Difficulty Validation and Auto-Pilot Watching

**Input**: Design documents from `/specs/DEATHN-28-bot-mode-for/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Test tasks are included by default (constitution). Only skip if the user explicitly instructs not to generate tests.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/main.zig` at repository root (all bot logic lives here per constitution §1)
- **Tests**: Zig inline `test` blocks in `src/main.zig` (extend existing 74 tests)

---

## Phase 1: Setup (Bot State Foundation)

**Purpose**: Add all bot state variables and constants to `src/main.zig` so subsequent phases can reference them.

- [ ] T001 Add bot constants (`BOT_REACTION_DELAY = 0.2`) near existing timing constants (~line 62) in `src/main.zig`
- [ ] T002 Add bot state variables (`bot_active`, `bot_tainted`, `bot_target_index`, `bot_targeting_boss`, `bot_char_index`, `bot_type_timer`, `bot_reaction_timer`) as module-level vars after `game_mode` (~line 232) in `src/main.zig`
- [ ] T003 Add `resetBotState()` function that clears all bot variables to defaults, following the `resetSessionState()` pattern (~line 1951) in `src/main.zig`
- [ ] T004 Wire `resetBotState()` into `startGame()` (~line 1223) alongside existing reset calls, and clear `bot_tainted` there (new session = clean slate) in `src/main.zig`

**Checkpoint**: Bot state variables exist and are reset on game start. No functional behavior yet.

---

## Phase 2: Foundational (Core Bot Logic — Blocking Prerequisites)

**Purpose**: Core bot functions that MUST be complete before ANY user story can be implemented.

**CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T005 Implement `selectBotTarget()` function that scans `zombies` array for highest-Y active zombie, tie-breaks by shortest name then lowest X, and sets `bot_target_index`; when `boss != null`, set `bot_targeting_boss = true` instead in `src/main.zig`
- [ ] T006 Implement `updateBot()` function: gate on `bot_active and !is_transitioning and !is_dying and current_screen == .playing`; handle reaction delay countdown; call `selectBotTarget()` when no target; accumulate `bot_type_timer` and inject characters into shared `name` buffer at `target_wpm / 12.0` chars/sec; call `typedMatchesAnyEnemy()`, `recordCorrectTimestamp()`, `playTypingSound()` for metrics/sound side effects; reset bot state on target kill in `src/main.zig`
- [ ] T007 Wire `updateBot()` into the game loop inside the `.playing` screen case, after the `!is_transitioning and !is_dying` block; when `bot_active`, skip the human `GetCharPressed` loop and backspace handler in `src/main.zig`
- [ ] T008 Add bot-aware high-score gating: guard `highscore.save(.survival, ...)` at line 605 with `and !bot_tainted`; guard `highscore.save(.zen, ...)` at line 1219 with `and !bot_tainted` in `src/main.zig`

**Checkpoint**: Bot can type zombie names at the correct cadence when `bot_active` is set programmatically. High scores are blocked when tainted. No UI entry point yet.

---

## Phase 3: User Story 1 — Watch the Bot Validate Wave 1 Survival Floor (Priority: P1) MVP

**Goal**: Developer selects "BOT" from main menu, watches bot type zombie names at wave-1 cadence, all zombies killed before landing. No high-score written.

**Independent Test**: Start the game, select BOT from menu, observe wave 1 — all zombies killed before landing. Check `highscore.dat` is not created/updated.

### Tests for User Story 1
**NOTE: Write these tests FIRST, ensure they FAIL before implementation**
**RULE (constitution): Extend existing test blocks in `src/main.zig` (74 tests already present at ~line 2108). No new test file needed.**

- [ ] T009 [P] [US1] Extend tests in `src/main.zig`: add `test "bot reaction delay constant is 0.2"` verifying `BOT_REACTION_DELAY == 0.2`
- [ ] T010 [P] [US1] Extend tests in `src/main.zig`: add `test "bot chars per second at wave 1"` verifying `20 * 5.0 / 60.0` equals ~1.667 chars/sec
- [ ] T011 [P] [US1] Extend tests in `src/main.zig`: add `test "bot chars per second at max wave"` verifying formula at 250 WPM yields ~20.83 chars/sec
- [ ] T012 [P] [US1] Extend tests in `src/main.zig`: add `test "bot state reset clears all fields"` verifying `resetBotState()` sets all bot vars to defaults
- [ ] T013 [P] [US1] Extend tests in `src/main.zig`: add `test "menu has 5 items with BOT at index 2"` verifying `MENU_ITEMS[2]` is `"BOT"` and `MENU_ITEM_COUNT == 5`
- [ ] T014 [P] [US1] Extend tests in `src/main.zig`: add `test "bot_tainted blocks high score save"` verifying the gating condition `!bot_tainted` is checked before save calls
- [ ] T015 [P] [US1] Extend tests in `src/main.zig`: add `test "bot_tainted cleared on startGame"` verifying `bot_tainted` resets to false on new session

### Implementation for User Story 1

- [ ] T016 [US1] Update `MENU_ITEMS` array to `{ "SURVIVAL", "ZEN", "BOT", "SOUND", "QUIT" }` and `MENU_ITEM_COUNT` to 5 at line 756-757 in `src/main.zig`
- [ ] T017 [US1] Update the menu Enter handler switch: add case 2 for BOT (`bot_active = true; bot_tainted = true; startGame(.survival, allocator);`), shift SOUND to case 3 and QUIT to case 4 in `src/main.zig`
- [ ] T018 [US1] Update existing menu wrap-around tests to expect `MENU_ITEM_COUNT == 5` (adjust values at ~line 2961-2963) in `src/main.zig`
- [ ] T019 [US1] Suppress player keyboard input when bot active: wrap the `GetCharPressed` loop and backspace handler (~line 490-523) in `if (!bot_active) { ... }` in `src/main.zig`
- [ ] T020 [US1] Suppress power-up activation when bot active: guard Space key activation (~line 485) with `and !bot_active` per FR-008 in `src/main.zig`

**Checkpoint**: BOT menu entry works, bot plays wave 1 autonomously at correct cadence, high scores not persisted. US1 is fully functional and testable independently.

---

## Phase 4: User Story 2 — Toggle Bot On/Off Mid-Game with F2 (Priority: P2)

**Goal**: Player presses F2 during Survival session to toggle bot on/off. BOT badge appears/disappears. Bot-tainted flag persists for entire session.

**Independent Test**: Start a Survival game normally, press F2 mid-wave, confirm bot starts typing. Press F2 again, confirm manual control resumes. Verify no high-score written at game over.

### Tests for User Story 2
**RULE (constitution): Extend existing test blocks in `src/main.zig`.**

- [ ] T021 [P] [US2] Extend tests in `src/main.zig`: add `test "bot_tainted persists through F2 toggle off"` — set tainted via activation, toggle bot off, verify tainted still true
- [ ] T022 [P] [US2] Extend tests in `src/main.zig`: add `test "bot does not type during transition"` — verify `updateBot()` gate respects `is_transitioning`
- [ ] T023 [P] [US2] Extend tests in `src/main.zig`: add `test "bot does not type during dying"` — verify `updateBot()` gate respects `is_dying`

### Implementation for User Story 2

- [ ] T024 [US2] Add F2 toggle in the `.playing` screen update: `if (raylib.IsKeyPressed(raylib.KEY_F2) and !is_dying and game_mode == .survival)` toggles `bot_active`, sets `bot_tainted = true` on activation, clears input buffer on activation, starts reaction delay in `src/main.zig`
- [ ] T025 [US2] On F2 deactivation: leave input buffer as-is so player resumes from current state; clear `bot_target_index` and `bot_char_index` in `src/main.zig`
- [ ] T026 [US2] Ensure F2 is a no-op when `current_screen != .playing` (pause, game-over, menu) and when `game_mode == .zen` per FR-016 in `src/main.zig`

**Checkpoint**: F2 toggle works mid-game, bot-tainted flag persists. US1 and US2 both work independently.

---

## Phase 5: User Story 3 — Bot Handles Boss Waves (Priority: P2)

**Goal**: Bot encounters a boss wave (every 5th wave), types the full boss phrase at wave cadence including spaces.

**Independent Test**: Let bot play through waves 1–5, observe wave 5 (boss). Bot types boss phrase correctly and kills boss before it reaches the bottom.

### Tests for User Story 3
**RULE (constitution): Extend existing test blocks in `src/main.zig`.**

- [ ] T027 [P] [US3] Extend tests in `src/main.zig`: add `test "bot target selection picks boss when present"` — verify `selectBotTarget()` sets `bot_targeting_boss = true` when boss exists

### Implementation for User Story 3

- [ ] T028 [US3] Ensure `selectBotTarget()` prioritizes boss: when `boss != null`, set `bot_targeting_boss = true` and `bot_target_index = null`; bot types boss phrase characters (including spaces) via the same input buffer path in `src/main.zig`
- [ ] T029 [US3] Ensure `updateBot()` reads from boss phrase (up to `MAX_BOSS_INPUT_CHARS = 35`) when `bot_targeting_boss == true`, and resets boss targeting state when boss is killed in `src/main.zig`

**Checkpoint**: Bot handles boss waves correctly. US1, US2, and US3 all work independently.

---

## Phase 6: User Story 4 — Bot Ignores Power-Ups (Priority: P3)

**Goal**: Bot never activates held power-ups. Power-ups sit in inventory until wave ends or player takes manual control.

**Independent Test**: Enable bot mode, play several waves, observe power-ups are picked up (HUD shows held power-up) but never consumed.

### Tests for User Story 4
**RULE (constitution): Extend existing test blocks in `src/main.zig`.**

- [ ] T030 [P] [US4] Extend tests in `src/main.zig`: add `test "bot never activates power-ups"` — verify Space key activation is gated by `!bot_active`

### Implementation for User Story 4

- [ ] T031 [US4] Verify that T020 (Space key guard with `!bot_active`) covers FR-008 completely — bot cannot issue Space key input since it only injects name characters into the buffer; confirm no additional code path triggers power-up activation in `src/main.zig`

**Checkpoint**: Bot plays through carrier waves without activating power-ups. All US1–US4 work independently.

---

## Phase 7: User Story 5 — "BOT" Visual Badge (Priority: P3)

**Goal**: Prominent "BOT" badge displayed on HUD whenever bot mode is active.

**Independent Test**: Activate bot mode, confirm badge visible in `CRT_WARN` color. Deactivate, confirm badge disappears.

### Tests for User Story 5
**RULE (constitution): Extend existing test blocks in `src/main.zig`.**

- [ ] T032 [P] [US5] Extend tests in `src/main.zig`: add `test "bot badge uses CRT_WARN tint"` — verify the badge color constant matches `CRT_WARN`

### Implementation for User Story 5

- [ ] T033 [US5] Draw "BOT" badge in `drawPlayingHud()` (~line 1083) when `bot_active == true`: use `drawText()` with `CRT_WARN` color, positioned top-center (e.g., y=35, x centered), visible during both gameplay and transitions in `src/main.zig`

**Checkpoint**: BOT badge appears/disappears correctly. All user stories (US1–US5) work independently.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Edge case handling and robustness across all user stories.

- [ ] T034 Clear `bot_target_index` and `bot_char_index` when `is_transitioning` becomes true (wave transition resets bot targeting state) in `src/main.zig`
- [ ] T035 In `updateBot()`, validate target zombie still exists before typing — if `zombies[bot_target_index.?]` is `null` (killed by bomb), clear target, clear partial input, start reaction delay in `src/main.zig`
- [ ] T036 [P] Extend tests in `src/main.zig`: add `test "bot target selection picks highest Y"` — create test scenarios with zombies at different Y positions
- [ ] T037 [P] Extend tests in `src/main.zig`: add `test "bot target tie-break: shortest name then leftmost"` — equidistant zombies with varying name lengths and X positions
- [ ] T038 Ensure `startGame()` sets `bot_active = true` and `bot_tainted = true` AFTER `resetBotState()` when called from the BOT menu entry (order matters: reset clears, then menu re-sets) in `src/main.zig`
- [ ] T039 Run `zig build test` to confirm all new and existing tests pass
- [ ] T040 Run `zig build` to confirm the project compiles without errors for native target

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Stories (Phases 3–7)**: All depend on Phase 2 completion
  - US1 (Phase 3): Can proceed immediately after Phase 2
  - US2 (Phase 4): Can proceed in parallel with US1 (different code paths)
  - US3 (Phase 5): Can proceed in parallel with US1/US2 (boss handling is independent)
  - US4 (Phase 6): Depends on T020 from US1 (Space key guard) — run after US1
  - US5 (Phase 7): Can proceed in parallel with all other stories (HUD-only)
- **Polish (Phase 8)**: Depends on Phases 2–7 completion

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P2)**: Can start after Phase 2 — independent from US1 (F2 toggle is separate from menu entry)
- **US3 (P2)**: Can start after Phase 2 — independent from US1/US2 (boss targeting is in `selectBotTarget`)
- **US4 (P3)**: Depends on US1 T020 (Space key guard) — run after US1 or verify guard exists
- **US5 (P3)**: Can start after Phase 2 — fully independent (HUD-only change)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Constants/state before logic functions
- Logic functions before UI integration
- Core implementation before edge cases

### Parallel Opportunities

- T001, T002 can run in parallel (different line locations in `src/main.zig`)
- T009–T015 (US1 tests) can all run in parallel
- T021–T023 (US2 tests) can all run in parallel
- US1, US2, US3, US5 can proceed in parallel after Phase 2
- T036, T037 (Polish tests) can run in parallel
- T039, T040 (build validation) should run sequentially

---

## Parallel Example: User Story 1

```bash
# Launch all tests for US1 together (T009-T015):
Task: "test bot reaction delay constant" in src/main.zig
Task: "test bot chars per second at wave 1" in src/main.zig
Task: "test bot chars per second at max wave" in src/main.zig
Task: "test bot state reset clears all fields" in src/main.zig
Task: "test menu has 5 items with BOT at index 2" in src/main.zig
Task: "test bot_tainted blocks high score save" in src/main.zig
Task: "test bot_tainted cleared on startGame" in src/main.zig

# Then implementation sequentially:
Task: T016 - Update MENU_ITEMS array
Task: T017 - Update menu Enter handler
Task: T018 - Update existing menu tests
Task: T019 - Suppress player input when bot active
Task: T020 - Suppress power-up activation
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T004)
2. Complete Phase 2: Foundational (T005–T008)
3. Complete Phase 3: User Story 1 (T009–T020)
4. **STOP and VALIDATE**: `zig build test` + `zig build run` → select BOT from menu → watch wave 1
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational  Foundation ready
2. Add User Story 1  Test independently  MVP! (bot plays from menu)
3. Add User Story 2  Test independently  (F2 toggle mid-game)
4. Add User Story 3  Test independently  (boss wave handling)
5. Add User Story 4  Test independently  (power-up suppression)
6. Add User Story 5  Test independently  (BOT badge on HUD)
7. Polish  Final validation

### Parallel Execution Strategy

1. Complete Setup + Foundational phases sequentially (T001–T008)
2. Once Foundational is done, stories can run in parallel:
   - Parallel task 1: User Story 1 (menu entry, core flow)
   - Parallel task 2: User Story 2 (F2 toggle)
   - Parallel task 3: User Story 3 (boss handling)
   - Parallel task 5: User Story 5 (HUD badge)
3. User Story 4 after US1 completes (depends on T020)
4. Polish phase after all stories complete

---

## Notes

- All 40 tasks modify a single file (`src/main.zig`) — tasks marked [P] affect different line regions with no overlap
- [Story] label maps each task to its user story for traceability
- Each user story is independently completable and testable
- Verify tests fail before implementing
- Commit after each phase or logical group
- Stop at any checkpoint to validate story independently
- The bot adds ~200 lines of new code to `src/main.zig`

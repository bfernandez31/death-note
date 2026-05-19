# Tasks: Modes Survie, Arcade et Simulation avec systeme de vies

**Input**: Design documents from `/specs/DEATHN-29-modes-survie-arcade/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

**Tests**: Test tasks are included by default (constitution). Tests are Zig `test "..." {}` blocks written inline in the module under test (no separate test files).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- **Single-module Zig game**: `src/` at repository root
- Files to modify: `src/zombie_types.zig`, `src/highscore.zig`, `src/main.zig`
- No new files created (constitution CP-1)

---

## Phase 1: Setup

**Purpose**: No project initialization needed. All changes extend existing files. No new dependencies, no new asset files.

*Skipped — the project is already structured and building.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend `GameMode` enum with `.arcade` and `.simulation` variants, then fix all compile errors in `highscore.zig` exhaustive switches. Declare the arcade high score variable. This unblocks all user story work.

**CRITICAL**: `highscore.zig` has exhaustive `switch` on `GameMode` at lines 16 and 23. Adding new enum variants will break compilation until these switches are updated. `main.zig` uses `if` conditionals (not exhaustive switches) on `game_mode`, so it compiles without changes.

- [x] T001 Extend `GameMode` enum with `.arcade` and `.simulation` variants in `src/zombie_types.zig:15-18`
- [x] T002 [P] Update test `"GameMode enum has 2 variants"` to expect 4 variants in `src/zombie_types.zig:84-87`
- [x] T003 Add `.arcade => "highscore-arcade.dat"` and `.simulation => "highscore.dat"` arms to `filename()` switch in `src/highscore.zig:15-20`
- [x] T004 Add `.arcade => "death-note.highscore.arcade"` and `.simulation => "death-note.highscore"` arms to `webKey()` switch in `src/highscore.zig:22-27`
- [x] T005 [P] Add test `"filename arcade returns highscore-arcade.dat"` and test `"webKey arcade returns death-note.highscore.arcade"` in `src/highscore.zig`
- [x] T006 Declare `var best_score_arcade: highscore.Record = .{};` at `src/main.zig:221` (after `best_score_survival`) and add `best_score_arcade = highscore.load(.arcade);` in initialization block

**Checkpoint**: `zig build test` passes. Code compiles with 4 GameMode variants. Arcade high score loads at startup.

---

## Phase 3: User Story 1 — Main Menu Mode Selection (Priority: P1) MVP

**Goal**: Redesign menu from 5 items (SURVIVAL, ZEN, BOT, SOUND, QUIT) to 6 items (SURVIE, ARCADE, SIMULATION, ZEN, SOUND, QUIT). Each item launches the correct mode.

**Independent Test**: Launch game, verify 6 menu items display in correct order, each launches the expected mode.

### Tests for User Story 1

- [x] T007 [P] [US1] Add test `"menu has 6 items"` verifying `MENU_ITEMS.len == 6` and `MENU_ITEM_COUNT == 6` in `src/main.zig`
- [x] T008 [P] [US1] Add test `"menu item labels are SURVIE ARCADE SIMULATION ZEN SOUND QUIT"` verifying exact label strings and order in `src/main.zig`

### Implementation for User Story 1

- [x] T009 [US1] Update `MENU_ITEMS` array to `{ "SURVIE", "ARCADE", "SIMULATION", "ZEN", "SOUND", "QUIT" }` and `MENU_ITEM_COUNT` to `6` in `src/main.zig:808-809`
- [x] T010 [US1] Update `updateMenu()` switch at `src/main.zig:821-852`: index 0 = SURVIE (`startGame(.survival, allocator)`), index 1 = ARCADE (`startGame(.arcade, allocator)`), index 2 = SIMULATION (current bot activation code with `.simulation`), index 3 = ZEN (current zen flow), index 4 = SOUND, index 5 = QUIT
- [x] T011 [US1] Update `drawMenu()` high score display at `src/main.zig:872-878` to handle `.arcade` and `.simulation` in the `last_played_mode` conditional, add mode label prefix (e.g., "SURVIE BEST:" / "ARCADE BEST:")

**Checkpoint**: Menu shows 6 items. Each mode launches correctly. High score display shows mode-specific labels.

---

## Phase 4: User Story 2 — Survie Mode: Hardcore Experience (Priority: P1)

**Goal**: Ensure Survie (`.survival`) mode has zero power-up drops. Same wave progression, same boss schedule, single zombie reaching bottom = game over. This is the current survival mode stripped of power-ups.

**Independent Test**: Select Survie, play 10+ waves, confirm zero power-ups appear and single death ends the game.

### Tests for User Story 2

- [x] T012 [P] [US2] Add test `"power-ups drop only in arcade mode"` verifying the mode condition in the power-up drop logic references `.arcade` in `src/main.zig`

### Implementation for User Story 2

- [x] T013 [US2] Change power-up drop condition from `if (game_mode == .survival)` to `if (game_mode == .arcade)` in `spawnZombieInZone()` at `src/main.zig:1732-1740`

**Checkpoint**: Survie mode produces zero power-up drops across all waves. All other survival behavior unchanged.

---

## Phase 5: User Story 3 — Arcade Mode: Lives and Powers (Priority: P1)

**Goal**: Implement the 3-heart lives system for Arcade mode. Hearts display on HUD, losing a zombie costs 1 heart (not instant death), defeating a boss restores 1 heart (capped at 3), game over at 0 hearts. Power-ups enabled.

**Independent Test**: Select Arcade, verify 3 hearts visible, lose hearts on zombie reach, restore on boss defeat, game over only at 0 hearts.

### Tests for User Story 3

- [x] T014 [P] [US3] Add test `"MAX_HEARTS is 3"` verifying the constant value in `src/main.zig`
- [x] T015 [P] [US3] Add test `"hearts start at MAX_HEARTS in arcade mode"` verifying initialization logic in `src/main.zig`
- [x] T016 [P] [US3] Add test `"hearts start at 0 in survival mode"` verifying non-arcade modes get 0 hearts in `src/main.zig`
- [x] T017 [P] [US3] Add test `"heart restore caps at MAX_HEARTS"` verifying increment never exceeds 3 in `src/main.zig`

### Implementation for User Story 3

- [x] T018 [US3] Add hearts constants (`MAX_HEARTS`, `HEART_LOSS_FLASH_DURATION`, `HEART_RESTORE_FLASH_DURATION`) and state variables (`hearts`, `heart_flash_timer`, `heart_flash_is_loss`) at file scope in `src/main.zig` near line 227
- [x] T019 [US3] Initialize `hearts = if (mode == .arcade) MAX_HEARTS else 0` and reset flash state in `startGame()` at `src/main.zig:1293`
- [x] T020 [US3] Add hearts reset (`hearts = 0`, `heart_flash_timer = 0.0`, `heart_flash_is_loss = false`) to `resetSessionState()` at `src/main.zig:2032-2041`
- [x] T021 [US3] Implement arcade heart-loss branch before existing death code in `updateZombies()` at `src/main.zig:1502`: decrement hearts, play damage sound, destroy zombie, set flash timer, trigger `is_dying` if hearts == 0, `continue` otherwise
- [x] T022 [US3] Implement heart restore on boss defeat: after boss kill scoring at `src/main.zig:1864-1879`, if arcade and `hearts < MAX_HEARTS`, increment hearts, set restore flash, play shield sound
- [x] T023 [US3] Add `heart_flash_timer` countdown (`-= GetFrameTime()`, clamp to 0) in the playing update phase in `src/main.zig`
- [x] T024 [US3] Expand starter pack guard from `.survival` to `.survival or .arcade or .simulation` at `startGame()` (`src/main.zig:1319`) and wave transition (`src/main.zig:634`)
- [x] T025 [US3] Add HUD constants (`HEART_HUD_Y`, `HEART_HUD_SIZE`, `HEART_SPACING`) and implement `drawHeartsHud()` function: draw filled hearts in `CRT_ERR`, empty in `CRT_DIM`, pulse flash during `heart_flash_timer > 0`, only when `game_mode == .arcade` in `src/main.zig`
- [x] T026 [US3] Call `drawHeartsHud()` from `drawPlayingHud()` at `src/main.zig:1149`
- [x] T027 [US3] Add arcade-specific high score save logic at dying timer expiry in `src/main.zig`: compare score against `best_score_arcade`, save via `highscore.save(.arcade, ...)` if better
- [x] T028 [US3] Update game-over stats screen to show final hearts info and arcade-specific high score in `src/main.zig`

**Checkpoint**: Arcade mode fully playable — 3 hearts, power-ups drop, heart loss on zombie reach (with flash + sound), heart restore on boss defeat (capped at 3), game over at 0 hearts, arcade high score saves independently.

---

## Phase 6: User Story 4 — Simulation Mode: Renamed Bot (Priority: P2)

**Goal**: Rename all visible "Bot" references to "Simulation". No gameplay logic changes — pure rename.

**Independent Test**: Select Simulation, verify auto-play works identically to old Bot mode, search all visible text for zero "Bot" occurrences.

### Tests for User Story 4

- [x] T029 [P] [US4] Add test `"no BOT string literal in MENU_ITEMS"` verifying none of the menu labels contain "BOT" in `src/main.zig`
- [x] T030 [P] [US4] Add test `"simulation mode activates bot"` verifying `bot_active` and `bot_tainted` are set when starting simulation in `src/main.zig`

### Implementation for User Story 4

- [x] T031 [US4] Replace all visible "BOT"/"Bot" string literals with "SIMULATION"/"Simulation" across `src/main.zig` (menu labels, HUD text, pause screen text, game-over text)

**Checkpoint**: Zero "Bot" text visible anywhere in the game. Simulation mode auto-plays identically to old Bot mode.

---

## Phase 7: User Story 5 — Separate High Scores per Mode (Priority: P2)

**Goal**: Survie, Arcade, and Zen each persist their own independent high score. Simulation never saves. Game-over screen shows the current mode's high score.

**Independent Test**: Achieve scores in Survie and Arcade, verify they don't cross-contaminate, verify Simulation doesn't save.

### Tests for User Story 5

- [ ] T032 [P] [US5] Add test `"simulation mode never saves high score"` verifying explicit mode guard prevents saving in `src/main.zig`

### Implementation for User Story 5

- [ ] T033 [US5] Add explicit `.simulation` mode guard to high score save path (complementing `bot_tainted` guard) at game-over in `src/main.zig`
- [ ] T034 [US5] Update game-over screen stats display to show mode-specific high score label (SURVIE BEST / ARCADE BEST / ZEN BEST) in `src/main.zig`

**Checkpoint**: Scores are fully independent per mode. Simulation mode never persists scores.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Edge case verification, rename sweep, and final validation across all modes.

- [ ] T035 [P] Add test `"shield absorbs before heart loss in arcade"` verifying shield check ordering at `src/main.zig:1492` runs before arcade heart-loss branch
- [ ] T036 Verify edge case: multiple zombies reaching bottom on the same frame in Arcade each cost 1 heart independently (arcade path uses `continue`, not `break`, until `hearts == 0`) in `src/main.zig`
- [ ] T037 Verify edge case: boss encounter continues after heart loss in Arcade (boss is in `boss` variable, not zombie pool) in `src/main.zig`
- [ ] T038 Run `zig build test` and verify all new and existing tests pass
- [ ] T039 Run `zig build run` and manually test all 4 modes per plan Phase 7 verification checklist: menu navigation, Survie (no powers, single death), Arcade (hearts, powers, boss restore), Simulation (auto-play, no "Bot" text), Zen (unchanged), cross-mode score independence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: No dependencies — start immediately. BLOCKS all user stories (enum extension must compile first).
- **US1 Menu (Phase 3)**: Depends on Phase 2 completion (needs `.arcade` and `.simulation` GameMode variants).
- **US2 Survie (Phase 4)**: Depends on Phase 2 completion. Independent of other user stories.
- **US3 Arcade (Phase 5)**: Depends on Phase 2 and Phase 3 (needs menu entry to launch arcade). Depends on Phase 4 (power-up gating change).
- **US4 Simulation (Phase 6)**: Depends on Phase 2 and Phase 3 (needs menu entry for simulation). Independent of US2/US3/US5.
- **US5 High Scores (Phase 7)**: Depends on Phase 2 (needs `best_score_arcade`). Partially overlaps with US3 (arcade score save).
- **Polish (Phase 8)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P1)**: Can start after Phase 2 — independent of US1 (only changes one `if` condition)
- **US3 (P1)**: Depends on US1 (menu entry) and US2 (power-up gating) being complete. The hearts system is self-contained but relies on mode being launchable.
- **US4 (P2)**: Can start after Phase 3 (US1) — independent rename
- **US5 (P2)**: Can start after Phase 2 — overlaps with US3 (arcade score save wired in T027)

### Within Each User Story

- Tests written alongside implementation (Zig `test` blocks reference production symbols — cannot compile without them)
- Constants/state before logic
- State mutation before rendering
- Core implementation before edge cases

### Parallel Opportunities

- T002 and T005 can run in parallel with T001/T003/T004 (different files)
- T007, T008 (US1 tests) can run in parallel
- T012 (US2 test) is independent of US1 tasks
- T014–T017 (US3 tests) can all run in parallel
- T029, T030 (US4 tests) can run in parallel
- US2 and US4 can run in parallel (different code areas, no conflicts)

---

## Parallel Example: Foundational Phase

```
# These touch different files and can run in parallel:
Task T001: Extend GameMode enum in src/zombie_types.zig
Task T003+T004: Fix highscore.zig switches
# Then after both complete:
Task T006: Declare best_score_arcade in src/main.zig
```

## Parallel Example: After Foundational

```
# US1 and US2 are independent and can start simultaneously:
Task T009-T011: Menu refactor (US1)
Task T013: Power-up gating change (US2)

# US4 can run in parallel with US3 once US1 is done:
Task T031: Bot→Simulation rename (US4)
Task T018-T028: Hearts system (US3)
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 2: Foundational (enum + highscore + best_score_arcade)
2. Complete Phase 3: US1 — Menu with 6 items
3. Complete Phase 4: US2 — Survie has no power-ups
4. **STOP and VALIDATE**: Menu works, Survie is hardcore, existing modes unbroken
5. This MVP is playable and shippable — Arcade launches but behaves like Survie (no hearts yet)

### Incremental Delivery

1. Foundational → Code compiles with 4 modes
2. US1 (Menu) → Players can see and select all modes
3. US2 (Survie) → Hardcore mode is correct
4. US3 (Arcade) → Hearts system fully functional → **Major feature complete**
5. US4 (Simulation) → Rename complete
6. US5 (High Scores) → Score separation verified
7. Polish → Edge cases verified, manual testing complete

### Parallel Execution Strategy

1. Complete Foundational phase sequentially (T001–T006)
2. Launch US1 + US2 in parallel (different code areas)
3. Once US1 complete, launch US3 + US4 in parallel
4. US5 can overlap with US4 (different concerns)
5. Polish after all stories done

---

## Notes

- All 3 modified files (`src/zombie_types.zig`, `src/highscore.zig`, `src/main.zig`) are existing — no new files created
- Tests are inline `test "..." {}` blocks within the module under test (Zig convention)
- Zig tests reference production symbols directly — they cannot compile before the symbols exist, so tests are written alongside implementation, not strictly before
- Hearts are a scalar counter (`u8`), not entities — no allocation, no pool
- Power-up gating is a single `if` condition change (`.survival` → `.arcade`)
- Simulation is a pure rename — zero gameplay logic changes
- `.simulation` high score entries in `filename()`/`webKey()` are sentinels (never reached due to upstream `bot_tainted` + explicit mode guard)
- Existing `highscore.dat` filename preserved for `.survival` → backward compatible for existing players

# Tasks: Game-Over Stats Screen and High Score Persistence

**Input**: Design documents from `specs/DEATHN-24-copy-of-game/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Test tasks are included by default (constitution). All tests are `test "..." { ... }` blocks in `src/main.zig` (26 existing test blocks). Run via `zig build test`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/` at repository root
- All source changes in `src/main.zig` and `src/raylib.zig`
- All tests in `src/main.zig` as `test "..." { ... }` blocks

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Declare new types, constants, and shared state needed by all user stories

- [X] T001 Declare `HighScoreRecord` struct (fields: `score: u64`, `wave: u32`, `wpm: u32`, `accuracy: u8`) after existing `ScorePopup` struct in `src/main.zig`
- [X] T002 Declare named constants for stats screen layout and persistence in `src/main.zig`: `DYING_DURATION: f32 = 1.0`, `STATS_TITLE_Y: c_int = 30`, `STATS_LINE_START_Y: c_int = 80`, `STATS_LINE_SPACING: c_int = 35`, `STATS_FONT_SIZE: c_int = 24`, `HIGHSCORE_FILENAME = "highscore.dat"`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core state variables and kill tracking that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Declare new module-level state variables near existing state block (~line 76-101) in `src/main.zig`: `total_kills: u32 = 0`, `is_dying: bool = false`, `dying_timer: f32 = 0.0`, `dying_zombie_index: ?usize = null`, `best_score: HighScoreRecord = .{ .score = 0, .wave = 0, .wpm = 0, .accuracy = 0 }`
- [X] T004 Increment `total_kills` in `updateZombies` (on regular zombie kill, after `wave_kills += 1`) and in `updateBoss` (on boss kill, after `raylib.PlaySound`) in `src/main.zig`
- [X] T005 Extend existing `resetScoreState` test to verify `total_kills` increments correctly in `src/main.zig`

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Game-Over Stats Display (Priority: P1) MVP

**Goal**: Replace the minimal game-over display with a 1-second death transition (red-tinted zombie, frozen gameplay) followed by a full-screen statistics summary showing wave, score, best, average WPM, accuracy, and kills.

**Independent Test**: Play a game until game-over and verify: (1) 1-second pause with red zombie, (2) all seven stat lines plus restart prompt appear with correct values at specified positions and styles.

### Tests for User Story 1
**NOTE**: Write these tests FIRST, ensure they FAIL before implementation.
**RULE (constitution)**: All tests extend existing test file `src/main.zig` — no new test files.

- [X] T006 [P] [US1] Extend tests in `src/main.zig`: add test "dying state transition" — verify `is_dying` set to true triggers timer countdown, and when timer reaches 0 `is_game_over` becomes true and `is_dying` becomes false
- [X] T007 [P] [US1] Extend tests in `src/main.zig`: add test "average WPM calculation" — verify `(600 / 5) / (60 / 60) = 120` and edge case where elapsed_time < 1.0 returns 0
- [X] T008 [P] [US1] Extend tests in `src/main.zig`: add test "accuracy edge case zero input" — verify 0 correct + 0 wrong returns 0% (spec says 0%, unlike existing `calculateTargetAccuracy` which returns 100%)
- [X] T009 [P] [US1] Extend tests in `src/main.zig`: add test "kill counter tracks total kills" — verify `total_kills` increments on regular zombie kill and on boss kill

### Implementation for User Story 1

- [X] T010 [US1] Implement dying state transition in `src/main.zig`: in `updateZombies`, when `zomb.y >= screen_height`, set `is_dying = true`, `dying_timer = DYING_DURATION`, `dying_zombie_index = i` instead of `is_game_over = true`. Apply same pattern in `updateBoss`
- [X] T011 [US1] Gate gameplay updates during dying state in `src/main.zig`: add `and !is_dying` to the `!is_game_over and !is_transitioning` condition in `frame()` (line 173). Add dying timer countdown logic — when `dying_timer <= 0`: set `is_game_over = true`, `is_dying = false`
- [X] T012 [US1] Implement red tint for dying zombie in `drawZombies` in `src/main.zig`: when `is_dying` and zombie slot index matches `dying_zombie_index`, pass `raylib.RED` tint instead of `raylib.WHITE` to `DrawTexturePro`. Also handle boss case in `drawBoss`
- [X] T013 [US1] Replace existing game-over drawing block (lines 313-328) in `src/main.zig` with full stats overlay: "GAME OVER" (size 48, red, centered, y=30), "Wave reached: N" (size 24, dark gray), "Score: N", "Best: N" or "NEW HIGH SCORE!" (gold), "Average WPM: N", "Accuracy: N%", "Kills: N", "Press ENTER to restart" (size 18, gray, near bottom ~y=405)
- [X] T014 [US1] Implement average WPM calculation for stats screen in `src/main.zig`: `(correct_chars / 5.0) / (elapsed_time / 60.0)`, returning 0 when `elapsed_time < 1.0` (FR-005, ARD-3). Implement stats accuracy as `(correct_chars * 100) / (correct_chars + wrong_chars)`, returning 0 when both are zero (spec edge case)

**Checkpoint**: User Story 1 should be fully functional — game-over shows death transition and complete stats screen

---

## Phase 4: User Story 4 — Restart Resets Session but Preserves Best (Priority: P1)

**Goal**: Ensure the ENTER restart handler resets all new session state variables (total_kills, dying state) while preserving `best_score` across restarts.

**Independent Test**: Complete a game, press ENTER, play again to game-over — all session stats should be fresh while "Best:" retains the previous high.

### Tests for User Story 4
**NOTE**: Write these tests FIRST, ensure they FAIL before implementation.

- [X] T015 [US4] Extend existing `resetScoreState` test in `src/main.zig`: verify that after reset, `total_kills = 0`, `is_dying = false`, `dying_timer = 0.0`, `dying_zombie_index = null`, and `best_score` fields are preserved (not zeroed)

### Implementation for User Story 4

- [X] T016 [US4] Update restart handler in the ENTER-pressed block (~line 331) in `src/main.zig`: add resets for `total_kills = 0`, `is_dying = false`, `dying_timer = 0.0`, `dying_zombie_index = null`. Do NOT reset `best_score`

**Checkpoint**: User Stories 1 and 4 should both work — full game-over loop with correct restart behavior

---

## Phase 5: User Story 2 — High Score Persistence on Native Build (Priority: P2)

**Goal**: Persist the high score to `highscore.dat` as a binary file on native builds so it survives across sessions. Display "NEW HIGH SCORE!" in gold when the current score exceeds the best.

**Independent Test**: Play two sessions — first sets a score, second verifies "Best:" displays the previously saved value. Delete `highscore.dat` and relaunch to confirm reset to zero.

### Tests for User Story 2
**NOTE**: Write these tests FIRST, ensure they FAIL before implementation.

- [X] T017 [P] [US2] Extend tests in `src/main.zig`: add test "HighScoreRecord struct size" — verify `@sizeOf(HighScoreRecord)` matches expected value for binary file validation
- [X] T018 [P] [US2] Extend tests in `src/main.zig`: add test "high score comparison logic" — verify `score > best_score.score` correctly identifies new high score, including edge cases (equal score = not new, zero score = not new)

### Implementation for User Story 2

- [X] T019 [US2] Implement `loadHighScore() !HighScoreRecord` function in `src/main.zig`: open `HIGHSCORE_FILENAME` for reading, read `@sizeOf(HighScoreRecord)` bytes, validate file size matches exactly, reinterpret bytes as struct. Return zero-initialized record on any failure (file missing, size mismatch, read error)
- [X] T020 [US2] Implement `saveHighScore(record: HighScoreRecord) !void` function in `src/main.zig`: create/overwrite `HIGHSCORE_FILENAME`, write struct as raw bytes
- [X] T021 [US2] Wire persistence into game lifecycle in `src/main.zig`: (1) in `main()` after window init, load `best_score = loadHighScore() catch .{ .score = 0, .wave = 0, .wpm = 0, .accuracy = 0 }`; (2) at game-over (when dying timer expires), if `score > best_score.score`, build new record with current stats and call `saveHighScore`, update `best_score` in memory. Gate all behind `comptime @import("builtin").target.os.tag != .emscripten`

**Checkpoint**: Native persistence working — high score survives game restarts and relaunches

---

## Phase 6: User Story 3 — High Score Persistence on Web Build (Priority: P3)

**Goal**: Persist the high score to `localStorage` under key `death-note.highscore` in JSON format on the web/emscripten build, mirroring native behavior.

**Independent Test**: Play web build, achieve high score, refresh page — verify "Best:" persists. Clear localStorage and refresh to confirm reset to zero.

### Tests for User Story 3
**NOTE**: Limited testing — web persistence requires a browser. Manual test only.

- [ ] T022 [US3] Extend tests in `src/main.zig`: add test "emscripten persistence branch compiles" — compile-time verification that the emscripten-gated code has no syntax errors (use `comptime` assertion or conditional compilation check)

### Implementation for User Story 3

- [ ] T023 [US3] Verify `emscripten_run_script` and `emscripten_run_script_int` are accessible through existing `@cImport` in `src/raylib.zig` — if not, add them to the emscripten conditional import block
- [ ] T024 [US3] Implement `loadHighScoreWeb() HighScoreRecord` function in `src/main.zig`: use `raylib.emscripten_run_script_int(...)` to read `localStorage.getItem('death-note.highscore')` and parse JSON fields. Return zero record on any failure (null, parse error)
- [ ] T025 [US3] Implement `saveHighScoreWeb(record: HighScoreRecord) void` function in `src/main.zig`: build JS string for `localStorage.setItem('death-note.highscore', JSON.stringify({score:N,wave:N,wpm:N,accuracy:N}))` and call `raylib.emscripten_run_script(js_string)`
- [ ] T026 [US3] Wire web persistence into game lifecycle in `src/main.zig`: dispatch to web variants at startup and game-over, gated behind `comptime @import("builtin").target.os.tag == .emscripten`

**Checkpoint**: Both native and web persistence working — high score survives across sessions on all platforms

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T027 Verify `zig build` compiles cleanly with all changes in `src/main.zig` and `src/raylib.zig`
- [ ] T028 Run `zig build test` and verify all new and existing tests pass
- [ ] T029 Manual play-test: verify death transition (red tint, 1s pause), all 8 stat lines on game-over screen, restart behavior, and "NEW HIGH SCORE!" display

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (Phase 2) — core deliverable
- **US4 (Phase 4)**: Depends on US1 (Phase 3) — restart must handle US1's new state variables
- **US2 (Phase 5)**: Depends on Foundational (Phase 2) — can run in parallel with US1/US4
- **US3 (Phase 6)**: Depends on US2 (Phase 5) — mirrors native persistence pattern
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **US4 (P1)**: Depends on US1 — the new state variables US4 resets are introduced in US1
- **US2 (P2)**: Can start after Foundational (Phase 2) — independent of US1 (persistence can be wired into the game-over flow alongside or after stats screen)
- **US3 (P3)**: Depends on US2 — mirrors native persistence functions with browser-specific implementation

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- State declarations before logic that uses them
- Core implementation before integration/wiring
- Story complete before moving to next priority

### Parallel Opportunities

- T006, T007, T008, T009 (US1 tests) can run in parallel
- T017, T018 (US2 tests) can run in parallel
- US2 (Phase 5) can run in parallel with US1 (Phase 3) since both modify different sections of `src/main.zig`

---

## Parallel Example: User Story 1

```
# Launch all US1 tests together (all extend src/main.zig with independent test blocks):
Task T006: "dying state transition test"
Task T007: "average WPM calculation test"
Task T008: "accuracy edge case zero input test"
Task T009: "kill counter tracks total kills test"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 4 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T005)
3. Complete Phase 3: User Story 1 (T006-T014)
4. Complete Phase 4: User Story 4 (T015-T016)
5. **STOP and VALIDATE**: `zig build test` + manual play-test
6. Deploy/demo if ready — stats screen fully working without persistence

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 + US4 → Test independently → Deploy/Demo (MVP: stats screen + restart)
3. Add US2 → Test independently → Deploy/Demo (native persistence)
4. Add US3 → Test independently → Deploy/Demo (web persistence)
5. Each story adds value without breaking previous stories

### Parallel Execution Strategy

1. Complete Setup + Foundational phases sequentially
2. Once Foundational is done, stories can proceed:
   - Sequential path (recommended): US1 → US4 → US2 → US3
   - Parallel path: US1+US4 in parallel with US2 (different function areas of `src/main.zig`)
3. US3 follows US2 (mirrors its pattern)

---

## Notes

- All source changes are in `src/main.zig` (~200-250 new lines) and `src/raylib.zig` (minor verify/extend)
- No new files created. No changes to `build.zig`, `build.zig.zon`, or assets
- All tests are `test "..." { ... }` blocks in `src/main.zig` — extend the existing 26 test blocks
- [P] tasks = different sections/functions, no dependencies
- [Story] label maps task to specific user story for traceability
- Stop at any checkpoint to validate story independently
- Total: 29 tasks across 7 phases

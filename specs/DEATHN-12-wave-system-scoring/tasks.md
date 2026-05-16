# Tasks: Wave System, Scoring and Difficulty Progression

**Input**: Design documents from `specs/DEATHN-12-wave-system-scoring/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/high-score-persistence.md

**Tests**: Included by default (constitution). All new tests extend the existing test section in `src/main.zig` (lines 348–433). No separate test files.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create new data file and declare all new constants, state variables, and struct extensions needed across all user stories.

- [x] T001 [P] Create boss phrase data table in `src/boss_phrases.zig` following the exact pattern of `src/zombie_names.zig` — a `pub const BossPhrases` array of `[*:0]const u8` containing the 15 curated phrases from data-model.md section 2.6
- [x] T002 Declare all new constants and tunables as module-level `const` at the top of `src/main.zig` (grouped by concern: wave system, scoring, difficulty scaling, stats, input, high score persistence) per data-model.md section 4. Update `MAX_INPUT_CHARS` from `9` to `40` and resize the input buffer accordingly
- [x] T003 Extend the `Zombie` struct in `src/main.zig` with `is_boss: bool` and `phrase_progress: usize` fields (data-model.md section 2.1). Update `spawnZombie` to initialize these new fields (`is_boss = false`, `phrase_progress = 0`) for normal zombies
- [x] T004 Add all new module-level state variables in `src/main.zig`: wave state (data-model.md section 2.2), score state (section 2.4), player stats (section 2.5). Add `@import("boss_phrases.zig")` alongside the existing `ZombieNames` import
- [x] T005 Verify `zig build` compiles cleanly with all new declarations (state is declared but not yet wired into the game loop)

**Checkpoint**: Project compiles with all new data structures and constants. No behavior changes yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement and test pure logic functions that all user stories depend on. These have no side effects and no raylib calls.

**CRITICAL**: No user story work can begin until this phase is complete.

### Pure Logic Functions

- [x] T006 Implement `cstrLen(name: [*:0]const u8) usize` helper function in `src/main.zig` to replace the inline null-terminator scan pattern used in `updateZombies` (research.md section 3.9). Refactor existing `updateZombies` to use `cstrLen` instead of the inline loop
- [x] T007 [P] Implement `comboMultiplier(combo: u32) u32` pure function in `src/main.zig` per data-model.md section 2.4 combo tier table (1x at 0-4, 2x at 5-9, 3x at 10-14, 4x at 15-19, 5x at 20+)
- [x] T008 [P] Implement difficulty scaling pure functions in `src/main.zig`: `waveSpawnDelay(wave: u32) f32`, `waveFallSpeed(wave: u32) f32`, `waveMaxActive(wave: u32) u32`, `waveKillTarget(wave: u32) u32`, `waveDuration(wave: u32) f32` — all per data-model.md section 2.3 formulas with floors and caps
- [x] T009 [P] Implement `calculateWpm(kill_times: []const f64, kill_count: usize, current_time: f64) u32` pure function in `src/main.zig` per data-model.md section 2.5 (count entries within 30-second window, divide by 0.5 minutes)
- [x] T010 [P] Implement `isValidPrefix(typed: []const u8, zombies_arr: [MAX_ZOMBIES]?*Zombie) bool` pure function in `src/main.zig` per research.md section 1.4 — check if typed buffer is a prefix of at least one active zombie's name using `std.mem.startsWith`

### Tests for Pure Logic Functions

- [x] T011 [P] Extend tests in `src/main.zig` (after existing test block at line 433): add `test "cstrLen"` verifying length of known strings, empty string, and single-character string
- [x] T012 [P] Extend tests in `src/main.zig`: add `test "comboMultiplier tier boundaries"` verifying multiplier at combo values 0, 4, 5, 9, 10, 14, 15, 19, 20, 100
- [x] T013 [P] Extend tests in `src/main.zig`: add `test "waveSpawnDelay"` at waves 1, 5, 12, 20 (verify floor at 0.5), `test "waveFallSpeed"` at waves 1, 5, 15, 20 (verify cap at 2.0), `test "waveMaxActive"` at waves 1, 5, 13, 20 (verify cap at 30), `test "waveKillTarget"` and `test "waveDuration"` boundary checks
- [x] T014 [P] Extend tests in `src/main.zig`: add `test "calculateWpm"` with empty buffer, partial buffer, full 30-second window, and expired entries outside window
- [x] T015 Run `zig build test` — all existing tests (T003–T005) and new tests (T011–T014) must pass

**Checkpoint**: Foundation ready — all pure logic tested. User story implementation can now begin.

---

## Phase 3: User Story 1 — Wave-Based Gameplay Loop (Priority: P1) MVP

**Goal**: Restructure the endless-spawn game into sequential numbered waves with kill targets, timers, difficulty scaling per wave, and inter-wave transition screens.

**Independent Test**: Play through waves 1-3 and verify wave numbers increment, transitions appear with stats, countdown works, and difficulty increases visibly.

### Tests for User Story 1

- [x] T016 [P] [US1] Extend tests in `src/main.zig`: add `test "wave state resets on new wave"` verifying `wave_kill_count` resets to 0 and `wave_timer` resets to 0 when a new wave starts
- [x] T017 [P] [US1] Extend tests in `src/main.zig`: add `test "wave transition timer progression"` verifying the 5-second recap + 3-second countdown total equals `WAVE_TRANSITION_TOTAL_DURATION` (8.0)

### Implementation for User Story 1

- [x] T018 [US1] Modify `spawnZombie` in `src/main.zig` to accept wave-derived parameters: use `waveFallSpeed(current_wave)` for zombie speed instead of `ZOMBIE_FALL_SPEED`, check `waveMaxActive(current_wave)` active zombie count before spawning, use `waveSpawnDelay(current_wave)` to replace the hardcoded `spawn_delay` constant in the spawn timer check
- [x] T019 [US1] Add wave completion detection in the update phase of `frame()` in `src/main.zig`: kill target met → enter transition state; timer expired (no boss alive) → clear remaining non-boss zombies via `resetZombies`, enter transition with no bonus; timer expired but boss alive → pause timer
- [x] T020 [US1] Implement wave transition logic in `frame()` in `src/main.zig`: set `is_wave_transitioning = true` and `wave_transition_timer = 0` on wave end; advance timer by `GetFrameTime()` during transition; at `WAVE_TRANSITION_TOTAL_DURATION` → increment `current_wave`, reset `wave_kill_count` and `wave_timer`, set `is_wave_transitioning = false`, clear remaining zombies
- [x] T021 [US1] Add wave transition drawing in the draw phase of `frame()` in `src/main.zig`: during first 5 seconds show recap screen (wave number, kills, accuracy, WPM) using `raylib.DrawText`; during last 3 seconds show countdown ("3", "2", "1"). Gate normal zombie drawing and input handling behind `!is_wave_transitioning`
- [x] T022 [US1] Add wave timer advancement in the update phase of `frame()` in `src/main.zig`: increment `wave_timer` by `raylib.GetFrameTime()` each frame during `WAVE_ACTIVE` state, gated by `!boss_alive` for timer pause
- [x] T023 [US1] Implement `resetGameState(allocator: *std.mem.Allocator) void` in `src/main.zig` to reset all wave, score, combo, stats, and timer state to initial values, call existing `resetZombies(allocator)`, but preserve `best_score` and `best_score_loaded`. Wire into the game-over restart handler replacing the inline reset code
- [x] T024 [US1] Verify `zig build` and `zig build test` both pass cleanly

**Checkpoint**: Wave-based gameplay loop is fully functional. Waves progress, transitions show stats, difficulty increases per wave. Can be manually tested by playing waves 1-3.

---

## Phase 4: User Story 2 — Score, Combo, and HUD Display (Priority: P2)

**Goal**: Add scoring on kills with combo multiplier, combo tracking that resets on mistyped characters, and a HUD showing wave/score/combo/WPM/accuracy.

**Independent Test**: Play a single wave, verify score increments on kills, combo builds on consecutive kills, combo resets on mistype, and HUD is readable without overlapping play area.

### Tests for User Story 2

- [x] T025 [P] [US2] Extend tests in `src/main.zig`: add `test "score calculation with combo"` verifying normal kill score = `BASE_KILL_SCORE * comboMultiplier(combo)` at various combo values
- [x] T026 [P] [US2] Extend tests in `src/main.zig`: add `test "wave completion bonus"` verifying bonus = `WAVE_COMPLETION_BONUS_PER_WAVE * current_wave`

### Implementation for User Story 2

- [x] T027 [US2] Wire combo tracking into `updateZombies` in `src/main.zig`: on zombie kill increment `combo`, compute score delta = `BASE_KILL_SCORE * comboMultiplier(combo)`, add to `score`, increment `wave_kill_count` and `total_kills`, record kill timestamp in `wpm_kill_times` circular buffer
- [x] T028 [US2] Wire combo-breaking into the input handler in `frame()` in `src/main.zig`: after accepting a character, call `isValidPrefix` on the updated buffer. If not valid prefix → `combo = 0`, increment `total_keystrokes` only. If valid prefix → increment both `total_keystrokes` and `correct_keystrokes`
- [x] T029 [US2] Add wave-completion bonus in wave completion detection in `src/main.zig`: when kill target is met before timer expires, add `WAVE_COMPLETION_BONUS_PER_WAVE * current_wave` to `score`
- [x] T030 [US2] Implement `drawHud()` function in `src/main.zig`: draw top-left "Wave: {current_wave}", top-center "Score: {score}" and "Best: {best_score}" (if loaded), top-right "Combo: {combo} ({multiplier}x)" / "WPM: {wpm}" / "Accuracy: {accuracy}%" using `raylib.DrawText` with font size 16-18 in the top 25px margin. Call after `drawZombies()` in the draw phase during active gameplay (not during transition or game-over)
- [x] T031 [US2] Calculate live WPM and accuracy each frame for HUD display in `src/main.zig`: WPM via `calculateWpm(wpm_kill_times, wpm_kill_count, raylib.GetTime())`, accuracy via `(correct_keystrokes * 100) / total_keystrokes` (or 100 if no keystrokes)
- [x] T032 [US2] Verify `zig build` and `zig build test` both pass cleanly

**Checkpoint**: Scoring, combo, and HUD all functional. Score changes on kills, combo resets on errors, HUD is always visible during gameplay.

---

## Phase 5: User Story 3 — Boss Zombie Every 5 Waves (Priority: P3)

**Goal**: Spawn a boss zombie with a multi-word phrase at every 5th wave, with slower fall speed, typing progress indicator, and wave-blocking until defeated.

**Independent Test**: Reach wave 5, verify boss spawns with a phrase, falls slowly, shows typing progress bar, and blocks wave completion until defeated.

### Tests for User Story 3

- [x] T033 [P] [US3] Extend tests in `src/main.zig`: add `test "boss wave detection"` verifying `wave % BOSS_WAVE_INTERVAL == 0` is true for waves 5, 10, 15 and false for 1, 3, 7
- [x] T034 [P] [US3] Extend tests in `src/main.zig`: add `test "boss fall speed"` verifying boss speed = normal speed * `BOSS_FALL_SPEED_FACTOR` (0.5x)

### Implementation for User Story 3

- [x] T035 [US3] Add boss spawning logic in `src/main.zig`: when `current_wave % BOSS_WAVE_INTERVAL == 0` and `wave_kill_count >= waveKillTarget(current_wave)`, spawn a boss zombie using `spawnZombie` (or a variant) that selects a phrase from `BossPhrases`, sets `is_boss = true`, speed = `waveFallSpeed(current_wave) * BOSS_FALL_SPEED_FACTOR`, and sets `boss_alive = true`
- [x] T036 [US3] Modify `updateZombies` in `src/main.zig` to handle boss phrase matching: for boss zombies check if typed buffer matches the first `letter_count` characters of the phrase. If full match → kill boss, clear buffer, set `boss_alive = false`, award `BOSS_KILL_SCORE * comboMultiplier(combo)`. Update `phrase_progress` on each keystroke that extends the match
- [x] T037 [US3] Draw boss progress indicator in `drawZombies` in `src/main.zig`: below the boss sprite draw a progress bar (`raylib.DrawRectangle` for background and filled portions) showing `phrase_progress / phrase_length`. Display the phrase text above the boss with typed portion in green and remaining in red
- [x] T038 [US3] Wire boss-alive check into wave completion in `src/main.zig`: if boss is alive when timer expires → timer pauses (`wave_timer` stops advancing). Wave cannot transition until `boss_alive == false`
- [x] T039 [US3] Verify `zig build` and `zig build test` both pass cleanly

**Checkpoint**: Boss zombies appear every 5 waves with phrase typing, progress bar, and wave-blocking. Normal zombies can still cause game-over during boss fights.

---

## Phase 6: User Story 4 — Game-Over Screen with Stats and Persistent High Score (Priority: P4)

**Goal**: Expand game-over screen with detailed stats and persist the best score across sessions using file (native) or localStorage (web).

**Independent Test**: Play until game over, verify all stats display, restart, close and reopen the game, confirm best score persists.

### Tests for User Story 4

- [x] T040 [P] [US4] Extend tests in `src/main.zig`: add `test "high score is monotonic"` verifying that `best_score` only updates when `score > best_score` and never decrements

### Implementation for User Story 4

- [x] T041 [US4] Expand the game-over screen drawing in `frame()` in `src/main.zig`: display wave reached (`current_wave`), final score (`score`), best score (`best_score` with "New High Score!" if applicable), average WPM, accuracy (`(correct_keystrokes * 100) / total_keystrokes`), and total kills (`total_kills`) using `raylib.DrawText`
- [x] T042 [US4] Implement `loadHighScore() u64` in `src/main.zig` per contracts/high-score-persistence.md: native path uses `std.fs.cwd().openFile` to read 8-byte LE u64 from `HIGHSCORE_FILE` (return 0 on error); web path uses `emscripten_run_script_int` via `raylib` import. Gate with `comptime builtin.target.os.tag == .emscripten`
- [x] T043 [US4] Implement `saveHighScore(score: u64) void` in `src/main.zig` per contracts/high-score-persistence.md: native path uses `std.fs.cwd().createFile` to write 8-byte LE u64 to `HIGHSCORE_FILE`; web path uses `emscripten_run_script` for `localStorage.setItem`. Errors silently ignored (FR-022)
- [x] T044 [US4] Call `loadHighScore()` once during startup in `main()` in `src/main.zig` (after raylib init, before game loop). Set `best_score` and `best_score_loaded = true` on success
- [x] T045 [US4] Call `saveHighScore(score)` in the game-over handler in `src/main.zig` when `score > best_score`. Update `best_score = score` in memory. Wire into `resetGameState` to ensure `best_score` and `best_score_loaded` are NOT reset on restart
- [x] T046 [US4] Verify `zig build` and `zig build test` both pass cleanly

**Checkpoint**: Game-over screen shows full stats. High score persists across sessions on both native and web.

---

## Phase 7: User Story 5 — Live WPM and Accuracy Stats (Priority: P5)

**Goal**: Display real-time WPM (30-second rolling window) and accuracy in the HUD, updating every frame.

**Independent Test**: Type several zombie names and verify WPM is non-zero, deliberately mistype and verify accuracy decreases.

### Tests for User Story 5

- [ ] T047 [P] [US5] Extend tests in `src/main.zig`: add `test "accuracy calculation"` verifying accuracy = 100 with 0 keystrokes, accuracy = 80 with 20 correct and 5 incorrect keystrokes, accuracy = 100 with all correct keystrokes
- [ ] T048 [P] [US5] Extend tests in `src/main.zig`: add `test "wpm drops to zero after window expires"` verifying `calculateWpm` returns 0 when all entries are older than 30 seconds

### Implementation for User Story 5

- [ ] T049 [US5] Ensure WPM circular buffer recording is wired into kill events in `updateZombies` in `src/main.zig`: on each kill, record `raylib.GetTime()` in `wpm_kill_times[wpm_kill_index]`, advance `wpm_kill_index` with modulo `WPM_BUFFER_SIZE`, increment `wpm_kill_count`
- [ ] T050 [US5] Verify the `drawHud()` function (from T030) displays live WPM and accuracy values computed each frame. Confirm WPM shows 0 when no kills in the last 30 seconds and accuracy displays correctly with mixed correct/incorrect keystrokes
- [ ] T051 [US5] Verify `zig build` and `zig build test` both pass cleanly

**Checkpoint**: Live WPM and accuracy update in real-time during gameplay. WPM reflects recent typing speed, accuracy reflects keystroke precision.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration testing, edge-case handling, and final verification across all user stories.

- [ ] T052 Wire the wave timer display into the HUD in `src/main.zig` — show remaining time as a countdown or progress bar alongside existing HUD elements
- [ ] T053 Ensure zombie clearing on wave timer expiry in `src/main.zig` properly frees memory via the allocator (call `resetZombies` or equivalent cleanup, not just setting `is_active = false`)
- [ ] T054 Update existing test T004 (input buffer bounds) in `src/main.zig` to use `MAX_INPUT_CHARS = 40` instead of `9` — verify the bounds check still works at the new limit
- [ ] T055 Run `zig build` and `zig build test` as a final gate — all tests must pass, no compiler warnings
- [ ] T056 Manual playtest: verify full flow (wave 1 → transition → wave 2 → ... → wave 5 boss → transition → wave 6), HUD readability at 800x450, difficulty progression feel, boss encounter timing, high score persistence across restarts (native), high score persistence in browser (web build via `zig build web`)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on US1 (needs wave structure and kill events to attach scoring)
- **User Story 3 (Phase 5)**: Depends on US1 (needs wave lifecycle) and US2 (needs scoring for boss kills)
- **User Story 4 (Phase 6)**: Depends on US2 (needs scoring system) — can parallel with US3
- **User Story 5 (Phase 7)**: Depends on US2 (needs HUD infrastructure and keystroke tracking)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational)
                      │
                      ▼
                   Phase 3 (US1: Waves) ─────────────────┐
                      │                                   │
                      ▼                                   ▼
                   Phase 4 (US2: Scoring/HUD)      Phase 6 (US4: Game-Over/Persistence)*
                      │         │                         (* can start after US2)
                      ▼         ▼
            Phase 5 (US3)   Phase 7 (US5)
              (Boss)        (Live Stats)
                      │         │
                      ▼         ▼
                   Phase 8 (Polish)
```

### Within Each User Story

1. Tests written and verified to fail before implementation
2. Core logic before wiring into game loop
3. Game loop integration before drawing/rendering
4. `zig build test` pass before moving to next story

### Parallel Opportunities

- **Phase 1**: T001 (boss_phrases.zig) can run in parallel with T002-T004 (main.zig changes)
- **Phase 2**: T007, T008, T009, T010 can all run in parallel (different functions, no dependencies). T011-T014 can all run in parallel (different test blocks)
- **Phase 4 & 6**: US4 (game-over/persistence) can start as soon as US2 is complete, in parallel with US3
- **Phase 4 & 7**: US5 (live stats) can start as soon as US2 is complete, in parallel with US3

---

## Parallel Example: Phase 2 (Foundational)

```
# Launch all pure function implementations together:
T007: comboMultiplier in src/main.zig
T008: difficulty scaling functions in src/main.zig
T009: calculateWpm in src/main.zig
T010: isValidPrefix in src/main.zig

# Launch all test blocks together:
T011: test "cstrLen" in src/main.zig
T012: test "comboMultiplier tier boundaries" in src/main.zig
T013: test "difficulty scaling" in src/main.zig
T014: test "calculateWpm" in src/main.zig
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T015)
3. Complete Phase 3: User Story 1 — Waves (T016-T024)
4. **STOP and VALIDATE**: Play waves 1-3, verify transitions, difficulty scaling
5. This is a playable game with wave progression — demo-ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Waves) → Test independently → **MVP!**
3. Add US2 (Scoring/HUD) → Test independently → Score feedback visible
4. Add US3 (Bosses) → Test independently → Climactic boss fights every 5 waves
5. Add US4 (Game-Over/Persistence) → Test independently → Long-term replayability
6. Add US5 (Live Stats) → Test independently → Real-time typing feedback
7. Polish → Final integration pass

### Parallel Execution Strategy

1. Complete Setup + Foundational sequentially
2. Complete US1 sequentially (core dependency for all)
3. Complete US2 sequentially (scoring dependency)
4. After US2, run in parallel:
   - Track A: US3 (Bosses)
   - Track B: US4 (Game-Over/Persistence) + US5 (Live Stats)
5. Polish after all tracks converge

---

## Notes

- All source changes target `src/main.zig` (single-module game loop per constitution) except T001 (`src/boss_phrases.zig`)
- All tests extend the existing test section in `src/main.zig` (lines 348-433) — no separate test files
- [P] tasks = different functions/files, no data dependencies
- [Story] label maps task to specific user story for traceability
- Verify tests fail before implementing (test-first within each story)
- Run `zig build test` at every checkpoint
- The existing tests T003/T004/T005 must continue to pass throughout

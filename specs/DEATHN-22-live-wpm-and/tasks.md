# Tasks: Live WPM and Accuracy with Character-Based Metrics

**Input**: Design documents from `specs/DEATHN-22-live-wpm-and/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Included by default (constitution). All tests extend `src/main.zig` (existing test block at lines 743–1053).

**Organization**: Tasks are grouped by user story. All changes are in `src/main.zig` (single-module architecture), so no tasks are parallelizable.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (not applicable — all tasks modify `src/main.zig`)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- All file paths reference `src/main.zig` unless stated otherwise

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add all new constants and state variables needed by the metrics system.

- [x] T001 Add metric constants (WPM_BUFFER_SIZE, WPM_WINDOW_SECONDS, SMOOTHING_FACTOR, WPM_HUD_X, WPM_HUD_Y, ACC_HUD_X, ACC_HUD_Y, METRICS_HUD_SIZE) after the existing score/combo constants block (~line 33) in src/main.zig
- [x] T002 Add metric state variables (wpm_buffer, wpm_buffer_head, wpm_buffer_count, correct_chars, wrong_chars, elapsed_time, displayed_wpm, displayed_accuracy) as a new block after the score/combo state variables (~line 80) in src/main.zig

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure functions and integration points that all user stories depend on.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Implement recordCorrectTimestamp() function that pushes elapsed_time into the circular wpm_buffer, advancing wpm_buffer_head with modular wrap and capping wpm_buffer_count at WPM_BUFFER_SIZE, in src/main.zig
- [x] T004 Implement countCharsInWindow() function that scans all valid wpm_buffer entries and returns the count of timestamps within the last WPM_WINDOW_SECONDS of current elapsed_time, in src/main.zig
- [x] T005 Implement resetMetricsState() function that zeros wpm_buffer, wpm_buffer_head, wpm_buffer_count, correct_chars, wrong_chars, elapsed_time, sets displayed_wpm to 0.0 and displayed_accuracy to 100.0, in src/main.zig
- [x] T006 Modify the input loop (~lines 152–176) in frame() to classify each keypress inside the while-loop: call typedMatchesAnyEnemy() per key — if true, call recordCorrectTimestamp(elapsed_time) and increment correct_chars; if false, increment wrong_chars and set combo_count to 0. Remove the post-loop mismatch check at lines 174–176 in src/main.zig
- [x] T007 Add resetMetricsState() call in the game-over restart block (~line 300, alongside resetScoreState()) in src/main.zig
- [x] T008 Add elapsed_time accumulation (elapsed_time += raylib.GetFrameTime()) per frame, gated by !is_game_over, placed after the is_transitioning countdown block (~line 229) in src/main.zig
- [x] T009 Add unit tests for circular buffer wrap (fill > WPM_BUFFER_SIZE entries, verify head wraps and count caps at WPM_BUFFER_SIZE) and resetMetricsState (verify all fields return to initial values) at the end of the test block in src/main.zig

**Checkpoint**: Foundation ready — all shared state, helper functions, and integration points are in place.

---

## Phase 3: User Story 1 — Live WPM Feedback (Priority: P1) MVP

**Goal**: Display a real-time WPM value on the HUD using a 10-second sliding window of correct-character timestamps.

**Independent Test**: Type zombie names during gameplay and verify the WPM number in the top-right corner updates and matches expected values from FR-017.

### Tests for User Story 1
**NOTE: Write these tests FIRST, ensure they FAIL before implementation.**
**RULE (constitution): All tests extend the existing test block in src/main.zig (lines 743–1053). No new test files.**

- [x] T010 [US1] Add WPM sliding window unit test: set up 60 entries in wpm_buffer within a 10-second window, call calculateTargetWpm(), assert result equals 72.0 (60 × 1.2) in src/main.zig
- [x] T011 [US1] Add WPM early-game unit test: set correct_chars to 12, elapsed_time to 5.0, call calculateTargetWpm(), assert result is approximately 28.8 (12 × 12 / 5) in src/main.zig
- [x] T012 [US1] Add WPM zero-input unit test: with empty buffer and elapsed_time 0.0, call calculateTargetWpm(), assert result equals 0.0 in src/main.zig

### Implementation for User Story 1

- [x] T013 [US1] Implement calculateTargetWpm() function: if elapsed_time < WPM_WINDOW_SECONDS use early-game formula (correct_chars × 12 / elapsed_time), else use sliding window formula (countCharsInWindow() × 1.2), returning 0 when elapsed_time is 0, in src/main.zig
- [x] T014 [US1] Implement updateMetrics() function with WPM section: advance elapsed_time, compute target WPM via calculateTargetWpm(), apply smoothing (displayed_wpm += SMOOTHING_FACTOR × (target − displayed_wpm)), and call updateMetrics() per frame gated by !is_game_over (replacing the raw elapsed_time accumulation from T008) in src/main.zig
- [x] T015 [US1] Add WPM HUD drawing inside the if (!is_game_over) block (~line 257, after combo HUD): format displayed_wpm as "WPM {d}" (rounded to integer) via bufPrintZ, draw with DrawText at (WPM_HUD_X, WPM_HUD_Y) with METRICS_HUD_SIZE and DARKGRAY color in src/main.zig

**Checkpoint**: WPM displays on HUD, updates in real time, declines when typing stops. Tests pass for reference cases.

---

## Phase 4: User Story 2 — Live Accuracy Feedback (Priority: P1)

**Goal**: Display a session-wide accuracy percentage on the HUD based on cumulative correct/incorrect keypresses.

**Independent Test**: Type a mix of correct and incorrect characters and verify the accuracy percentage on the HUD matches the expected formula.

### Tests for User Story 2
**NOTE: Write these tests FIRST, ensure they FAIL before implementation.**

- [x] T016 [US2] Add accuracy unit test: set correct_chars to 100, wrong_chars to 4, call calculateTargetAccuracy(), assert result is approximately 96.15 in src/main.zig
- [x] T017 [US2] Add accuracy zero-input unit test: with correct_chars 0 and wrong_chars 0, call calculateTargetAccuracy(), assert result equals 100.0 in src/main.zig

### Implementation for User Story 2

- [x] T018 [US2] Implement calculateTargetAccuracy() function: compute (correct_chars / (correct_chars + wrong_chars)) × 100.0 using float casts, returning 100.0 when both counters are zero, in src/main.zig
- [x] T019 [US2] Extend updateMetrics() with accuracy section: compute target accuracy via calculateTargetAccuracy(), apply smoothing (displayed_accuracy += SMOOTHING_FACTOR × (target − displayed_accuracy)) in src/main.zig
- [x] T020 [US2] Add accuracy HUD drawing inside the if (!is_game_over) block (below WPM HUD): format displayed_accuracy as "Acc {d}%" (rounded to integer) via bufPrintZ, draw with DrawText at (ACC_HUD_X, ACC_HUD_Y) with METRICS_HUD_SIZE and DARKGRAY color in src/main.zig

**Checkpoint**: Accuracy displays on HUD, decreases on wrong keypresses, persists across wave transitions, resets on restart. Tests pass for reference cases.

---

## Phase 5: User Story 3 — Smooth HUD Display (Priority: P2)

**Goal**: WPM and accuracy values interpolate smoothly toward their targets rather than snapping, making the HUD pleasant and readable.

**Independent Test**: Watch WPM changes during gameplay — the displayed number should interpolate toward the target value rather than snapping instantly.

### Tests for User Story 3

- [x] T021 [US3] Add smoothing convergence unit test: set displayed_wpm to 0.0, simulate multiple updateMetrics() calls with a fixed target WPM of 72.0, verify displayed_wpm increases by 20% of the remaining gap each step (e.g., after 1 step: 14.4, after 2 steps: 25.92) in src/main.zig

### Implementation for User Story 3

Smoothing logic is already implemented within updateMetrics() (T014, T019). This phase verifies the smoothing constant is correctly applied.

- [x] T022 [US3] Verify SMOOTHING_FACTOR constant is 0.2 and is used in both WPM and accuracy smoothing paths within updateMetrics() in src/main.zig — no code change expected if T014 and T019 are correct

**Checkpoint**: Both WPM and accuracy HUD values animate smoothly. No frame-to-frame jumps visible during gameplay.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification across all user stories.

- [x] T023 Run zig build test and verify all existing + new unit tests pass
- [x] T024 Run zig build and verify clean compilation with no warnings
- [ ] T025 Manual play-test against acceptance scenarios: verify WPM climbs during typing, declines when idle for 10s, accuracy drops on wrong keys, combo resets on wrong keys, both metrics freeze on game-over, both reset to initial values (WPM 0, Acc 100%) on restart, accuracy persists across wave transitions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 completion
- **US2 (Phase 4)**: Depends on Phase 2 completion; can start after US1 or in parallel conceptually, but shares `src/main.zig` so executes sequentially
- **US3 (Phase 5)**: Depends on Phase 3 and Phase 4 (smoothing verifies both WPM and accuracy paths)
- **Polish (Phase 6)**: Depends on all prior phases

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) — Shares input loop with US1 but correct_chars and wrong_chars tracking are independent concerns
- **User Story 3 (P2)**: Depends on US1 and US2 — smoothing applies to both displayed_wpm and displayed_accuracy

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Calculation functions before integration (updateMetrics)
- Integration before HUD drawing
- Story complete before moving to next priority

### Parallel Opportunities

- No parallelism within phases — all tasks modify `src/main.zig`
- User stories 1 and 2 could theoretically be implemented in parallel via separate worktrees, but the shared `updateMetrics()` function makes sequential execution cleaner
- Tests within a story could be written in one batch since they're all in the same file

---

## Parallel Example: User Story 1

```
# Sequential execution required (single file):
Step 1: T010, T011, T012 — write all WPM tests (they will fail)
Step 2: T013 — implement calculateTargetWpm()
Step 3: T014 — implement updateMetrics() WPM section
Step 4: T015 — add WPM HUD drawing
Step 5: Run zig build test — WPM tests should now pass
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T002)
2. Complete Phase 2: Foundational (T003–T009)
3. Complete Phase 3: User Story 1 (T010–T015)
4. **STOP and VALIDATE**: Run `zig build test`, verify WPM displays correctly
5. WPM feedback is functional — MVP delivered

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → WPM on HUD (MVP)
3. Add User Story 2 → Accuracy on HUD (full P1 scope)
4. Add User Story 3 → Smooth transitions (polish)
5. Each story adds value without breaking previous stories

---

## Notes

- All 25 tasks modify or verify `src/main.zig` — no other files are changed
- No new files are created; all tests extend the existing test block (lines 743–1053)
- Estimated scope: ~100 lines of new logic, ~60 lines of new tests (per plan.md)
- The `typedMatchesAnyEnemy()` function (line 713) already checks both regular zombies AND the boss — no separate boss tracking needed

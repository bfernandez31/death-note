# Tasks: Per-kill scoring formula with combo and HUD

**Input**: Design documents from `specs/DEATHN-21-per-kill-scoring/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

**Tests**: Test tasks are included by default (constitution). All tests are inline `test` blocks in `src/main.zig`, extending the existing 12 test blocks (lines 612–827).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. All changes are in `src/main.zig` (single-module game — no new files, no new dependencies).

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies) — Not applicable for this feature since all tasks modify `src/main.zig`
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Constants, Types, and State)

**Purpose**: Add all new constants, the `ScorePopup` struct, and module-level state variables needed by every user story.

- [ ] T001 Add scoring, combo, and popup constants after existing constants (line ~20) in `src/main.zig`: `MAX_POPUPS = 32`, `POPUP_DURATION: f32 = 0.5`, `POPUP_RISE_PX: f32 = 30.0`, `SCORE_HUD_X: c_int = 10`, `SCORE_HUD_Y: c_int = 5`, `SCORE_HUD_SIZE: c_int = 24`, `COMBO_HUD_X: c_int = 10`, `COMBO_HUD_Y: c_int = 35`, `COMBO_HUD_SIZE: c_int = 18`, `POPUP_FONT_SIZE: c_int = 20`, `BOSS_TYPE_MULTIPLIER: f32 = 3.0`, `STANDARD_TYPE_MULTIPLIER: f32 = 1.0`
- [ ] T002 Add `ScorePopup` struct definition after the `Zombie` struct in `src/main.zig`: fields `x: f32`, `y: f32`, `points: u64`, `timer: f32`, `active: bool`
- [ ] T003 Add module-level state variables after existing game state vars (~line 62) in `src/main.zig`: `var score: u64 = 0`, `var combo_count: u32 = 0`, `var popups: [MAX_POPUPS]ScorePopup` (initialized to all-inactive), `var popup_next: usize = 0`

---

## Phase 2: Foundational (Pure Functions)

**Purpose**: Implement the core pure functions that all user stories depend on. These MUST be complete before any user story integration.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 Implement `getComboMultiplier` function in `src/main.zig` — input: `combo: u32`, output: `u64`. Tier lookup: 0–4→1, 5–9→2, 10–14→3, 15–19→4, 20+→5
- [ ] T005 Implement `calculateScore` function in `src/main.zig` — input: `name_len: usize, y_pos: f32, is_boss: bool, combo: u32`, output: `u64`. Formula: `@intFromFloat(@round((@as(f32, @floatFromInt(name_len)) * 10.0 + @round(100.0 * (y_pos / @as(f32, @floatFromInt(screen_height))))) * type_mult)) * getComboMultiplier(combo)` where `type_mult` is `BOSS_TYPE_MULTIPLIER` (3.0) for boss, `STANDARD_TYPE_MULTIPLIER` (1.0) for standard
- [ ] T006 Implement `spawnPopup` function in `src/main.zig` — input: `x: f32, y: f32, points: u64`. Writes to `popups[popup_next]` with `active = true`, `timer = POPUP_DURATION`, then advances `popup_next = (popup_next + 1) % MAX_POPUPS`
- [ ] T007 Implement `typedMatchesAnyEnemy` function in `src/main.zig` — reads globals `name`, `letter_count`, `zombies`, `boss`, `boss_phrase_len`. Returns `true` if `letter_count == 0` or the typed text is a prefix of any active zombie name or the active boss phrase. Used for combo mismatch detection

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 — Scoring on zombie kill (Priority: P1) 🎯 MVP

**Goal**: Each kill (standard zombie or boss) earns points based on `calculateScore` and adds them to the running total. The combo counter increments on each kill. A score popup spawns at the kill location.

**Independent Test**: Kill a single standard zombie at a known position with combo at 0 and verify the score matches the formula. Kill a boss and verify the boss type multiplier (3.0) is applied.

### Tests for User Story 1

- [ ] T008 [US1] Add test `"calculateScore reference cases"` after existing tests in `src/main.zig` — verify all four FR-013 cases: `calculateScore(4, 0, false, 0)` → 40, `calculateScore(4, 0, false, 20)` → 200, `calculateScore(4, 440, false, 0)` → 138, `calculateScore(19, 300, true, 10)` → 2313

### Implementation for User Story 1

- [ ] T009 [US1] Extend `updateZombies` kill site (~line 365) in `src/main.zig` — BEFORE `allocator.destroy(zomb)`: capture `zomb.x`, `zomb.y`, compute name length from `zomb.name`, call `calculateScore(name_len, zomb.y, false, combo_count)`, add result to `score`, increment `combo_count`, call `spawnPopup(zomb.x, zomb.y, points)`
- [ ] T010 [US1] Extend `updateBoss` kill site (~line 484) in `src/main.zig` — BEFORE `allocator.destroy(b)`: capture `b.x`, `b.y`, call `calculateScore(boss_phrase_len, b.y, true, combo_count)`, add result to `score`, increment `combo_count`, call `spawnPopup(b.x, b.y, points)`
- [ ] T011 [US1] Extend game restart handler (~lines 238–250) in `src/main.zig` — add `score = 0; combo_count = 0; popup_next = 0;` and loop over `&popups` setting each `.active = false`

**Checkpoint**: At this point, killing enemies awards score, increments combo, and spawns popups. Score and combo reset on restart. User Story 1 is testable via `zig build test` (formula tests) and manual play (score accumulates per kill).

---

## Phase 4: User Story 2 — Combo counter progression and reset (Priority: P1)

**Goal**: The combo counter resets to 0 when the player types a character that doesn't match any active enemy's prefix, or when a wave transition begins. Backspace does NOT reset the combo.

**Independent Test**: Kill several zombies to build combo, type an incorrect character, verify combo resets to 0. Start a new wave and verify combo resets. Use backspace and verify combo is preserved.

### Tests for User Story 2

- [ ] T012 [US2] Add test `"getComboMultiplier tier boundaries"` in `src/main.zig` — verify: combo 0→1, 4→1, 5→2, 9→2, 10→3, 14→3, 15→4, 19→4, 20→5, 100→5
- [ ] T013 [US2] Add test `"typedMatchesAnyEnemy mismatch detection"` in `src/main.zig` — set up `name` buffer and `letter_count` with a string that does NOT prefix-match any zombie in the `zombies` array, verify function returns `false`. Also test that `letter_count == 0` returns `true`

### Implementation for User Story 2

- [ ] T014 [US2] Add combo mismatch check in `frame()` after the character-input loop and before `updateZombies` in `src/main.zig` — track whether any new character was typed in the input loop (set a `var typed_this_frame: bool = false` flag), and if flag is set and `!typedMatchesAnyEnemy()`: set `combo_count = 0`. Backspace must NOT set the flag
- [ ] T015 [US2] Add `combo_count = 0` at wave transition start (~line 180, where `is_transitioning = true`) in `src/main.zig`

**Checkpoint**: Combo now correctly increments on kills, resets on mismatch or wave transition, and is preserved on backspace. User Story 2 is testable via `zig build test` (multiplier tiers, mismatch detection) and manual play.

---

## Phase 5: User Story 3 — HUD display (Priority: P2)

**Goal**: The player sees a persistent score line and combo line at the top-left of the screen. The combo line changes color based on the current combo tier.

**Independent Test**: Start a game and verify both HUD lines are visible. Kill enemies to raise combo through each tier (0–4 dark gray, 5–14 orange, 15+ red) and verify color changes.

### Tests for User Story 3

No automated tests — HUD rendering is verified manually (TS-4). See manual test checklist in Polish phase.

### Implementation for User Story 3

- [ ] T016 [US3] Add score HUD rendering in the active-gameplay draw section (after existing wave HUD) in `src/main.zig` — format `"Score: {d}"` using `std.fmt.bufPrintZ` into a `[32]u8` buffer, draw at `(SCORE_HUD_X, SCORE_HUD_Y)` with font size `SCORE_HUD_SIZE` and color `raylib.DARKGREEN`
- [ ] T017 [US3] Add combo HUD rendering below score HUD in `src/main.zig` — format `"Combo: {d} x{d}"` using `std.fmt.bufPrintZ` into a `[32]u8` buffer, draw at `(COMBO_HUD_X, COMBO_HUD_Y)` with font size `COMBO_HUD_SIZE`. Color: combo < 5 → `raylib.DARKGRAY`, 5–14 → `raylib.ORANGE`, 15+ → `raylib.RED`

**Checkpoint**: Score and combo are now visible to the player during gameplay. User Story 3 is testable via manual play — verify HUD positions, formats, and color tier transitions.

---

## Phase 6: User Story 4 — Floating score popup (Priority: P2)

**Goal**: When an enemy is killed, a "+{score}" popup appears at the kill position, rises 30 pixels, and fades out over 0.5 seconds. The popup pool holds 32 entries with circular recycling.

**Independent Test**: Kill a zombie and verify a gold popup appears, rises, and fades. Kill 33+ enemies rapidly and verify the oldest popup is recycled without crashes.

### Tests for User Story 4

- [ ] T018 [US4] Add test `"popup pool circular recycling"` in `src/main.zig` — call `spawnPopup` 33 times, verify `popup_next` wraps to 1 (slot 0 overwritten) and `popups[0].active == true` with the 33rd popup's data

### Implementation for User Story 4

- [ ] T019 [US4] Implement `drawPopups` function in `src/main.zig` — for each active popup: compute progress as `1.0 - (timer / POPUP_DURATION)`, draw Y as `y - (POPUP_RISE_PX * progress)`, alpha as `@intFromFloat((timer / POPUP_DURATION) * 255.0)`, color as `raylib.Color{ .r = 255, .g = 203, .b = 0, .a = alpha }`, format text as `"+{d}"` via `bufPrintZ`, draw with `raylib.DrawText`
- [ ] T020 [US4] Add popup timer update in the update phase of `frame()` in `src/main.zig` (after `updateBoss`, outside the `!is_game_over` gate so popups fade during game-over) — for each active popup: decrement `timer` by `raylib.GetFrameTime()`, if `timer <= 0` set `active = false`
- [ ] T021 [US4] Call `drawPopups()` in the draw section alongside `drawZombies()` and `drawBoss()` in the active-gameplay else branch of `src/main.zig`

**Checkpoint**: Kill popups now appear, animate, and recycle correctly. User Story 4 is testable via `zig build test` (circular recycling) and manual play (visual animation).

---

## Phase 7: User Story 5 — Score shown on game-over screen (Priority: P3)

**Goal**: The final score is displayed on the game-over screen alongside existing wave and WPM info. Score resets to 0 on restart.

**Independent Test**: Play until game over and verify the score value appears on the game-over screen. Press Enter to restart and verify score resets.

### Tests for User Story 5

- [ ] T022 [US5] Add test `"score and combo reset on restart"` in `src/main.zig` — set `score` to a non-zero value, `combo_count` to a non-zero value, `popup_next` to a non-zero value, activate a popup, then simulate the reset logic (set all to 0, deactivate popups), and verify all values are reset

### Implementation for User Story 5

- [ ] T023 [US5] Add score display to game-over screen rendering in `src/main.zig` — format `"Score: {d}"` using `bufPrintZ`, draw centered below existing game-over info using `drawCenteredText`

**Checkpoint**: All user stories are now independently functional. Score persists through gameplay and displays on game over.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Verify all tests pass and document manual testing requirements.

- [ ] T024 Run `zig build test` to verify all new and existing tests pass in `src/main.zig`
- [ ] T025 Run `zig build` to verify clean compilation with no errors

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (needs constants and types) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 (needs `calculateScore`, `spawnPopup`)
- **US2 (Phase 4)**: Depends on Phase 3 (kill-site combo increment added in US1)
- **US3 (Phase 5)**: Depends on Phase 2 (needs `score` and `combo_count` state)
- **US4 (Phase 6)**: Depends on Phase 2 (needs `spawnPopup`, `ScorePopup` pool)
- **US5 (Phase 7)**: Depends on Phase 3 (needs `score` state and restart handler from US1)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational only — no dependencies on other stories
- **US2 (P1)**: Depends on US1 (combo increment is integrated into kill sites in US1)
- **US3 (P2)**: Depends on Foundational only — can start after Phase 2, in parallel with US1
- **US4 (P2)**: Depends on Foundational only — can start after Phase 2, in parallel with US1
- **US5 (P3)**: Depends on US1 (needs score state and restart handler)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Pure functions before integration
- Core implementation before rendering
- Story complete before moving to next priority

### Parallel Opportunities

Since all tasks modify `src/main.zig`, true file-level parallelism is not available. However, the following execution optimizations apply:

- **US3 and US4** can be implemented in parallel with US1 by different developers (they touch different sections of the draw loop)
- **US3 and US4** are independent of each other (HUD vs. popups — different draw functions)
- **Tests within a story** can be written before implementation begins (test-first)

### Suggested Execution Order (Sequential)

```
Phase 1 → Phase 2 → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 6 (US4) → Phase 7 (US5) → Phase 8
```

### Parallel Example: After Phase 2

```
┌─ US1 (Phase 3): Kill-site scoring integration
│  └─ US2 (Phase 4): Mismatch detection + wave transition reset
│     └─ US5 (Phase 7): Game-over score display
│
└─ US3 (Phase 5): HUD rendering ──┐
   US4 (Phase 6): Popup rendering ─┘── can run alongside US1
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (constants, types, state)
2. Complete Phase 2: Foundational (pure functions)
3. Complete Phase 3: User Story 1 (kill-site scoring)
4. **STOP and VALIDATE**: Run `zig build test` — all 4 reference cases must pass
5. Manual play: verify score accumulates on kills

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test independently → Score works on kills (MVP!)
3. Add US2 → Test independently → Combo resets work correctly
4. Add US3 → Test independently → HUD visible with color tiers
5. Add US4 → Test independently → Popups animate at kill locations
6. Add US5 → Test independently → Score on game-over screen
7. Each story adds value without breaking previous stories

---

## Notes

- All 25 tasks modify `src/main.zig` — no new files created
- No [P] markers used because all tasks operate on the same file
- Existing tests (12 blocks, lines 612–827) must continue to pass after all changes
- New tests extend `src/main.zig` after line 827, following existing `test "..." { ... }` pattern
- Manual testing required for rendering (HUD, popups, game-over screen) per TS-4
- `screen_height` is an existing module-level constant (450) used in the scoring formula

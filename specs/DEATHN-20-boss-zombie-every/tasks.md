# Tasks: Boss Zombie Every Five Waves

**Input**: Design documents from `specs/DEATHN-20-boss-zombie-every/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Included by default (constitution). All tests in `src/main.zig` (single-module game).

**Organization**: Tasks grouped by user story. One new file (`src/boss_phrases.zig`); all other changes target `src/main.zig`. Parallel opportunities limited to the new file.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- All file paths are verified against the current repository state

---

## Phase 1: Setup (Boss Phrase Data)

**Purpose**: Create the boss phrase data file following the existing `src/zombie_names.zig` pattern.

- [x] T001 [P] Create `src/boss_phrases.zig` with `pub const BossPhrases` — a `[10][*:0]const u8` array of 10 lowercase phrases with spaces, all within 35 characters, following the `src/zombie_names.zig` pattern. Phrases: "the dead walk again", "bones remember every step", "silence feeds the horde", "no grave holds them long", "they rise when sun falls", "cold hands reach for you", "the earth spits them out", "shadows crawl at midnight", "a whisper wakes the dead", "run before they find you"

**Checkpoint**: New file compiles — `zig build` succeeds

---

## Phase 2: Foundational (Constants, State, Helpers)

**Purpose**: Add boss constants, state variables, and helper functions that ALL user stories depend on.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T002 Add `BossPhrases` import and boss constants at the top of `src/main.zig` (alongside existing constants at lines 7-12): `const BossPhrases = @import("boss_phrases.zig").BossPhrases;`, `const MAX_BOSS_INPUT_CHARS = 35;`, `const BOSS_SCALE: f32 = 0.4;`, `const BOSS_SPEED_MULTIPLIER: f32 = 0.5;`, `const BOSS_HEALTH_BAR_WIDTH: c_int = 200;`, `const BOSS_HEALTH_BAR_HEIGHT: c_int = 8;`
- [x] T003 Enlarge input buffer in `src/main.zig` (line 40): change `var name = [_]u8{0} ** (MAX_INPUT_CHARS + 1)` to `var name = [_]u8{0} ** (MAX_BOSS_INPUT_CHARS + 1)` so the buffer can hold boss phrases
- [x] T004 Add boss state module-level variables after `transition_timer` (line 50) in `src/main.zig`: `var boss: ?*Zombie = null;`, `var boss_spawned_this_wave: bool = false;`, `var boss_phrase_len: usize = 0;`
- [x] T005 Add `getCurrentMaxInput() usize` helper function in `src/main.zig`: returns `MAX_BOSS_INPUT_CHARS` when `boss != null`, else `MAX_INPUT_CHARS`
- [x] T006 Add `resetBoss(allocator: *std.mem.Allocator) void` function in `src/main.zig`: if `boss` is non-null, destroy it and set `boss = null`; reset `boss_spawned_this_wave = false` and `boss_phrase_len = 0`

**Checkpoint**: Foundation ready — `zig build test` passes, all user stories can now proceed sequentially

---

## Phase 3: User Story 1 — Boss Encounter on Wave 5 (Priority: P1) MVP

**Goal**: A boss zombie spawns on every 5th wave at 50% pool kills. The boss is visually distinct: 2x scale (0.4), red tint, phrase displayed above in dark red.

**Independent Test**: Start game, survive to wave 5, kill 7 zombies, verify boss spawns with correct visual treatment.

### Tests for User Story 1
**NOTE: Write these tests FIRST, ensure they FAIL before implementation**
**RULE (constitution): Extend existing test blocks in `src/main.zig` — do not create new test files.**

- [ ] T007 [US1] Add test `"boss wave detection"` in `src/main.zig` — verify `wave % 5 == 0` is true for waves 5, 10, 15, 20 and false for waves 1, 4, 6, 14
- [ ] T008 [US1] Add test `"boss spawn threshold calculation"` in `src/main.zig` — verify `(pool_size + 1) / 2` yields: wave 5 (pool_size=13) threshold=7, wave 10 (pool_size=23) threshold=12, wave 20 (pool_size=43) threshold=22

### Implementation for User Story 1

- [ ] T009 [US1] Add `spawnBoss(allocator: *std.mem.Allocator) !void` function in `src/main.zig` following the `spawnZombie` pattern (line 395): allocate `Zombie` with `try allocator.create(Zombie)`, use `errdefer allocator.destroy(new_boss)`, set `x` to horizontal center (`screen_width / 2.0 - 30.0`), `y = 0.0`, `speed = getWaveConfig(current_wave).fall_speed * BOSS_SPEED_MULTIPLIER`, select random phrase from `BossPhrases`, assign to `boss`, set `boss_spawned_this_wave = true`, precompute `boss_phrase_len` by scanning to null terminator
- [ ] T010 [US1] Add boss spawn trigger in `frame()` after `updateZombies(ctx.allocator)` call (line 141) and before wave completion check (line 145) in `src/main.zig`: if `current_wave % 5 == 0 and !boss_spawned_this_wave and boss == null`, compute threshold as `(wave_cfg.pool_size + 1) / 2`, if `wave_kills >= threshold` then call `spawnBoss(ctx.allocator) catch {}`
- [ ] T011 [US1] Add `drawBoss() void` function in `src/main.zig`: if `boss` is null return; animate using same spritesheet logic as `drawZombies` (lines 351-359); compute source rectangle; draw with `DrawTexturePro` using `BOSS_SCALE` (0.4) and `raylib.RED` tint; draw phrase text above sprite at `(boss_x, boss_y - 30)` with font size 20 and dark red color `raylib.Color{ .r = 139, .g = 0, .b = 0, .a = 255 }`
- [ ] T012 [US1] Call `drawBoss()` in the draw phase of `src/main.zig` alongside `drawZombies()` (line 225, inside the `else` branch that draws active gameplay)

**Checkpoint**: Boss spawns visually on wave 5 at 50% kills — visible on screen with distinct look

---

## Phase 4: User Story 2 — Typing Boss Phrase to Kill (Priority: P1)

**Goal**: While the boss is active, input buffer extends to 35 characters. Player types the full phrase to kill the boss. Health bar shows typing progress.

**Independent Test**: With boss on screen, type the displayed phrase and verify health bar depletes and boss is destroyed.

### Tests for User Story 2
**NOTE: Write these tests FIRST, ensure they FAIL before implementation**
**RULE (constitution): Extend existing test blocks in `src/main.zig` — do not create new test files.**

- [ ] T013 [US2] Add test `"getCurrentMaxInput returns correct limits"` in `src/main.zig` — verify returns `MAX_INPUT_CHARS` when `boss == null` and `MAX_BOSS_INPUT_CHARS` when `boss` is set (temporarily set the global for the test)
- [ ] T014 [US2] Add test `"boss phrase validity"` in `src/main.zig` — verify all 10 phrases in `BossPhrases` are: non-empty, within 35 characters, contain only lowercase letters (97-122) and spaces (32)
- [ ] T015 [US2] Add test `"input buffer capacity for boss phrases"` in `src/main.zig` — verify `name.len >= MAX_BOSS_INPUT_CHARS + 1` (buffer can hold longest boss phrase plus null terminator)

### Implementation for User Story 2

- [ ] T016 [US2] Add `updateBoss(allocator: *std.mem.Allocator) void` function in `src/main.zig`: if `boss` is null return; unwrap with `if (boss) |b|`; advance `b.y += b.speed`; if `b.y >= screen_height` set `is_game_over = true` and return (FR-013); compute typed name `name[0..letter_count]`; compute boss phrase slice by scanning `b.name` to null; check if typed input is a valid prefix: `std.mem.eql(u8, typed_name, boss_phrase[0..letter_count])`; if prefix matches AND `letter_count == boss_phrase_len`: destroy boss, set `boss = null`, clear input (`letter_count = 0`, `name[0] = '\x00'`), play `zombie_kill_sound` (do NOT increment `wave_kills`)
- [ ] T017 [US2] Call `updateBoss(ctx.allocator)` in `frame()` right after the boss spawn check (T010) and before the wave completion check in `src/main.zig`
- [ ] T018 [US2] Update input acceptance guard in `frame()` (line 109) of `src/main.zig`: change `letter_count < MAX_INPUT_CHARS` to `letter_count < getCurrentMaxInput()`
- [ ] T019 [US2] Update blinking cursor guard (line 228) in `src/main.zig`: change `letter_count < MAX_INPUT_CHARS` to `letter_count < getCurrentMaxInput()`
- [ ] T020 [US2] Update "Press BACKSPACE" hint guard (line 232) in `src/main.zig`: change `letter_count >= MAX_INPUT_CHARS` to `letter_count >= getCurrentMaxInput()`
- [ ] T021 [US2] Add health bar drawing to `drawBoss()` in `src/main.zig`: below phrase text, draw background `DrawRectangle(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.LIGHTGRAY)`, fill `DrawRectangle(bar_x, bar_y, fill_width, BOSS_HEALTH_BAR_HEIGHT, raylib.RED)` where `fill_width = BOSS_HEALTH_BAR_WIDTH * (boss_phrase_len - letter_count) / boss_phrase_len` (only when input is valid prefix), border `DrawRectangleLines(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.DARKGRAY)`

**Checkpoint**: Boss can be killed by typing full phrase, health bar shows progress, input limit extends to 35 during boss

---

## Phase 5: User Story 3 — Boss Priority Over Regular Zombies (Priority: P2)

**Goal**: While the boss is active and typed input is a valid boss phrase prefix, regular zombie kills are suppressed.

**Independent Test**: With boss and a matching-prefix regular zombie on screen, type that prefix and verify the regular zombie is not killed.

### Implementation for User Story 3

- [ ] T022 [US3] Add boss priority check in `updateZombies()` in `src/main.zig`: before the `std.mem.eql` check for regular zombies (line 329), add guard — if `boss != null`, unwrap and compute `boss_slice = b.name[0..boss_phrase_len]`, if `letter_count <= boss_phrase_len and std.mem.eql(u8, typed_name, boss_slice[0..letter_count])` then `continue` to skip this regular zombie

**Checkpoint**: Regular zombies are not accidentally killed while typing a boss phrase prefix

---

## Phase 6: User Story 4 — Wave Completion Requires Boss Kill (Priority: P2)

**Goal**: On boss waves (multiples of 5), the wave does not complete until both the pool AND the boss are defeated.

**Independent Test**: Kill all pool zombies on wave 5 without killing the boss — verify wave does not transition.

### Tests for User Story 4
**RULE (constitution): Extend existing test blocks in `src/main.zig`.**

- [ ] T023 [US4] Add test `"wave completion requires boss kill on boss waves"` in `src/main.zig` — verify that on a boss wave (wave % 5 == 0), the completion condition requires `boss == null and boss_spawned_this_wave` in addition to pool kills and spawns reaching pool_size

### Implementation for User Story 4

- [ ] T024 [US4] Modify wave completion check in `frame()` (line 145) of `src/main.zig`: add `const boss_done = if (current_wave % 5 == 0) boss == null and boss_spawned_this_wave else true;` and append `and boss_done` to the existing `if` condition
- [ ] T025 [US4] Call `resetBoss(ctx.allocator)` in wave transition block (line 160, inside `if (transition_timer <= 0)`) alongside `resetZombies` in `src/main.zig`
- [ ] T026 [US4] Call `resetBoss(ctx.allocator)` in game restart block (line 214, inside `if (raylib.IsKeyPressed(raylib.KEY_ENTER))`) alongside `resetZombies` in `src/main.zig`

**Checkpoint**: Boss waves cannot be skipped — wave only transitions after both pool and boss are cleared

---

## Phase 7: User Story 5 — Boss Reaches Bottom Causes Game Over (Priority: P2)

**Goal**: If the boss falls to the bottom of the screen, game over triggers. Boss falls at 0.5x wave speed.

**Independent Test**: Allow boss to fall without typing — verify game over triggers at bottom.

### Implementation for User Story 5

- [ ] T027 [US5] Verify `updateBoss()` (from T016) includes game-over check: `if (b.y >= screen_height) { is_game_over = true; return; }` and that `spawnBoss()` (from T009) sets `speed = getWaveConfig(current_wave).fall_speed * BOSS_SPEED_MULTIPLIER` in `src/main.zig` — verification task, no new code expected

**Checkpoint**: Boss reaching bottom triggers game over, consistent with regular zombie behavior

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Build verification and manual integration testing.

- [ ] T028 Verify `zig build test` passes with all new and existing tests in `src/main.zig`
- [ ] T029 Verify `zig build` compiles cleanly (native target) with all changes in `src/main.zig` and `src/boss_phrases.zig`
- [ ] T030 Manual integration test per plan.md testing strategy: start game, survive to wave 5, kill 7 zombies, verify boss spawns with red tint and phrase, type phrase to verify health bar and kill, verify wave waits for boss kill, let boss reach bottom to verify game over, restart and verify clean state, play to wave 10 to verify second boss

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately. [P] with Phase 2 since different file.
- **Foundational (Phase 2)**: Depends on Phase 1 (T002 imports from `boss_phrases.zig`). BLOCKS all user stories.
- **US1 (Phase 3)**: Depends on Phase 2. Core boss spawn + visual — must complete before other stories.
- **US2 (Phase 4)**: Depends on US1 (boss must exist to be typed). Core typing mechanic.
- **US3 (Phase 5)**: Depends on US2 (boss update logic must exist for priority to matter).
- **US4 (Phase 6)**: Depends on US1 (boss must spawn for wave gate to apply). Can run after US1.
- **US5 (Phase 7)**: Depends on US2 (game-over logic is in `updateBoss`). Verification only.
- **Polish (Phase 8)**: Depends on all phases complete.

### Recommended Execution Order

```
Phase 1 (Setup — boss_phrases.zig)    [P] Phase 2 starts after T001
    |
Phase 2 (Foundational — constants, state, helpers)
    |
Phase 3 (US1 — Boss Encounter on Wave 5)  <- MVP
    |
Phase 4 (US2 — Typing Boss Phrase)
    |
Phase 5 (US3 — Boss Priority)
    |
Phase 6 (US4 — Wave Completion Gate)
    |
Phase 7 (US5 — Boss Reaches Bottom) <- verification only
    |
Phase 8 (Polish)
```

### Within Each User Story

1. Tests written FIRST, verified to FAIL before implementation
2. Implementation tasks in dependency order
3. Story checkpoint verified before moving to next

### Parallel Opportunities

- **T001** (`src/boss_phrases.zig`) is [P] — different file from all `src/main.zig` tasks
- **T007, T008** (US1 tests) can be written in a single batch — independent test blocks
- **T013, T014, T015** (US2 tests) can be written in a single batch — independent test blocks
- All other tasks modify `src/main.zig` sequentially — no file-level parallelism available

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Boss phrase data file
2. Complete Phase 2: Foundational constants and helpers
3. Complete Phase 3: US1 — Boss spawns visually on wave 5
4. Complete Phase 4: US2 — Boss can be killed by typing
5. **STOP and VALIDATE**: `zig build test` + `zig build run` — verify boss spawns, is typable, health bar works
6. This delivers the core feature: boss zombie with phrase typing on every 5th wave

### Incremental Delivery

1. Phase 1 + 2 -> Foundation ready
2. Phase 3 (US1) -> Boss spawns visually -> **MVP start**
3. Phase 4 (US2) -> Boss is killable -> **MVP complete**
4. Phase 5 (US3) -> Priority prevents accidental kills -> polished UX
5. Phase 6 (US4) -> Wave gate enforces boss -> mandatory challenge
6. Phase 7 (US5) -> Game-over verified -> consistency check
7. Phase 8 -> Build verification -> ship-ready

---

## Notes

- 1 new file: `src/boss_phrases.zig` (follows `src/zombie_names.zig` pattern)
- 29 of 30 tasks target `src/main.zig` — minimal parallelism
- Existing 7 tests at lines 448-572 remain unchanged and valid
- Boss reuses existing `Zombie` struct, `zombie_texture`, and `zombie_kill_sound` — no new asset loads
- No new `@cImport` calls — raylib interop stays walled off in `src/raylib.zig`
- `resetBoss` must be called everywhere `resetZombies` is called (wave transition + game restart)

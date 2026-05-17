# Tasks: DEATHN-13 — Zombie Variety and Name List Depth

**Input**: Design documents from `/specs/DEATHN-13-zombie-variety-and/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included by default (constitution). Tests are inline `test` blocks in the module under test (Zig convention).

**Organization**: Tasks grouped by user story. Each story is independently testable and deliverable.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No new project initialization needed — extending existing Zig project. This phase adds core data types and constants that all user stories depend on.

- [ ] T001 Add `ZombieType` enum (`standard`, `runner`, `tank`) after existing type declarations in `src/main.zig`
- [ ] T002 Add `zombie_type: ZombieType` field to `Zombie` struct (default `.standard`) in `src/main.zig`
- [ ] T003 Add `SpawnWeights` and `NameWeights` structs in `src/main.zig`
- [ ] T004 Add new named constants at module top in `src/main.zig`: `RUNNER_SPEED_MULTIPLIER` (1.8), `TANK_SPEED_MULTIPLIER` (0.5), `RUNNER_MAX_NAME_LEN` (5), `TANK_MIN_NAME_LEN` (8), `MAX_SPAWN_RETRIES` (10)
- [ ] T005 Add `SPAWN_WEIGHT_TABLE` compile-time array (4 wave brackets) in `src/main.zig`
- [ ] T006 Add `NAME_WEIGHT_TABLE` compile-time array (4 wave brackets) in `src/main.zig`
- [ ] T007 Change `MAX_INPUT_CHARS` from 9 to 20 in `src/main.zig`
- [ ] T008 Add helper functions `getSpeedMultiplier`, `getSpawnWeights`, `getNameWeights`, `selectZombieType`, `getZombieTint` in `src/main.zig`
- [ ] T009 Add trap cluster state variables (`trap_cluster_group: ?usize`, `trap_cluster_remaining: u8`) as module-level globals in `src/main.zig`
- [ ] T010 Add `prng: std.Random.DefaultPrng` module-level variable and initialize it in `main()` with `std.time.milliTimestamp()` seed in `src/main.zig`

**Checkpoint**: `zig build` compiles cleanly. `zig build test` passes (existing tests still green). Game runs unchanged — all zombies spawn as `.standard`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the name lists module that all name-related user stories depend on.

**CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T011 Create `src/name_lists.zig` with `NameCategory` enum, `TrapGroup` struct, and `NameSelection` struct
- [ ] T012 Add `PrimaryNames` array (349+ entries, all 49 original names from `src/zombie_names.zig` included) in `src/name_lists.zig`
- [ ] T013 Add `CompoundNames` array (30+ hyphenated names, each ≤20 chars, ASCII + hyphen only) in `src/name_lists.zig`
- [ ] T014 Add `TrapGroups` array (15+ groups of 3–5 visually similar names) in `src/name_lists.zig`
- [ ] T015 Implement `cstrLen` helper function in `src/name_lists.zig`
- [ ] T016 Implement `selectName` function per contract (`specs/DEATHN-13-zombie-variety-and/contracts/name-lists-module.md`) in `src/name_lists.zig`
- [ ] T017 Add `const name_lists = @import("name_lists.zig");` import to `src/main.zig`

### Tests for Foundational Phase

- [ ] T018 [P] Add compile-time test `"primary list size"` verifying PrimaryNames.len >= 349 in `src/name_lists.zig`
- [ ] T019 [P] Add test `"all names ASCII"` scanning every name for bytes in [32, 125] in `src/name_lists.zig`
- [ ] T020 [P] Add test `"compound names valid"` verifying each ≤20 chars, only [A-Za-z-] in `src/name_lists.zig`
- [ ] T021 [P] Add test `"trap group sizes"` verifying each has 3–5 entries in `src/name_lists.zig`
- [ ] T022 [P] Add test `"sufficient runner names"` counting names ≤5 chars ≥ 30 in `src/name_lists.zig`
- [ ] T023 [P] Add test `"sufficient tank names"` counting names ≥8 chars ≥ 30 in `src/name_lists.zig`
- [ ] T024 [P] Add test `"weight tables sum to 100"` for both SPAWN_WEIGHT_TABLE and NAME_WEIGHT_TABLE in `src/name_lists.zig` (import from main or validate inline)

**Checkpoint**: `zig build test` passes all new compile-time validations. `zig build` compiles with name_lists imported.

---

## Phase 3: User Story 1 — Encountering Different Zombie Types (Priority: P1) MVP

**Goal**: Players see Standard, Runner (green, fast, short names), and Tank (blue, slow, long names) zombies appear based on wave progression.

**Independent Test**: Start a game, play through waves 1–7, verify that Standard/Runner/Tank zombies appear with correct tinting, speed, and name length patterns.

### Tests for User Story 1

**Extend existing test file `src/main.zig` (lines 1017–1645) with new test blocks:**

- [ ] T025 [P] [US1] Add test `"ZombieType speed multipliers"` verifying getSpeedMultiplier returns 1.0/1.8/0.5 in `src/main.zig`
- [ ] T026 [P] [US1] Add test `"spawn weight table wave brackets"` verifying getSpawnWeights returns correct weights for waves 1-3, 4-6, 7-10, 11+ in `src/main.zig`
- [ ] T027 [P] [US1] Add test `"selectZombieType distribution"` seeding PRNG and verifying type selection matches weight distribution in `src/main.zig`
- [ ] T028 [P] [US1] Add test `"zombie tint colors"` verifying getZombieTint returns WHITE/GREEN/BLUE per type in `src/main.zig`

### Implementation for User Story 1

- [ ] T029 [US1] Rewrite `spawnZombie` to accept `rng` parameter, select `ZombieType` via `selectZombieType(getSpawnWeights(current_wave), ...)`, and set `speed = fall_speed * getSpeedMultiplier(zombie_type)` in `src/main.zig`
- [ ] T030 [US1] Update `spawnZombie` to call `name_lists.selectName(wave, type, active_names, forced_trap_group, rng)` — build `active_names` slice by scanning zombie slots in `src/main.zig`
- [ ] T031 [US1] Update call site in `frame()` to pass module-level `prng` to `spawnZombie` in `src/main.zig`
- [ ] T032 [US1] Update tint block in `drawZombies` (line 582–589) to use `getZombieTint(zomb.zombie_type)` with dying tint priority in `src/main.zig`

**Checkpoint**: `zig build run` — Runners (green, fast) appear from wave 4, Tanks (blue, slow) from wave 7+. Speed differences visible. All zombies typed correctly.

---

## Phase 4: User Story 2 — Expanded Name Variety (Priority: P1)

**Goal**: Players encounter 349+ unique names, compound hyphenated names in later waves, and the input field accommodates 20-character names.

**Independent Test**: Play through waves 1–10, verify names come from expanded pool, compound names appear, hyphens accepted as input.

### Tests for User Story 2

- [ ] T033 [P] [US2] Add test `"selectName anti-doublon"` passing all names as active, verifying null returned in `src/name_lists.zig`
- [ ] T034 [P] [US2] Add test `"selectName length filtering"` verifying Runner gets ≤5 chars, Tank gets ≥8 chars in `src/name_lists.zig`
- [ ] T035 [P] [US2] Add test `"hyphen accepted in input"` verifying key 45 passes the gate and matches in name comparison in `src/main.zig`
- [ ] T036 [P] [US2] Update existing test `"input buffer bounds"` (line 1031) for new MAX_INPUT_CHARS=20 in `src/main.zig`
- [ ] T037 [P] [US2] Update existing test `"getCurrentMaxInput returns correct limits"` (line 1168) to expect 20 instead of 9 in `src/main.zig`

### Implementation for User Story 2

- [ ] T038 [US2] Update text box width in `frame()` for 20-char input: change default from 225px to ~500px, recenter at `screen_width / 2.0 - 250.0` in `src/main.zig`
- [ ] T039 [US2] Verify zombie name text (`DrawText` at line 606) renders correctly for longer compound names — adjust position if needed in `src/main.zig`
- [ ] T040 [US2] Add test `"name weight table wave brackets"` verifying getNameWeights returns correct weights for waves 1-3, 4-7, 8-12, 13+ in `src/main.zig`

**Checkpoint**: `zig build run` — compound names like "Jean-Pierre" appear from wave 4+. Input box fits 20-char names. Hyphens type correctly.

---

## Phase 5: User Story 3 — No Duplicate Names on Screen (Priority: P2)

**Goal**: No two active zombies share the same name simultaneously. Anti-doublon retries up to 10 times, then defers spawn.

**Independent Test**: Play waves 10+ with 20+ active zombies, verify no duplicates ever appear on screen.

### Tests for User Story 3

- [ ] T041 [P] [US3] Add test `"anti-doublon retries exhaust gracefully"` verifying spawnZombie returns false when all names collide, in `src/main.zig`

### Implementation for User Story 3

- [ ] T042 [US3] Verify anti-doublon is enforced in `spawnZombie` via `name_lists.selectName` active_names parameter (implemented in T030) — no additional code if selectName handles retries in `src/main.zig`

**Checkpoint**: No duplicate names observed during play. Spawn defers silently when pool exhausted.

---

## Phase 6: User Story 4 — Trap Name Clusters Create Typing Challenge (Priority: P2)

**Goal**: In mid-to-late waves, groups of visually similar names (e.g., "Liam", "Lila", "Lina") spawn close together, increasing cognitive challenge.

**Independent Test**: Play waves 8+ and verify trap-group names occasionally appear in clusters of 2–3 similar names on screen.

### Tests for User Story 4

- [ ] T043 [P] [US4] Add test `"selectName trap group preference"` verifying forced_trap_group returns name from that group in `src/name_lists.zig`
- [ ] T044 [P] [US4] Add test `"trap cluster state reset"` verifying `resetZombies` clears trap_cluster_group and trap_cluster_remaining in `src/main.zig`

### Implementation for User Story 4

- [ ] T045 [US4] Add trap cluster logic to `spawnZombie`: when `selection.category == .trap`, set `trap_cluster_group` and `trap_cluster_remaining = random(1, 2)`; decrement on subsequent spawns in `src/main.zig`
- [ ] T046 [US4] Update `resetZombies` to clear trap cluster state (`trap_cluster_group = null`, `trap_cluster_remaining = 0`) in `src/main.zig`
- [ ] T047 [US4] Update game restart block (around line 392–406) to also clear trap cluster state in `src/main.zig`

**Checkpoint**: `zig build run` — trap name clusters appear in waves 8+. Similar names on screen simultaneously. Exact typing required.

---

## Phase 7: User Story 5 — Type-Appropriate Name Selection (Priority: P3)

**Goal**: Runners consistently get short names (≤5 chars), Tanks get long names (≥8 chars), reinforcing each type's identity.

**Independent Test**: Spawn 50 Runners and 50 Tanks across multiple waves, verify name length constraints hold.

### Tests for User Story 5

- [ ] T048 [P] [US5] Add test `"runner names are short"` spawning multiple Runners and verifying all names ≤5 chars in `src/name_lists.zig`
- [ ] T049 [P] [US5] Add test `"tank names are long"` spawning multiple Tanks and verifying all names ≥8 chars in `src/name_lists.zig`

### Implementation for User Story 5

- [ ] T050 [US5] Verify `selectName` length filtering is enforced per zombie_type (implemented in T016/T030) — validate with manual play-test in `src/name_lists.zig`

**Checkpoint**: Runners always have short names, Tanks always have long names. Standard zombies get any length.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, edge cases, and cleanup.

- [ ] T051 Verify `zig build web` compiles without regression (no new deps, no new C imports)
- [ ] T052 Run full test suite `zig build test` and fix any failures
- [ ] T053 Manual play-test waves 1–15: verify all zombie types, name variety, trap clusters, input box, speed differences, dying tint, boss encounters unchanged
- [ ] T054 Remove or deprecate `src/zombie_names.zig` import from `src/main.zig` if fully superseded by `name_lists.zig` (keep file for reference)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (needs ZombieType enum) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — core spawn system rewrite
- **US2 (Phase 4)**: Depends on Phase 2 — can run in parallel with US1 (test tasks are parallel, but implementation T038-T040 are in same file as US1)
- **US3 (Phase 5)**: Depends on Phase 3 (anti-doublon is part of spawn rewrite)
- **US4 (Phase 6)**: Depends on Phase 3 (trap clusters require spawn system)
- **US5 (Phase 7)**: Depends on Phase 2 (length filtering in selectName)
- **Polish (Phase 8)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: Requires Foundational phase. Core spawn rewrite — other stories build on this.
- **US2 (P1)**: Requires Foundational phase. Input/display changes are independent of spawn logic.
- **US3 (P2)**: Requires US1 (anti-doublon is in the rewritten spawnZombie).
- **US4 (P2)**: Requires US1 (trap clusters extend spawnZombie).
- **US5 (P3)**: Requires Foundational phase (selectName handles filtering). Can verify after US1.

### Within Each User Story

- Tests written first (test blocks in module under test)
- Constants/types before logic
- Core implementation before integration
- Manual play-test at each checkpoint

### Parallel Opportunities

- **Phase 1**: T001–T010 are all in `src/main.zig` — sequential within the file, but each is small
- **Phase 2**: T011–T017 are sequential (building the module), T018–T024 tests are parallel
- **Phase 3**: T025–T028 tests are parallel, T029–T032 implementation is sequential (same function)
- **Phase 4**: T033–T037 tests are parallel (across `src/main.zig` and `src/name_lists.zig`)
- **US2 implementation** (T038–T040) can run in parallel with **US4 tests** (T043–T044) since they touch different areas

---

## Parallel Example: User Story 1

```
# Launch all US1 tests in parallel (all in src/main.zig but independent test blocks):
Task T025: test "ZombieType speed multipliers" in src/main.zig
Task T026: test "spawn weight table wave brackets" in src/main.zig
Task T027: test "selectZombieType distribution" in src/main.zig
Task T028: test "zombie tint colors" in src/main.zig

# Then implement sequentially (same function spawnZombie):
Task T029: Rewrite spawnZombie type selection
Task T030: Integrate name_lists.selectName
Task T031: Update frame() call site
Task T032: Update drawZombies tint block
```

## Parallel Example: Foundational Tests

```
# Launch all name_lists.zig validation tests in parallel:
Task T018: test "primary list size"
Task T019: test "all names ASCII"
Task T020: test "compound names valid"
Task T021: test "trap group sizes"
Task T022: test "sufficient runner names"
Task T023: test "sufficient tank names"
Task T024: test "weight tables sum to 100"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (types, constants, helpers)
2. Complete Phase 2: Foundational (name_lists.zig module)
3. Complete Phase 3: User Story 1 (spawn system + visual differentiation)
4. **STOP and VALIDATE**: `zig build run` — play waves 1–8, verify three zombie types
5. All three types visible, speeds correct, tints correct → MVP done

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (zombie types) → Play-test → Checkpoint (MVP!)
3. Add US2 (name variety + input) → Play-test → Checkpoint
4. Add US3 (anti-doublon) → Play-test → Checkpoint
5. Add US4 (trap clusters) → Play-test → Checkpoint
6. Add US5 (type-name coupling) → Play-test → Checkpoint
7. Polish → Final verification

### Parallel Execution Strategy

1. Complete Setup + Foundational phases sequentially
2. Once Foundational is done:
   - **Parallel track A**: US1 (spawn system rewrite in `src/main.zig`)
   - **Parallel track B**: US2 tests + US5 tests (in `src/name_lists.zig`)
3. After US1 complete: US3 and US4 (extend spawn system)
4. Polish phase last

---

## Notes

- All source changes are in two files: `src/main.zig` (extend) and `src/name_lists.zig` (create new)
- `src/zombie_names.zig` is preserved — its 49 names are included in PrimaryNames
- No new raylib calls, no new assets, no new dependencies
- Existing boss system (DEATHN-20) is untouched per ARD-9
- PRNG (`std.Random.DefaultPrng`) used for type/name selection; `raylib.GetRandomValue` stays for X-position
- All tests use deterministic PRNG seeds per constitution §Testing-5

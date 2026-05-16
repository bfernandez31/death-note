# Tasks: Wave Loop with Per-Wave Difficulty Table

**Input**: Design documents from `specs/DEATHN-19-wave-loop-with/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Included by default (constitution). All tests in `src/main.zig` (single-module game).

**Organization**: Tasks grouped by user story. All changes target `src/main.zig` — single file, so parallel opportunities within a phase are limited.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- All file paths are verified against the current repository state

---

## Phase 1: Foundational (Data Structures & State)

**Purpose**: Add the WaveConfig type, difficulty table, lookup function, and wave state variables that ALL user stories depend on. Remove replaced constants.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T001 Add `WaveConfig` struct after the `Zombie` struct (line 33) in `src/main.zig` with fields: `target_wpm: u32`, `spawn_delay: f32`, `fall_speed: f32`, `pool_size: u32`
- [ ] T002 Add `WAVE_TABLE` compile-time constant array of 15 `WaveConfig` entries (matching the difficulty table in spec.md) at module top in `src/main.zig`
- [ ] T003 Add `WAVE_TRANSITION_DURATION: f32 = 3.0` constant at module top in `src/main.zig`
- [ ] T004 Add `getWaveConfig(wave: u32) WaveConfig` function in `src/main.zig` — returns `WAVE_TABLE[wave - 1]` for waves 1–15, computes scaling formula (`target_wpm=110, spawn_delay=0.66, fall_speed=2.0, pool_size=33+2*(wave-15)`) for wave 16+
- [ ] T005 Add wave state module-level variables after `is_game_over` (line 22) in `src/main.zig`: `current_wave: u32 = 1`, `wave_kills: u32 = 0`, `wave_spawned: u32 = 0`, `is_transitioning: bool = false`, `transition_timer: f32 = 0.0`
- [ ] T006 Remove `const ZOMBIE_FALL_SPEED: f32 = 0.5` (line 12) and `const spawn_delay: f32 = 3.0` (line 19) from `src/main.zig` — these are replaced by per-wave lookups via `getWaveConfig()`

**Checkpoint**: Foundation ready — `zig build test` passes, all user stories can now proceed sequentially

---

## Phase 2: User Story 1 — Progressive Wave Gameplay (Priority: P1) 🎯 MVP

**Goal**: Player progresses through waves with increasing difficulty. Each wave has a finite zombie pool; completing all kills triggers a transition countdown before the next wave.

**Independent Test**: Start game, type all 5 wave-1 names, verify 3-second countdown appears, verify wave 2 spawns 7 zombies at faster settings.

### Tests for User Story 1
**NOTE: Write these tests FIRST, ensure they FAIL before implementation**
**RULE (constitution): Extend existing test blocks in `src/main.zig` — do not create new test files.**

- [ ] T007 [US1] Add test `"getWaveConfig returns correct values for wave 1"` in `src/main.zig` — verify target_wpm=15, spawn_delay=4.80, fall_speed=0.5, pool_size=5
- [ ] T008 [US1] Add test `"getWaveConfig returns correct values for wave 15"` in `src/main.zig` — verify target_wpm=100, spawn_delay=0.72, fall_speed=1.9, pool_size=33
- [ ] T009 [US1] Add test `"wave completes when kills equals pool size"` in `src/main.zig` — set wave_spawned and wave_kills to pool_size, verify completion condition evaluates to true

### Implementation for User Story 1

- [ ] T010 [US1] Parameterize zombie speed in `spawnZombie` (line 326): change `.speed = ZOMBIE_FALL_SPEED` to `.speed = getWaveConfig(current_wave).fall_speed` in `src/main.zig`
- [ ] T011 [US1] Parameterize spawn delay in frame function (line 99): change `spawn_timer >= spawn_delay` to `spawn_timer >= getWaveConfig(current_wave).spawn_delay` in `src/main.zig`
- [ ] T012 [US1] Gate spawning on pool_size: before the `spawnZombie` call (line 103), add condition `wave_spawned < getWaveConfig(current_wave).pool_size`. After successful spawn, increment `wave_spawned += 1` in `src/main.zig`
- [ ] T013 [US1] Track wave kills: in `updateZombies` after `zomb.is_active = false` (line 248), increment `wave_kills += 1` in `src/main.zig`
- [ ] T014 [US1] Add wave completion detection: after `updateZombies()` call (line 108), check if `wave_kills >= cfg.pool_size and wave_spawned >= cfg.pool_size`, then set `is_transitioning = true` and `transition_timer = WAVE_TRANSITION_DURATION` in `src/main.zig`
- [ ] T015 [US1] Add wave transition countdown logic in the `frame` function: if `is_transitioning`, decrement `transition_timer` by `GetFrameTime()`. When timer <= 0: increment `current_wave`, reset `wave_kills = 0`, `wave_spawned = 0`, `spawn_timer = 0.0`, set `is_transitioning = false`, call `resetZombies(ctx.allocator)` in `src/main.zig`
- [ ] T016 [US1] Add wave transition screen rendering in the draw phase of `src/main.zig`: when `is_transitioning`, draw "WAVE {n} — {wpm} WPM challenge — {countdown}..." centered on screen using `std.fmt.bufPrintZ` and `raylib.DrawText`

**Checkpoint**: Wave progression loop works — player can complete wave 1 and advance to wave 2 with correct difficulty parameters

---

## Phase 3: User Story 2 — HUD Displays Wave Progress (Priority: P1)

**Goal**: Centered HUD at top of screen shows wave number, target WPM, and kill progress (e.g., "WAVE 5 — 30 WPM — 7 / 13"), updating in real time.

**Independent Test**: During any wave, kill a zombie and verify HUD counter increments. Verify text is centered at y=10, font size 20, DARKGRAY.

### Implementation for User Story 2

- [ ] T017 [US2] Add HUD rendering after `ClearBackground` (line 114) and before textbox drawing in `src/main.zig`: format "WAVE {current_wave} — {target_wpm} WPM — {wave_kills} / {pool_size}" using `std.fmt.bufPrintZ` into a stack buffer, center horizontally with `raylib.MeasureText`, draw at y=10, font size 20, DARKGRAY color. HUD renders during both playing and transitioning states (not during game-over).

**Checkpoint**: HUD visible and updates in real time as zombies are killed

---

## Phase 4: User Story 4 — Wave Transition Freeze (Priority: P2)

**Goal**: During the 3-second countdown between waves, no zombies spawn, no existing zombies move, and input is ignored.

**Independent Test**: Complete wave 1, verify no zombies spawn or move during countdown, verify countdown decrements visually 3→2→1.

### Implementation for User Story 4

- [ ] T018 [US4] Gate the update phase in `frame` function: change `if (!is_game_over)` (line 75) to `if (!is_game_over and !is_transitioning)` in `src/main.zig` — this freezes input processing, spawning, and zombie movement during wave transition

**Checkpoint**: Gameplay freezes completely during wave transition countdown

---

## Phase 5: User Story 3 — Game Over with Wave Info (Priority: P2)

**Goal**: Game-over screen shows wave reached and required WPM. ENTER restarts from wave 1 with all state reset.

**Independent Test**: Let a zombie reach bottom during wave 3, verify game-over shows "Wave reached: 3" and "Required WPM: 22". Press ENTER, verify restart at wave 1.

### Implementation for User Story 3

- [ ] T019 [US3] Update game-over text in draw phase (lines 130-131) of `src/main.zig`: keep "GAME OVER" (40pt, RED, centered), add "Wave reached: {current_wave}" (20pt, GRAY) and "Required WPM: {target_wpm}" (20pt, GRAY) using `std.fmt.bufPrintZ`, keep "Press ENTER to Restart"
- [ ] T020 [US3] Reset wave state on restart (lines 134-141) in `src/main.zig`: after existing restart logic, add `current_wave = 1`, `wave_kills = 0`, `wave_spawned = 0`, `is_transitioning = false`, `transition_timer = 0.0`

**Checkpoint**: Game-over screen shows wave/WPM info, restart returns to wave 1 cleanly

---

## Phase 6: User Story 5 — Zombie Accumulation Under Pressure (Priority: P2)

**Goal**: If the player cannot type fast enough, zombies accumulate on screen. Game only ends when a zombie reaches the bottom — not when a spawn limit is reached.

**Independent Test**: Start a wave and don't type. Verify zombies keep spawning and falling until one reaches bottom and triggers game over.

### Implementation for User Story 5

- [ ] T021 [US5] Verify spawn gating logic in `src/main.zig` only checks `wave_spawned < pool_size` (wave pool limit) and the existing `zombies` slot array (MAX_ZOMBIES=100) — confirm there is no artificial cap on simultaneously active zombies. No code change expected; this is a verification task that the wave spawn gating from T012 does not inadvertently limit concurrent active zombies.

**Checkpoint**: Zombies accumulate freely when player doesn't type; game-over only triggers on ground contact

---

## Phase 7: User Story 6 — Endless Scaling Beyond Wave 15 (Priority: P3)

**Goal**: Waves 16+ use capped WPM/speed/delay (110 WPM, 0.66s delay, 2.0 speed) but increase pool_size by +2 per wave.

**Independent Test**: Reach wave 16, verify pool_size=35. Reach wave 17, verify pool_size=37. Verify spawn_delay and fall_speed remain at 0.66s and 2.0.

### Tests for User Story 6
**RULE (constitution): Extend existing test blocks in `src/main.zig`.**

- [ ] T022 [US6] Add test `"getWaveConfig scales correctly for wave 16+"` in `src/main.zig` — verify wave 16: target_wpm=110, spawn_delay=0.66, fall_speed=2.0, pool_size=35. Verify wave 20: pool_size=43. Verify wave 100: pool_size=203.

**Checkpoint**: Endless mode works correctly with scaling pool_size and capped parameters

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Build verification and manual integration testing

- [ ] T023 Verify `zig build test` passes with all new tests in `src/main.zig`
- [ ] T024 Verify `zig build` compiles cleanly (native target) with all changes in `src/main.zig`
- [ ] T025 Verify `zig build web` compiles cleanly (wasm32-emscripten target) — no regressions from wave changes in `src/main.zig`
- [ ] T026 Manual integration test per plan.md Phase 7 checklist: start game → complete wave 1 → verify transition → verify wave 2 parameters → let zombie reach bottom → verify game-over info → restart → verify wave 1

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies — start immediately. BLOCKS all user stories.
- **US1 (Phase 2)**: Depends on Phase 1. Core wave loop — most other stories build on this.
- **US2 (Phase 3)**: Depends on Phase 1 (needs `current_wave`, `wave_kills`). Can start after Phase 1, independent of US1 for HUD rendering, but kill counter updates depend on US1's `wave_kills` tracking (T013).
- **US4 (Phase 4)**: Depends on US1 (T015, T016) — transition state must exist before it can be gated. Single-line change.
- **US3 (Phase 5)**: Depends on Phase 1 (needs `current_wave`). Can start after Phase 1, but full testing requires US1.
- **US5 (Phase 6)**: Depends on US1 (T012) — verification that spawn gating works correctly.
- **US6 (Phase 7)**: Depends on Phase 1 (T004) — `getWaveConfig` already handles wave 16+. Test-only phase.
- **Polish (Phase 8)**: Depends on all phases complete.

### Recommended Execution Order

```
Phase 1 (Foundational)
    ↓
Phase 2 (US1 - Progressive Wave Gameplay) ← MVP
    ↓
Phase 3 (US2 - HUD) ← can partially overlap with US1 after T013
    ↓
Phase 4 (US4 - Transition Freeze) ← single task, depends on T015/T016
    ↓
Phase 5 (US3 - Game Over Info) ← depends on Phase 1, but test after US1
    ↓
Phase 6 (US5 - Accumulation) ← verification only, after T012
    ↓
Phase 7 (US6 - Endless Scaling) ← test only, after T004
    ↓
Phase 8 (Polish)
```

### Within Each User Story

1. Tests written FIRST, verified to FAIL before implementation
2. Implementation tasks in dependency order
3. Story checkpoint verified before moving to next

### Parallel Opportunities

Since all tasks modify `src/main.zig`, true file-level parallelism is not available. However:

- **T007, T008, T009** (US1 tests) can be written in a single batch — they're independent test blocks
- **T022** (US6 test) can be written alongside US1 tests — independent test block
- **US3 (T019-T020)** and **US6 (T022)** could proceed in parallel with US1 if managed carefully (non-overlapping regions of `src/main.zig`)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Foundational data structures
2. Complete Phase 2: US1 — Progressive Wave Gameplay
3. **STOP and VALIDATE**: `zig build test` + `zig build run` — verify wave 1→2 progression works
4. This delivers the core feature: wave-based progression with difficulty scaling

### Incremental Delivery

1. Phase 1 → Foundation ready
2. Phase 2 (US1) → Wave loop works → **MVP** 🎯
3. Phase 3 (US2) → Player sees progress → enhanced feedback
4. Phase 4 (US4) → Clean transitions → polished UX
5. Phase 5 (US3) → Informative game-over → complete feedback loop
6. Phase 6 (US5) → Verified pressure mechanics → confidence
7. Phase 7 (US6) → Endless mode tested → completeness
8. Phase 8 → Build verification → ship-ready

---

## Notes

- All 26 tasks target `src/main.zig` — no new files created (per constitution and plan)
- Existing tests at lines 348–433 remain unchanged and valid
- `std.fmt.bufPrintZ` produces null-terminated output suitable for `raylib.DrawText`
- `resetZombies` already handles full deallocation — reused at wave transition end
- The `FrameContext` struct is unchanged; wave state uses module-level globals (per research.md decision)

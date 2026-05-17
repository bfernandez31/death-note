# Tasks: Power-ups, Game Modes & Main Menu

**Branch**: `DEATHN-11-power-ups-modes` | **Generated**: 2026-05-17
**Spec**: `specs/DEATHN-11-power-ups-modes/spec.md`
**Plan**: `specs/DEATHN-11-power-ups-modes/plan.md`

## Task Summary

| Phase | Description | Task Count | Parallel Tasks |
|-------|-------------|------------|----------------|
| 1 | Setup | 3 | 2 |
| 2 | Foundational — GameScreen Refactor | 4 | 0 |
| 3 | US2 — Main Menu & Pause (P1) | 6 | 1 |
| 4 | US1 — Survival Mode with Power-ups (P1) | 12 | 5 |
| 5 | US3 — Zen Mode (P2) | 8 | 3 |
| 6 | US4 — Per-Mode High Scores (P2) | 8 | 3 |
| 7 | Polish & Cross-Cutting | 3 | 0 |
| **Total** | | **44** | **14** |

---

## Phase 1: Setup

- [X] T001 [P] Add `GameMode` enum (`survival`, `zen`) to `src/zombie_types.zig` after the `ZombieType` enum (~line 11)
- [X] T002 [P] Add `PowerUpType` enum (`freeze`, `bomb`, `shield`) and `pub const POWER_UP_DROP_CHANCE: u8 = 10` constant to `src/zombie_types.zig`
- [X] T003 Extend tests in `src/zombie_types.zig`: add test blocks for `PowerUpType` enum size (3 variants via `@typeInfo`), `GameMode` enum size (2 variants), and `POWER_UP_DROP_CHANCE == 10`

---

## Phase 2: Foundational — GameScreen Refactor

**Goal**: Replace `is_game_over` boolean with `GameScreen` enum to enable multi-screen routing. Blocking for all user stories.

- [ ] T004 Add `GameScreen` enum (`main_menu`, `wpm_select`, `playing`, `paused`, `game_over`) and module-level state variables (`current_screen: GameScreen = .main_menu`, `game_mode: zt.GameMode = .survival`, `menu_selection: u8 = 0`, `pause_selection: u8 = 0`) to `src/main.zig` (~line 188, before `Zombie` struct)
- [ ] T005 Replace all `is_game_over` references with `current_screen` equivalents throughout `src/main.zig`: `is_game_over = true` → `current_screen = .game_over`, `if (is_game_over)` → `if (current_screen == .game_over)`, `if (!is_game_over)` → `if (current_screen == .playing)`. Remove `is_game_over` declaration. Key locations: ~lines 287, 358, 365, 400, 440, 515. Update existing test blocks that reference `is_game_over`
- [ ] T006 Refactor `frame()` in `src/main.zig` to dispatch update and draw logic via `switch (current_screen)` — `.playing` runs existing gameplay update/draw, `.game_over` runs existing game-over draw, `.main_menu`/`.wpm_select`/`.paused` are initially stub blocks (filled in Phases 3-5). Ensure `drawCrtOverlay()` still runs unconditionally after the switch
- [ ] T007 Extend tests in `src/main.zig`: add test blocks for `GameScreen` enum having exactly 5 variants, and game state reset setting `current_screen = .playing`

---

## Phase 3: US2 — Main Menu & Pause (P1)

**Goal**: Implement main menu with Survival/Zen/Quit options and pause overlay with Resume/Quit to Menu.

**Independent Test**: Launch game → navigate menu → start Survival → pause with Escape → resume → quit to menu.

- [ ] T008 [US2] Implement `updateMenu()` function in `src/main.zig`: handle Up/Down arrow navigation with circular wrap (`menu_selection = (menu_selection + MENU_ITEM_COUNT - 1) % MENU_ITEM_COUNT` for Up, `(menu_selection + 1) % MENU_ITEM_COUNT` for Down), Enter to select. Add `const MENU_ITEMS = [_][]const u8{ "SURVIVAL", "ZEN", "QUIT" }` and `const MENU_ITEM_COUNT: u8 = 3`
- [ ] T009 [US2] Implement `drawMenu()` function in `src/main.zig`: draw game title using `CRT_FG`, menu items with `CRT_DIM` for unselected and `CRT_ACCENT` for selected item, best score display below menu. Wire both `updateMenu()` and `drawMenu()` into `frame()` switch arms for `current_screen == .main_menu`
- [ ] T010 [US2] Implement game start from menu selection in `src/main.zig`: index 0 ("Survival") → call `resetSessionState()`, `resetScoreState()`, `resetMetricsState()`, `resetZombies()`, `resetBoss()`, set `game_mode = .survival`, `current_screen = .playing`; index 1 ("Zen") → `current_screen = .wpm_select`; index 2 ("Quit") → `raylib.CloseWindow()` or equivalent
- [ ] T011 [P] [US2] Implement `updatePause()` and `drawPauseOverlay()` in `src/main.zig`: draw semi-transparent dark rectangle over frozen gameplay, "PAUSED" title in `CRT_FG`, "Resume"/"Quit to Menu" options with circular-wrap navigation (`pause_selection`, 2 items). Resume → `current_screen = .playing`. Quit → discard session (no high score save per FR-020), `current_screen = .main_menu`. Wire into `frame()` switch for `.paused`
- [ ] T012 [US2] Implement pause entry and game-over Escape in `src/main.zig` `frame()` update phase: when `current_screen == .playing` and `IsKeyPressed(KEY_ESCAPE)` → set `current_screen = .paused`, `pause_selection = 0`. When `current_screen == .game_over` and `IsKeyPressed(KEY_ESCAPE)` → `current_screen = .main_menu` (FR-021). Preserve existing Enter-to-retry on game-over
- [ ] T013 [US2] Extend tests in `src/main.zig`: add test blocks for menu selection circular wrap (`(0 -% 1 +% 3) % 3 == 2`, `(2 + 1) % 3 == 0`), pause selection wrap (`(0 -% 1 +% 2) % 2 == 1`), and verify pause does not modify game state (score, wave, kills values preserved)

---

## Phase 4: US1 — Survival Mode with Power-ups (P1)

**Goal**: Implement Freeze, Bomb, and Shield power-ups with carrier designation, single-slot inventory, and Space bar activation.

**Independent Test**: Play Survival → verify carrier icons on zombies → kill carrier → HUD shows power-up → press Space → observe effect.

- [ ] T014 [US1] Extend `Zombie` struct with `power_up: ?zt.PowerUpType = null` field in `src/main.zig` (~line 197, after `zombie_type` field)
- [ ] T015 [US1] Add power-up module-level state variables to `src/main.zig` (~line 186, with other state vars): `var held_power_up: ?zt.PowerUpType = null`, `var freeze_timer: f32 = 0.0`, `var shield_active: bool = false`, and `const FREEZE_DURATION: f32 = 3.0`
- [ ] T016 [US1] Implement power-up carrier designation in `spawnZombie()` in `src/main.zig` (~after line 791): if `game_mode == .survival`, roll `prng.random().intRangeAtMost(u8, 0, 99)` < `zt.POWER_UP_DROP_CHANCE`, then assign random type via `intRangeAtMost(u8, 0, 2)` mapped to `.freeze`/`.bomb`/`.shield`
- [ ] T017 [US1] Implement power-up pickup on zombie kill in `updateZombies()` in `src/main.zig` (~line 660): after kill confirmation and score award, check `zomb.power_up != null and held_power_up == null`, if true set `held_power_up = zomb.power_up` (FR-004: existing held → new drop lost)
- [ ] T018 [US1] Implement Space bar input interception in `src/main.zig` frame update (~line 291): before the `GetCharPressed()` loop, check `raylib.IsKeyPressed(raylib.KEY_SPACE)` — if `held_power_up != null`, activate power-up and consume (T019-T021 effects). If `held_power_up == null`, let space (ASCII 32) pass through to typing buffer as today. Ensure space is excluded from `GetCharPressed()` acceptance when consumed by power-up
- [ ] T019 [P] [US1] Implement Freeze effect in `src/main.zig`: on activation set `freeze_timer = FREEZE_DURATION`, clear `held_power_up`. In `updateZombies()` (~line 628): skip `zomb.y += zomb.speed` when `freeze_timer > 0`. In boss update (~line 858): skip `b.y += b.speed` when `freeze_timer > 0`. Decrement `freeze_timer -= raylib.GetFrameTime()` each frame, only when `current_screen == .playing`. Clamp to 0.0
- [ ] T020 [P] [US1] Implement Bomb effect in `src/main.zig`: on activation iterate `zombies` array, for each active standard-type zombie (`zombie_type == .standard`): award score via `calculateScore()`, increment `wave_kills`, destroy zombie (`allocator.destroy`, null slot). Boss is unaffected (FR-008). Clear `held_power_up`. Handle empty-screen case (no-op, power-up still consumed)
- [ ] T021 [P] [US1] Implement Shield effect in `src/main.zig`: on activation set `shield_active = true`, clear `held_power_up`. In `updateZombies()` at `y >= screen_height` check (~line 630): if `shield_active and game_mode == .survival`, destroy the triggering zombie, set `shield_active = false`, do NOT set `is_dying`. Shield is passive and single-use
- [ ] T022 [P] [US1] Implement power-up carrier visual in `drawZombies()` in `src/main.zig` (~line 720): if `zomb.power_up != null`, draw glyph above zombie name with pulsing alpha (`@sin(raylib.GetTime() * 4.0) * 0.3 + 0.7`): `"*"` in `CRT_ACCENT` for `.freeze`, `"!"` in `CRT_ERR` for `.bomb`, `"+"` in `CRT_WARN` for `.shield`
- [ ] T023 [P] [US1] Implement HUD power-up display in `src/main.zig` (~line 537, after existing HUD draws): if `held_power_up != null`, draw inventory label (`"[*] FREEZE"`, `"[!] BOMB"`, `"[+] SHIELD"`) using matching `CRT_*` color. If `freeze_timer > 0`, draw countdown timer. If `shield_active`, draw `"SHIELD ARMED"` indicator in `CRT_WARN`
- [ ] T024 [US1] Add power-up state reset to `resetSessionState()` in `src/main.zig` (~line 1041): set `held_power_up = null`, `freeze_timer = 0.0`, `shield_active = false`
- [ ] T025 [US1] Extend tests in `src/main.zig`: add test blocks for — Zombie struct default `power_up == null`, `FREEZE_DURATION == 3.0`, freeze timer decrement clamps to 0.0, shield state transition (`true` → `false`), Space with empty inventory (no state change), power-up pickup with full slot (`held_power_up` unchanged), carrier glyph mapping per `PowerUpType`

---

## Phase 5: US3 — Zen Mode (P2)

**Goal**: Implement Zen practice mode with WPM target selection, no game-over, constant spawn rate, and simplified HUD.

**Depends on**: Phase 3 (US2 — menu and pause system must exist)

**Independent Test**: Select Zen from menu → choose 50 WPM → type → verify no game-over on missed zombies → verify WPM/accuracy HUD → no power-ups or bosses.

- [ ] T026 [US3] Add Zen mode state variables and constants to `src/main.zig`: `var zen_wpm_selection: u8 = 0`, `var zen_target_wpm: u32 = 50`, and `const ZEN_WPM_TIERS = [_]u32{ 30, 50, 80 }`
- [ ] T027 [US3] Implement `updateWpmSelect()` and `drawWpmSelect()` in `src/main.zig`: title "SELECT WPM TARGET", three options with circular-wrap navigation over `ZEN_WPM_TIERS.len`. Enter → set `zen_target_wpm = ZEN_WPM_TIERS[zen_wpm_selection]`, `game_mode = .zen`, reset state, `current_screen = .playing`. Escape → `current_screen = .main_menu`. Wire into `frame()` switch for `.wpm_select`
- [ ] T028 [P] [US3] Implement Zen mode spawn configuration in `src/main.zig`: when `game_mode == .zen`, use `deriveWaveTiming(zen_target_wpm)` (existing function at ~line 824) instead of `getWaveConfig(current_wave)` for `spawn_delay` and `fall_speed`. No wave progression — constant spawn rate, no wave counter increment
- [ ] T029 [P] [US3] Implement Zen mode zombie-at-bottom behavior in `updateZombies()` in `src/main.zig` (~line 630): if `game_mode == .zen`, destroy zombie silently (`allocator.destroy(zomb)`, `slot.* = null`, continue) — do NOT set `is_dying` or trigger game-over (FR-025)
- [ ] T030 [P] [US3] Implement Zen mode HUD variant in `src/main.zig`: when `game_mode == .zen`, draw only current WPM, accuracy percentage, and target WPM reference. Hide score, combo counter, wave indicator, and power-up inventory slot (FR-026)
- [ ] T031 [US3] Suppress power-ups and boss spawns in Zen mode in `src/main.zig`: guard power-up carrier roll in `spawnZombie()` with `if (game_mode == .survival)` (FR-011), guard `spawnBoss()` call with `if (game_mode == .survival)` (FR-027)
- [ ] T032 [US3] Implement Zen session end in `src/main.zig`: when quitting to menu from pause and `game_mode == .zen`, compare session WPM/accuracy against `best_score_zen` — save via `highscore.save(.zen, ...)` if better (WPM first, accuracy tiebreaker)
- [ ] T033 [US3] Extend tests in `src/main.zig`: add test blocks for `ZEN_WPM_TIERS` having 3 entries with values 30/50/80, `deriveWaveTiming(50)` producing valid positive `spawn_delay` and `fall_speed`, Zen WPM selection circular wrap (`(0 -% 1 +% 3) % 3 == 2`)

---

## Phase 6: US4 — Per-Mode High Scores (P2)

**Goal**: Persist independent high scores for Survival and Zen modes on native and web platforms. Backward-compatible with existing `highscore.dat`.

**Depends on**: Phase 3 (US2 — menu for display), Phase 5 (US3 — zen mode for zen scores)

**Independent Test**: Play each mode → achieve scores → restart game → verify both high scores persist independently.

- [ ] T034 [US4] Import `GameMode` from `zombie_types.zig` in `src/highscore.zig` and add `fn filename(mode: GameMode) [*:0]const u8` — returns `"highscore.dat"` for `.survival` (backward-compatible FR-030), `"highscore-zen.dat"` for `.zen`
- [ ] T035 [US4] Add `fn webKey(mode: GameMode) []const u8` to `src/highscore.zig` — returns `"death-note.highscore"` for `.survival`, `"death-note.highscore.zen"` for `.zen`
- [ ] T036 [US4] Parameterize `pub fn load()` → `pub fn load(mode: GameMode)` and `pub fn save(record: Record)` → `pub fn save(mode: GameMode, record: Record)` in `src/highscore.zig`. Native path: pass `filename(mode)` to `std.c.fopen`. Web path: interpolate `webKey(mode)` into localStorage JS strings. Update existing test blocks that call `load()`/`save()` to pass a mode argument
- [ ] T037 [P] [US4] Update `src/main.zig` call sites: replace single `best_score` variable with `var best_score_survival: highscore.Record = .{}` and `var best_score_zen: highscore.Record = .{}`. Startup: `best_score_survival = highscore.load(.survival)`, `best_score_zen = highscore.load(.zen)`. Game-over save: `highscore.save(.survival, best_score_survival)`. Update all references to former `best_score`
- [ ] T038 [US4] Implement Zen high score comparison in `src/main.zig`: new best detected when `wpm > best_score_zen.wpm or (wpm == best_score_zen.wpm and accuracy > best_score_zen.accuracy)`. Wire into Zen session end (T032)
- [ ] T039 [US4] Update `drawMenu()` in `src/main.zig` to display high score for most recently played mode (FR-015): add `var last_played_mode: zt.GameMode = .survival` module-level variable, update on game start, read matching `best_score_*` in menu draw
- [ ] T040 [P] [US4] Extend tests in `src/highscore.zig`: add test blocks for `filename(.survival)` == `"highscore.dat"` (backward-compatible), `filename(.zen)` == `"highscore-zen.dat"`, `webKey(.survival)` == `"death-note.highscore"`, `webKey(.zen)` == `"death-note.highscore.zen"`, `DISK_SIZE` unchanged at 17 bytes
- [ ] T041 [P] [US4] Extend tests in `src/main.zig`: add test blocks for zen high score comparison logic (WPM-first, accuracy tiebreaker) and survival high score comparison unchanged

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T042 Verify freeze timer pauses when `current_screen == .paused` in `src/main.zig` — `freeze_timer` must NOT decrement during pause; remaining freeze time resumes on unpause
- [ ] T043 Verify edge cases in `src/main.zig`: Bomb on empty screen (consumed, no error), carrier zombie reaching bottom (power-up lost, not awarded), last wave zombie as carrier (wave completes normally)
- [ ] T044 Run `zig build test` to verify all new and existing tests pass, then `zig build` to verify native compilation succeeds with zero errors

---

## Dependency Graph

```
Phase 1 (Setup)
  └── Phase 2 (Foundational — GameScreen Refactor)
        └── Phase 3 (US2 — Main Menu & Pause)
              ├── Phase 4 (US1 — Power-ups)       ← independent of US3
              ├── Phase 5 (US3 — Zen Mode)         ← independent of US1
              │     └─┐
              └───────── Phase 6 (US4 — Per-Mode High Scores)
                          └── Phase 7 (Polish)
```

**Story completion order**: US2 (menu/pause) → US1 (power-ups) | US3 (zen) in parallel → US4 (high scores) → Polish

## Parallel Execution Opportunities

**Within Phase 1**: T001 + T002 — different enum sections of `src/zombie_types.zig`

**Within Phase 3 (US2)**: T011 (pause system) can run alongside T008–T010 (menu system) — non-overlapping functions

**Within Phase 4 (US1)**: T019 + T020 + T021 (freeze/bomb/shield effects) — independent activation behaviors. T022 + T023 (carrier visual + HUD display) — different draw functions

**Within Phase 5 (US3)**: T028 + T029 + T030 (spawn config, bottom behavior, HUD) — non-overlapping game subsystems

**Within Phase 6 (US4)**: T040 + T041 (highscore.zig tests + main.zig tests) — different files. T037 (main.zig updates) can run alongside T040 (highscore.zig tests)

**Cross-Phase**: Phase 4 (US1) and Phase 5 (US3) can execute in parallel after Phase 3 completes

## Implementation Strategy

**MVP — Phases 1–3** (Setup + Foundational + US2 Main Menu & Pause):
- Delivers `GameScreen` enum architecture and the menu/pause system
- Game is fully playable in Survival mode via menu navigation
- Foundation for all subsequent features
- Suggested first milestone

**Increment 2 — Phase 4** (US1 — Survival Mode with Power-ups):
- Adds the primary new gameplay mechanic
- Independently playtestable in Survival mode

**Increment 3 — Phases 5–6** (US3 Zen Mode + US4 Per-Mode High Scores):
- Adds secondary game mode and completes high score separation
- Can develop US3 and US1 in parallel if multiple implementers available
- US4 should follow US3 completion (needs zen mode for zen high scores)

**Final — Phase 7** (Polish):
- Edge case verification and full test suite validation
- `zig build test` + `zig build` green gate

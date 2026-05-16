# Implementation Plan: Wave System, Scoring and Difficulty Progression

**Branch**: `DEATHN-12-wave-system-scoring` | **Date**: 2026-05-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/DEATHN-12-wave-system-scoring/spec.md`

## Summary

Restructure the endless-spawn typing game into a wave-based system with numbered waves, boss fights every 5 waves, combo-based scoring with a 5× multiplier cap, live HUD stats (WPM over a 30-second rolling window, accuracy), inter-wave transition screens, difficulty scaling per wave (spawn delay, fall speed, max active zombies), and persistent high scores (file on native, localStorage on web). All gameplay logic stays in `src/main.zig` per constitution; the Zombie struct is extended with boss fields; a new `src/boss_phrases.zig` provides phrase data.

## Technical Context

**Language/Version**: Zig (toolchain pinned by the repo; no `.zig-version` file)
**Primary Dependencies**: raylib (commit `52f2a10`, pinned in `build.zig.zon` — unchanged)
**Storage**: File (`highscore.dat`) on native; `localStorage` on web — for high score only (see `contracts/high-score-persistence.md`)
**Testing**: Zig's built-in test runner via `zig build test`. New pure-logic tests in `src/main.zig`.
**Target Platform**: Native (Linux/macOS/Windows) + Web (wasm32-emscripten) — both existing targets preserved
**Project Type**: Single project — one Zig module tree
**Performance Goals**: 60 FPS with up to 30 simultaneously active zombies (SC-004)
**Constraints**: 800×450 window, HUD must not overlap play area or input box (FR-017), no new dependencies
**Scale/Scope**: ~300–400 lines of new Zig code in `src/main.zig`, ~15-line `src/boss_phrases.zig`, ~20 new tunables as named constants

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Constitution clause | Plan compliance | Status |
|---|---|---|---|
| G1 — Single-module game loop | §Code Patterns/1 | All gameplay logic stays in `src/main.zig`. New `src/boss_phrases.zig` is a data table `@import`-ed from main, mirroring `zombie_names.zig`. No abstraction layers. | PASS |
| G2 — C interop walled in `raylib.zig` | §Code Patterns/2 | No new `@cImport` calls. Emscripten JS eval functions already available via existing conditional include. | PASS |
| G3 — Named constants for tunables | §Code Patterns/3 | All 20+ new gameplay tunables declared as module-level `const` (see data-model.md §4). No magic numbers. | PASS |
| G4 — Paired `Init…`/`defer Close…` | §Code Patterns/4 | No new resource loads (textures, sounds). Boss uses existing sprite. High score file is opened and closed within the load/save functions (not held open). | PASS |
| G5 — Optional pointers via `if (x) \|val\|` | §Code Patterns/5 | Boss zombies share the existing `?*Zombie` pool. All zombie iteration patterns preserved. | PASS |
| G6 — Allocator threaded through parameters | §Code Patterns/6 | Boss allocation uses the same `allocator: *std.mem.Allocator` parameter in `spawnZombie`. New `resetGameState` calls existing `resetZombies(allocator)`. | PASS |
| G7 — Fixed-size pools | §Code Patterns/7 | Boss zombies live in the existing `zombies[MAX_ZOMBIES]` pool. WPM kill times use a fixed `[WPM_BUFFER_SIZE]f64` circular buffer. No dynamic lists. | PASS |
| G8 — Testing via `zig build test` | §Testing Standards/1-2 | New tests added as `test "…" {}` blocks in `src/main.zig`. No separate test file or framework. | PASS |
| G9 — No network, no secrets | §Security Practices/1 | High score persistence is local-only (file or localStorage). No network. File write is justified by FR-021 and explicitly called out. | PASS |
| G10 — Bounded input buffers | §Security Practices/2 | `MAX_INPUT_CHARS` increases from 9 to 40 for boss phrases. The same `key >= 32 and key <= 125 and letter_count < MAX_INPUT_CHARS` guard remains at the write site. | PASS |
| G11 — Null-terminated C-string safety | §Security Practices/3 | All name/phrase comparisons use `std.mem.eql` on slices computed by scanning to `'\x00'`. No raw pointer arithmetic. | PASS |
| G12 — Asset paths are literals | §Security Practices/4 | No new asset loads. `HIGHSCORE_FILE` is a compile-time literal. | PASS |
| G13 — Pinned dependency hash | §Security Practices/5 | `build.zig.zon` unchanged. | PASS |
| G14 — `zig build` is the gate | §Code Quality/1 | Feature compiles cleanly with `zig build`. All new code follows existing patterns. | PASS |
| G15 — Idiomatic error handling | §Code Quality/2 | File I/O for high scores uses `!T` returns and `catch` for graceful degradation (FR-022). No `catch unreachable`. | PASS |
| G16 — Naming discipline | §Code Quality/3 | `snake_case` for vars (`wave_timer`, `combo`), `SCREAMING_SNAKE_CASE` for consts (`BASE_KILL_SCORE`, `WPM_BUFFER_SIZE`), `camelCase` for functions (`comboMultiplier`, `waveSpawnDelay`), `PascalCase` for types (`BossPhrases`). | PASS |
| G17 — No unused code | §Code Quality/5 | No dead code introduced. All new globals are used by the game loop. | PASS |
| G18 — Commit/PR expectations | §Governance/2-3 | PR will describe all gameplay changes, include manual-test notes for rendering/input/audio, and note the `highscore.dat` file write. | PASS |
| G19 — Agent authority | §Governance/5 | No changes to raylib dependency, no network capabilities, no removal of `defer` cleanup. File write is the only new capability — justified by FR-021 and explicitly flagged. | PASS |

**Result**: All gates pass. No Complexity Tracking entries required.

### Post-Phase-1 Re-evaluation

After generating `research.md`, `data-model.md`, and `contracts/high-score-persistence.md`:

- G9 (no network): High score persistence is strictly local. The `emscripten_run_script` calls for localStorage do not make network requests. **Still passes.**
- G10 (bounded input): The 40-character buffer is still guarded at the write site. All boss phrases in the curated list are under 30 characters. **Still passes.**
- G12 (asset paths): `HIGHSCORE_FILE` is a compile-time constant string literal. **Still passes.**
- All other gates unchanged.

**Result**: All gates still pass. Proceed to `/ai-board.tasks`.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-12-wave-system-scoring/
├── plan.md                                # This file
├── research.md                            # Phase 0: unknowns resolved, existing files, patterns
├── data-model.md                          # Phase 1: entity catalog, state machine, constants
├── contracts/
│   └── high-score-persistence.md          # Phase 1: persistence contract (native + web)
├── checklists/                            # (pre-existing)
├── spec.md                                # (pre-existing)
└── tasks.md                               # Phase 2 output (/ai-board.tasks — not created by this command)
```

### Source Code (repository root)

```
repo root
├── build.zig                              # [UNCHANGED]
├── build.zig.zon                          # [UNCHANGED]
├── src/
│   ├── main.zig                           # [MODIFIED] Wave system, scoring, combo, stats, HUD,
│   │                                      #   game-over stats, high score persistence, boss spawning,
│   │                                      #   difficulty scaling, new tests
│   ├── raylib.zig                         # [UNCHANGED]
│   ├── zombie_names.zig                   # [UNCHANGED]
│   ├── boss_phrases.zig                   # [NEW] Curated boss phrase list (same pattern as zombie_names.zig)
│   └── web_root.zig                       # [UNCHANGED]
├── assets/                                # [UNCHANGED] No new assets
├── src/web/shell.html                     # [UNCHANGED]
└── .github/workflows/deploy-web.yml       # [UNCHANGED]
```

**Structure Decision**: Single-module layout preserved per constitution §Code Patterns/1. The only new file is `src/boss_phrases.zig` — a data table following the exact pattern of `src/zombie_names.zig`. All logic stays in `src/main.zig`. No new directories, no new build steps, no new assets.

## Implementation Phases

### Phase A — Data Foundation and Tunables

1. Create `src/boss_phrases.zig` with the curated phrase list (data-model.md §2.6).
2. In `src/main.zig`: declare all new constants (data-model.md §4) at the top of the file, grouped by concern.
3. Extend the `Zombie` struct with `is_boss: bool` and `phrase_progress: usize` (data-model.md §2.1).
4. Increase `MAX_INPUT_CHARS` from `9` to `40`. Update the input buffer declaration accordingly.
5. Add module-level state variables for wave, scoring, and stats (data-model.md §2.2–2.5).
6. Add `@import("boss_phrases.zig")` alongside the existing `ZombieNames` import.
7. Confirm `zig build` compiles cleanly (new state is declared but not yet wired into the game loop).

### Phase B — Pure Logic Functions and Tests

1. Implement pure functions (no side effects, no raylib calls):
   - `comboMultiplier(combo: u32) u32` — combo tier lookup
   - `waveSpawnDelay(wave: u32) f32` — exponential decay with floor
   - `waveFallSpeed(wave: u32) f32` — exponential growth with cap
   - `waveMaxActive(wave: u32) u32` — linear growth with cap
   - `waveKillTarget(wave: u32) u32` — linear growth with cap
   - `waveDuration(wave: u32) f32` — linear growth with cap
   - `cstrLen(name: [*:0]const u8) usize` — null-terminated string length
   - `calculateWpm(kill_times: []const f64, kill_count: usize, current_time: f64) u32` — WPM from circular buffer
   - `isValidPrefix(typed: []const u8, zombies_arr: [MAX_ZOMBIES]?*Zombie) bool` — prefix match against active zombies

2. Write `test "…" {}` blocks for each pure function:
   - `comboMultiplier` tier boundaries (0, 4, 5, 9, 10, 14, 15, 19, 20, 100)
   - `waveSpawnDelay` at waves 1, 5, 12, 20 (verify floor)
   - `waveFallSpeed` at waves 1, 5, 15, 20 (verify cap)
   - `waveMaxActive` at waves 1, 5, 13, 20 (verify cap at 30)
   - `waveKillTarget` and `waveDuration` boundary checks
   - `calculateWpm` with empty buffer, partial buffer, full window, expired entries
   - `isValidPrefix` with matching and non-matching prefixes

3. Run `zig build test` — all tests must pass before proceeding.

### Phase C — Wave Lifecycle

1. Modify `spawnZombie` to accept wave-derived parameters:
   - Fall speed from `waveFallSpeed(current_wave)`
   - Active zombie cap from `waveMaxActive(current_wave)` (count active zombies before spawning)
   - Spawn delay from `waveSpawnDelay(current_wave)` (replaces the hardcoded `spawn_delay` constant)

2. Add boss spawning logic:
   - When `current_wave % BOSS_WAVE_INTERVAL == 0` and `wave_kill_count >= waveKillTarget(current_wave)`, spawn a boss.
   - Boss uses a phrase from `BossPhrases` (random selection), `is_boss = true`, speed = normal speed × `BOSS_FALL_SPEED_FACTOR`.

3. Add wave completion detection in the update phase:
   - Kill target met (and boss dead if boss wave) → enter transition state.
   - Timer expired (and no boss alive) → clear remaining non-boss zombies, enter transition with no bonus.
   - Timer expired but boss alive → pause timer, continue wave.

4. Implement wave transition:
   - Set `is_wave_transitioning = true`, `wave_transition_timer = 0`.
   - During transition: advance `wave_transition_timer` by `GetFrameTime()`.
   - At `WAVE_TRANSITION_TOTAL_DURATION`: increment `current_wave`, reset `wave_kill_count`, `wave_timer`, `is_wave_transitioning = false`, clear remaining zombies.

5. Add the transition drawing:
   - First 5 seconds: recap screen showing wave number, kills, accuracy, WPM.
   - Last 3 seconds: countdown display ("3", "2", "1").

### Phase D — Scoring and Combo System

1. Wire combo tracking into `updateZombies`:
   - On zombie kill: increment `combo`, compute score delta = base points × `comboMultiplier(combo)`, add to `score`.
   - Increment `wave_kill_count` and `total_kills`.
   - Record kill timestamp in `wpm_kill_times` circular buffer.

2. Wire combo-breaking into the input handler:
   - After accepting a character, call `isValidPrefix` on the updated buffer against all active zombies.
   - If not a valid prefix → `combo = 0`, increment `total_keystrokes` but not `correct_keystrokes`.
   - If valid prefix → increment both `total_keystrokes` and `correct_keystrokes`.

3. Add wave-completion bonus:
   - When kill target is met before timer expires: `score += WAVE_COMPLETION_BONUS_PER_WAVE * current_wave`.

4. Boss kill scoring:
   - Boss kill awards `BOSS_KILL_SCORE × comboMultiplier(combo)` instead of `BASE_KILL_SCORE`.

### Phase E — Boss Phrase Progress and Input Matching

1. Modify `updateZombies` to handle boss phrase matching:
   - For boss zombies: check if the typed buffer matches the first `letter_count` characters of the phrase.
   - If full match (all characters typed) → kill boss, clear buffer, set `boss_alive = false`.
   - Update `phrase_progress` on each keystroke that extends the match.

2. Draw boss progress indicator:
   - Below the boss sprite, draw a progress bar showing `phrase_progress / phrase_length`.
   - Use `raylib.DrawRectangle` for background and filled portions.
   - Display the phrase text above the boss, with typed portion in one color and remaining in another.

### Phase F — HUD Display

1. Implement HUD drawing function `drawHud()`:
   - Top-left: `Wave: {current_wave}` 
   - Top-center: `Score: {score}` and `Best: {best_score}` (if loaded)
   - Top-right: `Combo: {combo} ({multiplier}x)` / `WPM: {wpm}` / `Accuracy: {accuracy}%`
   - Use `raylib.DrawText` with font size 16–18 to fit in the top 25px margin.

2. Call `drawHud()` after `drawZombies()` in the draw phase (always visible during gameplay, not during transition or game-over).

3. Calculate live WPM and accuracy each frame for display:
   - WPM via `calculateWpm(wpm_kill_times, wpm_kill_count, raylib.GetTime())`
   - Accuracy via `(correct_keystrokes * 100) / total_keystrokes` (or 100 if no keystrokes yet)

### Phase G — Game-Over Screen with Stats

1. Expand the game-over screen (currently just "GAME OVER" + "Press ENTER to Restart"):
   - Wave reached: `current_wave`
   - Final score: `score`
   - Best score: `best_score` (with "New High Score!" indicator if applicable)
   - Average WPM: calculated over entire session
   - Accuracy: `(correct_keystrokes * 100) / total_keystrokes`
   - Total kills: `total_kills`

2. On game over, check and persist high score:
   - If `score > best_score`: update `best_score`, attempt persist (file or localStorage).
   - Display "New High Score!" text.

3. On restart (Enter key), call `resetGameState(allocator)`:
   - Reset wave, score, combo, stats, timers.
   - Call existing `resetZombies(allocator)`.
   - Do NOT reset `best_score` or `best_score_loaded`.

### Phase H — High Score Persistence

1. Implement `loadHighScore() u64`:
   - Native: open `HIGHSCORE_FILE`, read 8 bytes, interpret as LE u64. On any error, return 0.
   - Web: `emscripten_run_script_int("...")`. On 0 or negative, return 0.
   - Gated by `comptime builtin.target.os.tag == .emscripten`.

2. Implement `saveHighScore(score: u64) void`:
   - Native: create/overwrite `HIGHSCORE_FILE`, write 8 bytes LE.
   - Web: `emscripten_run_script("localStorage.setItem(...)"}`.
   - Errors silently ignored (FR-022).

3. Call `loadHighScore()` once during startup (after raylib init, before game loop).
4. Call `saveHighScore(score)` in the game-over handler when `score > best_score`.

### Phase I — Integration and Polish

1. Wire the wave timer display into the HUD (progress bar or countdown text).
2. Ensure zombie clearing on wave timer expiry properly frees memory via the allocator.
3. Test the full flow: wave 1 → transition → wave 2 → ... → wave 5 boss → transition → wave 6.
4. Verify `zig build` and `zig build test` both pass cleanly.
5. Manual playtest: verify HUD readability, difficulty progression feel, boss encounter timing, high score persistence across restarts.

## Testing Strategy

Following constitution §Testing Standards and the existing-files inventory in research.md §2.4:

- **Unit tests** live in `src/main.zig` (the root test file) — new `test "…" {}` blocks for all pure logic:
  - Combo multiplier tier boundaries
  - Difficulty scaling formulas (spawn delay, fall speed, max active, kill target, wave duration)
  - WPM calculation (empty, partial, full, expired entries)
  - Prefix validation
  - C-string length helper
- **Existing tests preserved**: `T003` (name-match), `T004` (input-buffer bounds — updated for MAX_INPUT_CHARS=40), `T005` (frame-index wrap).
- **No integration or E2E harness** — the game has no automated GUI test (constitution §Testing Standards/4). Browser and native behavior verified manually.
- **Manual-test note requirement** (§Testing Standards/4, §Governance/3): PR description must include what was played, difficulty progression observed, boss encounter verified, HUD readable, high score persists.
- **Determinism**: All new tests use explicit values, no PRNG. Tests that need zombie state construct it directly rather than through `spawnZombie` (which calls `raylib.GetRandomValue`).

## Complexity Tracking

*(None — Constitution Check passed with no violations.)*

---

## Artifacts produced by Phases 0 and 1

| Path | Phase | Purpose |
|---|---|---|
| `specs/DEATHN-12-wave-system-scoring/research.md` | 0 | Decisions, existing-file inventory, patterns to follow |
| `specs/DEATHN-12-wave-system-scoring/data-model.md` | 1 | Entity catalog, state machine, constants |
| `specs/DEATHN-12-wave-system-scoring/contracts/high-score-persistence.md` | 1 | Persistence contract (native + web) |
| `CLAUDE.md` | 1 | Agent context refreshed via `update-agent-context.sh claude` |

## Next step

Run `/ai-board.tasks` to decompose Phases A–I into an ordered `tasks.md`.

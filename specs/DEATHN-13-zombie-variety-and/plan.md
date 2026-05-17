# Implementation Plan: DEATHN-13 — Zombie Variety and Name List Depth

**Branch**: `DEATHN-13-zombie-variety-and`
**Spec**: `specs/DEATHN-13-zombie-variety-and/spec.md`
**Created**: 2026-05-17

---

## Technical Context

| Aspect | Value |
|--------|-------|
| Language | Zig (system toolchain) |
| Build system | `zig build` (build.zig + build.zig.zon) |
| Graphics | raylib (pinned commit, static linkage) |
| Entry point | `src/main.zig` — single-module game loop |
| Test runner | `zig build test` — inline `test` blocks in source modules |
| Current zombie count | 49 names in `src/zombie_names.zig` |
| Current input limit | 9 chars (regular), 35 chars (boss) |
| Current zombie types | 1 (standard) + boss (separate entity) |
| Web target | wasm32-emscripten via `zig build web` |
| Dependencies added | None — pure Zig, no new packages |

## Constitution Check

| Constitution Rule | Status | Notes |
|---|---|---|
| §1 Single-module game loop | PASS | Core changes extend `src/main.zig` in place. New `src/name_lists.zig` is a data/utility module (like `zombie_names.zig`), not a second game loop |
| §2 C interop walled in raylib.zig | PASS | No new `@cImport` calls. All raylib access via existing `raylib.zig` |
| §3 Named constants for tunables | PASS | Six new constants: `RUNNER_SPEED_MULTIPLIER`, `TANK_SPEED_MULTIPLIER`, `RUNNER_MAX_NAME_LEN`, `TANK_MIN_NAME_LEN`, `MAX_SPAWN_RETRIES`, updated `MAX_INPUT_CHARS` |
| §4 Paired Init/defer Close | PASS | No new resource loads. Existing textures/sounds reused with tinting |
| §5 Optional pointer unwrap with if | PASS | All zombie slot access continues using `if (zombie) \|zomb\|` pattern |
| §6 Allocator passed by pointer | PASS | `spawnZombie` already takes `*std.mem.Allocator`; no change |
| §7 Fixed-size pools | PASS | `zombies[MAX_ZOMBIES]?*Zombie` unchanged. Name arrays are compile-time fixed-size |
| §Testing-1 Zig built-in test runner | PASS | All new tests are inline `test` blocks in source modules |
| §Testing-3 Pure logic coverage | PASS | Type selection, name filtering, anti-doublon, weight tables all testable |
| §Testing-5 Deterministic PRNG in tests | PASS | Introducing `std.Random.DefaultPrng` with explicit seed; tests seed deterministically |
| §Security-1 No secrets, no network | PASS | No network, no new file I/O |
| §Security-2 Bounded input buffers | PASS | Buffer remains 36 bytes; write gate raised to 20 (well within buffer) |
| §Security-3 Null-terminated C strings | PASS | All new names are `[*:0]const u8`, length computed by scanning to `'\x00'` |
| §Security-4 Asset paths are literals | PASS | No new asset loads |
| §Security-5 Pinned dependency hash | PASS | No dependency changes |
| §Agent-a No raylib dep change | PASS | |
| §Agent-b No network/fs-write | PASS | |
| §Agent-c No defer removal | PASS | |

**Gate evaluation**: All gates PASS. No violations.

---

## Implementation Phases

### Phase 1: Core Data Types and Constants

**Files**: `src/main.zig`
**Estimated scope**: ~40 lines added/changed

1. Add `ZombieType` enum (`standard`, `runner`, `tank`) after existing type declarations
2. Add `zombie_type: ZombieType` field to `Zombie` struct (default `.standard`)
3. Update `MAX_INPUT_CHARS` from 9 to 20
4. Add new constants at module top:
   - `RUNNER_SPEED_MULTIPLIER: f32 = 1.8`
   - `TANK_SPEED_MULTIPLIER: f32 = 0.5`
   - `RUNNER_MAX_NAME_LEN: usize = 5`
   - `TANK_MIN_NAME_LEN: usize = 8`
   - `MAX_SPAWN_RETRIES: u32 = 10`
5. Add `SpawnWeights` and `NameWeights` structs
6. Add `SPAWN_WEIGHT_TABLE` and `NAME_WEIGHT_TABLE` compile-time arrays
7. Add helper functions: `getSpeedMultiplier`, `getSpawnWeights`, `getNameWeights`, `selectZombieType`, `getZombieTint`
8. Add trap cluster state variables: `trap_cluster_group`, `trap_cluster_remaining`
9. Add `prng: std.Random.DefaultPrng` module-level variable, initialize in `main()`

**Verification**: `zig build` compiles cleanly. Existing tests pass (`zig build test`). Game runs unchanged (`zig build run`) — all zombies spawn as `.standard`.

**Depends on**: Nothing
**Blocks**: Phase 2, Phase 3

### Phase 2: Name Lists Module

**Files**: `src/name_lists.zig` (new), `src/main.zig` (import)
**Estimated scope**: ~500 lines (mostly name data)

1. Create `src/name_lists.zig` with:
   - `PrimaryNames`: 349+ first names as `[_][*:0]const u8` array
     - Include all 49 original names from `zombie_names.zig`
     - Add 300+ new ASCII-only first names
     - Ensure sufficient names ≤5 chars (for Runners) and ≥8 chars (for Tanks)
   - `CompoundNames`: 30+ hyphenated names (`"Jean-Pierre"`, `"Anne-Sophie"`, etc.)
     - Each ≤20 characters, ASCII + hyphen only
   - `TrapGroups`: 15+ groups of 3–5 visually similar names
     - e.g., `{ "Liam", "Lila", "Lina" }`, `{ "Sara", "Sera", "Sana" }`, `{ "Eric", "Erik", "Eris" }`
   - `TrapGroup` struct and `NameCategory` enum
   - `NameSelection` struct
   - `selectName` function (see `contracts/name-lists-module.md`)
   - `cstrLen` helper
2. Add `const name_lists = @import("name_lists.zig");` to `src/main.zig`
3. Add compile-time tests in `name_lists.zig`:
   - Primary list has ≥349 entries
   - All names are ASCII-only (bytes 32–125)
   - All compound names contain only [A-Za-z-]
   - All compound names ≤20 chars
   - Each trap group has 3–5 entries
   - Sufficient names exist for each length range
   - SpawnWeights and NameWeights sum to 100

**Verification**: `zig build test` passes all new compile-time validations. `zig build` compiles.

**Depends on**: Phase 1 (ZombieType enum)
**Blocks**: Phase 3

### Phase 3: Spawn System Integration

**Files**: `src/main.zig`
**Estimated scope**: ~80 lines changed

1. Rewrite `spawnZombie` to:
   - Accept `rng: *std.Random` parameter (or use module-level `prng`)
   - Select `ZombieType` via `selectZombieType(getSpawnWeights(current_wave), ...)`
   - Build `active_names` slice by scanning zombie slots
   - Call `name_lists.selectName(wave, type, active_names, forced_trap_group, rng)`
   - If selection is null, return false
   - If selection category is `.trap`, set trap cluster state
   - If `trap_cluster_remaining > 0`, decrement
   - Set `speed = fall_speed * getSpeedMultiplier(zombie_type)`
   - Set `zombie_type` on the new Zombie struct
2. Update `resetZombies` to clear trap cluster state
3. Update game restart block (line 392–406) to also clear trap cluster state
4. Update call site in `frame()` to pass PRNG if signature changes

**Verification**: `zig build run` — zombies spawn with varying types in later waves. Speed differences visible. Anti-doublon works (no duplicate names observed).

**Depends on**: Phase 1, Phase 2
**Blocks**: Phase 4

### Phase 4: Visual Differentiation

**Files**: `src/main.zig`
**Estimated scope**: ~20 lines changed

1. Update tint block in `drawZombies` (line 582–589):
   - Dying tint (RED) takes priority
   - Otherwise use `getZombieTint(zomb.zombie_type)`
2. Update text box width in `frame()` for 20-char input:
   - Change default width from 225 to ~500
   - Recenter: `.x = screen_width / 2.0 - 250.0`
   - Adjust boss mode width if needed (700 may be fine)
3. Verify that zombie name text (`DrawText` at line 606) renders correctly for longer names — may need position adjustment for compound names

**Verification**: `zig build run` — green Runners visible from wave 4, blue Tanks visible from wave 7+. Input box accommodates 20-char names. Dying tint still works.

**Depends on**: Phase 3
**Blocks**: Phase 5

### Phase 5: Hyphen Input Support

**Files**: `src/main.zig`
**Estimated scope**: ~0 lines changed (verification only)

1. Verify hyphen (ASCII 45) is already accepted by the key gate `(key >= 32) and (key <= 125)` — it is.
2. Verify `std.mem.eql` byte comparison matches hyphens correctly — it does (byte-for-byte).
3. Add a test that specifically validates hyphen acceptance and matching.

**Verification**: `zig build run` — type a compound name with hyphen, confirm it kills the correct zombie.

**Depends on**: Phase 4
**Blocks**: Phase 6

### Phase 6: Testing

**Files**: `src/main.zig`, `src/name_lists.zig`
**Estimated scope**: ~200 lines of test blocks

Tests in `src/main.zig`:
1. `test "ZombieType speed multipliers"` — verify getSpeedMultiplier returns correct values
2. `test "spawn weight table wave brackets"` — verify getSpawnWeights returns correct weights per wave range
3. `test "name weight table wave brackets"` — verify getNameWeights returns correct weights per wave range
4. `test "selectZombieType distribution"` — seed PRNG, verify type selection matches weight distribution over N iterations
5. `test "zombie tint colors"` — verify getZombieTint returns correct color per type
6. `test "input buffer accepts 20 characters"` — update existing T004 test for new MAX_INPUT_CHARS
7. `test "hyphen accepted in input"` — verify key 45 passes the gate and matches in name comparison
8. `test "trap cluster state reset"` — verify resetZombies clears trap state
9. `test "getCurrentMaxInput returns 20 without boss"` — update existing test

Tests in `src/name_lists.zig`:
1. `test "primary list size"` — PrimaryNames.len >= 349
2. `test "all names ASCII"` — scan every name for bytes in [32, 125]
3. `test "compound names valid"` — each ≤20 chars, only [A-Za-z-]
4. `test "trap group sizes"` — each has 3–5 entries
5. `test "sufficient runner names"` — count names ≤5 chars ≥ 30
6. `test "sufficient tank names"` — count names ≥8 chars ≥ 30
7. `test "selectName anti-doublon"` — pass all active names, verify null returned
8. `test "selectName length filtering"` — Runner gets ≤5, Tank gets ≥8
9. `test "selectName trap group preference"` — forced_trap_group returns name from that group
10. `test "weight tables sum to 100"` — compile-time validation

**Verification**: `zig build test` — all tests pass.

**Depends on**: Phases 1–5
**Blocks**: Nothing

---

## Testing Strategy

Per constitution §Testing:

- **Framework**: Zig built-in test runner (`zig build test`)
- **Location**: `test` blocks in the module under test
- **Existing test file**: `src/main.zig` (lines 1017–1645, 30+ existing tests) — extend with new tests
- **New test file**: `src/name_lists.zig` — compile-time validations and selectName logic tests
- **Determinism**: All tests using randomness seed `std.Random.DefaultPrng` explicitly (§Testing-5)
- **Manual testing**: After each phase, run `zig build run` and play through waves 1–8 to verify:
  - Visual tints appear correctly
  - Speed differences are noticeable
  - Name variety increases
  - Compound names with hyphens work
  - No duplicate names on screen
  - Input box accommodates longer names
- **Existing test updates**: Test "input buffer bounds" (T004) and "getCurrentMaxInput returns correct limits" need MAX_INPUT_CHARS value updates from 9 to 20

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Name list has insufficient short/long names | Low | Medium | Compile-time test enforces minimums; catch at build time |
| PRNG introduction breaks existing behavior | Low | High | PRNG only used for type/name selection; X-position stays with raylib.GetRandomValue |
| Text box too small for 20-char names | Medium | Low | Adjust width constant in Phase 4; visual verification |
| Trap clusters cause spawn bursts | Low | Medium | Cluster is 1–2 extras max; anti-doublon prevents duplicates; pool_size cap unchanged |
| Web build regression | Low | High | No new dependencies, no new C imports; test with `zig build web` after completion |

---

## Generated Artifacts

| Artifact | Path |
|----------|------|
| Feature Spec | `specs/DEATHN-13-zombie-variety-and/spec.md` |
| Research | `specs/DEATHN-13-zombie-variety-and/research.md` |
| Data Model | `specs/DEATHN-13-zombie-variety-and/data-model.md` |
| Contracts | `specs/DEATHN-13-zombie-variety-and/contracts/name-lists-module.md` |
| Contracts | `specs/DEATHN-13-zombie-variety-and/contracts/spawn-system.md` |
| Implementation Plan | `specs/DEATHN-13-zombie-variety-and/plan.md` (this file) |

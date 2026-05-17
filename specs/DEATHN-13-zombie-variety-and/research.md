# Research: DEATHN-13 — Zombie Variety and Name List Depth

## Technical Unknowns Resolved

### U-1: How to visually differentiate zombie types via color tinting

- **Decision**: Use `raylib.Color` tint parameter already passed to `DrawTexturePro` in `drawZombies()` (src/main.zig:590). Currently only `raylib.WHITE` (no tint) and `raylib.RED` (dying) are used. Runner gets green (`raylib.GREEN`), Tank gets blue (`raylib.BLUE`).
- **Rationale**: `DrawTexturePro` already accepts a tint color — no new rendering API needed. The tint multiplies the sprite's pixel colors, so GREEN and BLUE produce visibly distinct results on the existing spritesheet.
- **Alternatives considered**: Separate spritesheets per type (asset overhead), size scaling (conflicts with BOSS_SCALE). Tinting is zero-asset-cost.

### U-2: How to store zombie type on the Zombie struct

- **Decision**: Add a `zombie_type: ZombieType` field to the `Zombie` struct where `ZombieType` is an enum `{ standard, runner, tank }`. This drives tint color, speed multiplier, and name-length filtering at spawn time.
- **Rationale**: A single enum field is the simplest way to carry type identity through spawn → update → draw. Avoids parallel arrays or tagged unions.
- **Alternatives considered**: Separate struct per type (over-engineered for 3 types sharing identical fields), boolean flags (doesn't scale, harder to read).

### U-3: How to implement wave-based spawn weighting

- **Decision**: Define a `SpawnWeights` struct with `standard`, `runner`, `tank` fields (each `u8`, summing to 100). Create a compile-time `SPAWN_WEIGHT_TABLE` indexed by wave bracket. At spawn time, generate a random 0–99 value and select type by cumulative weight.
- **Rationale**: Mirrors the existing `WAVE_TABLE` pattern — compile-time data, runtime lookup. Probability-based selection matches spec ARD-5.
- **Alternatives considered**: Float probabilities (unnecessary precision), per-wave individual entries (too many entries for waves 11+).

### U-4: How to implement name list categorization and wave-weighted selection

- **Decision**: Create a new `src/name_lists.zig` module containing three arrays: `PrimaryNames` (349+ entries), `CompoundNames` (hyphenated), and `TrapNames` (grouped by similarity). Each array uses the same `[*:0]const u8` type as existing `ZombieNames`. A `selectName` function takes wave number, zombie type, active zombie names, and PRNG → returns a name.
- **Rationale**: Keeps `zombie_names.zig` as-is for backward compatibility during development. New module is cleanly importable from `main.zig` following the same pattern as `zombie_names.zig`.
- **Alternatives considered**: Extending `zombie_names.zig` in-place (messy with 300+ names + grouping metadata), JSON config (no JSON parser in project, Zig comptime arrays are idiomatic).

### U-5: How to implement anti-doublon (no duplicate names on screen)

- **Decision**: Before assigning a name in `spawnZombie`, scan all active zombie slots (`zombies[0..MAX_ZOMBIES]`) and the boss for matching names. Retry up to 10 times with a new random pick. If all retries collide, return `false` (spawn deferred).
- **Rationale**: The existing `zombies` array is small (100 slots) and already iterated every frame in `updateZombies` and `drawZombies`. A linear scan per spawn is negligible cost.
- **Alternatives considered**: Hash set of active names (overhead not justified for ≤100 entries), bloom filter (false positives unacceptable).

### U-6: How to implement trap name cluster spawning

- **Decision**: Add module-level state: `trap_cluster_group: ?usize` (index of active trap group) and `trap_cluster_remaining: u8` (0–2 pending cluster spawns). When a trap-list name is selected, set these. On subsequent spawns within 2 cycles, if `trap_cluster_remaining > 0`, preferentially pick from the same trap group (subject to anti-doublon).
- **Rationale**: Minimal state addition following the existing module-level global pattern. The "next 2 spawn cycles" window is naturally tracked by decrementing on each spawn attempt.
- **Alternatives considered**: Timer-based clusters (spawn_delay varies by wave, making timing unpredictable), queue-based (over-engineered for 1–2 extras).

### U-7: Input buffer size change from 9 to 20

- **Decision**: Change `MAX_INPUT_CHARS` from 9 to 20. The actual `name` buffer is already sized to `MAX_BOSS_INPUT_CHARS + 1` (36 bytes) at line 89, so no buffer reallocation needed. Only the write gate in `getCurrentMaxInput()` changes behavior.
- **Rationale**: The buffer is already large enough. The change is a single constant update plus updating `getCurrentMaxInput` to return 20 instead of 9 when no boss is active.
- **Alternatives considered**: Dynamic buffer sizing per zombie type (unnecessary complexity — 20 accommodates all compound names with margin).

## Existing Files

| Path | Purpose | Action |
|------|---------|--------|
| `src/main.zig` | Game loop, all gameplay logic, Zombie struct, spawn/update/draw functions | **Extend**: add ZombieType enum, modify Zombie struct, update spawnZombie/drawZombies/updateZombies, change MAX_INPUT_CHARS, add spawn weight logic |
| `src/zombie_names.zig` | 49 zombie names as `[*:0]const u8` array | **Keep as-is**: will be superseded by name_lists.zig import but preserved for reference |
| `src/raylib.zig` | C interop wrapper for raylib | **No change**: already exposes all needed raylib functions including DrawTexturePro tint |
| `src/boss_phrases.zig` | Boss phrase strings | **No change**: boss system unchanged per ARD-9 |
| `src/web_root.zig` | Emscripten entry point | **No change**: delegates to main.zig |
| `build.zig` | Build configuration | **No change**: new .zig files auto-discovered when @imported from main.zig |
| `build.zig.zon` | Package manifest | **No change**: no new dependencies |
| `assets/z_spritesheet.png` | Zombie spritesheet (17 frames) | **No change**: tinting reuses existing sprite |

### New files to create

| Path | Purpose | Justification |
|------|---------|---------------|
| `src/name_lists.zig` | Primary (349+), compound, and trap name arrays + selection logic | Too large for inline in main.zig; follows zombie_names.zig module pattern |

### Test files

All existing tests are inline `test` blocks in `src/main.zig` (lines 1017–1645). Per constitution, new tests go as `test` blocks in the module under test:
- `src/main.zig` for spawn weighting, type selection, anti-doublon, input buffer changes
- `src/name_lists.zig` for name list completeness, length filtering, trap group integrity

## Patterns to Follow

### P-1: Zombie spawn pattern (src/main.zig:613–637)

```
spawnZombie(allocator) → find null slot → allocator.create(Zombie) → errdefer destroy → 
fill struct fields → assign to slot → return true
```
**Error handling**: `try allocator.create()` with `errdefer allocator.destroy()`. Returns `!bool`.
**Must follow**: New spawn logic must preserve `errdefer` cleanup and `!bool` return convention.

### P-2: Color tint in drawZombies (src/main.zig:582–589)

```zig
const tint: raylib.Color = blk: {
    if (is_dying) {
        if (dying_zombie_index) |idx| {
            if (idx == i) break :blk raylib.RED;
        }
    }
    break :blk raylib.WHITE;
};
```
**Must follow**: Extend this block to check `zomb.zombie_type` and return the appropriate color. Dying tint takes priority over type tint.

### P-3: Module-level constants for tunables (src/main.zig:11–58)

All gameplay constants are `const` declarations at module top. New tunables (`RUNNER_SPEED_MULTIPLIER`, `TANK_SPEED_MULTIPLIER`, `RUNNER_MAX_NAME_LEN`, `TANK_MIN_NAME_LEN`, `MAX_SPAWN_RETRIES`) must follow this pattern.

### P-4: Name import pattern (src/main.zig:6–7)

```zig
const ZombieNames = @import("zombie_names.zig").ZombieNames;
const BossPhrases = @import("boss_phrases.zig").BossPhrases;
```
**Must follow**: `const NameLists = @import("name_lists.zig");` at the top, then reference `NameLists.PrimaryNames`, etc.

### P-5: Optional pointer unwrap (constitution rule 5)

```zig
if (zombie) |zomb| { ... }  // NOT zombie.?
```
All zombie slot access uses this pattern. New code that reads zombie slots must do the same.

### P-6: Allocator passed by pointer (constitution rule 6)

```zig
fn spawnZombie(allocator: *std.mem.Allocator) !bool { ... }
```
Any new function that allocates must take `allocator: *std.mem.Allocator` as parameter.

### P-7: C-string length computation (src/main.zig:528–531)

```zig
var zomb_name_length: usize = 0;
while (zomb.name[zomb_name_length] != '\x00') {
    zomb_name_length += 1;
}
```
Used whenever comparing typed input to zombie names. The anti-doublon check will need this same pattern to compare active names.

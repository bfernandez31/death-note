# Research: Boss Zombie Every Five Waves

**Branch**: `DEATHN-20-boss-zombie-every` | **Date**: 2026-05-16

## Existing Files

| Path | Covers | Action |
|------|--------|--------|
| `src/main.zig` | Game loop, zombie lifecycle, input handling, rendering, all gameplay state | Extend: add boss state, boss spawn/update/draw, input buffer changes, wave completion gate |
| `src/zombie_names.zig` | Flat array of 49 zero-terminated C strings for regular zombie names | Reuse as-is (pattern reference for new boss phrases file) |
| `src/raylib.zig` | `@cImport` wrapper for raylib headers | No changes needed |
| `src/web_root.zig` | Emscripten entry point, imports `main.zig` | No changes needed (transitively picks up main.zig changes) |
| `build.zig` | Build graph, test step, web step | No changes needed |
| `assets/z_spritesheet.png` | Zombie sprite sheet (17 frames) | Reuse as-is (boss uses same sprite, different scale + tint) |
| `assets/zombie-hit.wav` | Kill sound effect | Reuse as-is (boss uses same sound on kill) |

### New files needed

| Path | Purpose | Justification |
|------|---------|---------------|
| `src/boss_phrases.zig` | Flat array of 10 zero-terminated C strings for boss phrases | Mirrors `zombie_names.zig` pattern; keeps phrase data separate from gameplay logic per constitution rule 1 (sibling module imported from main.zig) |

### Test files

All tests live in `src/main.zig` as top-level `test` blocks (7 existing). New boss-related tests will be added there. No separate test files exist or are needed per Zig convention and the existing build.zig test step configuration.

## Patterns to Follow

### 1. Entity data pattern (from `zombie_names.zig`)

`src/zombie_names.zig:1` — compile-time array of zero-terminated C strings:
```zig
pub const ZombieNames = [_][*:0]const u8{ "Aaron", "Abby", ... };
```
Boss phrases file must follow this exact pattern: `pub const BossPhrases = [_][*:0]const u8{ ... };`

### 2. Spawn pattern (from `src/main.zig:395-419`)

`spawnZombie` allocates from `page_allocator`, uses `errdefer allocator.destroy(...)`, fills struct fields, stores in a slot. Boss spawn must follow the same allocate → errdefer → fill → store sequence but target a single `?*Zombie` instead of the slot array.

### 3. Update/kill pattern (from `src/main.zig:302-339`)

`updateZombies` iterates slots, advances `y`, checks bottom-of-screen game-over, then checks name match via `std.mem.eql(u8, typed, zomb_name_slice)`. On match: `allocator.destroy`, null the slot, clear input, increment `wave_kills`, play sound. Boss update must follow the same structure but with prefix-based progress checking instead of exact match.

### 4. Draw pattern (from `src/main.zig:341-391`)

`drawZombies` computes frame rectangle from spritesheet, uses `DrawTexturePro` with scale 0.2 and `raylib.WHITE` tint. Boss draw reuses the same animation logic but with scale 0.4 and `raylib.RED` tint. Name is drawn via `DrawText` at `(pos.x, pos.y - 20)` with font size 20 and `DARKGREEN`. Boss phrase uses font size 20 and dark red color.

### 5. Reset/cleanup pattern (from `src/main.zig:438-445`)

`resetZombies` iterates all slots, frees non-null pointers, nulls slots. Boss cleanup follows the same pattern for the single boss pointer. Must be called alongside `resetZombies` in wave transitions and game restart.

### 6. Module-level state pattern (from `src/main.zig:40-51`)

All gameplay state is declared as module-level `var` with explicit types. Boss state must follow: `var boss: ?*Zombie = null;`, `var boss_spawned_this_wave: bool = false;`, etc.

### 7. Resource lifecycle pattern (from `src/main.zig:265-269`)

Every `Load...` has a matching `defer Unload...`. No new resources are loaded for this feature (reuses existing texture and sound), so no new cleanup needed.

## Technical Decisions

### D1: Boss as separate pointer vs. zombie pool slot

- **Decision**: Store boss as a separate `var boss: ?*Zombie = null` outside the zombie slot array.
- **Rationale**: The boss is a singleton (FR-016: no more than one boss at any time). Using a pool slot would waste a slot and complicate priority logic. A dedicated pointer makes boss-specific code paths (draw with different scale/tint, health bar, priority matching) cleaner.
- **Alternatives considered**: Tagging a zombie in the slot array with an `is_boss: bool` field — rejected because it adds a field to every zombie and requires filtering the array for boss-specific logic.

### D2: Input buffer sizing

- **Decision**: Increase the static `name` buffer from `MAX_INPUT_CHARS + 1` (10 bytes) to `MAX_BOSS_INPUT_CHARS + 1` (36 bytes). Use a runtime function `getCurrentMaxInput()` to gate character acceptance at 9 or 35 depending on boss state.
- **Rationale**: The buffer must hold 35 characters during boss encounters (FR-009). A single larger buffer with a dynamic limit is simpler than swapping buffers.
- **Alternatives considered**: Two separate buffers (one for normal, one for boss) — rejected because input handling code would need to switch between them, increasing complexity for no benefit.

### D3: Boss phrase matching strategy

- **Decision**: While boss is active, check if the input buffer is a valid prefix of the boss phrase. When `letter_count == boss_phrase_len`, the boss is killed. Regular zombie matching is suppressed while the boss is active and the input is a valid boss phrase prefix (FR-010).
- **Rationale**: This preserves the existing character-by-character input model and naturally integrates with the health bar (fill = remaining / total).
- **Alternatives considered**: Matching individual words of the phrase separately — rejected because the spec explicitly says the player types the full phrase including spaces.

### D4: Boss spawn timing

- **Decision**: Check boss spawn condition in `frame()` after `updateZombies()` returns, when `current_wave % 5 == 0` and `wave_kills >= ceil(pool_size / 2)` and `!boss_spawned_this_wave`.
- **Rationale**: Checking after `updateZombies` ensures the kill that triggers the boss is fully processed. `ceil(pool_size / 2)` is computed as `(pool_size + 1) / 2` using integer arithmetic.
- **Alternatives considered**: Checking inside `updateZombies` at the kill site — rejected because it mixes spawn logic with update logic and complicates the control flow.

### D5: Boss phrase storage

- **Decision**: Create `src/boss_phrases.zig` with `pub const BossPhrases` as a `[10][*:0]const u8` array, imported from `main.zig`.
- **Rationale**: Mirrors the existing `zombie_names.zig` pattern per constitution rule 1 (sibling module).
- **Alternatives considered**: Inline the phrases in `main.zig` — rejected because it departs from the established pattern of separating name/phrase data into dedicated modules.

# Contract: src/name_lists.zig Module Interface

## Overview

New module providing categorized name arrays and a name selection function. Consumed by `src/main.zig` via `@import("name_lists.zig")`.

## Exported Symbols

### Arrays

```zig
pub const PrimaryNames: [N][*:0]const u8
```
- At least 349 entries (49 original + 300 new)
- ASCII-only, no accented characters
- No hyphens (simple first names only)
- Mix of lengths: sufficient names ≤5 chars for Runners, ≥8 chars for Tanks

```zig
pub const CompoundNames: [M][*:0]const u8
```
- Hyphenated names (e.g., "Jean-Pierre", "Anne-Sophie")
- Each name ≤ 20 characters
- ASCII + hyphen only

```zig
pub const TrapGroups: [G]TrapGroup
```
- Each group: 3–5 visually similar names (differ by 1–2 characters)
- Names in trap groups are also valid spawnable names
- Flat array `TrapNames` derived from groups for random access

### Types

```zig
pub const TrapGroup = struct {
    names: []const [*:0]const u8,
};

pub const NameCategory = enum {
    primary,
    compound,
    trap,
};

pub const NameSelection = struct {
    name: [*:0]const u8,
    category: NameCategory,
    trap_group_index: ?usize,  // non-null when category == .trap
};
```

### Functions

```zig
pub fn selectName(
    wave: u32,
    zombie_type: ZombieType,
    active_names: []const [*:0]const u8,
    forced_trap_group: ?usize,
    rng: *std.Random,
) ?NameSelection
```

**Parameters**:
- `wave`: Current wave number (determines name list weights)
- `zombie_type`: Determines eligible name length range
- `active_names`: Slice of currently active zombie names for anti-doublon check
- `forced_trap_group`: If non-null, preferentially select from this trap group (for cluster spawning)
- `rng`: Seeded PRNG (not `raylib.GetRandomValue` — testable)

**Returns**: `?NameSelection` — null if no eligible name found after MAX_SPAWN_RETRIES attempts.

**Behavior**:
1. Select name category based on wave weights (NAME_WEIGHT_TABLE)
2. If `forced_trap_group` is set and category allows, override to trap group
3. Filter names by zombie_type length constraint (Runner ≤5, Tank ≥8, Standard any)
4. Pick random name from filtered pool
5. Check against `active_names` for doublon — retry up to MAX_SPAWN_RETRIES times
6. Return selection with category and trap group metadata

### Helper

```zig
pub fn cstrLen(s: [*:0]const u8) usize
```
Compute length of null-terminated C string. Factored out since this pattern is used in multiple places.

## Invariants

- All names are null-terminated (`[*:0]const u8`)
- All names contain only bytes in range [32, 125] (printable ASCII)
- Compound names contain only [A-Za-z] and hyphen (45)
- No name exceeds 20 characters (excluding null terminator)
- PrimaryNames includes the original 49 names from zombie_names.zig
- Each TrapGroup has 3–5 entries
- TrapGroup names also appear in the searchable pool (not separate)

## Usage from main.zig

```zig
const name_lists = @import("name_lists.zig");

// In spawnZombie:
var active_buf: [MAX_ZOMBIES][*:0]const u8 = undefined;
var active_count: usize = 0;
for (zombies) |slot| {
    if (slot) |z| {
        if (z.is_active) {
            active_buf[active_count] = z.name;
            active_count += 1;
        }
    }
}
const selection = name_lists.selectName(
    current_wave, zombie_type, active_buf[0..active_count],
    if (trap_cluster_remaining > 0) trap_cluster_group else null,
    &prng,
) orelse return false;
```

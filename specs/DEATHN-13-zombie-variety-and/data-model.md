# Data Model: DEATHN-13 — Zombie Variety and Name List Depth

## 1. New Types

### 1.1 ZombieType (enum)

```zig
const ZombieType = enum {
    standard,
    runner,
    tank,
};
```

**Purpose**: Categorizes each zombie for visual tinting, speed multiplier, and name-length filtering.

| Type | Tint Color | Speed Multiplier | Name Length | Introduced |
|------|-----------|-------------------|-------------|------------|
| standard | `raylib.WHITE` | 1.0x | Any | Wave 1 |
| runner | `raylib.GREEN` | 1.8x | ≤5 chars | Wave 4 |
| tank | `raylib.BLUE` | 0.5x | ≥8 chars | Wave 4 |

### 1.2 NameCategory (enum)

```zig
const NameCategory = enum {
    primary,
    compound,
    trap,
};
```

**Purpose**: Tags which name list a name was drawn from. Used for trap cluster triggering.

### 1.3 SpawnWeights (struct)

```zig
const SpawnWeights = struct {
    standard: u8,
    runner: u8,
    tank: u8,
};
```

**Constraint**: Fields must sum to 100.

### 1.4 NameWeights (struct)

```zig
const NameWeights = struct {
    primary: u8,
    trap: u8,
    compound: u8,
};
```

**Constraint**: Fields must sum to 100.

### 1.5 TrapGroup (struct concept)

```zig
// In name_lists.zig — a group of visually similar names
const TrapGroup = struct {
    names: []const [*:0]const u8,
};
```

**Purpose**: Each group contains 3–5 names differing by 1–2 characters. When one is selected for spawning, the system attempts to spawn others from the same group.

## 2. Modified Types

### 2.1 Zombie (struct) — MODIFIED

```zig
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    zombie_type: ZombieType,     // NEW — determines tint + speed multiplier
};
```

**Changes**:
- Added `zombie_type` field (default: `.standard`)
- `speed` is now set to `wave_fall_speed * type_multiplier` at spawn time

**Backward compatibility**: All existing code that reads Zombie fields continues to work. The new field is only read in `drawZombies` (for tint) and set in `spawnZombie`.

## 3. New Constants

```zig
const RUNNER_SPEED_MULTIPLIER: f32 = 1.8;
const TANK_SPEED_MULTIPLIER: f32 = 0.5;
const RUNNER_MAX_NAME_LEN: usize = 5;
const TANK_MIN_NAME_LEN: usize = 8;
const MAX_SPAWN_RETRIES: u32 = 10;
const MAX_INPUT_CHARS = 20;  // Changed from 9
```

### 3.1 Spawn Weight Table (compile-time)

```zig
const SPAWN_WEIGHT_TABLE = [_]SpawnWeights{
    .{ .standard = 100, .runner = 0,  .tank = 0  },  // Waves 1-3
    .{ .standard = 70,  .runner = 20, .tank = 10 },  // Waves 4-6
    .{ .standard = 50,  .runner = 30, .tank = 20 },  // Waves 7-10
    .{ .standard = 40,  .runner = 30, .tank = 30 },  // Waves 11+
};
```

### 3.2 Name Weight Table (compile-time)

```zig
const NAME_WEIGHT_TABLE = [_]NameWeights{
    .{ .primary = 100, .trap = 0,  .compound = 0  },  // Waves 1-3
    .{ .primary = 85,  .trap = 10, .compound = 5  },  // Waves 4-7
    .{ .primary = 65,  .trap = 20, .compound = 15 },  // Waves 8-12
    .{ .primary = 50,  .trap = 25, .compound = 25 },  // Waves 13+
};
```

## 4. New Module-Level State

```zig
// Trap cluster state — drives ARD-10 cluster spawning
var trap_cluster_group: ?usize = null;       // Active trap group index
var trap_cluster_remaining: u8 = 0;          // Pending cluster spawns (0-2)
```

**Reset on**: wave transition (`resetZombies`), game restart.

## 5. Relationships

```
Wave Number ──determines──> SpawnWeights (which ZombieType to spawn)
Wave Number ──determines──> NameWeights (which name list to draw from)
ZombieType  ──determines──> speed multiplier (applied to WaveConfig.fall_speed)
ZombieType  ──constrains──> eligible name length range
NameCategory ──triggers──> trap cluster state (when category == .trap)
TrapGroup   ──provides──> cluster siblings for preferential spawning
```

## 6. Validation Rules

| Rule | Where Enforced |
|------|----------------|
| SpawnWeights fields sum to 100 | Compile-time test |
| NameWeights fields sum to 100 | Compile-time test |
| Runner names ≤ 5 characters | `selectName` filter in name_lists.zig |
| Tank names ≥ 8 characters | `selectName` filter in name_lists.zig |
| No duplicate active names | Anti-doublon check in spawnZombie |
| Max 10 retries on name collision | Counter in spawnZombie |
| All names ASCII-only, no accents | Compile-time test on name arrays |
| All compound names ≤ 20 characters | Compile-time test |
| Primary list ≥ 349 entries | Compile-time test |
| Trap groups contain 3–5 names each | Compile-time test |

## 7. State Transitions

### 7.1 Zombie Lifecycle (updated)

```
[null slot] ──spawnZombie──> [active, typed=standard/runner/tank]
   │
   ├── type selection (wave-weighted random)
   ├── name list selection (wave-weighted random)
   ├── name selection (type-length-filtered, anti-doublon)
   ├── speed = fall_speed * type_multiplier
   │
[active] ──y >= screen_height──> [dying] ──timer──> [game_over]
[active] ──name match──> [killed, slot freed]
```

### 7.2 Trap Cluster Lifecycle

```
[idle: trap_cluster_group=null, remaining=0]
   │
   ├── trap name selected for spawn
   ▼
[active: trap_cluster_group=N, remaining=2]
   │
   ├── next spawn: try same group, remaining -= 1
   ▼
[active: trap_cluster_group=N, remaining=1]
   │
   ├── next spawn: try same group, remaining -= 1
   ▼
[idle: trap_cluster_group=null, remaining=0]
```

### 7.3 Wave Progression (type introduction)

```
Waves 1-3:  100% Standard only
Wave 4:     First Runner appears (20% chance)
Wave 4:     First Tank appears (10% chance)
Waves 7-10: Mixed composition (50/30/20)
Waves 11+:  Full variety (40/30/30)
```

## 8. Impact on Existing Data

### 8.1 HighScoreRecord — NO CHANGE

The high score format (17 bytes: score/wave/wpm/accuracy) is not affected. Zombie types are a gameplay mechanic, not a persistence concern.

### 8.2 Input Buffer — WIDENED

`name` buffer at line 89 is already `[MAX_BOSS_INPUT_CHARS + 1]u8` = 36 bytes. Changing `MAX_INPUT_CHARS` from 9 to 20 only affects the write gate, not the buffer allocation.

### 8.3 Score Calculation — NO CHANGE

`calculateScore` uses `name_len` and `is_boss`, not zombie type. Standard/Runner/Tank all use `STANDARD_TYPE_MULTIPLIER` (1.0). Type-based score multipliers are out of scope.

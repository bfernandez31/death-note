// Shared zombie/name-selection types and configuration tables.
//
// Lives in its own module so name_lists.zig and main.zig can both depend on these
// declarations without forming a cycle. Per constitution: sibling modules MUST NOT
// import main.zig — shared symbols move to their own snake_case.zig.

const std = @import("std");

pub const ZombieType = enum {
    standard,
    runner,
    tank,
};

pub const GameMode = enum {
    survival,
    zen,
};

pub const PowerUpType = enum {
    freeze,
    bomb,
    shield,
};

pub const POWER_UP_DROP_CHANCE: u8 = 10;

pub const RUNNER_SPEED_MULTIPLIER: f32 = 1.8;
pub const TANK_SPEED_MULTIPLIER: f32 = 0.5;
pub const RUNNER_MAX_NAME_LEN: usize = 5;
pub const TANK_MIN_NAME_LEN: usize = 8;
pub const MAX_SPAWN_RETRIES: u32 = 10;

pub const SpawnWeights = struct {
    standard: u8,
    runner: u8,
    tank: u8,
};

pub const NameWeights = struct {
    primary: u8,
    trap: u8,
    compound: u8,
};

pub const SPAWN_WEIGHT_TABLE = [_]SpawnWeights{
    .{ .standard = 100, .runner = 0, .tank = 0 },
    .{ .standard = 70, .runner = 20, .tank = 10 },
    .{ .standard = 50, .runner = 30, .tank = 20 },
    .{ .standard = 40, .runner = 30, .tank = 30 },
};

pub const NAME_WEIGHT_TABLE = [_]NameWeights{
    .{ .primary = 100, .trap = 0, .compound = 0 },
    .{ .primary = 85, .trap = 10, .compound = 5 },
    .{ .primary = 65, .trap = 20, .compound = 15 },
    .{ .primary = 50, .trap = 25, .compound = 25 },
};

pub fn getSpawnWeights(wave: u32) SpawnWeights {
    if (wave <= 3) return SPAWN_WEIGHT_TABLE[0];
    if (wave <= 6) return SPAWN_WEIGHT_TABLE[1];
    if (wave <= 10) return SPAWN_WEIGHT_TABLE[2];
    return SPAWN_WEIGHT_TABLE[3];
}

pub fn getNameWeights(wave: u32) NameWeights {
    if (wave <= 3) return NAME_WEIGHT_TABLE[0];
    if (wave <= 7) return NAME_WEIGHT_TABLE[1];
    if (wave <= 12) return NAME_WEIGHT_TABLE[2];
    return NAME_WEIGHT_TABLE[3];
}

test "PowerUpType enum has 3 variants" {
    const fields = @typeInfo(PowerUpType).@"enum".fields;
    try std.testing.expectEqual(@as(usize, 3), fields.len);
}

test "GameMode enum has 2 variants" {
    const fields = @typeInfo(GameMode).@"enum".fields;
    try std.testing.expectEqual(@as(usize, 2), fields.len);
}

test "POWER_UP_DROP_CHANCE is 10" {
    try std.testing.expectEqual(@as(u8, 10), POWER_UP_DROP_CHANCE);
}
